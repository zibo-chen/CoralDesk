// No sync FRB functions needed here currently

use zeroclaw_config::autonomy::AutonomyLevel;
use zeroclaw_config::scattered_types::EmailConfig;
use zeroclaw_config::schema::{ToolFilterGroup, ToolFilterGroupMode};

// ──────────────────── Workspace Config ────────────────────────

/// Workspace configuration DTO
#[derive(Debug, Clone)]
pub struct WorkspaceConfig {
    pub workspace_dir: String,
    pub config_path: String,
}

/// Autonomy configuration DTO
#[derive(Debug, Clone)]
pub struct AutonomyConfig {
    pub level: String, // "read_only", "supervised", "full"
    pub trust_me: bool,
    pub workspace_only: bool,
    pub allowed_commands: Vec<String>,
    pub forbidden_paths: Vec<String>,
    pub max_actions_per_hour: u32,
    pub max_cost_per_day_cents: u32,
    pub require_approval_for_medium_risk: bool,
    pub block_high_risk_commands: bool,
    pub auto_approve: Vec<String>,
    pub always_ask: Vec<String>,
}

/// Agent config DTO
#[derive(Debug, Clone)]
pub struct AgentConfigDto {
    pub max_tool_iterations: u32,
    pub max_history_messages: u32,
    pub parallel_tools: bool,
    pub tool_dispatcher: String,
    pub compact_context: bool,
    pub tool_call_dedup_exempt: Vec<String>,
    pub tool_filter_groups: Vec<AgentToolFilterGroupDto>,
}

/// Agent tool-filter group DTO
#[derive(Debug, Clone)]
pub struct AgentToolFilterGroupDto {
    pub mode: String,
    pub tools: Vec<String>,
    pub keywords: Vec<String>,
    pub filter_builtins: bool,
}

/// Browser configuration DTO
#[derive(Debug, Clone)]
pub struct BrowserConfigDto {
    pub enabled: bool,
    pub backend: String,
    pub allowed_domains: Vec<String>,
    pub session_name: Option<String>,
    pub native_headless: bool,
    pub native_webdriver_url: String,
    pub native_chrome_path: Option<String>,
    pub computer_use_endpoint: String,
    pub computer_use_api_key: Option<String>,
    pub computer_use_allow_remote_endpoint: bool,
    pub computer_use_window_allowlist: Vec<String>,
    pub computer_use_max_coordinate_x: Option<i64>,
    pub computer_use_max_coordinate_y: Option<i64>,
    pub agent_browser_command: String,
    pub agent_browser_available: bool,
}

/// Gateway configuration DTO
#[derive(Debug, Clone)]
pub struct GatewayConfigDto {
    pub host: String,
    pub port: u16,
    pub require_pairing: bool,
    pub allow_public_bind: bool,
    pub trust_forwarded_headers: bool,
    pub path_prefix: Option<String>,
    pub pair_rate_limit_per_minute: u32,
    pub webhook_rate_limit_per_minute: u32,
    pub rate_limit_max_keys: u32,
    pub idempotency_ttl_secs: u64,
    pub idempotency_max_keys: u32,
    pub session_persistence: bool,
    pub session_ttl_hours: u32,
    pub web_dist_dir: Option<String>,
    pub pairing_code_length: u32,
    pub pairing_code_ttl_secs: u64,
    pub pairing_max_pending_codes: u32,
    pub pairing_max_failed_attempts: u32,
    pub pairing_lockout_secs: u64,
}

/// Memory config DTO
#[derive(Debug, Clone)]
pub struct MemoryConfigDto {
    pub backend: String,
    pub auto_save: bool,
    pub hygiene_enabled: bool,
    pub archive_after_days: u32,
    pub purge_after_days: u32,
    pub conversation_retention_days: u32,
    pub embedding_provider: String,
    pub embedding_model: String,
}

/// Cost config DTO
#[derive(Debug, Clone)]
pub struct CostConfigDto {
    pub enabled: bool,
    pub daily_limit_usd: f64,
    pub monthly_limit_usd: f64,
    pub warn_at_percent: u8,
}

/// Channel summary for listing in UI
#[derive(Debug, Clone)]
pub struct ChannelSummary {
    pub id: String,
    pub name: String,
    pub channel_type: String, // "telegram", "discord", etc.
    pub enabled: bool,
    pub description: String,
}

/// Tool info with security attributes
#[derive(Debug, Clone)]
pub struct ToolInfo {
    pub name: String,
    pub description: String,
    pub category: String,
    pub auto_approved: bool,
    pub always_ask: bool,
}

// ──────────────────── API Functions ──────────────────────────

/// Get workspace configuration
pub async fn get_workspace_config() -> WorkspaceConfig {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        WorkspaceConfig {
            workspace_dir: config.workspace_dir.to_string_lossy().to_string(),
            config_path: config.config_path.to_string_lossy().to_string(),
        }
    } else {
        WorkspaceConfig {
            workspace_dir: String::new(),
            config_path: String::new(),
        }
    }
}

/// Get autonomy settings
pub async fn get_autonomy_config() -> AutonomyConfig {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        let a = &config.autonomy;
        let level_str = serde_json::to_string(&a.level)
            .unwrap_or_else(|_| "\"supervised\"".into())
            .trim_matches('"')
            .to_string();
        let level_str: &str = &level_str;
        AutonomyConfig {
            level: level_str.into(),
            trust_me: matches!(a.level, AutonomyLevel::Full),
            workspace_only: a.workspace_only,
            allowed_commands: a.allowed_commands.clone(),
            forbidden_paths: a.forbidden_paths.clone(),
            max_actions_per_hour: a.max_actions_per_hour,
            max_cost_per_day_cents: a.max_cost_per_day_cents,
            require_approval_for_medium_risk: a.require_approval_for_medium_risk,
            block_high_risk_commands: a.block_high_risk_commands,
            auto_approve: a.auto_approve.clone(),
            always_ask: a.always_ask.clone(),
        }
    } else {
        AutonomyConfig {
            level: "supervised".into(),
            trust_me: false,
            workspace_only: true,
            allowed_commands: vec![],
            forbidden_paths: vec![],
            max_actions_per_hour: 20,
            max_cost_per_day_cents: 500,
            require_approval_for_medium_risk: true,
            block_high_risk_commands: true,
            auto_approve: vec![],
            always_ask: vec![],
        }
    }
}

/// Update autonomy level
pub async fn update_autonomy_level(level: String) -> String {
    let new_level = match serde_json::from_value(serde_json::Value::String(level.clone())) {
        Ok(l) => l,
        Err(_) => return format!("error: unknown level: {level}"),
    };
    // Update both global_config and legacy config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.autonomy.level = new_level;
        }
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        if let Some(config) = cs.config.as_mut() {
            config.autonomy.level = new_level;
        } else {
            return "error: not initialized".into();
        }
    }
    super::agent_api::invalidate_all_agents().await;
    "ok".into()
}

