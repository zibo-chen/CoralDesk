use flutter_rust_bridge::frb;

// ──────────────────────── DTOs ────────────────────────────

/// A configured model provider profile exposed to Flutter UI.
/// Maps to zeroclaw's `[providers.models.<id>]` config section.
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
        .providers
        .models
        .iter()
        .map(|(id, cfg)| ModelProviderProfileDto {
            id: id.clone(),
            name: cfg.name.clone(),
            base_url: cfg.base_url.clone(),
            wire_api: cfg.wire_api.clone(),
            default_model: cfg.model.clone(),
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
        api_key: profile
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
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
        model: profile
            .default_model
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        api_path: None,
        temperature: None,
        timeout_secs: None,
        extra_headers: Default::default(),
        requires_openai_auth: false,
        azure_openai_resource: None,
        azure_openai_deployment: None,
        azure_openai_api_version: None,
        max_tokens: None,
        merge_system_into_user: false,
    };

    // Update BOTH global_config and config_state
    {
        let mut gc = super::agent_api::global_config().write().await;
        let mut cs = super::agent_api::config_state().write().await;
        let config = match gc.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        config.providers.models.insert(id, provider_config);
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
        if config.providers.models.remove(&id).is_none() {
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

    // Check if provider matches a providers.models profile
    let profile_config = {
        let gc = super::agent_api::global_config().read().await;
        match &gc.config {
            Some(c) => c.providers.models.get(&provider).cloned(),
            None => None,
        }
    };

    if profile_config.is_some() {
        // Update BOTH global_config and config_state
        {
            let mut gc = super::agent_api::global_config().write().await;
            let mut cs = super::agent_api::config_state().write().await;

            // Track which profile is selected so init_runtime can reconcile on restart
            gc.default_profile_id = Some(provider.clone());

            let config = match gc.config.as_mut() {
                Some(c) => c,
                None => return "error: runtime not initialized".into(),
            };

            config.providers.fallback = Some(provider.clone());
            if let Some(active_profile) = config.providers.models.get_mut(&provider) {
                active_profile.model = Some(model);
            }

            cs.config = Some(config.clone());
        }

        super::agent_api::invalidate_all_agents().await;
        // Persist to disk immediately to keep memory and disk in sync
        return super::agent_api::save_config_to_disk().await;
    }

    // No matching profile, use provider directly (may be a known provider like "openrouter")
    {
        let mut gc = super::agent_api::global_config().write().await;
        // Clear profile ID when using a raw provider (not a profile)
        gc.default_profile_id = None;
    }
    let result =
        super::agent_api::update_config(Some(provider), Some(model), None, None, None).await;
    if result == "ok" {
        // Also persist to disk to prevent stale values from being written later
        return super::agent_api::save_config_to_disk().await;
    }
    result
}

/// Set a provider profile as the default.
/// Marks a saved profile as the active fallback profile.
pub async fn set_default_profile(id: String) -> String {
    let id = id.trim().to_string();
    if id.is_empty() {
        return "error: profile id must not be empty".into();
    }

    let model = {
        let gc = super::agent_api::global_config().read().await;
        let config = match &gc.config {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        let profile = match config.providers.models.get(&id) {
            Some(p) => p,
            None => return format!("error: profile '{}' not found", id),
        };
        profile.model.clone().unwrap_or_default()
    };

    // Update BOTH global_config and config_state (critical for agent creation)
    {
        let mut gc = super::agent_api::global_config().write().await;
        let mut cs = super::agent_api::config_state().write().await;

        // Store the profile ID for UI persistence (do this first to avoid borrow issues)
        gc.default_profile_id = Some(id.clone());

        let config = match gc.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };

        config.providers.fallback = Some(id.clone());

        if !model.is_empty() {
            if let Some(profile) = config.providers.models.get_mut(&id) {
                profile.model = Some(model);
            }
        }

        // Sync to legacy config_state
        cs.config = Some(config.clone());
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Get the current default profile ID.
/// Returns the stored profile ID if set, otherwise returns empty string.
pub async fn get_default_profile_id() -> String {
    let gc = super::agent_api::global_config().read().await;
    gc.default_profile_id.clone().unwrap_or_default()
}

/// Return the count of configured model provider profiles (sync for quick UI display)
#[frb(sync)]
pub fn model_provider_profile_count() -> u32 {
    if let Ok(guard) = super::agent_api::global_config().try_read() {
        if let Some(config) = &guard.config {
            return config.providers.models.len() as u32;
        }
    }
    0
}
