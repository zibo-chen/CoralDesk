use flutter_rust_bridge::frb;
use zeroclaw::observability::llm_debug;

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

impl From<llm_debug::LlmDebugEntry> for LlmDebugEntryDto {
    fn from(e: llm_debug::LlmDebugEntry) -> Self {
        Self {
            id: e.id,
            timestamp: e.timestamp,
            session_id: e.session_id.unwrap_or_default(),
            provider: e.provider,
            model: e.model,
            temperature: e.temperature,
            iteration: e.iteration as u32,
            request_messages: e
                .request_messages
                .into_iter()
                .map(|m| LlmDebugMessageDto {
                    role: m.role,
                    content: m.content,
                    char_count: m.char_count as u32,
                })
                .collect(),
            tool_names: e.tool_names.unwrap_or_default(),
            response_text: e.response_text.unwrap_or_default(),
            response_tool_calls: e
                .response_tool_calls
                .unwrap_or_default()
                .into_iter()
                .map(|tc| LlmDebugToolCallDto {
                    name: tc.name,
                    arguments: tc.arguments,
                })
                .collect(),
            input_tokens: e.input_tokens,
            output_tokens: e.output_tokens,
            duration_ms: e.duration_ms.map(|d| d as u64),
            success: e.success,
            error: e.error.unwrap_or_default(),
            stop_reason: e.stop_reason.unwrap_or_default(),
        }
    }
}

// ──────────────────────────── API Functions ────────────────────────────

/// Check if LLM debug logging is enabled.
#[frb(sync)]
pub fn is_llm_debug_enabled() -> bool {
    llm_debug::is_enabled()
}

/// Enable or disable LLM debug logging.
#[frb(sync)]
pub fn set_llm_debug_enabled(enabled: bool) {
    llm_debug::set_enabled(enabled);
}

/// Load recent LLM debug entries.
/// Returns entries in reverse chronological order (most recent first).
pub fn get_llm_debug_entries(limit: u32, session_filter: String) -> Vec<LlmDebugEntryDto> {
    let filter = if session_filter.is_empty() {
        None
    } else {
        Some(session_filter.as_str())
    };
    match llm_debug::load_entries(limit as usize, filter) {
        Ok(entries) => entries.into_iter().map(LlmDebugEntryDto::from).collect(),
        Err(e) => {
            tracing::warn!("Failed to load LLM debug entries: {e}");
            Vec::new()
        }
    }
}

/// Get a single LLM debug entry by ID.
pub fn get_llm_debug_entry(entry_id: String) -> Option<LlmDebugEntryDto> {
    match llm_debug::load_entries(500, None) {
        Ok(entries) => entries
            .into_iter()
            .find(|e| e.id == entry_id)
            .map(LlmDebugEntryDto::from),
        Err(_) => None,
    }
}

/// Clear all LLM debug entries.
pub fn clear_llm_debug_entries() -> String {
    match llm_debug::clear_entries() {
        Ok(()) => "ok".to_string(),
        Err(e) => format!("error: {e}"),
    }
}

/// Get the path to the LLM debug log file.
#[frb(sync)]
pub fn get_llm_debug_log_path() -> String {
    llm_debug::get_log_path()
}