/// Toggle trust-me mode. When enabled, all security checks are bypassed
/// and tool calls are auto-approved without user confirmation.
pub async fn update_trust_me(enabled: bool) -> String {
    let new_level = if enabled {
        AutonomyLevel::Full
    } else {
        AutonomyLevel::Supervised
    };

    // Update both global_config and legacy config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.autonomy.level = new_level;
        }
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        if let Some(config) = cs.config.as_mut() {
            config.autonomy.level = new_level;
        } else {
            return "error: not initialized".into();
        }
    }
    // Invalidate agent so it gets recreated with new security policy
    super::agent_api::invalidate_all_agents().await;
    "ok".into()
}

/// Update allowed commands list. Replaces the entire list.
pub async fn update_allowed_commands(commands: Vec<String>) -> String {
    // Update both global_config and legacy config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.autonomy.allowed_commands = commands.clone();
        }
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        if let Some(config) = cs.config.as_mut() {
            config.autonomy.allowed_commands = commands;
        } else {
            return "error: not initialized".into();
        }
    }
    // Invalidate agent so it gets recreated with new security policy
    super::agent_api::invalidate_all_agents().await;
    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Add a single command to allowed_commands list
pub async fn add_allowed_command(command: String) -> String {
    // Update both global_config and legacy config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            if !config.autonomy.allowed_commands.contains(&command) {
                config.autonomy.allowed_commands.push(command.clone());
            }
        }
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        if let Some(config) = cs.config.as_mut() {
            if !config.autonomy.allowed_commands.contains(&command) {
                config.autonomy.allowed_commands.push(command);
            }
        } else {
            return "error: not initialized".into();
        }
    }
    // Invalidate agent so it gets recreated with new security policy
    super::agent_api::invalidate_all_agents().await;
    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Remove a single command from allowed_commands list
pub async fn remove_allowed_command(command: String) -> String {
    // Update both global_config and legacy config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.autonomy.allowed_commands.retain(|c| c != &command);
        }
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        if let Some(config) = cs.config.as_mut() {
            config.autonomy.allowed_commands.retain(|c| c != &command);
        } else {
            return "error: not initialized".into();
        }
    }
    // Invalidate agent so it gets recreated with new security policy
    super::agent_api::invalidate_all_agents().await;
    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Get agent config
pub async fn get_agent_config() -> AgentConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        let a = &config.agent;
        AgentConfigDto {
            max_tool_iterations: a.max_tool_iterations as u32,
            max_history_messages: a.max_history_messages as u32,
            parallel_tools: a.parallel_tools,
            tool_dispatcher: a.tool_dispatcher.clone(),
            compact_context: a.compact_context,
            tool_call_dedup_exempt: a.tool_call_dedup_exempt.clone(),
            tool_filter_groups: a
                .tool_filter_groups
                .iter()
                .map(tool_filter_group_to_dto)
                .collect(),
        }
    } else {
        AgentConfigDto {
            max_tool_iterations: 50,
            max_history_messages: 50,
            parallel_tools: true,
            tool_dispatcher: "auto".into(),
            compact_context: false,
            tool_call_dedup_exempt: vec![],
            tool_filter_groups: vec![],
        }
    }
}

/// Update agent settings
pub async fn update_agent_config(
    max_tool_iterations: Option<u32>,
    max_history_messages: Option<u32>,
    parallel_tools: Option<bool>,
    compact_context: Option<bool>,
    tool_call_dedup_exempt: Option<Vec<String>>,
    tool_filter_groups: Option<Vec<AgentToolFilterGroupDto>>,
) -> String {
    let parsed_tool_filter_groups = match tool_filter_groups {
        Some(groups) => {
            let mut parsed = Vec::with_capacity(groups.len());
            for group in groups {
                let parsed_group = match tool_filter_group_from_dto(group) {
                    Ok(value) => value,
                    Err(error) => return error,
                };
                parsed.push(parsed_group);
            }
            Some(parsed)
        }
        None => None,
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        if let Some(v) = max_tool_iterations {
            config.agent.max_tool_iterations = v as usize;
        }
        if let Some(v) = max_history_messages {
            config.agent.max_history_messages = v as usize;
        }
        if let Some(v) = parallel_tools {
            config.agent.parallel_tools = v;
        }
        if let Some(v) = compact_context {
            config.agent.compact_context = v;
        }
        if let Some(values) = tool_call_dedup_exempt {
            config.agent.tool_call_dedup_exempt = sanitize_string_list(values);
        }
        if let Some(groups) = parsed_tool_filter_groups {
            config.agent.tool_filter_groups = groups;
        }
    }

    let result = persist_config_state_to_disk().await;
    if result != "ok" {
        return result;
    }
    super::agent_api::invalidate_all_agents().await;
    "ok".into()
}

/// Get browser configuration
pub async fn get_browser_config() -> BrowserConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        browser_config_to_dto(config)
    } else {
        browser_config_to_dto(&zeroclaw::Config::default())
    }
}

/// Save browser configuration
pub async fn save_browser_config(config_dto: BrowserConfigDto) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        let payload = serde_json::json!({
            "enabled": config_dto.enabled,
            "backend": config_dto.backend,
            "allowed_domains": config_dto.allowed_domains,
            "session_name": config_dto.session_name,
            "native_headless": config_dto.native_headless,
            "native_webdriver_url": config_dto.native_webdriver_url,
            "native_chrome_path": config_dto.native_chrome_path,
            "computer_use_endpoint": config_dto.computer_use_endpoint,
            "computer_use_api_key": config_dto.computer_use_api_key,
            "computer_use_allow_remote_endpoint": config_dto.computer_use_allow_remote_endpoint,
            "computer_use_window_allowlist": config_dto.computer_use_window_allowlist,
            "computer_use_max_coordinate_x": config_dto.computer_use_max_coordinate_x,
            "computer_use_max_coordinate_y": config_dto.computer_use_max_coordinate_y,
        });

        if let Err(error) = apply_browser_config_value(config, &payload) {
            return error;
        }
    }

    let result = persist_config_state_to_disk().await;
    if result != "ok" {
        return result;
    }
    super::agent_api::invalidate_all_agents().await;
    "ok".into()
}

/// Get gateway configuration
pub async fn get_gateway_config() -> GatewayConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        gateway_config_to_dto(config)
    } else {
        gateway_config_to_dto(&zeroclaw::Config::default())
    }
}

