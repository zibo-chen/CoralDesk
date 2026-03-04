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
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        config.agents.insert(name, delegate_config);
    }

    // Invalidate agent so delegate tool picks up the new config
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Remove a delegate agent by name. Returns "ok" on success, error string otherwise.
pub async fn remove_delegate_agent(name: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        if config.agents.remove(&name).is_none() {
            return format!("error: agent '{}' not found", name);
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
