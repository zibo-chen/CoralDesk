use flutter_rust_bridge::frb;

// ──────────────────────── DTOs ────────────────────────────

/// A configured model provider profile exposed to Flutter UI.
/// Maps to zeroclaw's `[model_providers.<id>]` config section.
#[derive(Debug, Clone)]
pub struct ModelProviderProfileDto {
    /// Unique profile id (config key)
    pub id: String,
    /// Display name or provider type override (e.g. "openai", "anthropic")
    pub name: Option<String>,
    /// Base URL for OpenAI-compatible endpoints
    pub base_url: Option<String>,
    /// Wire API protocol ("responses" or "chat_completions")
    pub wire_api: Option<String>,
    /// Default model for this profile
    pub default_model: Option<String>,
    /// API key (profile-scoped)
    pub api_key: Option<String>,
}

// ──────────────────── API Functions ──────────────────────────

/// List all configured model provider profiles
pub async fn list_model_provider_profiles() -> Vec<ModelProviderProfileDto> {
    let gc = super::agent_api::global_config().read().await;
    let config = match &gc.config {
        Some(c) => c,
        None => return vec![],
    };

    let mut profiles: Vec<ModelProviderProfileDto> = config
        .model_providers
        .iter()
        .map(|(id, cfg)| ModelProviderProfileDto {
            id: id.clone(),
            name: cfg.name.clone(),
            base_url: cfg.base_url.clone(),
            wire_api: cfg.wire_api.clone(),
            default_model: cfg.default_model.clone(),
            api_key: cfg.api_key.clone(),
        })
        .collect();

    profiles.sort_by(|a, b| a.id.cmp(&b.id));
    profiles
}

/// Create or update a model provider profile. Returns "ok" on success.
pub async fn upsert_model_provider_profile(profile: ModelProviderProfileDto) -> String {
    let id = profile.id.trim().to_string();
    if id.is_empty() {
        return "error: profile id must not be empty".into();
    }

    // Validate: at least one of name or base_url must be provided
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
        return "error: profile must have at least one of 'name' or 'base_url'".into();
    }

    let provider_config = zeroclaw::config::schema::ModelProviderConfig {
        name: profile
            .name
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        base_url: profile
            .base_url
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        wire_api: profile
            .wire_api
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        default_model: profile
            .default_model
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        api_key: profile
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        requires_openai_auth: false,
    };

    // Update BOTH global_config and config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        let mut cs = super::agent_api::config_state().write().await;
        let config = match gc.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        config.model_providers.insert(id, provider_config);
        cs.config = Some(config.clone());
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Remove a model provider profile. Returns "ok" on success.
pub async fn remove_model_provider_profile(id: String) -> String {
    // Update BOTH global_config and config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        let mut cs = super::agent_api::config_state().write().await;
        let config = match gc.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        if config.model_providers.remove(&id).is_none() {
            return format!("error: profile '{}' not found", id);
        }
        cs.config = Some(config.clone());
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Switch the active default provider + model at runtime.
/// Used by the chat model selector to quickly switch models.
/// If `provider` matches a model_provider profile ID, applies that profile's configuration.
pub async fn switch_active_model(provider: String, model: String) -> String {
    let provider = provider.trim().to_string();
    let model = model.trim().to_string();

    if provider.is_empty() {
        return "error: provider must not be empty".into();
    }
    if model.is_empty() {
        return "error: model must not be empty".into();
    }

    // Check if provider matches a model_provider profile
    let profile_config = {
        let gc = super::agent_api::global_config().read().await;
        match &gc.config {
            Some(c) => c.model_providers.get(&provider).cloned(),
            None => None,
        }
    };

    if let Some(profile) = profile_config {
        // Apply profile configuration like set_default_profile does
        const KNOWN_PROVIDERS: &[&str] = &[
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
        ];

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
        let api_key = profile
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty());

        // Determine effective provider
        let effective_provider = if let Some(url) = base_url {
            if let Some(name) = provider_name {
                let name_lower = name.to_lowercase();
                if KNOWN_PROVIDERS.iter().any(|p| *p == name_lower) {
                    name.to_string()
                } else {
                    format!("custom:{}", url)
                }
            } else {
                format!("custom:{}", url)
            }
        } else if let Some(name) = provider_name {
            name.to_string()
        } else {
            provider.clone()
        };

        // Update BOTH global_config and config_state
        {
            let mut gc = super::agent_api::global_config().write().await;
            let mut cs = super::agent_api::config_state().write().await;

            let config = match gc.config.as_mut() {
                Some(c) => c,
                None => return "error: runtime not initialized".into(),
            };

            config.default_provider = Some(effective_provider);
            config.default_model = Some(model);

            if let Some(key) = api_key {
                config.api_key = Some(key.to_string());
            }

            if let Some(url) = base_url {
                config.api_url = Some(url.to_string());
            }

            cs.config = Some(config.clone());
        }

        super::agent_api::invalidate_all_agents().await;
        return "ok".to_string();
    }

    // No matching profile, use provider directly (may be a known provider like "openrouter")
    super::agent_api::update_config(Some(provider), Some(model), None, None, None).await
}