/// Save gateway configuration
pub async fn save_gateway_config(config_dto: GatewayConfigDto) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        let host = config_dto.host.trim();
        if host.is_empty() {
            return "error: gateway host cannot be empty".into();
        }

        let path_prefix = match normalize_optional_string(config_dto.path_prefix) {
            Some(prefix) => {
                if !prefix.starts_with('/') {
                    return "error: gateway path prefix must start with /".into();
                }
                if prefix.len() > 1 && prefix.ends_with('/') {
                    return "error: gateway path prefix must not end with /".into();
                }
                Some(prefix)
            }
            None => None,
        };

        config.gateway.host = host.to_string();
        config.gateway.port = config_dto.port;
        config.gateway.require_pairing = config_dto.require_pairing;
        config.gateway.allow_public_bind = config_dto.allow_public_bind;
        config.gateway.trust_forwarded_headers = config_dto.trust_forwarded_headers;
        config.gateway.path_prefix = path_prefix;
        config.gateway.pair_rate_limit_per_minute = config_dto.pair_rate_limit_per_minute;
        config.gateway.webhook_rate_limit_per_minute = config_dto.webhook_rate_limit_per_minute;
        config.gateway.rate_limit_max_keys = config_dto.rate_limit_max_keys as usize;
        config.gateway.idempotency_ttl_secs = config_dto.idempotency_ttl_secs;
        config.gateway.idempotency_max_keys = config_dto.idempotency_max_keys as usize;
        config.gateway.session_persistence = config_dto.session_persistence;
        config.gateway.session_ttl_hours = config_dto.session_ttl_hours;
        config.gateway.web_dist_dir = normalize_optional_string(config_dto.web_dist_dir);
        config.gateway.pairing_dashboard.code_length = config_dto.pairing_code_length as usize;
        config.gateway.pairing_dashboard.code_ttl_secs = config_dto.pairing_code_ttl_secs;
        config.gateway.pairing_dashboard.max_pending_codes =
            config_dto.pairing_max_pending_codes as usize;
        config.gateway.pairing_dashboard.max_failed_attempts =
            config_dto.pairing_max_failed_attempts;
        config.gateway.pairing_dashboard.lockout_secs = config_dto.pairing_lockout_secs;
    }

    persist_config_state_to_disk().await
}

/// Get memory configuration
pub async fn get_memory_config() -> MemoryConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        let m = &config.memory;
        MemoryConfigDto {
            backend: m.backend.clone(),
            auto_save: m.auto_save,
            hygiene_enabled: m.hygiene_enabled,
            archive_after_days: m.archive_after_days,
            purge_after_days: m.purge_after_days,
            conversation_retention_days: m.conversation_retention_days,
            embedding_provider: m.embedding_provider.clone(),
            embedding_model: m.embedding_model.clone(),
        }
    } else {
        MemoryConfigDto {
            backend: "sqlite".into(),
            auto_save: true,
            hygiene_enabled: true,
            archive_after_days: 7,
            purge_after_days: 30,
            conversation_retention_days: 30,
            embedding_provider: "none".into(),
            embedding_model: "text-embedding-3-small".into(),
        }
    }
}

/// Get cost configuration
pub async fn get_cost_config() -> CostConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        let c = &config.cost;
        CostConfigDto {
            enabled: c.enabled,
            daily_limit_usd: c.daily_limit_usd,
            monthly_limit_usd: c.monthly_limit_usd,
            warn_at_percent: c.warn_at_percent,
        }
    } else {
        CostConfigDto {
            enabled: false,
            daily_limit_usd: 10.0,
            monthly_limit_usd: 100.0,
            warn_at_percent: 80,
        }
    }
}

/// List configured channels with their enabled status
pub async fn list_channels() -> Vec<ChannelSummary> {
    let cs = super::agent_api::config_state().read().await;
    let mut channels = Vec::new();

    if let Some(config) = &cs.config {
        let ch = &config.channels;

        channels.push(ChannelSummary {
            id: "cli".into(),
            name: "CLI".into(),
            channel_type: "cli".into(),
            enabled: ch.cli,
            description: "Terminal command-line interface".into(),
        });

        channels.push(ChannelSummary {
            id: "telegram".into(),
            name: "Telegram".into(),
            channel_type: "telegram".into(),
            enabled: ch.telegram.is_some(),
            description: "Telegram Bot integration".into(),
        });

        channels.push(ChannelSummary {
            id: "discord".into(),
            name: "Discord".into(),
            channel_type: "discord".into(),
            enabled: ch.discord.is_some(),
            description: "Discord Bot integration".into(),
        });

        channels.push(ChannelSummary {
            id: "slack".into(),
            name: "Slack".into(),
            channel_type: "slack".into(),
            enabled: ch.slack.is_some(),
            description: "Slack Bot integration".into(),
        });

        channels.push(ChannelSummary {
            id: "matrix".into(),
            name: "Matrix".into(),
            channel_type: "matrix".into(),
            enabled: ch.matrix.is_some(),
            description: "Matrix (Element) integration".into(),
        });

        channels.push(ChannelSummary {
            id: "webhook".into(),
            name: "Webhook".into(),
            channel_type: "webhook".into(),
            enabled: ch.webhook.is_some(),
            description: "HTTP Webhook endpoint".into(),
        });

        channels.push(ChannelSummary {
            id: "email".into(),
            name: "Email".into(),
            channel_type: "email".into(),
            enabled: ch.email.is_some(),
            description: "Email (SMTP/IMAP) integration".into(),
        });

        channels.push(ChannelSummary {
            id: "lark".into(),
            name: "Lark / Feishu".into(),
            channel_type: "lark".into(),
            enabled: ch.lark.is_some() || ch.feishu.is_some(),
            description: "Lark / Feishu Bot integration".into(),
        });

        channels.push(ChannelSummary {
            id: "dingtalk".into(),
            name: "DingTalk".into(),
            channel_type: "dingtalk".into(),
            enabled: ch.dingtalk.is_some(),
            description: "DingTalk Bot integration".into(),
        });

        channels.push(ChannelSummary {
            id: "whatsapp".into(),
            name: "WhatsApp".into(),
            channel_type: "whatsapp".into(),
            enabled: ch.whatsapp.is_some(),
            description: "WhatsApp Cloud / Web integration".into(),
        });

        channels.push(ChannelSummary {
            id: "signal".into(),
            name: "Signal".into(),
            channel_type: "signal".into(),
            enabled: ch.signal.is_some(),
            description: "Signal Messenger integration".into(),
        });

        channels.push(ChannelSummary {
            id: "irc".into(),
            name: "IRC".into(),
            channel_type: "irc".into(),
            enabled: ch.irc.is_some(),
            description: "IRC chat integration".into(),
        });
    }

    channels
}

