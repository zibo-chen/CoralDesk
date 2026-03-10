use flutter_rust_bridge::frb;

/// Supported LLM provider types

#[derive(Debug, Clone)]
pub enum ProviderType {
    OpenAi,
    Anthropic,
    Gemini,
    Ollama,
    OpenRouter,
    Compatible,
    Bedrock,
    Copilot,
    Telnyx,
    Glm,
}

/// Application configuration exposed to Flutter

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub provider: String,
    pub model: String,
    pub api_key: String,
    pub api_base: Option<String>,
    pub temperature: f64,
    pub max_tool_iterations: u32,
    pub language: String,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            provider: "openrouter".into(),
            model: "anthropic/claude-sonnet-4-20250514".into(),
            api_key: String::new(),
            api_base: None,
            temperature: 0.7,
            max_tool_iterations: 50,
            language: "en".into(),
        }
    }
}

/// Provider info for display in UI

#[derive(Debug, Clone)]
pub struct ProviderInfo {
    pub id: String,
    pub name: String,
    pub provider_type: ProviderType,
    pub models: Vec<String>,
    pub requires_api_key: bool,
    pub requires_api_base: bool,
    /// Whether this provider uses OAuth device flow instead of API key.
    pub requires_oauth: bool,
}

/// Get the list of available providers with their supported models
#[frb(sync)]
pub fn list_providers() -> Vec<ProviderInfo> {
    vec![
        ProviderInfo {
            id: "copilot".into(),
            name: "GitHub Copilot".into(),
            provider_type: ProviderType::Copilot,
            models: vec![
                "gpt-4o".into(),
                "gpt-4o-mini".into(),
                "claude-sonnet-4-20250514".into(),
                "claude-3.5-haiku-20241022".into(),
                "o1".into(),
                "o3-mini".into(),
            ],
            requires_api_key: false,
            requires_api_base: false,
            requires_oauth: true,
        },
        ProviderInfo {
            id: "openai".into(),
            name: "OpenAI".into(),
            provider_type: ProviderType::OpenAi,
            models: vec![
                "gpt-4o".into(),
                "gpt-4o-mini".into(),
                "gpt-4-turbo".into(),
                "o1".into(),
                "o1-mini".into(),
                "o3-mini".into(),
            ],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "anthropic".into(),
            name: "Anthropic".into(),
            provider_type: ProviderType::Anthropic,
            models: vec![
                "claude-sonnet-4-20250514".into(),
                "claude-3-5-haiku-20241022".into(),
                "claude-3-opus-20240229".into(),
            ],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "gemini".into(),
            name: "Google Gemini".into(),
            provider_type: ProviderType::Gemini,
            models: vec![
                "gemini-2.0-flash".into(),
                "gemini-2.0-pro".into(),
                "gemini-1.5-pro".into(),
            ],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "ollama".into(),
            name: "Ollama (Local)".into(),
            provider_type: ProviderType::Ollama,
            models: vec![
                "llama3.3".into(),
                "qwen2.5".into(),
                "deepseek-r1".into(),
                "mistral".into(),
                "codellama".into(),
            ],
            requires_api_key: false,
            requires_api_base: true,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "openrouter".into(),
            name: "OpenRouter".into(),
            provider_type: ProviderType::OpenRouter,
            models: vec![
                "anthropic/claude-sonnet-4-20250514".into(),
                "openai/gpt-4o".into(),
                "google/gemini-2.0-flash".into(),
                "deepseek/deepseek-r1".into(),
                "meta-llama/llama-3.3-70b-instruct".into(),
            ],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "compatible".into(),
            name: "OpenAI Compatible".into(),
            provider_type: ProviderType::Compatible,
            models: vec!["default".into()],
            requires_api_key: true,
            requires_api_base: true,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "bedrock".into(),
            name: "AWS Bedrock".into(),
            provider_type: ProviderType::Bedrock,
            models: vec![
                "anthropic.claude-sonnet-4-20250514-v1:0".into(),
                "anthropic.claude-3-haiku-20240307-v1:0".into(),
            ],
            requires_api_key: true,
            requires_api_base: true,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "telnyx".into(),
            name: "Telnyx".into(),
            provider_type: ProviderType::Telnyx,
            models: vec![
                "meta-llama/Meta-Llama-3.1-70B-Instruct".into(),
                "meta-llama/Meta-Llama-3.1-8B-Instruct".into(),
            ],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
        ProviderInfo {
            id: "glm".into(),
            name: "Zhipu GLM".into(),
            provider_type: ProviderType::Glm,
            models: vec!["glm-4".into(), "glm-4-flash".into(), "glm-4-long".into()],
            requires_api_key: true,
            requires_api_base: false,
            requires_oauth: false,
        },
    ]
}

/// Load config from the zeroclaw runtime state
pub async fn load_config() -> AppConfig {
    super::agent_api::get_current_config().await
}

/// Save config — updates runtime state and persists to disk
pub async fn save_config(config: AppConfig) -> bool {
    let result = super::agent_api::update_config(
        Some(config.provider),
        Some(config.model),
        Some(config.api_key),
        config.api_base,
        Some(config.temperature),
    )
    .await;

    if result != "ok" {
        return false;
    }

    // Also persist to disk
    let disk_result = super::agent_api::save_config_to_disk().await;
    disk_result == "ok"
}
