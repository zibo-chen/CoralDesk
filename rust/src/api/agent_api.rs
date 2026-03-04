use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, OnceLock};
use std::time::Instant;
use tokio::sync::{Mutex as TokioMutex, RwLock};
use tokio::time::{timeout, Duration};
use tokio_util::sync::CancellationToken;

// ──────────────────────────── DTOs ────────────────────────────

/// Events emitted during agent processing, streamed to Flutter UI

#[derive(Debug, Clone)]
pub enum AgentEvent {
    /// Agent is thinking / preparing
    Thinking,
    /// Incremental text token from LLM
    TextDelta { text: String },
    /// Clear any previously streamed content (e.g., when tool calls are detected
    /// after streaming partial response that included raw tool_call tags)
    ClearStreamedContent,
    /// LLM started calling a tool
    ToolCallStart { name: String, args: String },
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

/// Global configuration (shared across all sessions)
pub(crate) struct GlobalConfig {
    pub(crate) config: Option<zeroclaw::Config>,
    /// Currently selected default profile ID (separate from default_provider)
    pub(crate) default_profile_id: Option<String>,
    /// API key for embedding provider (not in zeroclaw::Config)
    pub(crate) embedding_api_key: Option<String>,
}

pub(crate) fn global_config() -> &'static RwLock<GlobalConfig> {
    static STATE: OnceLock<RwLock<GlobalConfig>> = OnceLock::new();
    STATE.get_or_init(|| {
        RwLock::new(GlobalConfig {
            config: None,
            default_profile_id: None,
            embedding_api_key: None,
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
    pub(crate) injected_allowed_roots: Vec<String>,
}

pub(crate) fn config_state() -> &'static RwLock<ConfigState> {
    static STATE: OnceLock<RwLock<ConfigState>> = OnceLock::new();
    STATE.get_or_init(|| {
        RwLock::new(ConfigState {
            config: None,
            active_session_id: None,
            injected_allowed_roots: Vec::new(),
        })
    })
}

/// Invalidate all cached session agents (e.g., when config changes).
/// Other modules should call this instead of the old agent_handle().
pub(crate) async fn invalidate_all_agents() {
    let mut agents = session_agents().write().await;
    agents.clear();
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
    response_tx: tokio::sync::oneshot::Sender<zeroclaw::approval::ApprovalResponse>,
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
        "yes" | "y" => zeroclaw::approval::ApprovalResponse::Yes,
        "always" | "a" => zeroclaw::approval::ApprovalResponse::Always,
        _ => zeroclaw::approval::ApprovalResponse::No,
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
        "yes" | "y" => zeroclaw::approval::ApprovalResponse::Yes,
        "always" | "a" => zeroclaw::approval::ApprovalResponse::Always,
        _ => zeroclaw::approval::ApprovalResponse::No,
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

/// Load embedding_api_key from config file (custom field not in zeroclaw::Config)
async fn load_embedding_api_key(config_path: &std::path::Path) -> Option<String> {
    let content = tokio::fs::read_to_string(config_path).await.ok()?;
    let table: toml::Table = content.parse().ok()?;
    table
        .get("embedding_api_key")
        .and_then(|v| v.as_str())
        .map(String::from)
}

/// Initialize the agent runtime: load zeroclaw config from ~/.zeroclaw/config.toml.
/// Returns a status string describing what was loaded.
pub async fn init_runtime() -> String {
    crate::logging::init_rust_logging();

    match zeroclaw::Config::load_or_init().await {
        Ok(mut config) => {
            // ── Browser auto-setup: ensure agent-browser is installed ──
            let agent_browser_path = crate::api::browser_bootstrap::ensure_agent_browser().await;
            crate::api::browser_bootstrap::apply_browser_defaults(&mut config, &agent_browser_path);
            tracing::info!(
                browser_enabled = config.browser.enabled,
                browser_backend = %config.browser.backend,
                agent_browser_cmd = %config.browser.agent_browser_command,
                "Browser defaults applied"
            );

            let info = format!(
                "provider={}, model={}, has_key={}",
                config.default_provider.as_deref().unwrap_or("(none)"),
                config.default_model.as_deref().unwrap_or("(none)"),
                config.api_key.is_some(),
            );

            // Load default_profile_id from config file (not part of zeroclaw::Config)
            let default_profile_id = load_default_profile_id(&config.config_path).await;
            // Load embedding_api_key from config file (not part of zeroclaw::Config)
            let embedding_api_key = load_embedding_api_key(&config.config_path).await;

            // Update global config
            {
                let mut gc = global_config().write().await;
                gc.config = Some(config.clone());
                gc.default_profile_id = default_profile_id;
                gc.embedding_api_key = embedding_api_key;
            }

            // Also update legacy config_state for backward compatibility
            {
                let mut cs = config_state().write().await;
                cs.config = Some(config);
                cs.active_session_id = None;
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
    match &cs.config {
        Some(config) => RuntimeStatus {
            initialized: true,
            has_api_key: config.api_key.is_some(),
            provider: config
                .default_provider
                .clone()
                .unwrap_or_else(|| "openrouter".into()),
            model: config
                .default_model
                .clone()
                .unwrap_or_else(|| "anthropic/claude-sonnet-4-20250514".into()),
        },
        None => RuntimeStatus {
            initialized: false,
            has_api_key: false,
            provider: String::new(),
            model: String::new(),
        },
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

    // Handle api_base first since "compatible" provider needs it
    if let Some(base) = api_base {
        config.api_url = if base.is_empty() {
            None
        } else {
            Some(base.clone())
        };
    }
    if let Some(p) = provider {
        // Map "compatible" to zeroclaw's "custom:<url>" format
        if p == "compatible" {
            let base_url = config.api_url.clone().unwrap_or_default();
            if !base_url.is_empty() {
                config.default_provider = Some(format!("custom:{base_url}"));
            } else {
                config.default_provider = Some("compatible".into());
            }
        } else {
            config.default_provider = Some(p);
        }
    }
    if let Some(m) = model {
        config.default_model = Some(m);
    }
    if let Some(k) = api_key {
        config.api_key = if k.is_empty() { None } else { Some(k) };
    }
    if let Some(t) = temperature {
        config.default_temperature = t;
    }

    // Sync to legacy config_state
    cs.config = Some(config.clone());
    cs.active_session_id = None;
    drop(gc);
    drop(cs);

    // Invalidate ALL session agents so they get recreated with new config
    {
        let mut agents = session_agents().write().await;
        agents.clear();
    }

    "ok".into()
}

/// Persist current config to disk (~/.zeroclaw/config.toml).
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

    // Read existing TOML or start fresh
    let mut table: toml::Table = match tokio::fs::read_to_string(config_path).await {
        Ok(content) => content.parse().unwrap_or_default(),
        Err(_) => toml::Table::new(),
    };

    // Persist default_profile_id (UI-selected profile)
    if let Some(ref profile_id) = gc.default_profile_id {
        table.insert(
            "default_profile_id".into(),
            toml::Value::String(profile_id.clone()),
        );
    } else {
        table.remove("default_profile_id");
    }

    // Persist embedding_api_key (not in zeroclaw::Config)
    if let Some(ref api_key) = gc.embedding_api_key {
        table.insert(
            "embedding_api_key".into(),
            toml::Value::String(api_key.clone()),
        );
    } else {
        table.remove("embedding_api_key");
    }

    // Update the user-facing fields
    if let Some(ref provider) = config.default_provider {
        table.insert(
            "default_provider".into(),
            toml::Value::String(provider.clone()),
        );
    }
    if let Some(ref model) = config.default_model {
        table.insert("default_model".into(), toml::Value::String(model.clone()));
    }
    if let Some(ref key) = config.api_key {
        table.insert("api_key".into(), toml::Value::String(key.clone()));
    }
    if let Some(ref url) = config.api_url {
        table.insert("api_url".into(), toml::Value::String(url.clone()));
    }
    table.insert(
        "default_temperature".into(),
        toml::Value::Float(config.default_temperature),
    );

    // ── Persist feature toggles ──────────────────────────────
    // [web_search]
    let mut ws_table = table
        .get("web_search")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    ws_table.insert(
        "enabled".into(),
        toml::Value::Boolean(config.web_search.enabled),
    );
    table.insert("web_search".into(), toml::Value::Table(ws_table));

    // [web_fetch]
    let mut wf_table = table
        .get("web_fetch")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    wf_table.insert(
        "enabled".into(),
        toml::Value::Boolean(config.web_fetch.enabled),
    );
    table.insert("web_fetch".into(), toml::Value::Table(wf_table));

    // [browser] — persist full browser config for out-of-box experience
    let mut br_table = table
        .get("browser")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    br_table.insert(
        "enabled".into(),
        toml::Value::Boolean(config.browser.enabled),
    );
    br_table.insert(
        "backend".into(),
        toml::Value::String(config.browser.backend.clone()),
    );
    br_table.insert(
        "agent_browser_command".into(),
        toml::Value::String(config.browser.agent_browser_command.clone()),
    );
    if !config.browser.allowed_domains.is_empty() {
        br_table.insert(
            "allowed_domains".into(),
            toml::Value::Array(
                config
                    .browser
                    .allowed_domains
                    .iter()
                    .map(|d| toml::Value::String(d.clone()))
                    .collect(),
            ),
        );
    }
    table.insert("browser".into(), toml::Value::Table(br_table));

    // [http_request]
    let mut hr_table = table
        .get("http_request")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    hr_table.insert(
        "enabled".into(),
        toml::Value::Boolean(config.http_request.enabled),
    );
    table.insert("http_request".into(), toml::Value::Table(hr_table));

    // [memory]
    let mut mem_table = table
        .get("memory")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    mem_table.insert(
        "auto_save".into(),
        toml::Value::Boolean(config.memory.auto_save),
    );
    mem_table.insert(
        "embedding_provider".into(),
        toml::Value::String(config.memory.embedding_provider.clone()),
    );
    mem_table.insert(
        "embedding_model".into(),
        toml::Value::String(config.memory.embedding_model.clone()),
    );
    mem_table.insert(
        "embedding_dimensions".into(),
        toml::Value::Integer(config.memory.embedding_dimensions as i64),
    );
    mem_table.insert(
        "vector_weight".into(),
        toml::Value::Float(config.memory.vector_weight),
    );
    mem_table.insert(
        "keyword_weight".into(),
        toml::Value::Float(config.memory.keyword_weight),
    );
    mem_table.insert(
        "min_relevance_score".into(),
        toml::Value::Float(config.memory.min_relevance_score),
    );
    table.insert("memory".into(), toml::Value::Table(mem_table));

    // [[model_routes]]
    if !config.model_routes.is_empty() {
        let routes: Vec<toml::Value> = config
            .model_routes
            .iter()
            .map(|r| {
                let mut t = toml::Table::new();
                t.insert("hint".into(), toml::Value::String(r.hint.clone()));
                t.insert("provider".into(), toml::Value::String(r.provider.clone()));
                t.insert("model".into(), toml::Value::String(r.model.clone()));
                if let Some(ref key) = r.api_key {
                    t.insert("api_key".into(), toml::Value::String(key.clone()));
                }
                toml::Value::Table(t)
            })
            .collect();
        table.insert("model_routes".into(), toml::Value::Array(routes));
    } else {
        table.remove("model_routes");
    }

    // [[embedding_routes]]
    if !config.embedding_routes.is_empty() {
        let routes: Vec<toml::Value> = config
            .embedding_routes
            .iter()
            .map(|r| {
                let mut t = toml::Table::new();
                t.insert("hint".into(), toml::Value::String(r.hint.clone()));
                t.insert("provider".into(), toml::Value::String(r.provider.clone()));
                t.insert("model".into(), toml::Value::String(r.model.clone()));
                if let Some(dims) = r.dimensions {
                    t.insert("dimensions".into(), toml::Value::Integer(dims as i64));
                }
                if let Some(ref key) = r.api_key {
                    t.insert("api_key".into(), toml::Value::String(key.clone()));
                }
                toml::Value::Table(t)
            })
            .collect();
        table.insert("embedding_routes".into(), toml::Value::Array(routes));
    } else {
        table.remove("embedding_routes");
    }

    // [cost]
    let mut cost_table = table
        .get("cost")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    cost_table.insert("enabled".into(), toml::Value::Boolean(config.cost.enabled));
    table.insert("cost".into(), toml::Value::Table(cost_table));

    // [skills]
    let mut skills_table = table
        .get("skills")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    skills_table.insert(
        "open_skills_enabled".into(),
        toml::Value::Boolean(config.skills.open_skills_enabled),
    );
    let injection_mode = match config.skills.prompt_injection_mode {
        zeroclaw::config::SkillsPromptInjectionMode::Compact => "compact",
        _ => "full",
    };
    skills_table.insert(
        "prompt_injection_mode".into(),
        toml::Value::String(injection_mode.into()),
    );
    table.insert("skills".into(), toml::Value::Table(skills_table));

    // ── Persist autonomy / tool approval settings ────────────
    let mut autonomy_table = table
        .get("autonomy")
        .and_then(|v| v.as_table())
        .cloned()
        .unwrap_or_default();
    autonomy_table.insert(
        "trust_me".into(),
        toml::Value::Boolean(config.autonomy.trust_me),
    );
    autonomy_table.insert(
        "auto_approve".into(),
        toml::Value::Array(
            config
                .autonomy
                .auto_approve
                .iter()
                .map(|s| toml::Value::String(s.clone()))
                .collect(),
        ),
    );
    autonomy_table.insert(
        "always_ask".into(),
        toml::Value::Array(
            config
                .autonomy
                .always_ask
                .iter()
                .map(|s| toml::Value::String(s.clone()))
                .collect(),
        ),
    );
    autonomy_table.insert(
        "allowed_commands".into(),
        toml::Value::Array(
            config
                .autonomy
                .allowed_commands
                .iter()
                .map(|s| toml::Value::String(s.clone()))
                .collect(),
        ),
    );
    table.insert("autonomy".into(), toml::Value::Table(autonomy_table));

    // ── Persist model provider profiles [model_providers.<id>] ───
    let mut mp_table = toml::Table::new();
    for (id, profile) in &config.model_providers {
        // Skip invalid profiles (must have at least name or base_url)
        let has_name = profile
            .name
            .as_deref()
            .map(str::trim)
            .is_some_and(|v| !v.is_empty());
        let has_base_url = profile
            .base_url
            .as_deref()
            .map(str::trim)
            .is_some_and(|v| !v.is_empty());
        if !has_name && !has_base_url {
            continue;
        }

        let mut entry = toml::Table::new();
        if let Some(ref name) = profile.name {
            entry.insert("name".into(), toml::Value::String(name.clone()));
        }
        if let Some(ref base_url) = profile.base_url {
            entry.insert("base_url".into(), toml::Value::String(base_url.clone()));
        }
        if let Some(ref wire_api) = profile.wire_api {
            entry.insert("wire_api".into(), toml::Value::String(wire_api.clone()));
        }
        if let Some(ref model) = profile.default_model {
            entry.insert("default_model".into(), toml::Value::String(model.clone()));
        }
        if let Some(ref key) = profile.api_key {
            entry.insert("api_key".into(), toml::Value::String(key.clone()));
        }
        mp_table.insert(id.clone(), toml::Value::Table(entry));
    }
    if !mp_table.is_empty() {
        table.insert("model_providers".into(), toml::Value::Table(mp_table));
    } else {
        table.remove("model_providers");
    }

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
        if !agent_cfg.enabled {
            entry.insert("enabled".into(), toml::Value::Boolean(false));
        }
        if !agent_cfg.capabilities.is_empty() {
            entry.insert(
                "capabilities".into(),
                toml::Value::Array(
                    agent_cfg
                        .capabilities
                        .iter()
                        .map(|s| toml::Value::String(s.clone()))
                        .collect(),
                ),
            );
        }
        if agent_cfg.priority != 0 {
            entry.insert(
                "priority".into(),
                toml::Value::Integer(agent_cfg.priority as i64),
            );
        }
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
        agents_table.insert(name.clone(), toml::Value::Table(entry));
    }
    if !agents_table.is_empty() {
        table.insert("agents".into(), toml::Value::Table(agents_table));
    } else {
        table.remove("agents");
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
        let raw_provider = config
            .default_provider
            .clone()
            .unwrap_or_else(|| "openrouter".into());

        // Reverse-map zeroclaw's "custom:<url>" back to UI's "compatible"
        let (ui_provider, ui_api_base) = if raw_provider.starts_with("custom:") {
            let url = raw_provider
                .strip_prefix("custom:")
                .unwrap_or("")
                .to_string();
            ("compatible".to_string(), Some(url))
        } else {
            (raw_provider, config.api_url.clone())
        };

        super::config_api::AppConfig {
            provider: ui_provider,
            model: config
                .default_model
                .clone()
                .unwrap_or_else(|| "anthropic/claude-sonnet-4-20250514".into()),
            api_key: config.api_key.clone().unwrap_or_default(),
            api_base: ui_api_base,
            temperature: config.default_temperature,
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

/// Helper: ensure agent exists for a session, creating if needed.
/// Returns an Arc to the session's agent mutex for concurrent access.
async fn ensure_session_agent(session_id: &str) -> Result<Arc<TokioMutex<SessionAgent>>, String> {
    // 1. Read global config
    let mut config = {
        let gc = global_config().read().await;
        match &gc.config {
            Some(c) => c.clone(),
            None => return Err("Runtime not initialized. Call init_runtime() first.".into()),
        }
    };

    // 2. Check API key
    let provider_name = config.default_provider.as_deref().unwrap_or("openrouter");
    let needs_key = !matches!(provider_name, "ollama");
    if needs_key && config.api_key.is_none() {
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

    // 6. Configure session-specific workspace
    let session_workspace = dirs::home_dir()
        .unwrap_or_default()
        .join(".zeroclaw")
        .join("workspace")
        .join("session")
        .join(session_id);
    let _ = std::fs::create_dir_all(&session_workspace);

    // Symlink shared memory directory
    let global_memory_dir = config.workspace_dir.join("memory");
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

    config.workspace_dir = session_workspace;

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

    // 7. Create the agent
    let agent = zeroclaw::agent::Agent::from_config(&config)
        .map_err(|e| format!("Failed to create agent: {e}"))?;

    let session_agent = SessionAgent {
        agent,
        last_used: Instant::now(),
        injected_allowed_roots: session_files,
    };

    let agent_arc = Arc::new(TokioMutex::new(session_agent));

    // 8. Store in map
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

            events.push(AgentEvent::TextDelta { text: response });
            events.push(AgentEvent::MessageComplete {
                input_tokens: None,
                output_tokens: None,
            });
        }
        Err(e) => {
            tracing::error!("Agent turn error: {e}");
            events.push(AgentEvent::Error {
                message: e.to_string(),
            });
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
    const TURN_TIMEOUT_SECS: u64 = 180;
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

    // Create an mpsc channel for streaming deltas from zeroclaw
    // Use larger buffer to prevent backpressure during high-frequency deltas
    let (tx, mut rx) = tokio::sync::mpsc::channel::<String>(256);

    // Wrap the sink in an Arc so it can be shared with the relay task
    let sink = Arc::new(sink);
    let sink_clone = sink.clone();
    let stream_cancel_token = CancellationToken::new();
    let relay_cancel_token = stream_cancel_token.clone();

    // Store the token so Flutter can cancel via cancel_generation()
    {
        let mut tokens = active_stream_tokens().lock().await;
        tokens.insert(session_id.clone(), stream_cancel_token.clone());
    }

    // Spawn a relay task that converts zeroclaw's string-based delta protocol
    // into typed AgentEvent messages for Flutter.
    //
    // Zeroclaw sends progress deltas with sentinel prefixes:
    //   - `\x00PROGRESS\x00`      — verbose-only progress line (thinking, tool counts, retries)
    //   - `\x00PROGRESS_BLOCK\x00` — compact progress block (tool start/end lifecycle)
    //   - `\x00CLEAR\x00`         — clear accumulated progress before final answer
    //   - `\x01TOOL_RESULT\x02`   — structured tool result
    //   - plain text              — final answer chunks
    let relay_handle = tokio::spawn(async move {
        // Helper macro to send events and exit early if sink is closed
        macro_rules! send_or_break {
            ($event:expr) => {
                if sink_clone.add($event).is_err() {
                    relay_cancel_token.cancel();
                    tracing::debug!("Sink closed, relay task exiting early");
                    break;
                }
            };
        }

        while let Some(delta) = rx.recv().await {
            let trimmed = delta.trim();

            // Sentinel: clear accumulated progress (final answer coming)
            if trimmed == "\x00CLEAR\x00" {
                send_or_break!(AgentEvent::ClearStreamedContent);
                continue;
            }

            // Structured tool result: \x01TOOL_RESULT\x02name\x02success\x02output\x01
            // Sent right after ✅/❌ with the actual tool output.
            if delta.starts_with('\x01') && delta.contains("TOOL_RESULT\x02") {
                if let Some(rest) = delta
                    .trim_start_matches('\x01')
                    .strip_prefix("TOOL_RESULT\x02")
                {
                    // rest = "name\x02success\x02output\x01"
                    let rest = rest.trim_end_matches('\x01');
                    let parts: Vec<&str> = rest.splitn(3, '\x02').collect();
                    if parts.len() == 3 {
                        let name = parts[0].to_string();
                        let success = parts[1] == "true";
                        let result = parts[2].to_string();
                        send_or_break!(AgentEvent::ToolCallEnd {
                            name,
                            result,
                            success,
                        });
                    }
                }
                continue;
            }

            // Strip sentinel prefixes added by zeroclaw v0.1.7+.
            // \x00PROGRESS\x00 wraps verbose-only lines (🤔, 💬, ↻, ⚠️)
            // \x00PROGRESS_BLOCK\x00 wraps compact tool lifecycle lines (⏳, ✅, ❌)
            //
            // A PROGRESS_BLOCK may contain multiple lines (one per tool),
            // e.g. "⏳ shell: pwd\n⏳ shell: ls".  We split by newline and
            // process each line individually so every tool gets its own event.
            let is_progress_block = trimmed.starts_with("\x00PROGRESS_BLOCK\x00");
            let effective_block = if let Some(inner) = trimmed
                .strip_prefix("\x00PROGRESS_BLOCK\x00")
                .or_else(|| trimmed.strip_prefix("\x00PROGRESS\x00"))
            {
                inner.trim()
            } else {
                trimmed
            };

            // Collect lines to process.  For PROGRESS_BLOCK deltas we split
            // on newlines; for everything else we treat as a single line.
            let lines: Vec<&str> = if is_progress_block {
                effective_block
                    .lines()
                    .map(|l| l.trim())
                    .filter(|l| !l.is_empty())
                    .collect()
            } else {
                vec![effective_block]
            };

            // Track whether any line triggered a `continue` (i.e. was handled)
            let mut handled = false;

            for effective in lines {
                // Tool start: "⏳ tool_name: args" or "⏳ tool_name"
                if effective.starts_with('⏳') {
                    let rest = effective.trim_start_matches('⏳').trim();
                    let (name, args) = if let Some((n, a)) = rest.split_once(':') {
                        (n.trim().to_string(), a.trim().to_string())
                    } else {
                        (rest.to_string(), String::new())
                    };
                    send_or_break!(AgentEvent::ToolCallStart { name, args });
                    handled = true;
                    continue;
                }

                // Tool success: "✅ tool_name (Ns)"
                // Status-only; the actual result follows in the TOOL_RESULT message.
                if effective.starts_with('✅') {
                    handled = true;
                    continue;
                }

                // Tool failure: "❌ tool_name (Ns)"
                // Status-only; the actual result follows in the TOOL_RESULT message.
                if effective.starts_with('❌') {
                    handled = true;
                    continue;
                }

                // Thinking progress: "🤔 Thinking..."
                if effective.starts_with('🤔') {
                    send_or_break!(AgentEvent::Thinking);
                    handled = true;
                    continue;
                }

                // Tool call count: "💬 Got N tool call(s) ..."
                if effective.starts_with('💬') {
                    // Informational — skip or treat as thinking
                    handled = true;
                    continue;
                }

                // Retry progress: "↻ Retrying: ..."
                if effective.starts_with('↻') {
                    // Informational — skip
                    handled = true;
                    continue;
                }

                // Loop detection warning: "⚠️ Loop detected..."
                if effective.starts_with('⚠') {
                    // Informational — skip
                    handled = true;
                    continue;
                }
            } // end for each line

            if handled {
                continue;
            }

            // If the original delta had a sentinel prefix, it was a progress
            // line we didn't specifically handle above — skip it silently
            // rather than leaking raw text to the UI.
            if trimmed.starts_with('\x00') {
                continue;
            }

            // Everything else is streamed text content.
            if !delta.is_empty() {
                send_or_break!(AgentEvent::TextDelta { text: delta });
            }
        }
    });

    // Determine whether to enable desktop approval (non-trust-me mode).
    let trust_me = {
        let gc = global_config().read().await;
        gc.config
            .as_ref()
            .map(|c| c.autonomy.trust_me)
            .unwrap_or(false)
    };

    // Build the approval callback. When trust_me is OFF, this callback sends
    // a ToolApprovalRequest event to Flutter and waits for the user's decision
    // via `respond_to_tool_approval()`.
    let sink_for_approval = sink.clone();
    let session_id_for_approval = session_id.clone();
    let on_approval_fn: Option<zeroclaw::agent::loop_::OnApprovalFn> = if !trust_me {
        Some(Box::new(
            move |tool_name: String, tool_args: serde_json::Value| {
                let sink_inner = sink_for_approval.clone();
                let _session_id = session_id_for_approval.clone();
                Box::pin(async move {
                    let request_id = uuid::Uuid::new_v4().to_string();
                    let args_str = serde_json::to_string(&tool_args).unwrap_or_default();

                    // Send approval request to Flutter UI
                    let _ = sink_inner.add(AgentEvent::ToolApprovalRequest {
                        request_id: request_id.clone(),
                        name: tool_name,
                        args: args_str,
                    });

                    // Create a oneshot channel
                    let (resp_tx, resp_rx) = tokio::sync::oneshot::channel();

                    // Store in legacy slot for FRB single-argument respond_to_tool_approval
                    {
                        let mut legacy = legacy_pending_approval().lock().await;
                        *legacy = Some((
                            request_id.clone(),
                            PendingApproval {
                                response_tx: resp_tx,
                            },
                        ));
                    }

                    // Wait for Flutter to respond (with a generous timeout)
                    match tokio::time::timeout(Duration::from_secs(300), resp_rx).await {
                        Ok(Ok(decision)) => decision,
                        Ok(Err(_)) => {
                            // Channel was dropped — treat as denied
                            zeroclaw::approval::ApprovalResponse::No
                        }
                        Err(_) => {
                            // Timeout — clean up and treat as denied
                            {
                                let mut legacy = legacy_pending_approval().lock().await;
                                *legacy = None;
                            }
                            tracing::warn!("Tool approval timed out for request {request_id}");
                            zeroclaw::approval::ApprovalResponse::No
                        }
                    }
                })
            },
        ))
    } else {
        None
    };

    // Lock only this session's agent — other sessions remain unblocked
    let turn_result = {
        let mut session_agent = agent_arc.lock().await;
        session_agent.last_used = Instant::now();
        let agent = &mut session_agent.agent;
        timeout(
            Duration::from_secs(TURN_TIMEOUT_SECS),
            agent.turn_streaming(
                &enriched_message,
                tx,
                Some(stream_cancel_token.clone()),
                on_approval_fn.as_ref(),
            ),
        )
        .await
    };

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

    if stream_cancel_token.is_cancelled() {
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
        Ok(Ok(_)) => {
            tracing::info!(
                session_id = %session_id,
                "Agent turn completed successfully"
            );
            let _ = sink.add(AgentEvent::MessageComplete {
                input_tokens: None,
                output_tokens: None,
            });
        }
        Ok(Err(e)) => {
            tracing::info!(
                session_id = %session_id,
                error = %e,
                "Agent turn encountered an error"
            );
            tracing::error!("Agent turn error: {e}");
            let _ = sink.add(AgentEvent::Error {
                message: e.to_string(),
            });
        }
        Err(_) => {
            let msg =
                format!("Request timed out after {TURN_TIMEOUT_SECS} seconds. Please try again.");
            tracing::error!(
                "send_message_stream timeout for session {session_id}: {TURN_TIMEOUT_SECS}s"
            );
            let _ = sink.add(AgentEvent::Error { message: msg });
        }
    }
}

// ──────────────────── Tool Listing ────────────────────────────

/// List available tools dynamically from any agent's registered tool specs.
/// Falls back to a minimal static list if no agent is currently initialized.
///
/// Note: kept as sync (#[frb(sync)]) to match the existing FRB generated binding.
/// Uses `try_lock` to avoid blocking if agents are busy.
#[frb(sync)]
pub fn list_tools() -> Vec<ToolSpecDto> {
    // Try to get tool specs from any available session agent
    if let Ok(agents) = session_agents().try_read() {
        for (_session_id, agent_arc) in agents.iter() {
            if let Ok(session_agent) = agent_arc.try_lock() {
                return session_agent
                    .agent
                    .tool_specs()
                    .iter()
                    .map(|spec| ToolSpecDto {
                        name: spec.name.clone(),
                        description: spec.description.clone(),
                    })
                    .collect();
            }
        }
    }

    // Fallback: no agents yet or all agents are busy
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
        .join(".zeroclaw")
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
        .join(".zeroclaw")
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
