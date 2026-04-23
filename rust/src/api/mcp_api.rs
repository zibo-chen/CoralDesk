use std::collections::HashMap;

// ──────────────────────── DTOs ────────────────────────────

/// A key-value pair for HashMap serialization over FFI.
#[derive(Debug, Clone)]
pub struct KeyValueDto {
    pub key: String,
    pub value: String,
}

/// MCP server DTO for Flutter bridge
#[derive(Debug, Clone)]
pub struct McpServerDto {
    pub name: String,
    /// Whether this MCP server is enabled (active).
    pub enabled: bool,
    /// "stdio" | "http" | "sse"
    pub transport: String,
    pub url: String,
    pub command: String,
    pub args: Vec<String>,
    pub env: Vec<KeyValueDto>,
    pub headers: Vec<KeyValueDto>,
    pub tool_timeout_secs: Option<u64>,
}

/// MCP configuration overview
#[derive(Debug, Clone)]
pub struct McpConfigDto {
    pub enabled: bool,
    pub servers: Vec<McpServerDto>,
}

// ──────────────────── Helpers ──────────────────────────

fn transport_to_string(t: &zeroclaw::config::schema::McpTransport) -> String {
    match t {
        zeroclaw::config::schema::McpTransport::Stdio => "stdio".into(),
        zeroclaw::config::schema::McpTransport::Http => "http".into(),
        zeroclaw::config::schema::McpTransport::Sse => "sse".into(),
    }
}

fn string_to_transport(s: &str) -> zeroclaw::config::schema::McpTransport {
    match s.to_lowercase().as_str() {
        "http" => zeroclaw::config::schema::McpTransport::Http,
        "sse" => zeroclaw::config::schema::McpTransport::Sse,
        _ => zeroclaw::config::schema::McpTransport::Stdio,
    }
}

fn hashmap_to_kvs(map: &HashMap<String, String>) -> Vec<KeyValueDto> {
    map.iter()
        .map(|(k, v)| KeyValueDto {
            key: k.clone(),
            value: v.clone(),
        })
        .collect()
}

fn kvs_to_hashmap(kvs: &[KeyValueDto]) -> HashMap<String, String> {
    kvs.iter()
        .map(|kv| (kv.key.clone(), kv.value.clone()))
        .collect()
}

fn server_to_dto(s: &zeroclaw::config::schema::McpServerConfig) -> McpServerDto {
    McpServerDto {
        name: s.name.clone(),
        enabled: true,
        transport: transport_to_string(&s.transport),
        url: s.url.clone().unwrap_or_default(),
        command: s.command.clone(),
        args: s.args.clone(),
        env: hashmap_to_kvs(&s.env),
        headers: hashmap_to_kvs(&s.headers),
        tool_timeout_secs: s.tool_timeout_secs,
    }
}

fn dto_to_server(d: &McpServerDto) -> zeroclaw::config::schema::McpServerConfig {
    zeroclaw::config::schema::McpServerConfig {
        name: d.name.trim().to_string(),
        transport: string_to_transport(&d.transport),
        url: if d.url.trim().is_empty() {
            None
        } else {
            Some(d.url.trim().to_string())
        },
        command: d.command.trim().to_string(),
        args: d.args.clone(),
        env: kvs_to_hashmap(&d.env),
        headers: kvs_to_hashmap(&d.headers),
        tool_timeout_secs: d.tool_timeout_secs,
    }
}

// ──────────────────── API Functions ──────────────────────────

/// Get MCP configuration
pub async fn get_mcp_config() -> McpConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        McpConfigDto {
            enabled: config.mcp.enabled,
            servers: config.mcp.servers.iter().map(server_to_dto).collect(),
        }
    } else {
        McpConfigDto {
            enabled: false,
            servers: vec![],
        }
    }
}

/// List all configured MCP servers
pub async fn list_mcp_servers() -> Vec<McpServerDto> {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        config.mcp.servers.iter().map(server_to_dto).collect()
    } else {
        vec![]
    }
}

/// Helper: synchronise the MCP section from `config_state` into
/// `global_config` so that `ensure_session_agent` (which reads
/// `global_config`) picks up the latest MCP settings.
async fn sync_mcp_to_global() {
    let mcp_clone = {
        let cs = super::agent_api::config_state().read().await;
        cs.config.as_ref().map(|c| c.mcp.clone())
    };
    if let Some(mcp) = mcp_clone {
        let mut gc = super::agent_api::global_config().write().await;
        if let Some(ref mut gc_config) = gc.config {
            gc_config.mcp = mcp;
        }
    }
}

/// Enable or disable MCP
pub async fn set_mcp_enabled(enabled: bool) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        config.mcp.enabled = enabled;
    }
    sync_mcp_to_global().await;
    // Invalidate agent so it rebuilds with updated MCP tools
    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Add an MCP server. Returns "ok" or "error: ...".
pub async fn add_mcp_server(server: McpServerDto) -> String {
    let name = server.name.trim().to_string();
    if name.is_empty() {
        return "error: name must not be empty".into();
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        // Check for duplicate
        if config.mcp.servers.iter().any(|s| s.name == name) {
            return format!("error: server '{}' already exists", name);
        }
        config.mcp.servers.push(dto_to_server(&server));
    }
    sync_mcp_to_global().await;
    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Update an existing MCP server by name. Returns "ok" or "error: ...".
pub async fn update_mcp_server(server: McpServerDto) -> String {
    let name = server.name.trim().to_string();
    if name.is_empty() {
        return "error: name must not be empty".into();
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        match config.mcp.servers.iter_mut().find(|s| s.name == name) {
            Some(existing) => *existing = dto_to_server(&server),
            None => return format!("error: server '{}' not found", name),
        }
    }
    sync_mcp_to_global().await;
    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Toggle an MCP server enabled/disabled by name. Returns "ok" or "error: ...".
pub async fn toggle_mcp_server(name: String, enabled: bool) -> String {
    let name = name.trim().to_string();
    if !enabled {
        return format!(
            "error: server '{}' cannot be disabled in-place on zeroclaw v0.7; remove it instead",
            name
        );
    }
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        if !config.mcp.servers.iter().any(|s| s.name == name) {
            return format!("error: server '{}' not found", name);
        }
    }
    sync_mcp_to_global().await;
    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}

/// Remove an MCP server by name. Returns "ok" or "error: ...".
pub async fn remove_mcp_server(name: String) -> String {
    let name = name.trim().to_string();
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: runtime not initialized".into(),
        };
        let before = config.mcp.servers.len();
        config.mcp.servers.retain(|s| s.name != name);
        if config.mcp.servers.len() == before {
            return format!("error: server '{}' not found", name);
        }
    }
    sync_mcp_to_global().await;
    super::agent_api::invalidate_all_agents().await;
    super::agent_api::save_config_to_disk().await
}
