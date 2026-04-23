use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Instant;
use tokio::sync::{Mutex as TokioMutex, RwLock};
use tokio::time::{timeout, Duration};
use tokio_util::sync::CancellationToken;
use zeroclaw_api::agent::TurnEvent;
use zeroclaw_api::channel::ChannelApprovalResponse;
use zeroclaw_config::autonomy::AutonomyLevel;

fn mark_turn_activity(activity_epoch: &Instant, last_activity_ms: &AtomicU64) {
    last_activity_ms.store(
        activity_epoch.elapsed().as_millis() as u64,
        Ordering::Relaxed,
    );
}

// ──────────────────────────── DTOs ────────────────────────────

/// Events emitted during agent processing, streamed to Flutter UI

#[derive(Debug, Clone)]
pub enum AgentEvent {
    /// Agent is thinking / preparing
    Thinking,
    /// Incremental text token from LLM
    TextDelta {
        text: String,
        /// The delegate agent role producing this delta (None = main agent)
        role_name: Option<String>,
    },
    /// Clear any previously streamed content (e.g., when tool calls are detected
    /// after streaming partial response that included raw tool_call tags)
    ClearStreamedContent,
    /// LLM started calling a tool
    ToolCallStart {
        name: String,
        args: String,
        /// The delegate agent role calling this tool (None = main agent)
        role_name: Option<String>,
    },
    /// Tool call completed
    ToolCallEnd {
        name: String,
        result: String,
        success: bool,
    },
    /// Tool requires user approval before execution.
    /// Flutter should display a confirmation dialog and call
    /// `respond_to_tool_approval()` with the request_id and decision.
    ToolApprovalRequest {
        request_id: String,
        name: String,
        args: String,
    },
    /// A delegate agent role has started producing output.
    /// Emitted when the orchestrator delegates to a sub-agent.
    RoleSwitch {
        role_name: String,
        role_color: String,
        role_icon: String,
    },
    /// A delegate agent role has finished and handed off to another role.
    /// Emitted when a sub-agent completes and suggests the next agent/task.
    RoleHandoff {
        from_role: String,
        to_role: String,
        summary: String,
    },
    /// Full message generation complete
    MessageComplete {
        input_tokens: Option<u64>,
        output_tokens: Option<u64>,
    },
    /// Error during processing
    Error { message: String },
}

/// A single message in a chat session

#[derive(Debug, Clone)]
pub struct ChatMessageDto {
    pub id: String,
    pub role: String,
    pub content: String,
    pub timestamp: i64,
    pub tool_calls: Option<Vec<ToolCallDto>>,
}

/// Tool call information

#[derive(Debug, Clone)]
pub struct ToolCallDto {
    pub id: String,
    pub name: String,
    pub arguments: String,
    pub result: Option<String>,
    pub success: Option<bool>,
}

/// Chat session info

#[derive(Debug, Clone)]
pub struct ChatSessionInfo {
    pub id: String,
    pub title: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub message_count: u32,
}

/// Tool specification for UI display

#[derive(Debug, Clone)]
pub struct ToolSpecDto {
    pub name: String,
    pub description: String,
}

/// Runtime status information

#[derive(Debug, Clone)]
pub struct RuntimeStatus {
    pub initialized: bool,
    pub has_api_key: bool,
    pub provider: String,
    pub model: String,
}

// ──────────────────────── Runtime State ───────────────────────
//
// Multi-session architecture: each session has its own Agent instance,
// allowing concurrent requests across different sessions.
//
//   - `GlobalConfig` (RwLock): shared zeroclaw config
//   - `SessionAgentMap` (RwLock): session_id -> SessionAgent mapping
//   - `PendingApprovals` (TokioMutex): request_id -> approval channel mapping

/// Maximum number of cached session agents (LRU eviction when exceeded)
const MAX_SESSION_AGENTS: usize = 10;

/// Session-specific agent with metadata
pub(crate) struct SessionAgent {
    pub(crate) agent: zeroclaw::agent::Agent,
    pub(crate) last_used: Instant,
    /// Tracks which files were injected into allowed_roots for this session.
    pub(crate) injected_allowed_roots: Vec<String>,
}

#[derive(Debug, Clone)]
pub(crate) struct DelegateAgentMeta {
    pub(crate) capabilities: Vec<String>,
    pub(crate) priority: i32,
    pub(crate) enabled: bool,
    pub(crate) role_label: Option<String>,
    pub(crate) role_color: Option<String>,
    pub(crate) role_icon: Option<String>,
    pub(crate) is_preset: bool,
    pub(crate) allow_nested_delegate: bool,
}

impl Default for DelegateAgentMeta {
    fn default() -> Self {
        Self {
            capabilities: Vec::new(),
            priority: 0,
            enabled: true,
            role_label: None,
            role_color: None,
            role_icon: None,
            is_preset: false,
            allow_nested_delegate: false,
        }
    }
}

/// Global configuration (shared across all sessions)
pub(crate) struct GlobalConfig {
    pub(crate) config: Option<zeroclaw::Config>,
    /// Currently selected default profile ID (separate from default_provider)
    pub(crate) default_profile_id: Option<String>,
    /// API key for embedding provider (not in zeroclaw::Config)
    pub(crate) embedding_api_key: Option<String>,
    /// DeskClaw-specific delegate metadata not represented in zeroclaw v0.7 config.
    pub(crate) delegate_agent_meta: HashMap<String, DelegateAgentMeta>,
}

pub(crate) fn global_config() -> &'static RwLock<GlobalConfig> {
    static STATE: OnceLock<RwLock<GlobalConfig>> = OnceLock::new();
    STATE.get_or_init(|| {
        RwLock::new(GlobalConfig {
            config: None,
            default_profile_id: None,
            embedding_api_key: None,
            delegate_agent_meta: HashMap::new(),
        })
    })
}

/// Session agents map: each session has its own independent Agent
type SessionAgentMap = HashMap<String, Arc<TokioMutex<SessionAgent>>>;

pub(crate) fn session_agents() -> &'static RwLock<SessionAgentMap> {
    static AGENTS: OnceLock<RwLock<SessionAgentMap>> = OnceLock::new();
    AGENTS.get_or_init(|| RwLock::new(HashMap::new()))
}

// ──────────────────── Deprecated Compatibility ────────────────
// These are kept for backward compatibility but delegate to new architecture

pub(crate) struct ConfigState {
    pub(crate) config: Option<zeroclaw::Config>,
    pub(crate) active_session_id: Option<String>,
}

pub(crate) fn config_state() -> &'static RwLock<ConfigState> {
    static STATE: OnceLock<RwLock<ConfigState>> = OnceLock::new();
    STATE.get_or_init(|| {
        RwLock::new(ConfigState {
            config: None,
            active_session_id: None,
        })
    })
}

/// Invalidate all cached session agents (e.g., when config changes).
/// Other modules should call this instead of the old agent_handle().
pub(crate) async fn invalidate_all_agents() {
    let mut agents = session_agents().write().await;
    agents.clear();
}

/// Invalidate a specific session's cached agent (e.g., when multi-agent mode changes).
pub(crate) async fn invalidate_session_agent(session_id: &str) {
    let mut agents = session_agents().write().await;
    agents.remove(session_id);
}

// ──────────── Active Stream Cancellation Tokens ──────────────
//
// When a session is actively streaming, its CancellationToken is stored here
// so that Flutter can explicitly cancel a generation via `cancel_generation()`.

type ActiveStreamTokens = HashMap<String, CancellationToken>;

fn active_stream_tokens() -> &'static TokioMutex<ActiveStreamTokens> {
    static TOKENS: OnceLock<TokioMutex<ActiveStreamTokens>> = OnceLock::new();
    TOKENS.get_or_init(|| TokioMutex::new(HashMap::new()))
}

/// Cancel an active generation for the given session.
///
/// If the session has an active streaming request, its CancellationToken is
/// triggered, causing the agent turn and relay to stop gracefully.
/// Returns "ok" if cancelled, or an informational message if nothing was active.
pub async fn cancel_generation(session_id: String) -> String {
    let mut tokens = active_stream_tokens().lock().await;
    if let Some(token) = tokens.remove(&session_id) {
        token.cancel();
        tracing::info!(session_id = %session_id, "Generation cancelled by user");
        "ok".into()
    } else {
        "no active generation".into()
    }
}

// ──────────────── Desktop Tool Approval ──────────────────────
//
// Supports multiple concurrent approval requests (one per session).
// Each request has a unique request_id that maps to its oneshot channel.

/// Pending approval request waiting for Flutter's response.
struct PendingApproval {
    response_tx: tokio::sync::oneshot::Sender<ChannelApprovalResponse>,
}