/// List tools with their approval status based on autonomy config
pub async fn list_tools_with_status() -> Vec<ToolInfo> {
    let cs = super::agent_api::config_state().read().await;
    let (auto_approve, always_ask) = if let Some(config) = &cs.config {
        (
            config.autonomy.auto_approve.clone(),
            config.autonomy.always_ask.clone(),
        )
    } else {
        (vec![], vec![])
    };

    let tools = vec![
        ("shell", "Execute shell commands", "core"),
        ("file_read", "Read file contents", "core"),
        ("file_write", "Write content to files", "core"),
        ("file_edit", "Edit files with search/replace", "core"),
        ("glob_search", "Find files by glob pattern", "core"),
        ("content_search", "Search file contents", "core"),
        ("git_operations", "Git version control", "vcs"),
        ("web_search", "Search the web", "web"),
        ("web_fetch", "Fetch webpage content", "web"),
        ("http_request", "HTTP API requests", "web"),
        ("browser", "Browser automation", "web"),
        ("memory_store", "Store in memory", "memory"),
        ("memory_recall", "Recall from memory", "memory"),
        ("memory_forget", "Remove from memory", "memory"),
        ("screenshot", "Take screenshots", "system"),
        ("pdf_read", "Extract PDF text", "file"),
        ("image_info", "Image metadata", "file"),
        ("schedule", "Schedule future tasks", "system"),
        ("delegate", "Delegate task to sub-agent", "agent"),
        ("cron_add", "Add cron job", "cron"),
        ("cron_list", "List cron jobs", "cron"),
        ("cron_remove", "Remove cron job", "cron"),
    ];

    tools
        .into_iter()
        .map(|(name, desc, cat)| ToolInfo {
            name: name.to_string(),
            description: desc.to_string(),
            category: cat.to_string(),
            auto_approved: auto_approve.contains(&name.to_string()),
            always_ask: always_ask.contains(&name.to_string()),
        })
        .collect()
}

/// Toggle a tool's approval status: "auto", "ask", or "default"
pub async fn set_tool_approval(tool_name: String, approval: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        // Remove from both lists first
        config.autonomy.auto_approve.retain(|t| t != &tool_name);
        config.autonomy.always_ask.retain(|t| t != &tool_name);

        // Add to the appropriate list
        match approval.as_str() {
            "auto" => config.autonomy.auto_approve.push(tool_name),
            "ask" => config.autonomy.always_ask.push(tool_name),
            _ => {} // "default" — removed from both
        }
    }
    // Invalidate agent
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Batch update tool approvals: set multiple tools at once
pub async fn batch_set_tool_approvals(
    auto_approve: Vec<String>,
    always_ask: Vec<String>,
) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        config.autonomy.auto_approve = auto_approve;
        config.autonomy.always_ask = always_ask;
    }
    super::agent_api::invalidate_all_agents().await;

    super::agent_api::save_config_to_disk().await
}

/// Get feature toggles for quick configuration
pub async fn get_feature_toggles() -> FeatureToggles {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        FeatureToggles {
            web_search_enabled: config.web_search.enabled,
            web_fetch_enabled: config.web_fetch.enabled,
            browser_enabled: config.browser.enabled,
            http_request_enabled: config.http_request.enabled,
            memory_auto_save: config.memory.auto_save,
            cost_tracking_enabled: config.cost.enabled,
            skills_open_enabled: config.skills.open_skills_enabled,
        }
    } else {
        FeatureToggles::default()
    }
}

/// Update a single feature toggle
pub async fn update_feature_toggle(feature: String, enabled: bool) -> String {
    let mut gc = super::agent_api::global_config().write().await;
    let mut cs = super::agent_api::config_state().write().await;

    let config = match gc.config.as_mut() {
        Some(c) => c,
        None => return "error: not initialized".into(),
    };

    match feature.as_str() {
        "web_search" => config.web_search.enabled = enabled,
        "web_fetch" => config.web_fetch.enabled = enabled,
        "browser" => config.browser.enabled = enabled,
        "http_request" => config.http_request.enabled = enabled,
        "memory_auto_save" => config.memory.auto_save = enabled,
        "cost_tracking" => config.cost.enabled = enabled,
        "skills_open" => config.skills.open_skills_enabled = enabled,
        _ => return format!("error: unknown feature: {feature}"),
    }

    cs.config = Some(config.clone());

    drop(gc);
    drop(cs);

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Feature toggle state for quick configuration
#[derive(Debug, Clone)]
pub struct FeatureToggles {
    pub web_search_enabled: bool,
    pub web_fetch_enabled: bool,
    pub browser_enabled: bool,
    pub http_request_enabled: bool,
    pub memory_auto_save: bool,
    pub cost_tracking_enabled: bool,
    pub skills_open_enabled: bool,
}

impl Default for FeatureToggles {
    fn default() -> Self {
        Self {
            web_search_enabled: false,
            web_fetch_enabled: false,
            browser_enabled: false,
            http_request_enabled: false,
            memory_auto_save: true,
            cost_tracking_enabled: false,
            skills_open_enabled: false,
        }
    }
}

// ──────────────────── Tool Config API ──────────────────────────

/// Get tool configuration fields (returns JSON string for flexibility)
pub async fn get_tool_config(tool_name: String) -> String {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return "{}".into(),
    };

    match tool_name.as_str() {
        "web_search" => {
            let cfg = &config.web_search;
            let api_key = match cfg.provider.as_str() {
                "brave" => cfg.brave_api_key.clone(),
                _ => None,
            };
            let api_url = match cfg.provider.as_str() {
                "searxng" => cfg.searxng_instance_url.clone(),
                _ => None,
            };

            serde_json::json!({
                "enabled": cfg.enabled,
                "provider": cfg.provider,
                "api_key": api_key,
                "api_url": api_url,
            })
        }
        "web_fetch" => {
            let cfg = &config.web_fetch;
            serde_json::json!({
                "enabled": cfg.enabled,
                "provider": if cfg.firecrawl.enabled { "firecrawl" } else { "default" },
                "api_key": "",
                "api_url": cfg.firecrawl.api_url,
                "allowed_domains": cfg.allowed_domains,
                "blocked_domains": cfg.blocked_domains,
            })
        }
        "browser" => {
            let cfg = &config.browser;
            let agent_browser_command = crate::api::browser_bootstrap::find_agent_browser();
            serde_json::json!({
                "enabled": cfg.enabled,
                "backend": cfg.backend,
                "agent_browser_command": if agent_browser_command.starts_with("error:") {
                    "".to_string()
                } else {
                    agent_browser_command.clone()
                },
                "agent_browser_available": !agent_browser_command.starts_with("error:"),
                "allowed_domains": cfg.allowed_domains,
                "session_name": cfg.session_name,
                "native_headless": cfg.native_headless,
                "native_webdriver_url": cfg.native_webdriver_url,
                "native_chrome_path": cfg.native_chrome_path,
                "computer_use_endpoint": cfg.computer_use.endpoint,
                "computer_use_api_key": cfg.computer_use.api_key,
                "computer_use_allow_remote_endpoint": cfg.computer_use.allow_remote_endpoint,
                "computer_use_window_allowlist": cfg.computer_use.window_allowlist,
                "computer_use_max_coordinate_x": cfg.computer_use.max_coordinate_x,
                "computer_use_max_coordinate_y": cfg.computer_use.max_coordinate_y,
            })
        }
        "http_request" => {
            let cfg = &config.http_request;
            serde_json::json!({
                "enabled": cfg.enabled,
                "allowed_domains": cfg.allowed_domains,
            })
        }
        _ => serde_json::json!({}),
    }
    .to_string()
}

