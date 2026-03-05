// ──────────────────────── DTOs ────────────────────────────

/// Model route DTO — route a task hint to a specific provider + model
#[derive(Debug, Clone)]
pub struct ModelRouteDto {
    pub hint: String,
    pub provider: String,
    pub model: String,
    pub api_key: Option<String>,
}

/// Embedding route DTO — route an embedding hint to a specific provider + model
#[derive(Debug, Clone)]
pub struct EmbeddingRouteDto {
    pub hint: String,
    pub provider: String,
    pub model: String,
    pub dimensions: Option<u32>,
    pub api_key: Option<String>,
}

/// Embedding configuration for semantic search and memory recall
#[derive(Debug, Clone)]
pub struct EmbeddingConfigDto {
    pub embedding_provider: String,
    pub embedding_model: String,
    pub embedding_dimensions: u32,
    pub vector_weight: f64,
    pub keyword_weight: f64,
    pub min_relevance_score: f64,
    /// Base URL for custom embedding endpoints (extracted from "custom:<url>" provider)
    pub embedding_base_url: Option<String>,
    /// API key for embedding provider
    pub embedding_api_key: Option<String>,
}

// ──────────────────── Model Routes API ──────────────────────────

/// List all configured model routes
pub async fn list_model_routes() -> Vec<ModelRouteDto> {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return vec![],
    };

    config
        .model_routes
        .iter()
        .map(|r| ModelRouteDto {
            hint: r.hint.clone(),
            provider: r.provider.clone(),
            model: r.model.clone(),
            api_key: r.api_key.clone(),
        })
        .collect()
}