/// Map of pending approval requests: request_id -> PendingApproval
/// Supports multiple concurrent approvals across different sessions.
type PendingApprovalsMap = HashMap<String, PendingApproval>;

/// Slot for the most recent pending approval (legacy compatibility).
/// New code should use pending_approvals() HashMap instead.
static LEGACY_PENDING_APPROVAL: OnceLock<TokioMutex<Option<(String, PendingApproval)>>> =
    OnceLock::new();

fn legacy_pending_approval() -> &'static TokioMutex<Option<(String, PendingApproval)>> {
    LEGACY_PENDING_APPROVAL.get_or_init(|| TokioMutex::new(None))
}

fn pending_approvals() -> &'static TokioMutex<PendingApprovalsMap> {
    static APPROVALS: OnceLock<TokioMutex<PendingApprovalsMap>> = OnceLock::new();
    APPROVALS.get_or_init(|| TokioMutex::new(HashMap::new()))
}

/// Respond to a pending tool approval request from Flutter UI.
/// This is the FRB-compatible single-argument version.
/// When multiple approval requests are pending, responds to the most recent one.
///
/// `decision` values: "yes", "no", "always"
pub async fn respond_to_tool_approval(decision: String) -> String {
    let response = match decision.to_lowercase().as_str() {
        "yes" | "y" => ChannelApprovalResponse::Approve,
        "always" | "a" => ChannelApprovalResponse::AlwaysApprove,
        _ => ChannelApprovalResponse::Deny,
    };

    // First try the legacy slot (most recent request)
    let mut legacy = legacy_pending_approval().lock().await;
    if let Some((_request_id, pending)) = legacy.take() {
        let _ = pending.response_tx.send(response);
        return "ok".into();
    }
    drop(legacy);

    // Fallback: try any pending request from the HashMap
    let mut approvals = pending_approvals().lock().await;
    if let Some(request_id) = approvals.keys().next().cloned() {
        if let Some(pending) = approvals.remove(&request_id) {
            let _ = pending.response_tx.send(response);
            return "ok".into();
        }
    }

    "error: no pending approval request".into()
}

/// Respond to a specific pending tool approval request by request_id.
/// Use this when the UI tracks which request to respond to.
///
/// `request_id`: the unique ID sent with ToolApprovalRequest
/// `decision` values: "yes", "no", "always"
pub async fn respond_to_tool_approval_by_id(request_id: String, decision: String) -> String {
    let response = match decision.to_lowercase().as_str() {
        "yes" | "y" => ChannelApprovalResponse::Approve,
        "always" | "a" => ChannelApprovalResponse::AlwaysApprove,
        _ => ChannelApprovalResponse::Deny,
    };

    // Check legacy slot first
    let mut legacy = legacy_pending_approval().lock().await;
    if let Some((ref stored_id, _)) = *legacy {
        if stored_id == &request_id {
            if let Some((_, pending)) = legacy.take() {
                let _ = pending.response_tx.send(response);
                return "ok".into();
            }
        }
    }
    drop(legacy);

    // Then check HashMap
    let mut approvals = pending_approvals().lock().await;
    if let Some(pending) = approvals.remove(&request_id) {
        let _ = pending.response_tx.send(response);
        "ok".into()
    } else {
        format!("error: no pending approval request with id {request_id}")
    }
}

// ──────────────────── Initialization API ──────────────────────

/// Load default_profile_id from config file (custom field not in zeroclaw::Config)
async fn load_default_profile_id(config_path: &std::path::Path) -> Option<String> {
    let content = tokio::fs::read_to_string(config_path).await.ok()?;
    let table: toml::Table = content.parse().ok()?;
    table
        .get("default_profile_id")
        .and_then(|v| v.as_str())
        .map(String::from)
}

/// Load embedding_api_key from config file (from [memory] section)
async fn load_embedding_api_key(config_path: &std::path::Path) -> Option<String> {
    let content = tokio::fs::read_to_string(config_path).await.ok()?;
    let table: toml::Table = content.parse().ok()?;
    // First try [memory].embedding_api_key (new location)
    if let Some(memory_table) = table.get("memory").and_then(|v| v.as_table()) {
        if let Some(key) = memory_table
            .get("embedding_api_key")
            .and_then(|v| v.as_str())
        {
            return Some(key.to_string());
        }
    }
    // Fallback: check top-level for backward compatibility
    table
        .get("embedding_api_key")
        .and_then(|v| v.as_str())
        .map(String::from)
}

async fn load_delegate_agent_meta(
    config_path: &std::path::Path,
) -> HashMap<String, DelegateAgentMeta> {
    let content = match tokio::fs::read_to_string(config_path).await {
        Ok(content) => content,
        Err(_) => return HashMap::new(),
    };
    let table: toml::Table = match content.parse() {
        Ok(table) => table,
        Err(_) => return HashMap::new(),
    };

    table
        .get("deskclaw_agents_meta")
        .and_then(|value| value.as_table())
        .map(|meta_table| {
            meta_table
                .iter()
                .filter_map(|(name, value)| {
                    let entry = value.as_table()?;
                    let capabilities = entry
                        .get("capabilities")
                        .and_then(|v| v.as_array())
                        .map(|items| {
                            items
                                .iter()
                                .filter_map(|item| item.as_str().map(ToOwned::to_owned))
                                .collect::<Vec<_>>()
                        })
                        .unwrap_or_default();
                    let priority = entry
                        .get("priority")
                        .and_then(|v| v.as_integer())
                        .unwrap_or(0) as i32;
                    let enabled = entry
                        .get("enabled")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);
                    let role_label = entry
                        .get("role_label")
                        .and_then(|v| v.as_str())
                        .map(ToOwned::to_owned);
                    let role_color = entry
                        .get("role_color")
                        .and_then(|v| v.as_str())
                        .map(ToOwned::to_owned);
                    let role_icon = entry
                        .get("role_icon")
                        .and_then(|v| v.as_str())
                        .map(ToOwned::to_owned);
                    let is_preset = entry
                        .get("is_preset")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false);
                    let allow_nested_delegate = entry
                        .get("allow_nested_delegate")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false);

                    Some((
                        name.clone(),
                        DelegateAgentMeta {
                            capabilities,
                            priority,
                            enabled,
                            role_label,
                            role_color,
                            role_icon,
                            is_preset,
                            allow_nested_delegate,
                        },
                    ))
                })
                .collect::<HashMap<_, _>>()
        })
        .unwrap_or_default()
}

const DEFAULT_PROVIDER_NAME: &str = "openrouter";
const DEFAULT_MODEL_NAME: &str = "anthropic/claude-sonnet-4-20250514";
const KNOWN_PROVIDER_KEYS: &[&str] = &[
    "openai",
    "anthropic",
    "google",
    "gemini",
    "azure",
    "ollama",
    "openrouter",
    "bedrock",
    "vertexai",
    "databricks",
    "mistral",
    "cerebras",
    "deepseek",
    "groq",
    "xai",
    "copilot",
    "compatible",
];

fn derive_effective_provider_key(
    profile_id: &str,
    profile: &zeroclaw::config::ModelProviderConfig,
) -> String {
    let base_url = profile
        .base_url
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let provider_name = profile
        .name
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    if let Some(url) = base_url {
        if let Some(name) = provider_name {
            let normalized = name.to_ascii_lowercase();
            if KNOWN_PROVIDER_KEYS.iter().any(|key| *key == normalized)
                && normalized != "compatible"
            {
                name.to_string()
            } else {
                format!("custom:{url}")
            }
        } else {
            format!("custom:{url}")
        }
    } else if let Some(name) = provider_name {
        name.to_string()
    } else {
        profile_id.to_string()
    }
}

fn materialize_runtime_provider(config: &mut zeroclaw::Config, selected_profile_id: Option<&str>) {
    let Some(profile_id) = selected_profile_id.or(config.providers.fallback.as_deref()) else {
        return;
    };
    let Some(profile) = config.providers.models.get(profile_id).cloned() else {
        return;
    };

    let effective_provider = derive_effective_provider_key(profile_id, &profile);
    if effective_provider != profile_id {
        config
            .providers
            .models
            .insert(effective_provider.clone(), profile);
    }
    config.providers.fallback = Some(effective_provider);
}

pub(crate) fn build_runtime_config(
    config: &zeroclaw::Config,
    selected_profile_id: Option<&str>,
) -> zeroclaw::Config {
    let mut runtime_config = config.clone();
    materialize_runtime_provider(&mut runtime_config, selected_profile_id);
    runtime_config
}

