use flutter_rust_bridge::frb;
use zeroclaw::observability::runtime_trace;

// ──────────────────────────── DTOs ────────────────────────────

/// A single message in an LLM debug entry.

#[derive(Debug, Clone)]
pub struct LlmDebugMessageDto {
    pub role: String,
    pub content: String,
    pub char_count: u32,
}

/// A tool call from an LLM debug response.

#[derive(Debug, Clone)]
pub struct LlmDebugToolCallDto {
    pub name: String,
    pub arguments: String,
}

/// A single LLM API call debug entry with full request/response details.

#[derive(Debug, Clone)]
pub struct LlmDebugEntryDto {
    pub id: String,
    pub timestamp: String,
    pub session_id: String,
    pub provider: String,
    pub model: String,
    pub temperature: f64,
    pub iteration: u32,
    pub request_messages: Vec<LlmDebugMessageDto>,
    pub tool_names: Vec<String>,
    pub response_text: String,
    pub response_tool_calls: Vec<LlmDebugToolCallDto>,
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
    pub duration_ms: Option<u64>,
    pub success: bool,
    pub error: String,
    pub stop_reason: String,
}

impl From<runtime_trace::RuntimeTraceEvent> for LlmDebugEntryDto {
    fn from(e: runtime_trace::RuntimeTraceEvent) -> Self {
        let runtime_trace::RuntimeTraceEvent {
            id,
            timestamp,
            event_type,
            provider,
            model,
            turn_id,
            success,
            message,
            payload,
            ..
        } = e;
        let tool_names = payload
            .get("tool")
            .and_then(|value| value.as_str())
            .map(|value| vec![value.to_string()])
            .or_else(|| {
                payload
                    .get("tool_names")
                    .and_then(|value| value.as_array())
                    .map(|items| {
                        items
                            .iter()
                            .filter_map(|item| item.as_str().map(ToOwned::to_owned))
                            .collect::<Vec<_>>()
                    })
            })
            .unwrap_or_default();
        Self {
            id,
            timestamp,
            session_id: turn_id.unwrap_or_default(),
            provider: provider.unwrap_or_default(),
            model: model.unwrap_or_default(),
            temperature: payload
                .get("temperature")
                .and_then(|value| value.as_f64())
                .unwrap_or(0.0),
            iteration: payload
                .get("iteration")
                .and_then(|value| value.as_u64())
                .unwrap_or(0) as u32,
            request_messages: Vec::new(),
            tool_names,
            response_text: message.clone().unwrap_or_else(|| payload.to_string()),
            response_tool_calls: Vec::new(),
            input_tokens: payload.get("input_tokens").and_then(|value| value.as_u64()),
            output_tokens: payload
                .get("output_tokens")
                .and_then(|value| value.as_u64()),
            duration_ms: payload.get("duration_ms").and_then(|value| value.as_u64()),
            success: success.unwrap_or(true),
            error: if success == Some(false) {
                message.unwrap_or_default()
            } else {
                String::new()
            },
            stop_reason: event_type,
        }
    }
}

// ──────────────────────────── API Functions ────────────────────────────

/// Check if LLM debug logging is enabled.
#[frb(sync)]
pub fn is_llm_debug_enabled() -> bool {
    super::agent_api::config_state()
        .try_read()
        .ok()
        .and_then(|guard| {
            guard.config.as_ref().map(|config| {
                config.observability.runtime_trace_mode.to_ascii_lowercase() != "none"
            })
        })
        .unwrap_or(false)
}

/// Enable or disable LLM debug logging.
#[frb(sync)]
pub fn set_llm_debug_enabled(enabled: bool) {
    if let Ok(mut gc) = super::agent_api::global_config().try_write() {
        if let Some(config) = gc.config.as_mut() {
            config.observability.runtime_trace_mode = if enabled {
                "rolling".into()
            } else {
                "none".into()
            };
            runtime_trace::init_from_config(&config.observability, &config.workspace_dir);
        }
    }
    if let Ok(mut cs) = super::agent_api::config_state().try_write() {
        if let Some(config) = cs.config.as_mut() {
            config.observability.runtime_trace_mode = if enabled {
                "rolling".into()
            } else {
                "none".into()
            };
        }
    }
}

/// Load recent LLM debug entries.
/// Returns entries in reverse chronological order (most recent first).
pub fn get_llm_debug_entries(limit: u32, session_filter: String) -> Vec<LlmDebugEntryDto> {
    let path = get_llm_debug_log_path();
    let path = std::path::PathBuf::from(path);
    let contains = if session_filter.is_empty() {
        None
    } else {
        Some(session_filter.as_str())
    };
    match runtime_trace::load_events(&path, limit as usize, None, contains) {
        Ok(entries) => entries.into_iter().map(LlmDebugEntryDto::from).collect(),
        Err(e) => {
            tracing::warn!("Failed to load LLM debug entries: {e}");
            Vec::new()
        }
    }
}

/// Get a single LLM debug entry by ID.
pub fn get_llm_debug_entry(entry_id: String) -> Option<LlmDebugEntryDto> {
    let path = std::path::PathBuf::from(get_llm_debug_log_path());
    match runtime_trace::find_event_by_id(&path, &entry_id) {
        Ok(entry) => entry.map(LlmDebugEntryDto::from),
        Err(_) => None,
    }
}

/// Clear all LLM debug entries.
pub fn clear_llm_debug_entries() -> String {
    let path = std::path::PathBuf::from(get_llm_debug_log_path());
    match std::fs::remove_file(path) {
        Ok(()) => "ok".to_string(),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => "ok".to_string(),
        Err(e) => format!("error: {e}"),
    }
}

/// Get the path to the LLM debug log file.
#[frb(sync)]
pub fn get_llm_debug_log_path() -> String {
    super::agent_api::config_state()
        .try_read()
        .ok()
        .and_then(|guard| {
            guard.config.as_ref().map(|config| {
                runtime_trace::resolve_trace_path(&config.observability, &config.workspace_dir)
                    .to_string_lossy()
                    .to_string()
            })
        })
        .unwrap_or_default()
}
