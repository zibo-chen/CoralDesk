// No sync FRB functions needed here currently

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
            trust_me: a.trust_me,
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
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };

        let new_level = match serde_json::from_value(serde_json::Value::String(level.clone())) {
            Ok(l) => l,
            Err(_) => return format!("error: unknown level: {level}"),
        };
        config.autonomy.level = new_level;
    }
    *super::agent_api::agent_handle().lock().await = None;
    "ok".into()
}

/// Toggle trust-me mode. When enabled, all security checks are bypassed
/// and tool calls are auto-approved without user confirmation.
pub async fn update_trust_me(enabled: bool) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };
        config.autonomy.trust_me = enabled;
    }
    // Invalidate agent so it gets recreated with new security policy
    *super::agent_api::agent_handle().lock().await = None;
    "ok".into()
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
        }
    } else {
        AgentConfigDto {
            max_tool_iterations: 10,
            max_history_messages: 50,
            parallel_tools: false,
            tool_dispatcher: "auto".into(),
            compact_context: false,
        }
    }
}

/// Update agent settings
pub async fn update_agent_config(
    max_tool_iterations: Option<u32>,
    max_history_messages: Option<u32>,
    parallel_tools: Option<bool>,
    compact_context: Option<bool>,
) -> String {
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
    }
    *super::agent_api::agent_handle().lock().await = None;
    "ok".into()
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
        let ch = &config.channels_config;

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
        ("delegate", "Delegate to sub-agent", "agent"),
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
    *super::agent_api::agent_handle().lock().await = None;

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
    *super::agent_api::agent_handle().lock().await = None;

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
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
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
    }
    *super::agent_api::agent_handle().lock().await = None;
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
    let ch = &config.channels_config;

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
                    "channel_id": sc.channel_id,
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
                    "room_id": mc.room_id,
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

        match channel_type.as_str() {
            "cli" => {
                config.channels_config.cli =
                    val.get("enabled").and_then(|v| v.as_bool()).unwrap_or(true);
            }
            "telegram" => {
                let token = val
                    .get("bot_token")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                if token.is_empty() {
                    config.channels_config.telegram = None;
                } else {
                    config.channels_config.telegram = Some(zeroclaw::config::TelegramConfig {
                        bot_token: token,
                        allowed_users: json_str_array(&val, "allowed_users"),
                        mention_only: val
                            .get("mention_only")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
                        stream_mode: zeroclaw::config::StreamMode::default(),
                        draft_update_interval_ms: 1000,
                        interrupt_on_new_message: false,
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
                    config.channels_config.discord = None;
                } else {
                    config.channels_config.discord = Some(zeroclaw::config::DiscordConfig {
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
                        mention_only: val
                            .get("mention_only")
                            .and_then(|v| v.as_bool())
                            .unwrap_or(false),
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
                    config.channels_config.slack = None;
                } else {
                    config.channels_config.slack = Some(zeroclaw::config::SlackConfig {
                        bot_token: token,
                        app_token: val
                            .get("app_token")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        channel_id: val
                            .get("channel_id")
                            .and_then(|v| v.as_str())
                            .filter(|s| !s.is_empty())
                            .map(|s| s.to_string()),
                        allowed_users: json_str_array(&val, "allowed_users"),
                    });
                }
            }
            "webhook" => {
                let port = val.get("port").and_then(|v| v.as_u64()).unwrap_or(0) as u16;
                if port == 0 {
                    config.channels_config.webhook = None;
                } else {
                    config.channels_config.webhook = Some(zeroclaw::config::WebhookConfig {
                        port,
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
                    config.channels_config.email = None;
                } else {
                    config.channels_config.email =
                        Some(zeroclaw::channels::email_channel::EmailConfig {
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
                    config.channels_config.lark = None;
                } else {
                    config.channels_config.lark = Some(zeroclaw::config::LarkConfig {
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
                    config.channels_config.dingtalk = None;
                } else {
                    config.channels_config.dingtalk =
                        Some(zeroclaw::config::schema::DingTalkConfig {
                            client_id: cid,
                            client_secret: val
                                .get("client_secret")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string(),
                            allowed_users: json_str_array(&val, "allowed_users"),
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
                    config.channels_config.matrix = None;
                } else {
                    config.channels_config.matrix = Some(zeroclaw::config::MatrixConfig {
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
                        room_id: val
                            .get("room_id")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        allowed_users: json_str_array(&val, "allowed_users"),
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
                    config.channels_config.signal = None;
                } else {
                    config.channels_config.signal = Some(zeroclaw::config::schema::SignalConfig {
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
                    config.channels_config.whatsapp = None;
                } else {
                    config.channels_config.whatsapp =
                        Some(zeroclaw::config::schema::WhatsAppConfig {
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
                    config.channels_config.irc = None;
                } else {
                    config.channels_config.irc = Some(zeroclaw::config::schema::IrcConfig {
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
    *super::agent_api::agent_handle().lock().await = None;

    // Persist to disk
    save_channel_config_to_disk().await
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
            match channel_type.as_str() {
                "cli" => config.channels_config.cli = false,
                "telegram" => config.channels_config.telegram = None,
                "discord" => config.channels_config.discord = None,
                "slack" => config.channels_config.slack = None,
                "webhook" => config.channels_config.webhook = None,
                "email" => config.channels_config.email = None,
                "lark" => config.channels_config.lark = None,
                "dingtalk" => config.channels_config.dingtalk = None,
                "matrix" => config.channels_config.matrix = None,
                "signal" => config.channels_config.signal = None,
                "whatsapp" => config.channels_config.whatsapp = None,
                "irc" => config.channels_config.irc = None,
                _ => return format!("error: unknown channel: {channel_type}"),
            }
        }
        *super::agent_api::agent_handle().lock().await = None;
        save_channel_config_to_disk().await
    } else {
        // Enable requires configuration — caller should use save_channel_config
        "error: use save_channel_config to enable with configuration".into()
    }
}

/// Helper: extract string array from JSON value
fn json_str_array(val: &serde_json::Value, key: &str) -> Vec<String> {
    val.get(key)
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default()
}

/// Persist channel config section to disk
async fn save_channel_config_to_disk() -> String {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return "error: no config loaded".into(),
    };

    let config_path = &config.config_path;
    if config_path.as_os_str().is_empty() {
        return "error: config_path not set".into();
    }

    // Read existing TOML
    let mut table: toml::Table = match tokio::fs::read_to_string(config_path).await {
        Ok(content) => content.parse().unwrap_or_default(),
        Err(_) => toml::Table::new(),
    };

    // Serialize channels_config section
    let ch = &config.channels_config;
    let mut ch_table = toml::Table::new();
    ch_table.insert("cli".into(), toml::Value::Boolean(ch.cli));

    // Helper macro to serialize Option<T> channel configs
    macro_rules! serialize_channel {
        ($field:ident, $name:expr) => {
            if let Some(ref cfg) = ch.$field {
                if let Ok(val) = serde_json::to_value(cfg) {
                    if let Ok(toml_val) = json_value_to_toml(&val) {
                        ch_table.insert($name.into(), toml_val);
                    }
                }
            }
        };
    }

    serialize_channel!(telegram, "telegram");
    serialize_channel!(discord, "discord");
    serialize_channel!(slack, "slack");
    serialize_channel!(webhook, "webhook");
    serialize_channel!(email, "email");
    serialize_channel!(lark, "lark");
    serialize_channel!(dingtalk, "dingtalk");
    serialize_channel!(matrix, "matrix");
    serialize_channel!(signal, "signal");
    serialize_channel!(whatsapp, "whatsapp");
    serialize_channel!(irc, "irc");

    table.insert("channels_config".into(), toml::Value::Table(ch_table));

    let output = match toml::to_string_pretty(&table) {
        Ok(s) => s,
        Err(e) => return format!("error: serialize failed: {e}"),
    };

    match tokio::fs::write(config_path, output).await {
        Ok(()) => "ok".into(),
        Err(e) => format!("error: write failed: {e}"),
    }
}

/// Convert serde_json::Value to toml::Value
fn json_value_to_toml(val: &serde_json::Value) -> Result<toml::Value, String> {
    match val {
        serde_json::Value::Null => Ok(toml::Value::String(String::new())),
        serde_json::Value::Bool(b) => Ok(toml::Value::Boolean(*b)),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(toml::Value::Integer(i))
            } else if let Some(f) = n.as_f64() {
                Ok(toml::Value::Float(f))
            } else {
                Err("unsupported number".into())
            }
        }
        serde_json::Value::String(s) => Ok(toml::Value::String(s.clone())),
        serde_json::Value::Array(arr) => {
            let items: Result<Vec<_>, _> = arr.iter().map(json_value_to_toml).collect();
            Ok(toml::Value::Array(items?))
        }
        serde_json::Value::Object(map) => {
            let mut table = toml::Table::new();
            for (k, v) in map {
                // Skip null values
                if !v.is_null() {
                    table.insert(k.clone(), json_value_to_toml(v)?);
                }
            }
            Ok(toml::Value::Table(table))
        }
    }
}