fn runtime_provider_snapshot(
    config: &zeroclaw::Config,
    selected_profile_id: Option<&str>,
) -> (String, String, Option<String>, Option<String>, Option<f64>) {
    let runtime_config = build_runtime_config(config, selected_profile_id);

    let fallback_key = runtime_config
        .providers
        .fallback
        .clone()
        .unwrap_or_else(|| DEFAULT_PROVIDER_NAME.into());
    let fallback_profile = runtime_config.providers.fallback_provider();

    let provider = if fallback_key.starts_with("custom:") {
        "compatible".to_string()
    } else {
        fallback_key.clone()
    };
    let model = fallback_profile
        .and_then(|profile| profile.model.clone())
        .unwrap_or_else(|| DEFAULT_MODEL_NAME.into());
    let api_key = fallback_profile.and_then(|profile| profile.api_key.clone());
    let api_base = if fallback_key.starts_with("custom:") {
        fallback_key.strip_prefix("custom:").map(str::to_string)
    } else {
        fallback_profile.and_then(|profile| profile.base_url.clone())
    };
    let temperature = fallback_profile.and_then(|profile| profile.temperature);

    (provider, model, api_key, api_base, temperature)
}

fn trust_me_enabled(config: &zeroclaw::Config) -> bool {
    matches!(config.autonomy.level, AutonomyLevel::Full)
}

/// Initialize the agent runtime: load zeroclaw config from ~/.coraldesk/config.toml.
/// Returns a status string describing what was loaded.
pub async fn init_runtime() -> String {
    crate::logging::init_rust_logging();

    // ── Discover and enable bundled Python & Bun runtimes ──
    let bundled = crate::bundled_runtimes::prepend_bundled_runtimes_to_path();
    if !bundled.is_empty() {
        tracing::info!(
            paths = ?bundled.iter().map(|p| p.display().to_string()).collect::<Vec<_>>(),
            "Bundled runtimes injected into PATH"
        );
    }

    match zeroclaw::Config::load_or_init().await {
        Ok(mut config) => {
            // ── Browser setup: locate bundled agent-browser & configure system browser ──
            crate::bundled_runtimes::setup_system_browser_for_playwright();
            let agent_browser_path = crate::api::browser_bootstrap::find_agent_browser();
            crate::api::browser_bootstrap::apply_browser_defaults(&mut config, &agent_browser_path);
            tracing::info!(
                browser_enabled = config.browser.enabled,
                browser_backend = %config.browser.backend,
                "Browser defaults applied"
            );

            // Load default_profile_id from config file (not part of zeroclaw::Config)
            let default_profile_id = load_default_profile_id(&config.config_path).await;
            // Load embedding_api_key from config file
            let embedding_api_key = load_embedding_api_key(&config.config_path).await;
            let delegate_agent_meta = load_delegate_agent_meta(&config.config_path).await;
            let (provider, model, api_key, _, _) =
                runtime_provider_snapshot(&config, default_profile_id.as_deref());
            let info = format!(
                "provider={}, model={}, has_key={}",
                provider,
                model,
                api_key.is_some(),
            );

            // Update global config
            {
                let mut gc = global_config().write().await;
                gc.config = Some(config.clone());
                gc.default_profile_id = default_profile_id;
                gc.embedding_api_key = embedding_api_key;
                gc.delegate_agent_meta = delegate_agent_meta;
            }

            // Also update legacy config_state for backward compatibility
            {
                let mut cs = config_state().write().await;
                cs.config = Some(config.clone());
                cs.active_session_id = None;
            }

            // Explicitly sync proxy config to zeroclaw runtime (in case apply_env_overrides
            // was called before browser defaults modified the config)
            zeroclaw::config::set_runtime_proxy_config(config.proxy.clone());

            // Clear process env proxy vars if proxy is disabled to avoid stale state
            if !config.proxy.enabled {
                zeroclaw::config::ProxyConfig::clear_process_env();
            }

            // Clear all cached session agents (they need to be recreated with new config)
            {
                let mut agents = session_agents().write().await;
                agents.clear();
            }

            tracing::info!("CoralDesk runtime initialized: {info}");
            info
        }
        Err(e) => {
            tracing::error!("Failed to load config: {e}");
            format!("error: {e}")
        }
    }
}

/// Check if the runtime has a loaded config with an API key
pub async fn get_runtime_status() -> RuntimeStatus {
    let cs = config_state().read().await;
    let selected_profile_id = global_config().read().await.default_profile_id.clone();
    match &cs.config {
        Some(config) => {
            let (provider, model, api_key, _, _) =
                runtime_provider_snapshot(config, selected_profile_id.as_deref());
            RuntimeStatus {
                initialized: true,
                has_api_key: api_key.is_some(),
                provider,
                model,
            }
        }
        None => RuntimeStatus {
            initialized: false,
            has_api_key: false,
            provider: String::new(),
            model: String::new(),
        },
    }
}

/// Reload configuration from disk into memory.
/// This is useful when the config file has been modified externally
/// (e.g., by AI tool calls like model_routing_config upsert_agent).
/// Returns "ok" on success, or an error message.
pub async fn reload_config_from_disk() -> String {
    match zeroclaw::Config::load_or_init().await {
        Ok(mut config) => {
            // Re-apply browser defaults
            let agent_browser_path = crate::api::browser_bootstrap::find_agent_browser();
            crate::api::browser_bootstrap::apply_browser_defaults(&mut config, &agent_browser_path);

            // Reload auxiliary settings from disk
            let default_profile_id = load_default_profile_id(&config.config_path).await;
            let embedding_api_key = load_embedding_api_key(&config.config_path).await;
            let delegate_agent_meta = load_delegate_agent_meta(&config.config_path).await;
            // Update global config
            {
                let mut gc = global_config().write().await;
                gc.config = Some(config.clone());
                gc.default_profile_id = default_profile_id;
                gc.embedding_api_key = embedding_api_key;
                gc.delegate_agent_meta = delegate_agent_meta;
            }

            // Update legacy config_state
            {
                let mut cs = config_state().write().await;
                cs.config = Some(config.clone());
            }

            // Sync proxy config
            zeroclaw::config::set_runtime_proxy_config(config.proxy.clone());
            if !config.proxy.enabled {
                zeroclaw::config::ProxyConfig::clear_process_env();
            }

            // Clear cached session agents so they pick up new config
            {
                let mut agents = session_agents().write().await;
                agents.clear();
            }

            tracing::info!("Config reloaded from disk");
            "ok".into()
        }
        Err(e) => {
            tracing::error!("Failed to reload config: {e}");
            format!("error: {e}")
        }
    }
}

// ──────────────────── Config Management ───────────────────────

/// Update configuration fields. Invalidates all session agents so they
/// will be recreated with the new settings on next use.
pub async fn update_config(
    provider: Option<String>,
    model: Option<String>,
    api_key: Option<String>,
    api_base: Option<String>,
    temperature: Option<f64>,
) -> String {
    // Update both global_config and legacy config_state
    let mut gc = global_config().write().await;
    let mut cs = config_state().write().await;

    let config = match gc.config.as_mut() {
        Some(c) => c,
        None => return "error: runtime not initialized".into(),
    };

    let current_fallback = config
        .providers
        .fallback
        .clone()
        .unwrap_or_else(|| DEFAULT_PROVIDER_NAME.into());
    let mut fallback_key = current_fallback;

    if let Some(ref p) = provider {
        fallback_key = if p == "compatible" {
            match api_base.as_deref().map(str::trim).filter(|s| !s.is_empty()) {
                Some(base) => format!("custom:{base}"),
                None => "compatible".into(),
            }
        } else {
            p.clone()
        };
    } else if let Some(ref base) = api_base {
        let trimmed = base.trim();
        if !trimmed.is_empty() && fallback_key == "compatible" {
            fallback_key = format!("custom:{trimmed}");
        }
    }

    let clear_selected_profile = provider.is_some();

    config.providers.fallback = Some(fallback_key.clone());
    let active_profile = config.providers.models.entry(fallback_key).or_default();
    if let Some(m) = model {
        active_profile.model = if m.is_empty() { None } else { Some(m) };
    }
    if let Some(k) = api_key {
        active_profile.api_key = if k.is_empty() { None } else { Some(k) };
    }
    if let Some(base) = api_base {
        active_profile.base_url = if base.is_empty() { None } else { Some(base) };
    }
    if let Some(t) = temperature {
        active_profile.temperature = Some(t);
    }
    // Sync to legacy config_state
    cs.config = Some(config.clone());
    cs.active_session_id = None;
    if clear_selected_profile {
        gc.default_profile_id = None;
    }
    drop(gc);
    drop(cs);

    // Invalidate ALL session agents so they get recreated with new config
    {
        let mut agents = session_agents().write().await;
        agents.clear();
    }

    "ok".into()
}