/// Create or update a model route by hint. Returns "ok" on success.
pub async fn upsert_model_route(route: ModelRouteDto) -> String {
    let hint = route.hint.trim().to_string();
    if hint.is_empty() {
        return "error: hint must not be empty".into();
    }
    if route.provider.trim().is_empty() {
        return "error: provider must not be empty".into();
    }
    if route.model.trim().is_empty() {
        return "error: model must not be empty".into();
    }

    let route_config = zeroclaw::config::ModelRouteConfig {
        hint: hint.clone(),
        provider: route.provider.trim().to_string(),
        model: route.model.trim().to_string(),
        max_tokens: None,
        api_key: route
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
        transport: None,
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };

        if let Some(existing) = config.model_routes.iter_mut().find(|r| r.hint == hint) {
            *existing = route_config;
        } else {
            config.model_routes.push(route_config);
        }
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Remove a model route by hint. Returns "ok" on success.
pub async fn remove_model_route(hint: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        let before = config.model_routes.len();
        config.model_routes.retain(|r| r.hint != hint);
        if config.model_routes.len() == before {
            return format!("error: route '{}' not found", hint);
        }
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

// ──────────────────── Embedding Routes API ──────────────────────────

/// List all configured embedding routes
pub async fn list_embedding_routes() -> Vec<EmbeddingRouteDto> {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return vec![],
    };

    config
        .embedding_routes
        .iter()
        .map(|r| EmbeddingRouteDto {
            hint: r.hint.clone(),
            provider: r.provider.clone(),
            model: r.model.clone(),
            dimensions: r.dimensions.map(|d| d as u32),
            api_key: r.api_key.clone(),
        })
        .collect()
}

/// Create or update an embedding route by hint. Returns "ok" on success.
pub async fn upsert_embedding_route(route: EmbeddingRouteDto) -> String {
    let hint = route.hint.trim().to_string();
    if hint.is_empty() {
        return "error: hint must not be empty".into();
    }
    if route.provider.trim().is_empty() {
        return "error: provider must not be empty".into();
    }
    if route.model.trim().is_empty() {
        return "error: model must not be empty".into();
    }

    let route_config = zeroclaw::config::EmbeddingRouteConfig {
        hint: hint.clone(),
        provider: route.provider.trim().to_string(),
        model: route.model.trim().to_string(),
        dimensions: route.dimensions.map(|d| d as usize),
        api_key: route
            .api_key
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(String::from),
    };

    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };

        if let Some(existing) = config.embedding_routes.iter_mut().find(|r| r.hint == hint) {
            *existing = route_config;
        } else {
            config.embedding_routes.push(route_config);
        }
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Remove an embedding route by hint. Returns "ok" on success.
pub async fn remove_embedding_route(hint: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        let before = config.embedding_routes.len();
        config.embedding_routes.retain(|r| r.hint != hint);
        if config.embedding_routes.len() == before {
            return format!("error: route '{}' not found", hint);
        }
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

// ──────────────────── Embedding Config API ──────────────────────────

/// Get current embedding configuration
pub async fn get_embedding_config() -> EmbeddingConfigDto {
    let cs = super::agent_api::config_state().read().await;
    let gc = super::agent_api::global_config().read().await;
    if let Some(config) = &cs.config {
        let m = &config.memory;
        // Extract base_url from "custom:<url>" provider format
        let (ui_provider, base_url) = if m.embedding_provider.starts_with("custom:") {
            let url = m
                .embedding_provider
                .strip_prefix("custom:")
                .unwrap_or("")
                .to_string();
            (
                "custom".to_string(),
                if url.is_empty() { None } else { Some(url) },
            )
        } else {
            (m.embedding_provider.clone(), None)
        };
        EmbeddingConfigDto {
            embedding_provider: ui_provider,
            embedding_model: m.embedding_model.clone(),
            embedding_dimensions: m.embedding_dimensions as u32,
            vector_weight: m.vector_weight,
            keyword_weight: m.keyword_weight,
            min_relevance_score: m.min_relevance_score,
            embedding_base_url: base_url,
            embedding_api_key: gc.embedding_api_key.clone(),
        }
    } else {
        EmbeddingConfigDto {
            embedding_provider: "none".into(),
            embedding_model: "text-embedding-3-small".into(),
            embedding_dimensions: 1536,
            vector_weight: 0.7,
            keyword_weight: 0.3,
            min_relevance_score: 0.4,
            embedding_base_url: None,
            embedding_api_key: None,
        }
    }
}

/// Update embedding configuration. Returns "ok" on success.
pub async fn update_embedding_config(config: EmbeddingConfigDto) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let mut gc = super::agent_api::global_config().write().await;

        // Ensure runtime is initialized
        if gc.config.is_none() {
            return "error: runtime not initialized".into();
        }

        // Reconstruct internal provider string: "custom:<url>" for custom providers
        let internal_provider = if config.embedding_provider == "custom" {
            let base_url = config.embedding_base_url.as_deref().unwrap_or("");
            format!("custom:{base_url}")
        } else {
            config.embedding_provider.clone()
        };

        // Update config_state (legacy)
        if let Some(cfg) = cs.config.as_mut() {
            cfg.memory.embedding_provider = internal_provider.clone();
            cfg.memory.embedding_model = config.embedding_model.clone();
            cfg.memory.embedding_dimensions = config.embedding_dimensions as usize;
            cfg.memory.vector_weight = config.vector_weight;
            cfg.memory.keyword_weight = config.keyword_weight;
            cfg.memory.min_relevance_score = config.min_relevance_score;
            cfg.memory.embedding_api_key = config.embedding_api_key.clone();
        }

        // Update global_config (used by agent creation)
        if let Some(cfg) = gc.config.as_mut() {
            cfg.memory.embedding_provider = internal_provider;
            cfg.memory.embedding_model = config.embedding_model;
            cfg.memory.embedding_dimensions = config.embedding_dimensions as usize;
            cfg.memory.vector_weight = config.vector_weight;
            cfg.memory.keyword_weight = config.keyword_weight;
            cfg.memory.min_relevance_score = config.min_relevance_score;
            cfg.memory.embedding_api_key = config.embedding_api_key.clone();
        }

        // Store API key reference for UI access
        gc.embedding_api_key = config.embedding_api_key;
    }

    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}