/// Set a provider profile as the default.
/// Updates default_provider, api_url, api_key, and default_model based on the profile.
/// Uses custom:{base_url} format when base_url is provided with OpenAI-compatible endpoints.
pub async fn set_default_profile(id: String) -> String {
    let id = id.trim().to_string();
    if id.is_empty() {
        return "error: profile id must not be empty".into();
    }

    let (provider_name, base_url, model, api_key) = {
        let gc = super::agent_api::global_config().read().await;
        let config = match &gc.config {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        let profile = match config.model_providers.get(&id) {
            Some(p) => p,
            None => return format!("error: profile '{}' not found", id),
        };
        (
            profile.name.clone(),
            profile.base_url.clone(),
            profile.default_model.clone().unwrap_or_default(),
            profile.api_key.clone(),
        )
    };

    // Known valid zeroclaw provider types
    const KNOWN_PROVIDERS: &[&str] = &[
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
    ];

    // Determine the correct default_provider value:
    // 1. If base_url is provided, use "custom:{base_url}" (most reliable for compatible APIs)
    // 2. If name is a known valid provider, use it directly
    // 3. Otherwise fall back to profile id (may fail if not a valid provider)
    let effective_provider = if let Some(url) = &base_url {
        let url = url.trim();
        if !url.is_empty() {
            // Check if name is a known provider that doesn't need custom: prefix
            if let Some(name) = &provider_name {
                let name_lower = name.trim().to_lowercase();
                if KNOWN_PROVIDERS.iter().any(|p| *p == name_lower) {
                    name.trim().to_string()
                } else {
                    // Use custom:{base_url} for unknown provider names with base_url
                    format!("custom:{}", url)
                }
            } else {
                format!("custom:{}", url)
            }
        } else if let Some(name) = &provider_name {
            name.trim().to_string()
        } else {
            id.clone()
        }
    } else if let Some(name) = &provider_name {
        name.trim().to_string()
    } else {
        id.clone()
    };

    // Update BOTH global_config and config_state (critical for agent creation)
    {
        let mut gc = super::agent_api::global_config().write().await;
        let mut cs = super::agent_api::config_state().write().await;

        let config = match gc.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };

        config.default_provider = Some(effective_provider);

        if !model.is_empty() {
            config.default_model = Some(model);
        }

        if let Some(key) = &api_key {
            if !key.trim().is_empty() {
                config.api_key = Some(key.trim().to_string());
            }
        }

        if let Some(url) = &base_url {
            if !url.trim().is_empty() {
                config.api_url = Some(url.trim().to_string());
            }
        }

        // Sync to legacy config_state
        cs.config = Some(config.clone());
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Get the current default profile ID (returns default_provider value).
pub async fn get_default_profile_id() -> String {
    let gc = super::agent_api::global_config().read().await;
    match &gc.config {
        Some(c) => c.default_provider.clone().unwrap_or_default(),
        None => String::new(),
    }
}

/// Return the count of configured model provider profiles (sync for quick UI display)
#[frb(sync)]
pub fn model_provider_profile_count() -> u32 {
    if let Ok(guard) = super::agent_api::global_config().try_read() {
        if let Some(config) = &guard.config {
            return config.model_providers.len() as u32;
        }
    }
    0
}