/// Persist current config to disk (~/.coraldesk/config.toml).
/// Reads the existing file, merges relevant fields, and writes back.
pub async fn save_config_to_disk() -> String {
    let cs = config_state().read().await;
    let gc = global_config().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return "error: no config loaded".into(),
    };

    let config_path = &config.config_path;
    if config_path.as_os_str().is_empty() {
        return "error: config_path not set".into();
    }

    let mut config_to_save = config.clone();
    if let Some(ref profile_id) = gc.default_profile_id {
        config_to_save.providers.fallback = Some(profile_id.clone());
    }

    let encoded = match toml::to_string_pretty(&config_to_save) {
        Ok(s) => s,
        Err(e) => return format!("error: serialize failed: {e}"),
    };
    let mut table: toml::Table = encoded.parse().unwrap_or_default();

    // Persist default_profile_id (UI-selected profile)
    if let Some(ref profile_id) = gc.default_profile_id {
        table.insert(
            "default_profile_id".into(),
            toml::Value::String(profile_id.clone()),
        );
    } else {
        table.remove("default_profile_id");
    }

    let mut mem_table = table
        .get("memory")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    if let Some(ref api_key) = gc.embedding_api_key {
        mem_table.insert(
            "embedding_api_key".into(),
            toml::Value::String(api_key.clone()),
        );
    } else {
        mem_table.remove("embedding_api_key");
    }
    table.insert("memory".into(), toml::Value::Table(mem_table));

    // ── Persist delegate agents [agents.<name>] ─────────────
    let mut agents_table = toml::Table::new();
    for (name, agent_cfg) in &config.agents {
        let mut entry = toml::Table::new();
        entry.insert(
            "provider".into(),
            toml::Value::String(agent_cfg.provider.clone()),
        );
        entry.insert("model".into(), toml::Value::String(agent_cfg.model.clone()));
        if let Some(ref sp) = agent_cfg.system_prompt {
            entry.insert("system_prompt".into(), toml::Value::String(sp.clone()));
        }
        if let Some(ref key) = agent_cfg.api_key {
            entry.insert("api_key".into(), toml::Value::String(key.clone()));
        }
        if let Some(temp) = agent_cfg.temperature {
            entry.insert("temperature".into(), toml::Value::Float(temp));
        }
        entry.insert(
            "max_depth".into(),
            toml::Value::Integer(agent_cfg.max_depth as i64),
        );
        if agent_cfg.agentic {
            entry.insert("agentic".into(), toml::Value::Boolean(true));
            entry.insert(
                "allowed_tools".into(),
                toml::Value::Array(
                    agent_cfg
                        .allowed_tools
                        .iter()
                        .map(|s| toml::Value::String(s.clone()))
                        .collect(),
                ),
            );
            entry.insert(
                "max_iterations".into(),
                toml::Value::Integer(agent_cfg.max_iterations as i64),
            );
        }
        if let Some(timeout_secs) = agent_cfg.timeout_secs {
            entry.insert(
                "timeout_secs".into(),
                toml::Value::Integer(timeout_secs as i64),
            );
        }
        if let Some(timeout_secs) = agent_cfg.agentic_timeout_secs {
            entry.insert(
                "agentic_timeout_secs".into(),
                toml::Value::Integer(timeout_secs as i64),
            );
        }
        if let Some(ref skills_directory) = agent_cfg.skills_directory {
            entry.insert(
                "skills_directory".into(),
                toml::Value::String(skills_directory.clone()),
            );
        }
        if let Some(ref memory_namespace) = agent_cfg.memory_namespace {
            entry.insert(
                "memory_namespace".into(),
                toml::Value::String(memory_namespace.clone()),
            );
        }
        agents_table.insert(name.clone(), toml::Value::Table(entry));
    }
    if !agents_table.is_empty() {
        table.insert("agents".into(), toml::Value::Table(agents_table));
    } else {
        table.remove("agents");
    }

    let mut meta_table = toml::Table::new();
    for (name, meta) in &gc.delegate_agent_meta {
        let mut entry = toml::Table::new();
        if !meta.capabilities.is_empty() {
            entry.insert(
                "capabilities".into(),
                toml::Value::Array(
                    meta.capabilities
                        .iter()
                        .map(|value| toml::Value::String(value.clone()))
                        .collect(),
                ),
            );
        }
        if meta.priority != 0 {
            entry.insert(
                "priority".into(),
                toml::Value::Integer(meta.priority as i64),
            );
        }
        if !meta.enabled {
            entry.insert("enabled".into(), toml::Value::Boolean(false));
        }
        if let Some(ref label) = meta.role_label {
            entry.insert("role_label".into(), toml::Value::String(label.clone()));
        }
        if let Some(ref color) = meta.role_color {
            entry.insert("role_color".into(), toml::Value::String(color.clone()));
        }
        if let Some(ref icon) = meta.role_icon {
            entry.insert("role_icon".into(), toml::Value::String(icon.clone()));
        }
        if meta.is_preset {
            entry.insert("is_preset".into(), toml::Value::Boolean(true));
        }
        if meta.allow_nested_delegate {
            entry.insert("allow_nested_delegate".into(), toml::Value::Boolean(true));
        }
        if !entry.is_empty() {
            meta_table.insert(name.clone(), toml::Value::Table(entry));
        }
    }
    if !meta_table.is_empty() {
        table.insert(
            "deskclaw_agents_meta".into(),
            toml::Value::Table(meta_table),
        );
    } else {
        table.remove("deskclaw_agents_meta");
    }

    // [proxy]
    let mut proxy_table = table
        .get("proxy")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    proxy_table.insert("enabled".into(), toml::Value::Boolean(config.proxy.enabled));
    if let Some(ref url) = config.proxy.http_proxy {
        proxy_table.insert("http_proxy".into(), toml::Value::String(url.clone()));
    } else {
        proxy_table.remove("http_proxy");
    }
    if let Some(ref url) = config.proxy.https_proxy {
        proxy_table.insert("https_proxy".into(), toml::Value::String(url.clone()));
    } else {
        proxy_table.remove("https_proxy");
    }
    if let Some(ref url) = config.proxy.all_proxy {
        proxy_table.insert("all_proxy".into(), toml::Value::String(url.clone()));
    } else {
        proxy_table.remove("all_proxy");
    }
    if !config.proxy.no_proxy.is_empty() {
        proxy_table.insert(
            "no_proxy".into(),
            toml::Value::Array(
                config
                    .proxy
                    .no_proxy
                    .iter()
                    .map(|s| toml::Value::String(s.clone()))
                    .collect(),
            ),
        );
    } else {
        proxy_table.remove("no_proxy");
    }
    let scope_str = match config.proxy.scope {
        zeroclaw::config::ProxyScope::Environment => "environment",
        zeroclaw::config::ProxyScope::Zeroclaw => "zeroclaw",
        zeroclaw::config::ProxyScope::Services => "services",
    };
    proxy_table.insert("scope".into(), toml::Value::String(scope_str.into()));
    if !config.proxy.services.is_empty() {
        proxy_table.insert(
            "services".into(),
            toml::Value::Array(
                config
                    .proxy
                    .services
                    .iter()
                    .map(|s| toml::Value::String(s.clone()))
                    .collect(),
            ),
        );
    } else {
        proxy_table.remove("services");
    }
    table.insert("proxy".into(), toml::Value::Table(proxy_table));

    let output = match toml::to_string_pretty(&table) {
        Ok(s) => s,
        Err(e) => return format!("error: serialize failed: {e}"),
    };

    match tokio::fs::write(config_path, output).await {
        Ok(()) => "ok".into(),
        Err(e) => format!("error: write failed: {e}"),
    }
}

/// Get the current config values as an AppConfig DTO
pub async fn get_current_config() -> super::config_api::AppConfig {
    let cs = config_state().read().await;
    if let Some(config) = &cs.config {
        let selected_profile_id = super::agent_api::global_config()
            .read()
            .await
            .default_profile_id
            .clone();
        let (ui_provider, model, api_key, ui_api_base, temperature) =
            runtime_provider_snapshot(config, selected_profile_id.as_deref());

        super::config_api::AppConfig {
            provider: ui_provider,
            model,
            api_key: api_key.unwrap_or_default(),
            api_base: ui_api_base,
            temperature: temperature.unwrap_or(0.7),
            max_tool_iterations: config.agent.max_tool_iterations as u32,
            language: "en".into(),
        }
    } else {
        super::config_api::AppConfig::default()
    }
}

// ──────────────────── Session Management ──────────────────────

