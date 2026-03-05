use flutter_rust_bridge::frb;

// ──────────────────── DTOs ────────────────────────────────────

/// Proxy scope — determines which outbound traffic uses the proxy.
#[derive(Debug, Clone)]
pub enum ProxyScopeDto {
    /// Use system environment proxy variables only.
    Environment,
    /// Apply proxy to all ZeroClaw-managed HTTP traffic (default).
    Zeroclaw,
    /// Apply proxy only to explicitly listed service selectors.
    Services,
}

/// Proxy configuration exposed to Flutter.
#[derive(Debug, Clone)]
pub struct ProxyConfigDto {
    /// Whether proxy support is enabled.
    pub enabled: bool,
    /// Proxy URL for HTTP requests (http, https, socks5, socks5h).
    pub http_proxy: String,
    /// Proxy URL for HTTPS requests.
    pub https_proxy: String,
    /// Fallback proxy URL for all schemes.
    pub all_proxy: String,
    /// No-proxy bypass list (comma-separated).
    pub no_proxy: String,
    /// Proxy application scope.
    pub scope: ProxyScopeDto,
    /// Service selectors (used when scope = Services), comma-separated.
    pub services: String,
}

impl Default for ProxyConfigDto {
    fn default() -> Self {
        Self {
            enabled: false,
            http_proxy: String::new(),
            https_proxy: String::new(),
            all_proxy: String::new(),
            no_proxy: String::new(),
            scope: ProxyScopeDto::Zeroclaw,
            services: String::new(),
        }
    }
}

/// Supported service keys that can be used with scope = Services.
#[derive(Debug, Clone)]
pub struct ProxyServiceInfo {
    pub key: String,
    pub category: String,
}

// ──────────────────── Conversions ─────────────────────────────

impl From<zeroclaw::config::ProxyScope> for ProxyScopeDto {
    fn from(s: zeroclaw::config::ProxyScope) -> Self {
        match s {
            zeroclaw::config::ProxyScope::Environment => ProxyScopeDto::Environment,
            zeroclaw::config::ProxyScope::Zeroclaw => ProxyScopeDto::Zeroclaw,
            zeroclaw::config::ProxyScope::Services => ProxyScopeDto::Services,
        }
    }
}

impl From<ProxyScopeDto> for zeroclaw::config::ProxyScope {
    fn from(s: ProxyScopeDto) -> Self {
        match s {
            ProxyScopeDto::Environment => zeroclaw::config::ProxyScope::Environment,
            ProxyScopeDto::Zeroclaw => zeroclaw::config::ProxyScope::Zeroclaw,
            ProxyScopeDto::Services => zeroclaw::config::ProxyScope::Services,
        }
    }
}

fn proxy_config_to_dto(pc: &zeroclaw::config::ProxyConfig) -> ProxyConfigDto {
    ProxyConfigDto {
        enabled: pc.enabled,
        http_proxy: pc.http_proxy.clone().unwrap_or_default(),
        https_proxy: pc.https_proxy.clone().unwrap_or_default(),
        all_proxy: pc.all_proxy.clone().unwrap_or_default(),
        no_proxy: pc.no_proxy.join(", "),
        scope: pc.scope.into(),
        services: pc.services.join(", "),
    }
}

fn dto_to_proxy_config(dto: &ProxyConfigDto) -> zeroclaw::config::ProxyConfig {
    let parse_optional = |s: &str| -> Option<String> {
        let trimmed = s.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        }
    };
    let parse_list = |s: &str| -> Vec<String> {
        s.split(',')
            .map(|p| p.trim().to_string())
            .filter(|p| !p.is_empty())
            .collect()
    };

    zeroclaw::config::ProxyConfig {
        enabled: dto.enabled,
        http_proxy: parse_optional(&dto.http_proxy),
        https_proxy: parse_optional(&dto.https_proxy),
        all_proxy: parse_optional(&dto.all_proxy),
        no_proxy: parse_list(&dto.no_proxy),
        scope: dto.scope.clone().into(),
        services: parse_list(&dto.services),
    }
}

// ──────────────────── Public API ──────────────────────────────

/// Load the current proxy configuration from the runtime state.
pub async fn get_proxy_config() -> ProxyConfigDto {
    let cs = super::agent_api::config_state().read().await;
    match &cs.config {
        Some(config) => proxy_config_to_dto(&config.proxy),
        None => ProxyConfigDto::default(),
    }
}