/// Save tool configuration from JSON string
pub async fn save_tool_config(tool_name: String, config_json: String) -> String {
    let val: serde_json::Value = match serde_json::from_str(&config_json) {
        Ok(v) => v,
        Err(e) => return format!("error: invalid JSON: {e}"),
    };

    let mut gc = super::agent_api::global_config().write().await;
    let mut cs = super::agent_api::config_state().write().await;
    let config = match gc.config.as_mut() {
        Some(c) => c,
        None => return "error: not initialized".into(),
    };

    match tool_name.as_str() {
        "web_search" => {
            let provider = val
                .get("provider")
                .and_then(|v| v.as_str())
                .unwrap_or("duckduckgo")
                .trim()
                .to_ascii_lowercase();

            let provider = match provider.as_str() {
                "duckduckgo" | "ddg" => "duckduckgo",
                "brave" => "brave",
                "searxng" => "searxng",
                _ => return format!("error: unsupported web_search provider: {provider}"),
            };

            let api_key = val
                .get("api_key")
                .and_then(|v| v.as_str())
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());
            let api_url = val
                .get("api_url")
                .and_then(|v| v.as_str())
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());

            config.web_search.enabled = val
                .get("enabled")
                .and_then(|v| v.as_bool())
                .unwrap_or(config.web_search.enabled);
            config.web_search.provider = provider.to_string();
            config.web_search.brave_api_key = None;
            config.web_search.searxng_instance_url = None;

            match provider {
                "brave" => config.web_search.brave_api_key = api_key,
                "searxng" => config.web_search.searxng_instance_url = api_url,
                _ => {}
            }
        }
        "web_fetch" => {
            let provider = val
                .get("provider")
                .and_then(|v| v.as_str())
                .unwrap_or("fast_html2md")
                .trim()
                .to_ascii_lowercase();

            let firecrawl_enabled = match provider.as_str() {
                "default" | "fast_html2md" | "nanohtml2text" => false,
                "firecrawl" => true,
                _ => return format!("error: unsupported web_fetch provider: {provider}"),
            };

            config.web_fetch.enabled = val
                .get("enabled")
                .and_then(|v| v.as_bool())
                .unwrap_or(config.web_fetch.enabled);
            config.web_fetch.firecrawl.enabled = firecrawl_enabled;
            if let Some(api_url) = val
                .get("api_url")
                .and_then(|v| v.as_str())
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string())
            {
                config.web_fetch.firecrawl.api_url = api_url;
            }
            if val.get("allowed_domains").is_some() {
                config.web_fetch.allowed_domains = json_str_array(&val, "allowed_domains");
            }
            if val.get("blocked_domains").is_some() {
                config.web_fetch.blocked_domains = json_str_array(&val, "blocked_domains");
            }
        }
        "browser" => {
            if let Err(error) = apply_browser_config_value(config, &val) {
                return error;
            }
        }
        "http_request" => {
            config.http_request.enabled = val
                .get("enabled")
                .and_then(|v| v.as_bool())
                .unwrap_or(config.http_request.enabled);
            if val.get("allowed_domains").is_some() {
                config.http_request.allowed_domains = json_str_array(&val, "allowed_domains");
            }
        }
        _ => return format!("error: unknown tool config: {tool_name}"),
    }

    cs.config = Some(config.clone());

    drop(gc);
    drop(cs);

    super::agent_api::invalidate_all_agents().await;
    save_tool_config_to_disk().await
}

// ──────────────────── Channel Config API ────────────────────────

/// A channel configuration field for display/edit in the GUI
#[derive(Debug, Clone)]
pub struct ChannelConfigField {
    pub key: String,
    pub value: String,
    pub field_type: String, // "text", "bool", "text_list", "number", "password"
    pub required: bool,
    pub label: String,
    pub description: String,
}

/// Get channel configuration fields (returns JSON string for flexibility)
pub async fn get_channel_config(channel_type: String) -> String {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return "{}".into(),
    };
    let ch = &config.channels;

    match channel_type.as_str() {
        "telegram" => {
            if let Some(tc) = &ch.telegram {
                serde_json::json!({
                    "bot_token": tc.bot_token,
                    "allowed_users": tc.allowed_users,
                    "mention_only": tc.mention_only,
                })
            } else {
                serde_json::json!({
                    "bot_token": "",
                    "allowed_users": [],
                    "mention_only": false,
                })
            }
        }
        "discord" => {
            if let Some(dc) = &ch.discord {
                serde_json::json!({
                    "bot_token": dc.bot_token,
                    "guild_id": dc.guild_id,
                    "allowed_users": dc.allowed_users,
                    "listen_to_bots": dc.listen_to_bots,
                    "mention_only": dc.mention_only,
                })
            } else {
                serde_json::json!({
                    "bot_token": "",
                    "guild_id": "",
                    "allowed_users": [],
                    "listen_to_bots": false,
                    "mention_only": false,
                })
            }
        }
        "slack" => {
            if let Some(sc) = &ch.slack {
                serde_json::json!({
                    "bot_token": sc.bot_token,
                    "app_token": sc.app_token,
                    "channel_id": sc.channel_ids.first().cloned().unwrap_or_default(),
                    "allowed_users": sc.allowed_users,
                })
            } else {
                serde_json::json!({
                    "bot_token": "",
                    "app_token": "",
                    "channel_id": "",
                    "allowed_users": [],
                })
            }
        }
        "webhook" => {
            if let Some(wc) = &ch.webhook {
                serde_json::json!({
                    "port": wc.port,
                    "secret": wc.secret,
                })
            } else {
                serde_json::json!({
                    "port": 8080,
                    "secret": "",
                })
            }
        }
        "email" => {
            if let Some(ec) = &ch.email {
                serde_json::json!({
                    "imap_host": ec.imap_host,
                    "imap_port": ec.imap_port,
                    "smtp_host": ec.smtp_host,
                    "smtp_port": ec.smtp_port,
                    "smtp_tls": ec.smtp_tls,
                    "username": ec.username,
                    "password": ec.password,
                    "from_address": ec.from_address,
                    "allowed_senders": ec.allowed_senders,
                })
            } else {
                serde_json::json!({
                    "imap_host": "",
                    "imap_port": 993,
                    "smtp_host": "",
                    "smtp_port": 465,
                    "smtp_tls": true,
                    "username": "",
                    "password": "",
                    "from_address": "",
                    "allowed_senders": [],
                })
            }
        }
        "lark" => {
            if let Some(lc) = &ch.lark {
                serde_json::json!({
                    "app_id": lc.app_id,
                    "app_secret": lc.app_secret,
                    "allowed_users": lc.allowed_users,
                    "mention_only": lc.mention_only,
                })
            } else {
                serde_json::json!({
                    "app_id": "",
                    "app_secret": "",
                    "allowed_users": [],
                    "mention_only": false,
                })
            }
        }
        "dingtalk" => {
            if let Some(dc) = &ch.dingtalk {
                serde_json::json!({
                    "client_id": dc.client_id,
                    "client_secret": dc.client_secret,
                    "allowed_users": dc.allowed_users,
                })
            } else {
                serde_json::json!({
                    "client_id": "",
                    "client_secret": "",
                    "allowed_users": [],
                })
            }
        }
        "matrix" => {
            if let Some(mc) = &ch.matrix {
                serde_json::json!({
                    "homeserver": mc.homeserver,
                    "user_id": mc.user_id,
                    "access_token": mc.access_token,
                    "room_id": mc.allowed_rooms.first().cloned().unwrap_or_default(),
                    "allowed_users": mc.allowed_users,
                })
            } else {
                serde_json::json!({
                    "homeserver": "",
                    "user_id": "",
                    "access_token": "",
                    "room_id": "",
                    "allowed_users": [],
                })
            }
        }
        "signal" => {
            if let Some(sc) = &ch.signal {
                serde_json::json!({
                    "http_url": sc.http_url,
                    "account": sc.account,
                    "group_id": sc.group_id,
                    "allowed_from": sc.allowed_from,
                })
            } else {
                serde_json::json!({
                    "http_url": "",
                    "account": "",
                    "group_id": "",
                    "allowed_from": [],
                })
            }
        }
        "whatsapp" => {
            if let Some(wc) = &ch.whatsapp {
                serde_json::json!({
                    "phone_number_id": wc.phone_number_id,
                    "access_token": wc.access_token,
                    "verify_token": wc.verify_token,
                    "allowed_numbers": wc.allowed_numbers,
                })
            } else {
                serde_json::json!({
                    "phone_number_id": "",
                    "access_token": "",
                    "verify_token": "",
                    "allowed_numbers": [],
                })
            }
        }
        "irc" => {
            if let Some(ic) = &ch.irc {
                serde_json::json!({
                    "server": ic.server,
                    "port": ic.port,
                    "nickname": ic.nickname,
                    "channels": ic.channels,
                    "allowed_users": ic.allowed_users,
                    "verify_tls": ic.verify_tls,
                    "server_password": ic.server_password,
                })
            } else {
                serde_json::json!({
                    "server": "",
                    "port": 6697,
                    "nickname": "",
                    "channels": [],
                    "allowed_users": [],
                    "verify_tls": true,
                    "server_password": "",
                })
            }
        }
        "cli" => {
            serde_json::json!({
                "enabled": ch.cli,
            })
        }
        _ => serde_json::json!({}),
    }
    .to_string()
}