/// Create a new chat session descriptor
#[frb(sync)]
pub fn create_session() -> ChatSessionInfo {
    let now = chrono::Utc::now().timestamp();
    ChatSessionInfo {
        id: uuid::Uuid::new_v4().to_string(),
        title: "New Chat".into(),
        created_at: now,
        updated_at: now,
        message_count: 0,
    }
}

/// Clear a session's agent conversation history.
/// In the new multi-session architecture, this clears only the specified session.
pub async fn clear_session_agent(session_id: String) {
    let agents = session_agents().read().await;
    if let Some(agent_arc) = agents.get(&session_id) {
        let mut agent_guard = agent_arc.lock().await;
        agent_guard.agent.clear_history();
    }
}

/// Truncate a session agent's history to keep only the first N user turns.
///
/// Used by the retry / edit flow so that the Rust-side agent history stays
/// in sync with the Flutter-side message list after truncation.
/// A "user turn" = a user message + its subsequent assistant response / tool
/// calls / tool results.  The system prompt is always preserved.
pub async fn truncate_session_agent_history(session_id: String, keep_user_turns: u32) {
    let agents = session_agents().read().await;
    if let Some(agent_arc) = agents.get(&session_id) {
        let mut agent_guard = agent_arc.lock().await;
        let mut seeded_history = Vec::new();
        let mut user_turns_seen = 0usize;

        for message in agent_guard.agent.history() {
            if let zeroclaw::providers::ConversationMessage::Chat(chat) = message {
                if chat.role == "user" {
                    if user_turns_seen >= keep_user_turns as usize {
                        break;
                    }
                    user_turns_seen += 1;
                }
                seeded_history.push(chat.clone());
            }
        }

        agent_guard.agent.clear_history();
        if !seeded_history.is_empty() {
            agent_guard.agent.seed_history(&seeded_history);
        }
    }
}

/// Clear the current/active session (legacy compatibility).
/// Now a no-op since sessions are independent.
pub async fn clear_session() {
    // Legacy: just update config_state for backward compatibility
    config_state().write().await.active_session_id = None;
}

/// Switch to a different session.
/// In the new architecture, this is mostly a no-op since each session has
/// its own agent. We just update the active_session_id for UI tracking.
pub async fn switch_session(session_id: String) {
    // Update legacy config_state for UI tracking
    config_state().write().await.active_session_id = Some(session_id);
    // No agent manipulation needed — each session has independent agent
}

/// Remove a session's cached agent (e.g., when session is deleted).
pub async fn remove_session_agent(session_id: String) {
    let mut agents = session_agents().write().await;
    agents.remove(&session_id);
}

// ──────────────────── Message Handling ────────────────────────

/// Helper: LRU eviction — remove oldest agent when we exceed MAX_SESSION_AGENTS.
async fn evict_oldest_agent_if_needed() {
    let mut agents = session_agents().write().await;
    if agents.len() >= MAX_SESSION_AGENTS {
        // Find the oldest (least recently used) session
        let mut oldest: Option<(String, Instant)> = None;
        for (sid, agent_arc) in agents.iter() {
            if let Ok(agent) = agent_arc.try_lock() {
                match &oldest {
                    None => oldest = Some((sid.clone(), agent.last_used)),
                    Some((_, oldest_time)) if agent.last_used < *oldest_time => {
                        oldest = Some((sid.clone(), agent.last_used));
                    }
                    _ => {}
                }
            }
        }
        if let Some((oldest_sid, _)) = oldest {
            tracing::info!("Evicting oldest session agent: {oldest_sid}");
            agents.remove(&oldest_sid);
        }
    }
}

/// Resolve delegate agent provider names through provider profiles.
///
/// When a delegate agent has `provider = "openai"` and the same API key as a
/// provider profile that specifies a custom `base_url`, the provider is
/// rewritten to `"custom:{base_url}"` so the delegate hits the correct endpoint.
///
/// Without this, a delegate with `provider = "openai"` would always go to
/// `api.openai.com`, even when the user configured a DashScope/compatible endpoint.
fn resolve_delegate_providers(config: &mut zeroclaw::Config) {
    let fallback_key = config.providers.fallback.clone();
    let (_, _, main_api_key, main_api_url, _) =
        runtime_provider_snapshot(config, fallback_key.as_deref());
    let main_provider = fallback_key.unwrap_or_default();
    let model_providers = config.providers.models.clone();

    for (agent_name, agent_config) in config.agents.iter_mut() {
        // Skip if already using a custom URL provider
        if agent_config.provider.starts_with("custom:")
            || agent_config.provider.starts_with("anthropic-custom:")
        {
            continue;
        }

        let agent_key = agent_config.api_key.as_deref().unwrap_or("").trim();

        // Strategy 1: Match against configured provider profiles.
        // Look for a profile whose name matches the delegate's provider type
        // AND whose api_key matches the delegate's api_key, AND has a base_url.
        let matched_url = model_providers.values().find_map(|profile| {
            let profile_name = profile.name.as_deref().unwrap_or("").trim();
            let profile_key = profile.api_key.as_deref().unwrap_or("").trim();
            let profile_url = profile.base_url.as_deref().unwrap_or("").trim();

            if !profile_url.is_empty()
                && profile_name == agent_config.provider
                && !profile_key.is_empty()
                && profile_key == agent_key
            {
                Some(profile_url.to_string())
            } else {
                None
            }
        });

        if let Some(url) = matched_url {
            tracing::info!(
                agent = agent_name,
                old_provider = %agent_config.provider,
                new_provider = %format!("custom:{url}"),
                "Resolved delegate agent provider through provider profile"
            );
            agent_config.provider = format!("custom:{url}");
            continue;
        }

        // Strategy 2: If the delegate uses the same provider and API key as the
        // fallback runtime config and a custom api_url is configured, inherit it.
        if agent_config.provider == main_provider
            && !agent_key.is_empty()
            && Some(agent_key) == main_api_key.as_deref().map(str::trim)
            && main_api_url
                .as_deref()
                .map(str::trim)
                .is_some_and(|url| !url.is_empty())
        {
            let inherited_api_url = main_api_url.as_deref().unwrap_or("").trim();
            tracing::info!(
                agent = agent_name,
                old_provider = %agent_config.provider,
                new_provider = %format!("custom:{inherited_api_url}"),
                "Resolved delegate agent provider through main config api_url"
            );
            agent_config.provider = format!("custom:{inherited_api_url}");
        }
    }
}