/// Update the proxy configuration in-memory and apply it to the runtime
/// immediately (all future reqwest clients will use the new settings).
/// Returns "ok" on success or an error string.
pub async fn update_proxy_config(config: ProxyConfigDto) -> String {
    let proxy = dto_to_proxy_config(&config);

    // Validate before applying
    if let Err(e) = proxy.validate() {
        return format!("error: {e}");
    }

    // Update in-memory config
    {
        let mut cs = super::agent_api::config_state().write().await;
        match cs.config.as_mut() {
            Some(c) => c.proxy = proxy.clone(),
            None => return "error: runtime not initialized".into(),
        }
    }

    // Apply to runtime — this clears the cached clients so new requests
    // will pick up the proxy settings.
    zeroclaw::config::set_runtime_proxy_config(proxy.clone());

    // Handle environment variables based on proxy state
    if proxy.enabled && proxy.scope == zeroclaw::config::ProxyScope::Environment {
        // Set process env vars for Environment scope
        proxy.apply_to_process_env();
    } else {
        // Clear process env vars when proxy is disabled or scope changed
        // This ensures no stale proxy env vars affect future requests
        zeroclaw::config::ProxyConfig::clear_process_env();
    }

    "ok".into()
}

/// Save the current proxy configuration to disk (~/.zeroclaw/config.toml).
/// This is called separately from update so the user can test settings
/// before persisting.
pub async fn save_proxy_to_disk() -> String {
    super::agent_api::save_config_to_disk().await
}

/// Reset proxy configuration to defaults (disabled, no URLs).
/// This clears all proxy settings and syncs to both runtime and disk.
pub async fn reset_proxy_config() -> String {
    let default_proxy = zeroclaw::config::ProxyConfig::default();

    // Update in-memory config
    {
        let mut cs = super::agent_api::config_state().write().await;
        match cs.config.as_mut() {
            Some(c) => c.proxy = default_proxy.clone(),
            None => return "error: runtime not initialized".into(),
        }
    }

    // Apply to zeroclaw runtime
    zeroclaw::config::set_runtime_proxy_config(default_proxy);

    // Clear any process env vars
    zeroclaw::config::ProxyConfig::clear_process_env();

    // Persist to disk
    super::agent_api::save_config_to_disk().await
}

/// Get the current runtime proxy configuration status.
/// This returns the actual state from zeroclaw runtime, useful for debugging sync issues.
#[frb(sync)]
pub fn get_runtime_proxy_status() -> ProxyConfigDto {
    let runtime_proxy = zeroclaw::config::runtime_proxy_config();
    ProxyConfigDto {
        enabled: runtime_proxy.enabled,
        http_proxy: runtime_proxy.http_proxy.unwrap_or_default(),
        https_proxy: runtime_proxy.https_proxy.unwrap_or_default(),
        all_proxy: runtime_proxy.all_proxy.unwrap_or_default(),
        no_proxy: runtime_proxy.no_proxy.join(", "),
        scope: runtime_proxy.scope.into(),
        services: runtime_proxy.services.join(", "),
    }
}

/// List supported service keys for scope = Services.
/// Includes both specific keys and wildcard selectors.
#[frb(sync)]
pub fn list_proxy_services() -> Vec<ProxyServiceInfo> {
    let mut result: Vec<ProxyServiceInfo> = Vec::new();

    // Add wildcard selectors first (they appear at top of each category)
    for selector in zeroclaw::config::ProxyConfig::supported_service_selectors() {
        let category = selector.strip_suffix(".*").unwrap_or(selector).to_string();
        result.push(ProxyServiceInfo {
            key: selector.to_string(),
            category,
        });
    }

    // Add specific service keys
    for key in zeroclaw::config::ProxyConfig::supported_service_keys() {
        let category = key.split('.').next().unwrap_or("other").to_string();
        result.push(ProxyServiceInfo {
            key: key.to_string(),
            category,
        });
    }

    result
}

/// Quick test: validate a proxy URL without persisting anything.
#[frb(sync)]
pub fn validate_proxy_url(url: String) -> String {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return "ok".into();
    }
    // Basic URL validation: check scheme and host
    let Some((scheme, rest)) = trimmed.split_once("://") else {
        return "error: missing scheme. Use http://, https://, socks5://, or socks5h://".into();
    };
    match scheme {
        "http" | "https" | "socks5" | "socks5h" => {}
        other => {
            return format!(
                "error: unsupported scheme '{other}'. Use http, https, socks5, or socks5h"
            );
        }
    }
    // Must have a host part
    let host_part = rest.split('/').next().unwrap_or("");
    let host_no_port = host_part.split(':').next().unwrap_or("");
    if host_no_port.is_empty() {
        return "error: host is required".into();
    }
    "ok".into()
}