/// Save channel configuration from JSON string
pub async fn save_channel_config(channel_type: String, config_json: String) -> String {
    let val: serde_json::Value = match serde_json::from_str(&config_json) {
        Ok(v) => v,
        Err(e) => return format!("error: invalid JSON: {e}"),
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };
        let channels = &mut config.channels;

        match channel_type.as_str() {
            "cli" => {
                channels.cli = val.get("enabled").and_then(|v| v.as_bool()).unwrap_or(true);
            }
            "telegram" => {
                let token = val
                    .get("bot_token")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if token.is_empty() {
                    channels.telegram = None;
                } else {
                    channels.telegram = Some(zeroclaw::config::TelegramConfig {
                        enabled: true,
                        bot_token: token,
                        allowed_users: json_str_array(&val, "allowed_users"),
                        mention_only: val
                            .get("mention_only")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        stream_mode: zeroclaw::config::StreamMode::default(),
                        draft_update_interval_ms: 1000,
                        interrupt_on_new_message: false,
                        ack_reactions: None,
                        proxy_url: None,
                        approval_timeout_secs: 120,
                    });
                }
            }
            "discord" => {
                let token = val
                    .get("bot_token")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if token.is_empty() {
                    channels.discord = None;
                } else {
                    channels.discord = Some(zeroclaw::config::DiscordConfig {
                        enabled: true,
                        bot_token: token,
                        guild_id: val
                            .get("guild_id")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        allowed_users: json_str_array(&val, "allowed_users"),
                        listen_to_bots: val
                            .get("listen_to_bots")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        interrupt_on_new_message: false,
                        mention_only: val
                            .get("mention_only")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        proxy_url: None,
                        stream_mode: zeroclaw::config::StreamMode::default(),
                        draft_update_interval_ms: 1000,
                        multi_message_delay_ms: 800,
                        stall_timeout_secs: 0,
                    });
                }
            }
            "slack" => {
                let token = val
                    .get("bot_token")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if token.is_empty() {
                    channels.slack = None;
                } else {
                    let channel_ids = val
                        .get("channel_id")
                        .and_then(|v| v.as_str())
                        .filter(|s| !s.is_empty())
                        .map(|s| vec![s.to_string()])
                        .unwrap_or_default();
                    channels.slack = Some(zeroclaw::config::SlackConfig {
                        enabled: true,
                        bot_token: token,
                        app_token: val
                            .get("app_token")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        channel_ids,
                        allowed_users: json_str_array(&val, "allowed_users"),
                        interrupt_on_new_message: false,
                        thread_replies: None,
                        mention_only: false,
                        use_markdown_blocks: false,
                        proxy_url: None,
                        stream_drafts: false,
                        draft_update_interval_ms: 1200,
                        cancel_reaction: None,
                    });
                }
            }
            "webhook" => {
                let port = val.get("port").and_then(|v| v.as_u64()).unwrap_or(0) as u16;
                if port == 0 {
                    channels.webhook = None;
                } else {
                    channels.webhook = Some(zeroclaw::config::WebhookConfig {
                        enabled: true,
                        port,
                        listen_path: None,
                        send_url: None,
                        send_method: None,
                        auth_header: None,
                        secret: val
                            .get("secret")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                    });
                }
            }
            "email" => {
                let imap = val
                    .get("imap_host")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if imap.is_empty() {
                    channels.email = None;
                } else {
                    channels.email = Some(EmailConfig {
                        enabled: true,
                        imap_host: imap,
                        imap_port: val.get("imap_port").and_then(|v| v.as_u64()).unwrap_or(993)
                            as u16,
                        smtp_host: val
                            .get("smtp_host")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        smtp_port: val.get("smtp_port").and_then(|v| v.as_u64()).unwrap_or(465)
                            as u16,
                        smtp_tls: val
                            .get("smtp_tls")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(true),
                        username: val
                            .get("username")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        password: val
                            .get("password")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        from_address: val
                            .get("from_address")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        allowed_senders: json_str_array(&val, "allowed_senders"),
                        ..Default::default()
                    });
                }
            }
            "lark" => {
                let app_id = val
                    .get("app_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if app_id.is_empty() {
                    channels.lark = None;
                } else {
                    channels.lark = Some(zeroclaw::config::LarkConfig {
                        enabled: true,
                        app_id,
                        app_secret: val
                            .get("app_secret")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        encrypt_key: None,
                        verification_token: None,
                        allowed_users: json_str_array(&val, "allowed_users"),
                        mention_only: val
                            .get("mention_only")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        use_feishu: false,
                        receive_mode: zeroclaw::config::schema::LarkReceiveMode::default(),
                        port: None,
                        proxy_url: None,
                    });
                }
            }
            "dingtalk" => {
                let cid = val
                    .get("client_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if cid.is_empty() {
                    channels.dingtalk = None;
                } else {
                    channels.dingtalk = Some(zeroclaw::config::schema::DingTalkConfig {
                        enabled: true,
                        client_id: cid,
                        client_secret: val
                            .get("client_secret")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        allowed_users: json_str_array(&val, "allowed_users"),
                        proxy_url: None,
                    });
                }
            }
            "matrix" => {
                let url = val
                    .get("homeserver")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if url.is_empty() {
                    channels.matrix = None;
                } else {
                    let room_id = val
                        .get("room_id")
                        .and_then(|v| v.as_str())
                        .filter(|s| !s.is_empty())
                        .map(|s| vec![s.to_string()])
                        .unwrap_or_default();
                    channels.matrix = Some(zeroclaw::config::MatrixConfig {
                        enabled: true,
                        homeserver: url,
                        user_id: val
                            .get("user_id")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        access_token: val
                            .get("access_token")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        device_id: None,
                        allowed_rooms: room_id,
                        allowed_users: json_str_array(&val, "allowed_users"),
                        interrupt_on_new_message: false,
                        stream_mode: zeroclaw::config::StreamMode::default(),
                        draft_update_interval_ms: 1500,
                        multi_message_delay_ms: 800,
                        mention_only: false,
                        recovery_key: None,
                        password: None,
                    });
                }
            }
            "signal" => {
                let http_url = val
                    .get("http_url")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if http_url.is_empty() {
                    channels.signal = None;
                } else {
                    channels.signal = Some(zeroclaw::config::schema::SignalConfig {
                        enabled: true,
                        http_url,
                        account: val
                            .get("account")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        group_id: val
                            .get("group_id")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        allowed_from: json_str_array(&val, "allowed_from"),
                        ignore_attachments: false,
                        ignore_stories: false,
                        proxy_url: None,
                    });
                }
            }
            "whatsapp" => {
                let pid = val
                    .get("phone_number_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if pid.is_empty() {
                    channels.whatsapp = None;
                } else {
                    channels.whatsapp = Some(zeroclaw::config::schema::WhatsAppConfig {
                        enabled: true,
                        phone_number_id: Some(pid),
                        access_token: val
                            .get("access_token")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        verify_token: val
                            .get("verify_token")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        app_secret: None,
                        session_path: None,
                        pair_phone: None,
                        pair_code: None,
                        allowed_numbers: json_str_array(&val, "allowed_numbers"),
                        mention_only: false,
                        mode: zeroclaw::config::WhatsAppWebMode::default(),
                        dm_policy: zeroclaw::config::WhatsAppChatPolicy::default(),
                        group_policy: zeroclaw::config::WhatsAppChatPolicy::default(),
                        self_chat_mode: false,
                        dm_mention_patterns: vec![],
                        group_mention_patterns: vec![],
                        proxy_url: None,
                    });
                }
            }
            "irc" => {
                let server = val
                    .get("server")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if server.is_empty() {
                    channels.irc = None;
                } else {
                    channels.irc = Some(zeroclaw::config::schema::IrcConfig {
                        enabled: true,
                        server,
                        port: val.get("port").and_then(|v| v.as_u64()).unwrap_or(6697) as u16,
                        nickname: val
                            .get("nickname")
                            .and_then(|v| v.as_str())
                            .unwrap_or("zeroclaw")
                            .to_string(),
                        username: None,
                        channels: json_str_array(&val, "channels"),
                        allowed_users: json_str_array(&val, "allowed_users"),
                        server_password: val
                            .get("server_password")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        nickserv_password: None,
                        sasl_password: None,
                        verify_tls: val.get("verify_tls").and_then(|v| v.as_bool()),
                    });
                }
            }
            _ => return format!("error: unknown channel type: {channel_type}"),
        }
    }

    // Invalidate agent
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    let result = save_channel_config_to_disk().await;

    // Restart channel listeners so the new config takes effect
    if result == "ok" {
        let _ = super::channel_runtime_api::restart_channel_listeners().await;
    }

    result
}