/// Helper: ensure agent exists for a session, creating if needed.
/// Returns an Arc to the session's agent mutex for concurrent access.
async fn ensure_session_agent(session_id: &str) -> Result<Arc<TokioMutex<SessionAgent>>, String> {
    // 1. Read global config
    let (mut config, selected_profile_id) = {
        let gc = global_config().read().await;
        match &gc.config {
            Some(c) => (c.clone(), gc.default_profile_id.clone()),
            None => return Err("Runtime not initialized. Call init_runtime() first.".into()),
        }
    };

    // 2. Check API key
    let (provider_name, _, api_key, _, _) =
        runtime_provider_snapshot(&config, selected_profile_id.as_deref());
    let needs_key = !matches!(provider_name.as_str(), "ollama");
    if needs_key && api_key.is_none() {
        return Err("No API key configured. Please set your API key in Settings → Models.".into());
    }

    // 3. Get session attached files
    let session_files = super::sessions_api::get_session_files(session_id.to_string()).await;

    // 4. Check if agent exists and is up-to-date
    {
        let agents = session_agents().read().await;
        if let Some(agent_arc) = agents.get(session_id) {
            let agent = agent_arc.lock().await;
            // Check if session files changed
            if agent.injected_allowed_roots == session_files {
                // Agent is up-to-date, return it
                drop(agent);
                return Ok(agent_arc.clone());
            }
            // Files changed, need to recreate
            tracing::info!("Session {session_id} attached files changed, recreating agent");
        }
    }

    // 5. Need to create new agent — evict oldest if at capacity
    evict_oldest_agent_if_needed().await;

    tracing::info!(
        "Creating new agent for session {session_id} with {} attached files",
        session_files.len()
    );

    // 6. Configure the default session workspace.

    // 6a. Check if this session belongs to a project and inject project context
    let session_project_id = super::project_api::get_session_project(session_id.to_string()).await;
    if let Some(ref proj_id) = session_project_id {
        if let Some(project) = super::project_api::get_project(proj_id.clone()).await {
            // Inject project directory into allowed_roots
            if !project.project_dir.is_empty() {
                let proj_dir = project.project_dir.clone();
                if !config.autonomy.allowed_roots.contains(&proj_dir) {
                    config.autonomy.allowed_roots.push(proj_dir);
                }
            }
        }
    }

    let session_workspace = dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("workspace")
        .join("session")
        .join(session_id);
    let _ = std::fs::create_dir_all(&session_workspace);
    config.workspace_dir = session_workspace.clone();

    // Symlink shared memory directory
    let global_memory_dir = dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("workspace")
        .join("memory");
    let session_memory_link = session_workspace.join("memory");
    if !session_memory_link.exists() {
        let _ = std::fs::create_dir_all(&global_memory_dir);
        #[cfg(unix)]
        {
            let _ = std::os::unix::fs::symlink(&global_memory_dir, &session_memory_link);
        }
        #[cfg(windows)]
        {
            let _ = std::os::windows::fs::symlink_dir(&global_memory_dir, &session_memory_link);
        }
    }

    // Inject session files into allowed_roots
    for file_path in &session_files {
        let path_buf = std::path::PathBuf::from(file_path);
        if !config.autonomy.allowed_roots.contains(file_path) {
            config.autonomy.allowed_roots.push(file_path.clone());
        }
        if let Some(parent) = path_buf.parent() {
            let parent_str = parent.to_string_lossy().to_string();
            if !config.autonomy.allowed_roots.contains(&parent_str) {
                config.autonomy.allowed_roots.push(parent_str);
            }
        }
    }

    // Materialize the selected profile into a valid provider key only for this
    // execution config. The stored config keeps profile ids unchanged.
    materialize_runtime_provider(&mut config, selected_profile_id.as_deref());

    // 7. Resolve delegate agent providers through provider profiles.
    //    When a delegate agent's provider + api_key matches a provider profile
    //    profile that has a custom base_url, transform the provider to
    //    "custom:{base_url}" so the delegate hits the correct API endpoint
    //    instead of the provider's default URL (e.g. api.openai.com).
    resolve_delegate_providers(&mut config);

    // 7a. In trust-me mode, allow all public domains for network-facing tools
    // without mutating the persisted config. Private/local network guards still
    // apply inside zeroclaw's URL validation layer.
    if trust_me_enabled(&config) {
        config.browser.allowed_domains = vec!["*".to_string()];
        config.http_request.allowed_domains = vec!["*".to_string()];
        config.web_fetch.allowed_domains = vec!["*".to_string()];
    }

    // 7b. Multi-agent mode: inject orchestrator identity when active.
    //     This writes orchestrator instructions to the session workspace's
    //     SOUL.md file so the agent's SystemPromptBuilder picks them up,
    //     and augments delegate agent configs with the active roles.
    {
        let ma_sessions = super::agents_api::multi_agent_sessions().read().await;
        if let Some(active_roles) = ma_sessions.get(session_id) {
            let delegate_agent_meta = global_config().read().await.delegate_agent_meta.clone();
            let roles_desc = active_roles
                .iter()
                .filter_map(|name| {
                    let meta = delegate_agent_meta.get(name).cloned().unwrap_or_default();
                    config.agents.get(name).map(|_| {
                        let label = meta.role_label.as_deref().unwrap_or(name.as_str());
                        let icon = meta.role_icon.as_deref().unwrap_or("");
                        format!(
                            "- **{icon} {label}** (`{name}`): {}",
                            if meta.capabilities.is_empty() {
                                "delegate".to_string()
                            } else {
                                meta.capabilities.join(", ")
                            }
                        )
                    })
                })
                .collect::<Vec<_>>()
                .join("\n");

            let orchestrator_prompt = format!(
                "# Team Orchestrator\n\n\
                 You are the central Orchestrator. You coordinate specialized roles that \n\
                 work under your direction. ALL communication between roles flows through \n\
                 you — roles do NOT communicate with each other directly.\n\n\
                 ## Your Team\n\
                 Use the `delegate` tool with the role name to assign tasks:\n\
                 {roles_desc}\n\n\
                 ## Context Reference System\n\
                 Every `delegate` call returns a `[context_id: N]` at the top of its output.\n\
                 To pass that output to a subsequent role, use `context_refs: [N]` instead \n\
                 of re-typing the output. The tool automatically assembles referenced contexts.\n\n\
                 Example:\n\
                 1. delegate(agent: \"architect\", prompt: \"design API\") → [context_id: 1]\n\
                 2. delegate(agent: \"coder\", prompt: \"implement API\", context_refs: [1])\n\
                    → coder receives architect's full output automatically\n\
                 3. delegate(agent: \"critic\", prompt: \"review\", context_refs: [1, 2])\n\
                    → critic sees both architect + coder outputs\n\n\
                 **Always use `context_refs`** to pass prior outputs — never re-type them.\n\n\
                 ## Your Responsibilities\n\
                 1. **Task Decomposition**: Break complex requests into role-specific subtasks\n\
                 2. **Context Routing**: Use `context_refs` to route prior outputs to roles that need them\n\
                 3. **Result Synthesis**: Combine role outputs into a coherent final result\n\
                 4. **Context Persistence**: Use `team_context` to store key findings across the session\n\n\
                 ## Workflow\n\
                 1. Analyze the user's request — determine which roles are needed\n\
                 2. Delegate to the first role with a clear task\n\
                 3. Note the `context_id` returned\n\
                 4. For subsequent roles, reference prior outputs via `context_refs`\n\
                 5. Repeat until all subtasks are complete\n\
                 6. Synthesize and present the final result to the user\n\n\
                 ## Handoff Protocol\n\
                 When a role finishes, it returns a structured handoff:\n\
                 - **Status**: done | needs-review | blocked\n\
                 - **Summary**: What was accomplished\n\
                 - **Next**: Recommended next role (if any)\n\
                 You decide whether to follow the recommendation or proceed differently.\n\n\
                 For simple tasks, engage 1-2 roles. For complex tasks, use the full pipeline.\n"
            );

            // Write orchestrator identity to the session workspace SOUL.md
            let soul_path = session_workspace.join("SOUL.md");
            let existing_soul = std::fs::read_to_string(&soul_path).unwrap_or_default();
            if !existing_soul.contains("# Team Orchestrator") {
                let combined = format!("{orchestrator_prompt}\n{existing_soul}");
                let _ = std::fs::write(&soul_path, combined);
            }
        }
    }

    // 8. Create the agent
    let agent = zeroclaw::agent::Agent::from_config(&config)
        .await
        .map_err(|e| format!("Failed to create agent: {e}"))?;

    let session_agent = SessionAgent {
        agent,
        last_used: Instant::now(),
        injected_allowed_roots: session_files,
    };

    let agent_arc = Arc::new(TokioMutex::new(session_agent));

    // 9. Store in map
    {
        let mut agents = session_agents().write().await;
        agents.insert(session_id.to_string(), agent_arc.clone());
    }

    Ok(agent_arc)
}

