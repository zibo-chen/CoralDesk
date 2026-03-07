use flutter_rust_bridge::frb;

// ──────────────────────── DTOs ────────────────────────────

/// A delegate sub-agent configuration exposed to Flutter UI
#[derive(Debug, Clone)]
pub struct DelegateAgentDto {
    pub name: String,
    pub provider: String,
    pub model: String,
    pub system_prompt: Option<String>,
    pub api_key: Option<String>,
    pub temperature: Option<f64>,
    pub max_depth: u32,
    pub agentic: bool,
    pub allowed_tools: Vec<String>,
    pub max_iterations: u32,
    /// Capability tags for automatic agent selection
    pub capabilities: Vec<String>,
    /// Priority hint for auto-selection (higher wins on ties)
    pub priority: i32,
    /// Whether this agent profile is enabled
    pub enabled: bool,
    /// Optional display label for multi-agent role UI
    pub role_label: Option<String>,
    /// Optional hex color for multi-agent role UI (e.g. "#4A90D9")
    pub role_color: Option<String>,
    /// Optional emoji icon for multi-agent role UI (e.g. "🏗️")
    pub role_icon: Option<String>,
    /// Whether this is a built-in preset role
    pub is_preset: bool,
    /// Whether this sub-agent can delegate to other sub-agents
    pub allow_nested_delegate: bool,
}

// ──────────────────── API Functions ──────────────────────────

/// List all configured delegate agents
pub async fn list_delegate_agents() -> Vec<DelegateAgentDto> {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return vec![],
    };

    let mut agents: Vec<DelegateAgentDto> = config
        .agents
        .iter()
        .map(|(name, cfg)| DelegateAgentDto {
            name: name.clone(),
            provider: cfg.provider.clone(),
            model: cfg.model.clone(),
            system_prompt: cfg.system_prompt.clone(),
            api_key: cfg.api_key.clone(),
            temperature: cfg.temperature,
            max_depth: cfg.max_depth,
            agentic: cfg.agentic,
            allowed_tools: cfg.allowed_tools.clone(),
            max_iterations: cfg.max_iterations as u32,
            capabilities: cfg.capabilities.clone(),
            priority: cfg.priority,
            enabled: cfg.enabled,
            role_label: cfg.role_label.clone(),
            role_color: cfg.role_color.clone(),
            role_icon: cfg.role_icon.clone(),
            is_preset: cfg.is_preset,
            allow_nested_delegate: cfg.allow_nested_delegate,
        })
        .collect();

    agents.sort_by(|a, b| a.name.cmp(&b.name));
    agents
}

/// Get a single delegate agent by name
pub async fn get_delegate_agent(name: String) -> Option<DelegateAgentDto> {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return None,
    };

    config.agents.get(&name).map(|cfg| DelegateAgentDto {
        name: name.clone(),
        provider: cfg.provider.clone(),
        model: cfg.model.clone(),
        system_prompt: cfg.system_prompt.clone(),
        api_key: cfg.api_key.clone(),
        temperature: cfg.temperature,
        max_depth: cfg.max_depth,
        agentic: cfg.agentic,
        allowed_tools: cfg.allowed_tools.clone(),
        max_iterations: cfg.max_iterations as u32,
        capabilities: cfg.capabilities.clone(),
        priority: cfg.priority,
        enabled: cfg.enabled,
        role_label: cfg.role_label.clone(),
        role_color: cfg.role_color.clone(),
        role_icon: cfg.role_icon.clone(),
        is_preset: cfg.is_preset,
        allow_nested_delegate: cfg.allow_nested_delegate,
    })
}

/// Create or update a delegate agent. Returns "ok" on success, error string otherwise.
pub async fn upsert_delegate_agent(agent: DelegateAgentDto) -> String {
    let name = agent.name.trim().to_string();
    if name.is_empty() {
        return "error: agent name must not be empty".into();
    }
    if agent.provider.trim().is_empty() {
        return "error: provider must not be empty".into();
    }
    if agent.model.trim().is_empty() {
        return "error: model must not be empty".into();
    }
    if agent.max_depth == 0 {
        return "error: max_depth must be greater than 0".into();
    }
    if agent.agentic && agent.allowed_tools.is_empty() {
        return "error: agentic mode requires at least one allowed tool".into();
    }
    if let Some(t) = agent.temperature {
        if !(0.0..=2.0).contains(&t) {
            return "error: temperature must be between 0.0 and 2.0".into();
        }
    }

    let delegate_config = zeroclaw::config::DelegateAgentConfig {
        provider: agent.provider.trim().to_string(),
        model: agent.model.trim().to_string(),
        system_prompt: agent
            .system_prompt
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        api_key: agent
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        enabled: agent.enabled,
        capabilities: agent
            .capabilities
            .iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect(),
        priority: agent.priority,
        temperature: agent.temperature,
        max_depth: agent.max_depth,
        agentic: agent.agentic,
        allowed_tools: agent
            .allowed_tools
            .iter()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect(),
        max_iterations: agent.max_iterations.max(1) as usize,
        role_label: agent
            .role_label
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        role_color: agent
            .role_color
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        role_icon: agent
            .role_icon
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        is_preset: agent.is_preset,
        allow_nested_delegate: agent.allow_nested_delegate,
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        config.agents.insert(name.clone(), delegate_config.clone());
    }

    // Sync to global_config so ensure_session_agent picks up the new delegate agents
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.agents.insert(name, delegate_config);
        }
    }

    // Invalidate agent so delegate tool picks up the new config
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Remove a delegate agent by name. Returns "ok" on success, error string otherwise.
/// Preset roles (is_preset = true) cannot be deleted.
pub async fn remove_delegate_agent(name: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        // Check if it's a preset role
        if let Some(agent) = config.agents.get(&name) {
            if agent.is_preset {
                return format!("error: cannot delete built-in preset role '{}'", name);
            }
        }
        if config.agents.remove(&name).is_none() {
            return format!("error: agent '{}' not found", name);
        }
    }

    // Sync removal to global_config
    {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(config) = gc.config.as_mut() {
            config.agents.remove(&name);
        }
    }

    // Invalidate agent
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Return the count of currently configured delegate agents (sync for quick display)
#[frb(sync)]
pub fn delegate_agent_count() -> u32 {
    if let Ok(guard) = super::agent_api::config_state().try_read() {
        if let Some(config) = &guard.config {
            return config.agents.len() as u32;
        }
    }
    0
}