/// Toggle a channel on/off. If disabling, removes config. If enabling, needs save_channel_config.
pub async fn toggle_channel(channel_type: String, enabled: bool) -> String {
    if !enabled {
        // Disable = remove config
        {
            let mut cs = super::agent_api::config_state().write().await;
            let config = match cs.config.as_mut() {
                Some(c) => c,
                None => return "error: not initialized".into(),
            };
            let channels = &mut config.channels;
            match channel_type.as_str() {
                "cli" => channels.cli = false,
                "telegram" => channels.telegram = None,
                "discord" => channels.discord = None,
                "slack" => channels.slack = None,
                "webhook" => channels.webhook = None,
                "email" => channels.email = None,
                "lark" => channels.lark = None,
                "dingtalk" => channels.dingtalk = None,
                "matrix" => channels.matrix = None,
                "signal" => channels.signal = None,
                "whatsapp" => channels.whatsapp = None,
                "irc" => channels.irc = None,
                _ => return format!("error: unknown channel: {channel_type}"),
            }
        }
        super::agent_api::invalidate_all_agents().await;
        let result = save_channel_config_to_disk().await;

        // Restart channel listeners to reflect the disabled channel
        if result == "ok" {
            let _ = super::channel_runtime_api::restart_channel_listeners().await;
        }

        result
    } else {
        // Enable requires configuration — caller should use save_channel_config
        "error: use save_channel_config to enable with configuration".into()
    }
}

fn tool_filter_group_to_dto(group: &ToolFilterGroup) -> AgentToolFilterGroupDto {
    AgentToolFilterGroupDto {
        mode: match group.mode {
            ToolFilterGroupMode::Always => "always".into(),
            ToolFilterGroupMode::Dynamic => "dynamic".into(),
        },
        tools: group.tools.clone(),
        keywords: group.keywords.clone(),
        filter_builtins: group.filter_builtins,
    }
}

fn tool_filter_group_from_dto(group: AgentToolFilterGroupDto) -> Result<ToolFilterGroup, String> {
    let mode = match group.mode.trim().to_ascii_lowercase().as_str() {
        "always" => ToolFilterGroupMode::Always,
        "dynamic" | "" => ToolFilterGroupMode::Dynamic,
        other => {
            return Err(format!(
                "error: unsupported tool filter group mode: {other}"
            ))
        }
    };

    let tools = sanitize_string_list(group.tools);
    if tools.is_empty() {
        return Err("error: tool filter group must include at least one tool pattern".into());
    }

    Ok(ToolFilterGroup {
        mode,
        tools,
        keywords: sanitize_string_list(group.keywords),
        filter_builtins: group.filter_builtins,
    })
}

/// Helper: extract string array from JSON value
fn json_str_array(val: &serde_json::Value, key: &str) -> Vec<String> {
    val.get(key)
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect::<Vec<_>>()
        })
        .map(sanitize_string_list)
        .unwrap_or_default()
}