/// Send a message to the zeroclaw agent and get response events.
/// This calls the real LLM provider and executes tools as needed.
/// Each session has its own agent, allowing concurrent requests.
pub async fn send_message(session_id: String, message: String) -> Vec<AgentEvent> {
    // Get or create session-specific agent
    let agent_arc = match ensure_session_agent(&session_id).await {
        Ok(a) => a,
        Err(msg) => return vec![AgentEvent::Error { message: msg }],
    };

    // Enrich message with session attached files context
    let enriched_message = {
        let files = super::sessions_api::get_session_files(session_id.clone()).await;
        if files.is_empty() {
            message
        } else {
            let files_list = files
                .iter()
                .map(|f| format!("- {f}"))
                .collect::<Vec<_>>()
                .join("\n");
            format!(
                "[The user has attached the following files/directories to this session. \
                 You can read them using the file_read tool if they are relevant to the request. \
                 You decide whether and how to use them based on the user's message.]\n\
                 {files_list}\n\n{message}"
            )
        }
    };

    // Lock only this session's agent — other sessions remain unblocked
    let mut session_agent = agent_arc.lock().await;
    session_agent.last_used = Instant::now();
    let agent = &mut session_agent.agent;

    let history_before = agent.history().len();
    let mut events = Vec::new();

    match agent.turn(&enriched_message).await {
        Ok(response) => {
            // Extract tool call events from conversation history
            let history = agent.history();
            let mut tool_name_map: HashMap<String, String> = HashMap::new();

            for msg in history.iter().skip(history_before) {
                match msg {
                    zeroclaw::providers::ConversationMessage::AssistantToolCalls {
                        tool_calls,
                        ..
                    } => {
                        for tc in tool_calls {
                            tool_name_map.insert(tc.id.clone(), tc.name.clone());
                            events.push(AgentEvent::ToolCallStart {
                                name: tc.name.clone(),
                                args: truncate_str(&tc.arguments, 1000),
                                role_name: None,
                            });
                        }
                    }
                    zeroclaw::providers::ConversationMessage::ToolResults(results) => {
                        for r in results {
                            let name = tool_name_map
                                .get(&r.tool_call_id)
                                .cloned()
                                .unwrap_or_else(|| r.tool_call_id.clone());
                            events.push(AgentEvent::ToolCallEnd {
                                name,
                                result: truncate_str(&r.content, 500),
                                success: true,
                            });
                        }
                    }
                    _ => {}
                }
            }

            events.push(AgentEvent::TextDelta {
                text: response,
                role_name: None,
            });
            events.push(AgentEvent::MessageComplete {
                input_tokens: None,
                output_tokens: None,
            });
        }
        Err(e) => {
            let err_str = e.to_string();
            let is_http_error = err_str.contains("HTTP error")
                || err_str.contains("error sending request")
                || err_str.contains("connection")
                || err_str.contains("timed out");

            // Retry once for transient HTTP/connection errors
            if is_http_error {
                tracing::warn!("Agent turn HTTP error (will retry once): {e}");
                tokio::time::sleep(Duration::from_millis(2000)).await;

                match agent.turn(&enriched_message).await {
                    Ok(response) => {
                        tracing::info!("Agent turn retry succeeded");
                        let history = agent.history();
                        let mut tool_name_map: HashMap<String, String> = HashMap::new();
                        for msg in history.iter().skip(history_before) {
                            match msg {
                                zeroclaw::providers::ConversationMessage::AssistantToolCalls {
                                    tool_calls,
                                    ..
                                } => {
                                    for tc in tool_calls {
                                        tool_name_map.insert(tc.id.clone(), tc.name.clone());
                                        events.push(AgentEvent::ToolCallStart {
                                            name: tc.name.clone(),
                                            args: truncate_str(&tc.arguments, 1000),
                                            role_name: None,
                                        });
                                    }
                                }
                                zeroclaw::providers::ConversationMessage::ToolResults(results) => {
                                    for r in results {
                                        let name = tool_name_map
                                            .get(&r.tool_call_id)
                                            .cloned()
                                            .unwrap_or_else(|| r.tool_call_id.clone());
                                        events.push(AgentEvent::ToolCallEnd {
                                            name,
                                            result: truncate_str(&r.content, 500),
                                            success: true,
                                        });
                                    }
                                }
                                _ => {}
                            }
                        }
                        events.push(AgentEvent::TextDelta {
                            text: response,
                            role_name: None,
                        });
                        events.push(AgentEvent::MessageComplete {
                            input_tokens: None,
                            output_tokens: None,
                        });
                    }
                    Err(retry_err) => {
                        tracing::error!("Agent turn retry also failed: {retry_err}");
                        events.push(AgentEvent::Error {
                            message: retry_err.to_string(),
                        });
                    }
                }
            } else {
                tracing::error!("Agent turn error: {e}");
                events.push(AgentEvent::Error {
                    message: e.to_string(),
                });
            }
        }
    }

    events
}

/// Streaming version: sends agent events in real-time through a StreamSink.
///
/// Uses zeroclaw's `Agent::turn_streaming()` which delegates to the internal
/// `run_tool_call_loop` with an `on_delta` channel.  Tool-start / tool-end /
/// thinking events are streamed **as they happen**, not after the full turn
/// completes.
///
/// Each session has its own agent, allowing concurrent streaming requests
/// across different sessions.
pub async fn send_message_stream(
    session_id: String,
    message: String,
    sink: StreamSink<AgentEvent>,
) {
    const TURN_IDLE_TIMEOUT_SECS: u64 = 180;
    const TURN_IDLE_POLL_MILLIS: u64 = 1_000;
    const RELAY_DRAIN_TIMEOUT_SECS: u64 = 10;

    // Get or create session-specific agent
    let agent_arc = match ensure_session_agent(&session_id).await {
        Ok(a) => a,
        Err(msg) => {
            let _ = sink.add(AgentEvent::Error { message: msg });
            return;
        }
    };

    // Enrich message with session attached files context
    let enriched_message = {
        let files = super::sessions_api::get_session_files(session_id.clone()).await;
        if files.is_empty() {
            message
        } else {
            let files_list = files
                .iter()
                .map(|f| format!("- {f}"))
                .collect::<Vec<_>>()
                .join("\n");
            format!(
                "[The user has attached the following files/directories to this session. \
                 You can read them using the file_read tool if they are relevant to the request. \
                 You decide whether and how to use them based on the user's message.]\n\
                 {files_list}\n\n{message}"
            )
        }
    };

    let _ = sink.add(AgentEvent::Thinking);

    // Create an mpsc channel for streaming turn events from zeroclaw.
    let (tx, mut rx) = tokio::sync::mpsc::channel::<TurnEvent>(256);

    // Wrap the sink in an Arc so it can be shared with the relay task
    let sink = Arc::new(sink);
    let sink_clone = sink.clone();
    let stream_cancel_token = CancellationToken::new();
    let relay_cancel_token = stream_cancel_token.clone();
    let watchdog_done_token = CancellationToken::new();
    let activity_epoch = Arc::new(Instant::now());
    let last_activity_ms = Arc::new(AtomicU64::new(0));
    let tool_active = Arc::new(AtomicBool::new(false));
    let idle_timeout_triggered = Arc::new(AtomicBool::new(false));

    mark_turn_activity(activity_epoch.as_ref(), last_activity_ms.as_ref());

    let watchdog_handle = {
        let stream_cancel_token = stream_cancel_token.clone();
        let watchdog_done_token = watchdog_done_token.clone();
        let activity_epoch = activity_epoch.clone();
        let last_activity_ms = last_activity_ms.clone();
        let tool_active = tool_active.clone();
        let idle_timeout_triggered = idle_timeout_triggered.clone();

        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = watchdog_done_token.cancelled() => break,
                    _ = tokio::time::sleep(Duration::from_millis(TURN_IDLE_POLL_MILLIS)) => {}
                }

                if tool_active.load(Ordering::Relaxed) {
                    continue;
                }

                let now_ms = activity_epoch.elapsed().as_millis() as u64;
                let last_ms = last_activity_ms.load(Ordering::Relaxed);
                let idle_ms = now_ms.saturating_sub(last_ms);

                if idle_ms >= TURN_IDLE_TIMEOUT_SECS.saturating_mul(1_000) {
                    idle_timeout_triggered.store(true, Ordering::Relaxed);
                    stream_cancel_token.cancel();
                    tracing::warn!(
                        "send_message_stream idle timeout for session after {}s of no activity",
                        TURN_IDLE_TIMEOUT_SECS
                    );
                    break;
                }
            }
        })
    };

    // Store the token so Flutter can cancel via cancel_generation()
    {
        let mut tokens = active_stream_tokens().lock().await;
        tokens.insert(session_id.clone(), stream_cancel_token.clone());
    }

    // Relay typed turn events into the Flutter event model.
    let relay_activity_epoch = activity_epoch.clone();
    let relay_last_activity_ms = last_activity_ms.clone();
    let relay_tool_active = tool_active.clone();
    let relay_handle = tokio::spawn(async move {
        let activity_epoch = relay_activity_epoch;
        let last_activity_ms = relay_last_activity_ms;
        let tool_active = relay_tool_active;
        let agent_role_metadata: HashMap<String, (String, String, String)> = {
            let gc = global_config().read().await;
            gc.delegate_agent_meta
                .iter()
                .filter_map(|(name, meta)| {
                    let label = meta.role_label.clone().unwrap_or_else(|| name.clone());
                    let color = meta.role_color.clone().unwrap_or_default();
                    let icon = meta.role_icon.clone().unwrap_or_default();
                    if color.is_empty() && icon.is_empty() {
                        None
                    } else {
                        Some((name.clone(), (label, color, icon)))
                    }
                })
                .collect()
        };
        let mut current_role: Option<String> = None;

        macro_rules! send_or_break {
            ($event:expr) => {
                if sink_clone.add($event).is_err() {
                    relay_cancel_token.cancel();
                    tracing::debug!("Sink closed, relay task exiting early");
                    break;
                }
            };
        }

        while let Some(event) = rx.recv().await {
            mark_turn_activity(activity_epoch.as_ref(), last_activity_ms.as_ref());
            match event {
                TurnEvent::Thinking { .. } => {
                    send_or_break!(AgentEvent::Thinking);
                }
                TurnEvent::Chunk { delta } => {
                    if !delta.is_empty() {
                        send_or_break!(AgentEvent::TextDelta {
                            text: delta,
                            role_name: current_role.clone(),
                        });
                    }
                }
                TurnEvent::ToolCall { name, args } => {
                    tool_active.store(true, Ordering::Relaxed);
                    if name == "delegate" {
                        let mut resolved_key = args
                            .get("agent")
                            .and_then(|value| value.as_str())
                            .map(ToOwned::to_owned)
                            .filter(|value| value != "auto");
                        if resolved_key.is_none() && agent_role_metadata.len() == 1 {
                            resolved_key = agent_role_metadata.keys().next().cloned();
                        }
                        if let Some(agent_key) = resolved_key {
                            if let Some((label, color, icon)) = agent_role_metadata.get(&agent_key)
                            {
                                send_or_break!(AgentEvent::RoleSwitch {
                                    role_name: label.clone(),
                                    role_color: color.clone(),
                                    role_icon: icon.clone(),
                                });
                                current_role = Some(agent_key);
                            }
                        }
                    }

                    send_or_break!(AgentEvent::ToolCallStart {
                        name,
                        args: serde_json::to_string(&args).unwrap_or_default(),
                        role_name: current_role.clone(),
                    });
                }
                TurnEvent::ToolResult { name, output } => {
                    tool_active.store(false, Ordering::Relaxed);
                    if name == "delegate" {
                        if let Some(from_role) = current_role.take() {
                            let mut to_role = String::new();
                            let mut summary = String::new();
                            for line in output.lines() {
                                let trimmed_line = line.trim().trim_start_matches("- ");
                                if trimmed_line.starts_with("**Summary**:")
                                    || trimmed_line.starts_with("**Summary:**")
                                {
                                    summary = trimmed_line
                                        .trim_start_matches("**Summary**:")
                                        .trim_start_matches("**Summary:**")
                                        .trim()
                                        .to_string();
                                }
                                if trimmed_line.starts_with("**Next**:")
                                    || trimmed_line.starts_with("**Next:**")
                                {
                                    let next_text = trimmed_line
                                        .trim_start_matches("**Next**:")
                                        .trim_start_matches("**Next:**")
                                        .trim();
                                    if let Some((role, _task)) = next_text.split_once(':') {
                                        to_role = role
                                            .trim()
                                            .to_lowercase()
                                            .replace("**", "")
                                            .replace('*', "");
                                    }
                                }
                            }
                            if !to_role.is_empty() || !summary.is_empty() {
                                send_or_break!(AgentEvent::RoleHandoff {
                                    from_role,
                                    to_role,
                                    summary,
                                });
                            }
                        }
                    }

                    send_or_break!(AgentEvent::ToolCallEnd {
                        name,
                        result: output,
                        success: true,
                    });
                }
            }
        }
    });

    let turn_handle = tokio::spawn({
        let agent_arc = agent_arc.clone();
        let enriched_message = enriched_message.clone();
        async move {
            let mut session_agent = agent_arc.lock().await;
            session_agent.last_used = Instant::now();
            session_agent
                .agent
                .turn_streamed(&enriched_message, tx)
                .await
        }
    });

    let turn_abort = turn_handle.abort_handle();
    let turn_result: anyhow::Result<String> = tokio::select! {
        result = turn_handle => match result {
            Ok(result) => result,
            Err(err) => Err(anyhow::anyhow!("agent task join error: {err}")),
        },
        _ = stream_cancel_token.cancelled() => {
            turn_abort.abort();
            Err(anyhow::anyhow!("agent turn cancelled"))
        }
    };

    watchdog_done_token.cancel();
    let _ = watchdog_handle.await;

    // If relay cannot finish quickly, abort it so the stream can close.
    let relay_abort = relay_handle.abort_handle();
    if timeout(Duration::from_secs(RELAY_DRAIN_TIMEOUT_SECS), relay_handle)
        .await
        .is_err()
    {
        stream_cancel_token.cancel();
        relay_abort.abort();
        tracing::warn!(
            "send_message_stream relay drain timed out for session {session_id}; aborting relay"
        );
    }

    if stream_cancel_token.is_cancelled() && !idle_timeout_triggered.load(Ordering::Relaxed) {
        tracing::info!(
            session_id = %session_id,
            "send_message_stream cancelled because Dart sink/relay closed"
        );
        // Clean up stored token
        {
            let mut tokens = active_stream_tokens().lock().await;
            tokens.remove(&session_id);
        }
        return;
    }

    // Clean up stored token (normal completion)
    {
        let mut tokens = active_stream_tokens().lock().await;
        tokens.remove(&session_id);
    }

    match turn_result {
        Ok(_) => {
            tracing::info!(
                session_id = %session_id,
                "Agent turn completed successfully"
            );
            let _ = sink.add(AgentEvent::MessageComplete {
                input_tokens: None,
                output_tokens: None,
            });
        }
        Err(e) => {
            if idle_timeout_triggered.load(Ordering::Relaxed) {
                let msg = format!(
                    "Agent 在 {} 秒内未收到新的模型/API响应，已停止本次请求。若任务仍在正常进行，可考虑提高空闲超时。",
                    TURN_IDLE_TIMEOUT_SECS
                );
                tracing::error!(
                    "send_message_stream idle timeout for session {session_id}: {TURN_IDLE_TIMEOUT_SECS}s"
                );
                let _ = sink.add(AgentEvent::Error { message: msg });
                return;
            }

            let err_str = e.to_string();
            tracing::info!(
                session_id = %session_id,
                error = %e,
                "Agent turn encountered an error"
            );
            tracing::error!("Agent turn error: {e}");

            // Provide a more helpful message for HTTP/connection errors
            let user_message = if err_str.contains("error sending request")
                || err_str.contains("connection")
                || err_str.contains("HTTP error")
            {
                format!("网络连接错误，请重试。\n\n详情: {}", err_str)
            } else {
                err_str
            };
            let _ = sink.add(AgentEvent::Error {
                message: user_message,
            });
        }
    }
}