/// Seed the 6 built-in preset roles if they don't already exist.
/// Called during app initialization to ensure preset agents are available.
/// Returns the number of presets created (0–6).
pub async fn seed_preset_roles() -> u32 {
    let presets: Vec<(&str, &str, &str, &str, Vec<&str>)> = vec![
        (
            "architect",
            "🏗️",
            "#4A90D9",
            "You are the **Architect** agent. Make architecture decisions, technology selections, define module boundaries and component interfaces. Evaluate trade-offs. Be concise but thorough.",
            vec!["architecture", "design", "planning", "decision"],
        ),
        (
            "coder",
            "✍️",
            "#50C878",
            "You are the **Coder** agent. Generate high-quality, production-ready code. Implement features, refactor for clarity and performance. Produce complete working code with no placeholders.",
            vec!["coding", "implementation", "refactoring", "debugging"],
        ),
        (
            "critic",
            "🔍",
            "#E74C3C",
            "You are the **Critic** agent. Review code for bugs, security issues, and design problems. Classify issues: 🔴 Fatal, 🟠 Critical, 🟡 Suggestion. Provide constructive feedback with specific fixes.",
            vec!["review", "analysis", "quality", "security"],
        ),
        (
            "validator",
            "🧪",
            "#F39C12",
            "You are the **Validator** agent. Generate comprehensive test cases. Verify specification conformance. Design unit and integration tests covering happy paths, error paths, and edge cases.",
            vec!["testing", "validation", "verification", "coverage"],
        ),
        (
            "context_keeper",
            "📚",
            "#9B59B6",
            "You are the **Context Keeper** agent. Maintain summaries of architectural decisions, track design rationale and trade-offs, record requirements and constraints. Provide relevant context on request.",
            vec!["context", "memory", "documentation", "history"],
        ),
        (
            "integrator",
            "🔗",
            "#1ABC9C",
            "You are the **Integrator** agent. Ensure multi-module changes work together. Verify interface contracts, check data flows across module boundaries, identify integration gaps.",
            vec!["integration", "api", "contracts", "compatibility"],
        ),
    ];

    let mut created = 0u32;

    // Read current config to check which presets already exist
    let existing_names: Vec<String> = {
        let cs = super::agent_api::config_state().read().await;
        match &cs.config {
            Some(c) => c.agents.keys().cloned().collect(),
            None => return 0,
        }
    };

    for (name, icon, color, system_prompt, capabilities) in presets {
        if existing_names.contains(&name.to_string()) {
            // Already exists — update is_preset flag if needed
            let mut cs = super::agent_api::config_state().write().await;
            if let Some(config) = cs.config.as_mut() {
                if let Some(agent) = config.agents.get_mut(name) {
                    if !agent.is_preset {
                        agent.is_preset = true;
                        agent.role_label = Some(name.to_string());
                        agent.role_color = Some(color.to_string());
                        agent.role_icon = Some(icon.to_string());
                    }
                }
            }
            drop(cs);
            // Also sync to global_config
            let mut gc = super::agent_api::global_config().write().await;
            if let Some(config) = gc.config.as_mut() {
                if let Some(agent) = config.agents.get_mut(name) {
                    if !agent.is_preset {
                        agent.is_preset = true;
                        agent.role_label = Some(name.to_string());
                        agent.role_color = Some(color.to_string());
                        agent.role_icon = Some(icon.to_string());
                    }
                }
            }
            continue;
        }

        // Read main provider/model from config to use for presets
        let (provider, model) = {
            let cs = super::agent_api::config_state().read().await;
            match &cs.config {
                Some(c) => (
                    c.default_provider
                        .clone()
                        .unwrap_or_else(|| "openrouter".to_string()),
                    c.default_model
                        .clone()
                        .unwrap_or_else(|| "anthropic/claude-sonnet-4-20250514".to_string()),
                ),
                None => continue,
            }
        };

        let delegate_config = zeroclaw::config::DelegateAgentConfig {
            provider,
            model,
            system_prompt: Some(system_prompt.to_string()),
            api_key: None,
            enabled: true,
            capabilities: capabilities.iter().map(|s| s.to_string()).collect(),
            priority: 0,
            temperature: None,
            max_depth: 3,
            agentic: true,
            allowed_tools: vec![
                "shell".to_string(),
                "file_read".to_string(),
                "file_write".to_string(),
                "file_edit".to_string(),
                "glob".to_string(),
                "grep".to_string(),
                "collaborate".to_string(),
            ],
            max_iterations: 10,
            role_label: Some(name.to_string()),
            role_color: Some(color.to_string()),
            role_icon: Some(icon.to_string()),
            is_preset: true,
            allow_nested_delegate: true,
        };

        {
            let mut cs = super::agent_api::config_state().write().await;
            if let Some(config) = cs.config.as_mut() {
                config
                    .agents
                    .insert(name.to_string(), delegate_config.clone());
                created += 1;
            }
        }
        // Also insert into global_config immediately
        {
            let mut gc = super::agent_api::global_config().write().await;
            if let Some(config) = gc.config.as_mut() {
                config.agents.insert(name.to_string(), delegate_config);
            }
        }
    }

    if created > 0 {
        // Sync all agents from config_state to global_config so ensure_session_agent
        // can see the preset roles and register the delegate tool.
        {
            let cs = super::agent_api::config_state().read().await;
            if let Some(cs_config) = &cs.config {
                let agents_clone = cs_config.agents.clone();
                drop(cs);
                let mut gc = super::agent_api::global_config().write().await;
                if let Some(gc_config) = gc.config.as_mut() {
                    gc_config.agents = agents_clone;
                }
            }
        }

        super::agent_api::invalidate_all_agents().await;
        let _ = super::agent_api::save_config_to_disk().await;
    }

    created
}