fn normalize_optional_string(value: Option<String>) -> Option<String> {
    value
        .map(|item| item.trim().to_string())
        .filter(|item| !item.is_empty())
}

fn sanitize_string_list(values: Vec<String>) -> Vec<String> {
    let mut result = Vec::new();
    for value in values {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            continue;
        }
        let normalized = trimmed.to_string();
        if !result.contains(&normalized) {
            result.push(normalized);
        }
    }
    result
}

fn browser_config_to_dto(config: &zeroclaw::Config) -> BrowserConfigDto {
    let agent_browser_command = crate::api::browser_bootstrap::find_agent_browser();
    BrowserConfigDto {
        enabled: config.browser.enabled,
        backend: config.browser.backend.clone(),
        allowed_domains: config.browser.allowed_domains.clone(),
        session_name: config.browser.session_name.clone(),
        native_headless: config.browser.native_headless,
        native_webdriver_url: config.browser.native_webdriver_url.clone(),
        native_chrome_path: config.browser.native_chrome_path.clone(),
        computer_use_endpoint: config.browser.computer_use.endpoint.clone(),
        computer_use_api_key: config.browser.computer_use.api_key.clone(),
        computer_use_allow_remote_endpoint: config.browser.computer_use.allow_remote_endpoint,
        computer_use_window_allowlist: config.browser.computer_use.window_allowlist.clone(),
        computer_use_max_coordinate_x: config.browser.computer_use.max_coordinate_x,
        computer_use_max_coordinate_y: config.browser.computer_use.max_coordinate_y,
        agent_browser_available: !agent_browser_command.starts_with("error:"),
        agent_browser_command: if agent_browser_command.starts_with("error:") {
            String::new()
        } else {
            agent_browser_command
        },
    }
}

fn gateway_config_to_dto(config: &zeroclaw::Config) -> GatewayConfigDto {
    GatewayConfigDto {
        host: config.gateway.host.clone(),
        port: config.gateway.port,
        require_pairing: config.gateway.require_pairing,
        allow_public_bind: config.gateway.allow_public_bind,
        trust_forwarded_headers: config.gateway.trust_forwarded_headers,
        path_prefix: config.gateway.path_prefix.clone(),
        pair_rate_limit_per_minute: config.gateway.pair_rate_limit_per_minute,
        webhook_rate_limit_per_minute: config.gateway.webhook_rate_limit_per_minute,
        rate_limit_max_keys: config.gateway.rate_limit_max_keys as u32,
        idempotency_ttl_secs: config.gateway.idempotency_ttl_secs,
        idempotency_max_keys: config.gateway.idempotency_max_keys as u32,
        session_persistence: config.gateway.session_persistence,
        session_ttl_hours: config.gateway.session_ttl_hours,
        web_dist_dir: config.gateway.web_dist_dir.clone(),
        pairing_code_length: config.gateway.pairing_dashboard.code_length as u32,
        pairing_code_ttl_secs: config.gateway.pairing_dashboard.code_ttl_secs,
        pairing_max_pending_codes: config.gateway.pairing_dashboard.max_pending_codes as u32,
        pairing_max_failed_attempts: config.gateway.pairing_dashboard.max_failed_attempts,
        pairing_lockout_secs: config.gateway.pairing_dashboard.lockout_secs,
    }
}

fn apply_browser_config_value(
    config: &mut zeroclaw::Config,
    val: &serde_json::Value,
) -> Result<(), String> {
    if let Some(enabled) = val.get("enabled").and_then(|v| v.as_bool()) {
        config.browser.enabled = enabled;
    }
    if let Some(backend) = val.get("backend").and_then(|v| v.as_str()) {
        let normalized = backend.trim().to_ascii_lowercase();
        if !normalized.is_empty() {
            match normalized.as_str() {
                "agent_browser" | "rust_native" | "computer_use" | "auto" => {
                    config.browser.backend = normalized;
                }
                _ => return Err(format!("error: unsupported browser backend: {backend}")),
            }
        }
    }
    if val.get("allowed_domains").is_some() {
        config.browser.allowed_domains = json_str_array(val, "allowed_domains");
    }
    if val.get("session_name").is_some() {
        config.browser.session_name = normalize_optional_string(
            val.get("session_name")
                .and_then(|v| v.as_str())
                .map(|value| value.to_string()),
        );
    }
    if let Some(native_headless) = val.get("native_headless").and_then(|v| v.as_bool()) {
        config.browser.native_headless = native_headless;
    }
    if let Some(webdriver_url) = val.get("native_webdriver_url").and_then(|v| v.as_str()) {
        let trimmed = webdriver_url.trim();
        if !trimmed.is_empty() {
            config.browser.native_webdriver_url = trimmed.to_string();
        }
    }
    if val.get("native_chrome_path").is_some() {
        config.browser.native_chrome_path = normalize_optional_string(
            val.get("native_chrome_path")
                .and_then(|v| v.as_str())
                .map(|value| value.to_string()),
        );
    }
    if let Some(endpoint) = val.get("computer_use_endpoint").and_then(|v| v.as_str()) {
        let trimmed = endpoint.trim();
        if !trimmed.is_empty() {
            config.browser.computer_use.endpoint = trimmed.to_string();
        }
    }
    if val.get("computer_use_api_key").is_some() {
        config.browser.computer_use.api_key = normalize_optional_string(
            val.get("computer_use_api_key")
                .and_then(|v| v.as_str())
                .map(|value| value.to_string()),
        );
    }
    if let Some(allow_remote) = val
        .get("computer_use_allow_remote_endpoint")
        .and_then(|v| v.as_bool())
    {
        config.browser.computer_use.allow_remote_endpoint = allow_remote;
    }
    if val.get("computer_use_window_allowlist").is_some() {
        config.browser.computer_use.window_allowlist =
            json_str_array(val, "computer_use_window_allowlist");
    }
    if val.get("computer_use_max_coordinate_x").is_some() {
        config.browser.computer_use.max_coordinate_x = val
            .get("computer_use_max_coordinate_x")
            .and_then(|v| v.as_i64());
    }
    if val.get("computer_use_max_coordinate_y").is_some() {
        config.browser.computer_use.max_coordinate_y = val
            .get("computer_use_max_coordinate_y")
            .and_then(|v| v.as_i64());
    }
    Ok(())
}

/// Persist channel config section to disk
async fn save_channel_config_to_disk() -> String {
    persist_config_state_to_disk().await
}

/// Persist tool config sections to disk
async fn save_tool_config_to_disk() -> String {
    persist_config_state_to_disk().await
}

async fn persist_config_state_to_disk() -> String {
    let config_clone = {
        let cs = super::agent_api::config_state().read().await;
        match &cs.config {
            Some(c) => c.clone(),
            None => return "error: no config loaded".into(),
        }
    };

    {
        let mut gc = super::agent_api::global_config().write().await;
        gc.config = Some(config_clone);
    }
    super::agent_api::save_config_to_disk().await
}