// ──────────────────── Tool Listing ────────────────────────────

/// List available tools.
///
/// Zeroclaw v0.7 no longer exposes the agent's internal tool registry as a
/// public API, so keep a stable UI-oriented fallback list here.
#[frb(sync)]
pub fn list_tools() -> Vec<ToolSpecDto> {
    vec![
        ToolSpecDto {
            name: "shell".into(),
            description: "Execute shell commands".into(),
        },
        ToolSpecDto {
            name: "file_read".into(),
            description: "Read file contents".into(),
        },
        ToolSpecDto {
            name: "file_write".into(),
            description: "Write content to files".into(),
        },
        ToolSpecDto {
            name: "file_edit".into(),
            description: "Edit files with search/replace".into(),
        },
        ToolSpecDto {
            name: "glob_search".into(),
            description: "Find files by glob pattern".into(),
        },
        ToolSpecDto {
            name: "content_search".into(),
            description: "Search file contents".into(),
        },
    ]
}

// ──────────────────── Session Workspace ───────────────────────

/// File entry in the session workspace
#[derive(Debug, Clone)]
pub struct SessionFileEntry {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub size: u64,
}

/// Get the workspace directory for a session
pub fn get_session_workspace_dir(session_id: String) -> String {
    dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("workspace")
        .join("session")
        .join(&session_id)
        .to_string_lossy()
        .to_string()
}

/// List files in a session's workspace directory
pub fn list_session_workspace_files(session_id: String) -> Vec<SessionFileEntry> {
    let dir = dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("workspace")
        .join("session")
        .join(&session_id);

    if !dir.exists() {
        return vec![];
    }

    let mut entries = Vec::new();
    if let Ok(read_dir) = std::fs::read_dir(&dir) {
        for entry in read_dir.flatten() {
            let metadata = entry.metadata().ok();
            let is_dir = metadata.as_ref().map(|m| m.is_dir()).unwrap_or(false);
            let size = metadata.as_ref().map(|m| m.len()).unwrap_or(0);
            entries.push(SessionFileEntry {
                name: entry.file_name().to_string_lossy().to_string(),
                path: entry.path().to_string_lossy().to_string(),
                is_dir,
                size,
            });
        }
    }
    // Sort: directories first, then by name
    entries.sort_by(|a, b| b.is_dir.cmp(&a.is_dir).then(a.name.cmp(&b.name)));
    entries
}

/// Open a file or directory with the system default application
pub fn open_in_system(path: String) -> String {
    let p = std::path::Path::new(&path);
    if !p.exists() {
        return format!("error: path does not exist: {path}");
    }
    match open::that(&path) {
        Ok(()) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Copy a file from the session workspace to a user-chosen destination.
/// Returns the destination path on success.
pub async fn copy_file_to(src: String, dst: String) -> String {
    match tokio::fs::copy(&src, &dst).await {
        Ok(_) => dst,
        Err(e) => format!("error: {e}"),
    }
}

// ──────────────────── Helpers ─────────────────────────────────

fn truncate_str(s: &str, max_len: usize) -> String {
    if s.len() > max_len {
        format!("{}…", &s[..max_len])
    } else {
        s.to_string()
    }
}