/// Set the multi-agent orchestrator system prompt for a session.
/// When enabled, the main agent's system prompt is augmented with
/// orchestrator instructions that direct it to use the delegate tool
/// to coordinate the preset roles.
///
/// Returns "ok" on success, error string otherwise.
pub async fn set_session_multi_agent_mode(
    session_id: String,
    enabled: bool,
    role_names: Vec<String>,
) -> String {
    if enabled && role_names.is_empty() {
        return "error: must specify at least one role when enabling multi-agent mode".into();
    }

    if enabled {
        // Map workspace IDs (e.g. "preset_architect") to delegate agent config
        // names (e.g. "architect") so ensure_session_agent can look them up in
        // config.agents.
        let agent_names: Vec<String> = role_names
            .iter()
            .map(|id| {
                id.strip_prefix("preset_")
                    .unwrap_or(id.as_str())
                    .to_string()
            })
            .collect();

        // Ensure delegate agent configs exist for the selected roles.
        // If config.agents is empty, seed preset roles so the delegate tool
        // is registered when the agent is created.
        {
            let needs_seed = {
                let gc = super::agent_api::global_config().read().await;
                gc.config
                    .as_ref()
                    .map(|c| c.agents.is_empty())
                    .unwrap_or(true)
            };
            if needs_seed {
                let created = seed_preset_roles().await;
                if created > 0 {
                    tracing::info!(
                        "Auto-seeded {created} preset delegate agents for team mode activation"
                    );
                }
            }
        }

        // Store the mapped agent names (not workspace IDs)
        {
            let mut sessions = multi_agent_sessions().write().await;
            sessions.insert(session_id.clone(), agent_names);
        }
    } else {
        let mut sessions = multi_agent_sessions().write().await;
        sessions.remove(&session_id);
    }

    // Invalidate this session's agent so it gets recreated with/without orchestrator prompt
    super::agent_api::invalidate_session_agent(&session_id).await;

    "ok".into()
}

/// Check if a session has multi-agent mode enabled
pub async fn is_session_multi_agent(session_id: String) -> bool {
    let sessions = multi_agent_sessions().read().await;
    sessions.contains_key(&session_id)
}

/// Get the active roles for a multi-agent session
pub async fn get_session_active_roles(session_id: String) -> Vec<String> {
    let sessions = multi_agent_sessions().read().await;
    sessions.get(&session_id).cloned().unwrap_or_default()
}

// ── Multi-agent session state ────────────────────────────

use std::collections::HashMap;
use std::sync::OnceLock;
use tokio::sync::RwLock;

/// Maps session_id → list of active role names for multi-agent sessions
type MultiAgentSessionMap = HashMap<String, Vec<String>>;

pub(crate) fn multi_agent_sessions() -> &'static RwLock<MultiAgentSessionMap> {
    static STATE: OnceLock<RwLock<MultiAgentSessionMap>> = OnceLock::new();
    STATE.get_or_init(|| RwLock::new(HashMap::new()))
}
