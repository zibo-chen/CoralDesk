use flutter_rust_bridge::frb;
use std::sync::OnceLock;
use tokio::sync::Mutex as TokioMutex;

// ──────────────────────── DTOs ────────────────────────────

/// A persisted chat session with messages
#[derive(Debug, Clone)]
pub struct SessionDetail {
    pub id: String,
    pub title: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub message_count: u32,
    pub messages: Vec<SessionMessage>,
    pub attached_files: Vec<String>,
}

/// A message within a session
#[derive(Debug, Clone)]
pub struct SessionMessage {
    pub id: String,
    pub role: String,
    pub content: String,
    pub timestamp: i64,
    /// JSON-serialized tool calls (empty string = none)
    pub tool_calls_json: String,
    /// JSON-serialized message parts (empty string = none)
    pub parts_json: String,
    /// Agent role name for multi-agent sessions (empty = none)
    pub agent_role: String,
    /// Hex color for the agent role (empty = none)
    pub agent_color: String,
    /// Emoji icon for the agent role (empty = none)
    pub agent_icon: String,
}

/// Session list item (without messages)
#[derive(Debug, Clone)]
pub struct SessionSummary {
    pub id: String,
    pub title: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub message_count: u32,
    pub last_message_preview: String,
    pub attached_files: Vec<String>,
    /// Project this session belongs to (empty = free/independent)
    pub project_id: String,
    /// Whether this session is ephemeral (should not be persisted)
    pub ephemeral: bool,
    /// Agent workspace ID bound to this session (empty = none)
    pub agent_binding: String,
}

/// Session statistics
#[derive(Debug, Clone)]
pub struct SessionStats {
    pub total_sessions: u32,
    pub total_messages: u32,
    pub active_session_id: String,
}

// ──────────────────── Persistence State ──────────────────────

#[frb(ignore)]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct PersistedSession {
    id: String,
    title: String,
    created_at: i64,
    updated_at: i64,
    messages: Vec<PersistedMessage>,
    #[serde(default)]
    attached_files: Vec<String>,
    /// Project this session belongs to (empty = free/independent)
    #[serde(default)]
    project_id: String,
    /// Whether this session is ephemeral
    #[serde(default)]
    ephemeral: bool,
    /// Agent workspace binding (empty = none)
    #[serde(default)]
    agent_binding: String,
}

#[frb(ignore)]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
struct PersistedMessage {
    id: String,
    role: String,
    content: String,
    timestamp: i64,
    #[serde(default)]
    tool_calls_json: String,
    #[serde(default)]
    parts_json: String,
    #[serde(default)]
    agent_role: String,
    #[serde(default)]
    agent_color: String,
    #[serde(default)]
    agent_icon: String,
}

#[frb(ignore)]
#[derive(Debug, Default, serde::Serialize, serde::Deserialize)]
struct SessionStore {
    sessions: Vec<PersistedSession>,
}

fn session_store() -> &'static TokioMutex<SessionStore> {
    static STORE: OnceLock<TokioMutex<SessionStore>> = OnceLock::new();
    STORE.get_or_init(|| TokioMutex::new(SessionStore::default()))
}

fn sessions_file_path() -> std::path::PathBuf {
    dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("coraldesk_sessions.json")
}

// ──────────────────── API Functions ──────────────────────────

/// Initialize session store — load from disk
pub async fn init_session_store() -> String {
    let path = sessions_file_path();
    let store = if path.exists() {
        match tokio::fs::read_to_string(&path).await {
            Ok(content) => serde_json::from_str::<SessionStore>(&content).unwrap_or_default(),
            Err(_) => SessionStore::default(),
        }
    } else {
        SessionStore::default()
    };

    let count = store.sessions.len();

    // Restore agent workspace bindings from persisted session metadata
    {
        let mut bindings = super::agent_workspace_api::session_bindings_mut().await;
        for session in &store.sessions {
            if !session.agent_binding.is_empty() {
                bindings.insert(session.id.clone(), session.agent_binding.clone());
            }
        }
    }

    *session_store().lock().await = store;
    format!("loaded {} sessions", count)
}

/// List all sessions (without full messages)
pub async fn list_sessions() -> Vec<SessionSummary> {
    let store = session_store().lock().await;
    store
        .sessions
        .iter()
        .map(|s| {
            let preview = s
                .messages
                .last()
                .map(|m| {
                    let truncated: String = m.content.chars().take(80).collect();
                    if truncated.len() < m.content.len() {
                        format!("{}...", truncated)
                    } else {
                        m.content.clone()
                    }
                })
                .unwrap_or_default();
            SessionSummary {
                id: s.id.clone(),
                title: s.title.clone(),
                created_at: s.created_at,
                updated_at: s.updated_at,
                message_count: s.messages.len() as u32,
                last_message_preview: preview,
                attached_files: s.attached_files.clone(),
                project_id: s.project_id.clone(),
                ephemeral: s.ephemeral,
                agent_binding: s.agent_binding.clone(),
            }
        })
        .collect()
}

/// Get full session detail including messages
pub async fn get_session_detail(session_id: String) -> Option<SessionDetail> {
    let store = session_store().lock().await;
    store
        .sessions
        .iter()
        .find(|s| s.id == session_id)
        .map(|s| SessionDetail {
            id: s.id.clone(),
            title: s.title.clone(),
            created_at: s.created_at,
            updated_at: s.updated_at,
            message_count: s.messages.len() as u32,
            messages: s
                .messages
                .iter()
                .map(|m| SessionMessage {
                    id: m.id.clone(),
                    role: m.role.clone(),
                    content: m.content.clone(),
                    timestamp: m.timestamp,
                    tool_calls_json: m.tool_calls_json.clone(),
                    parts_json: m.parts_json.clone(),
                    agent_role: m.agent_role.clone(),
                    agent_color: m.agent_color.clone(),
                    agent_icon: m.agent_icon.clone(),
                })
                .collect(),
            attached_files: s.attached_files.clone(),
        })
}

/// Save/update a session with its messages
pub async fn save_session(
    session_id: String,
    title: String,
    messages: Vec<SessionMessage>,
    project_id: String,
    ephemeral: bool,
    agent_binding: String,
) -> String {
    let mut store = session_store().lock().await;
    let now = chrono::Utc::now().timestamp();

    let persisted_msgs: Vec<PersistedMessage> = messages
        .iter()
        .map(|m| PersistedMessage {
            id: m.id.clone(),
            role: m.role.clone(),
            content: m.content.clone(),
            timestamp: m.timestamp,
            tool_calls_json: m.tool_calls_json.clone(),
            parts_json: m.parts_json.clone(),
            agent_role: m.agent_role.clone(),
            agent_color: m.agent_color.clone(),
            agent_icon: m.agent_icon.clone(),
        })
        .collect();

    if let Some(session) = store.sessions.iter_mut().find(|s| s.id == session_id) {
        session.title = title;
        session.updated_at = now;
        session.messages = persisted_msgs;
        session.project_id = project_id;
        session.ephemeral = ephemeral;
        session.agent_binding = agent_binding;
    } else {
        store.sessions.insert(
            0,
            PersistedSession {
                id: session_id,
                title,
                created_at: now,
                updated_at: now,
                messages: persisted_msgs,
                attached_files: vec![],
                project_id,
                ephemeral,
                agent_binding,
            },
        );
    }

    // Persist to disk
    drop(store);
    persist_to_disk().await
}

/// Delete a session
pub async fn delete_session(session_id: String) -> String {
    let mut store = session_store().lock().await;
    store.sessions.retain(|s| s.id != session_id);
    drop(store);
    persist_to_disk().await
}

/// Rename a session
pub async fn rename_session(session_id: String, new_title: String) -> String {
    let mut store = session_store().lock().await;
    if let Some(session) = store.sessions.iter_mut().find(|s| s.id == session_id) {
        session.title = new_title;
        session.updated_at = chrono::Utc::now().timestamp();
    }
    drop(store);
    persist_to_disk().await
}

/// Update session metadata (project_id, ephemeral, agent_binding) without
/// touching messages. Useful when upgrading a session to a project or
/// changing the bound agent workspace.
/// Pass empty string for project_id or agent_binding to leave unchanged.
/// Use the special value \"__CLEAR__\" to explicitly clear a field.
/// For ephemeral: -1 = no change, 0 = set false, 1 = set true.
pub async fn update_session_metadata(
    session_id: String,
    project_id: String,
    ephemeral: i8,
    agent_binding: String,
) -> String {
    let mut store = session_store().lock().await;
    if let Some(session) = store.sessions.iter_mut().find(|s| s.id == session_id) {
        if project_id == "__CLEAR__" {
            session.project_id = String::new();
        } else if !project_id.is_empty() {
            session.project_id = project_id;
        }
        match ephemeral {
            0 => session.ephemeral = false,
            1 => session.ephemeral = true,
            _ => {} // -1 or anything else: no change
        }
        if agent_binding == "__CLEAR__" {
            session.agent_binding = String::new();
        } else if !agent_binding.is_empty() {
            session.agent_binding = agent_binding;
        }
        session.updated_at = chrono::Utc::now().timestamp();
    } else {
        return "error: session not found".into();
    }
    drop(store);
    persist_to_disk().await
}

/// Get session statistics
pub async fn get_session_stats() -> SessionStats {
    let store = session_store().lock().await;
    let total_msgs: u32 = store.sessions.iter().map(|s| s.messages.len() as u32).sum();
    let active = super::agent_api::config_state().read().await;
    let active_id = active.active_session_id.clone().unwrap_or_default();

    SessionStats {
        total_sessions: store.sessions.len() as u32,
        total_messages: total_msgs,
        active_session_id: active_id,
    }
}

/// Clear all sessions
pub async fn clear_all_sessions() -> String {
    let mut store = session_store().lock().await;
    store.sessions.clear();
    drop(store);
    persist_to_disk().await
}

// ──────────────────── Session File Attachments ───────────────

/// Add files to a session's attached files list.
/// Deduplicates and validates paths exist on disk.
pub async fn add_session_files(session_id: String, file_paths: Vec<String>) -> Vec<String> {
    let mut store = session_store().lock().await;

    // Ensure session exists — create a stub if it doesn't yet
    if !store.sessions.iter().any(|s| s.id == session_id) {
        let now = chrono::Utc::now().timestamp();
        store.sessions.insert(
            0,
            PersistedSession {
                id: session_id.clone(),
                title: "New Chat".into(),
                created_at: now,
                updated_at: now,
                messages: vec![],
                attached_files: vec![],
                project_id: String::new(),
                ephemeral: false,
                agent_binding: String::new(),
            },
        );
    }

    let session = store
        .sessions
        .iter_mut()
        .find(|s| s.id == session_id)
        .unwrap();

    for path in &file_paths {
        let p = std::path::Path::new(path);
        if p.exists() && !session.attached_files.contains(path) {
            session.attached_files.push(path.clone());
        }
    }
    session.updated_at = chrono::Utc::now().timestamp();
    let result = session.attached_files.clone();
    drop(store);
    let _ = persist_to_disk().await;
    result
}

/// Remove a file from a session's attached files list.
pub async fn remove_session_file(session_id: String, file_path: String) -> Vec<String> {
    let mut store = session_store().lock().await;
    if let Some(session) = store.sessions.iter_mut().find(|s| s.id == session_id) {
        session.attached_files.retain(|f| f != &file_path);
        session.updated_at = chrono::Utc::now().timestamp();
    }
    let result = store
        .sessions
        .iter()
        .find(|s| s.id == session_id)
        .map(|s| s.attached_files.clone())
        .unwrap_or_default();
    drop(store);
    let _ = persist_to_disk().await;
    result
}

/// Get the attached files for a session.
pub async fn get_session_files(session_id: String) -> Vec<String> {
    let store = session_store().lock().await;
    store
        .sessions
        .iter()
        .find(|s| s.id == session_id)
        .map(|s| s.attached_files.clone())
        .unwrap_or_default()
}

/// Clear all attached files for a session.
pub async fn clear_session_files(session_id: String) -> String {
    let mut store = session_store().lock().await;
    if let Some(session) = store.sessions.iter_mut().find(|s| s.id == session_id) {
        session.attached_files.clear();
        session.updated_at = chrono::Utc::now().timestamp();
    }
    drop(store);
    persist_to_disk().await
}

// ──────────────────── Helpers ─────────────────────────────────

async fn persist_to_disk() -> String {
    let store = session_store().lock().await;
    let path = sessions_file_path();

    // Ensure directory exists
    if let Some(parent) = path.parent() {
        let _ = tokio::fs::create_dir_all(parent).await;
    }

    match serde_json::to_string_pretty(&*store) {
        Ok(json) => match tokio::fs::write(&path, json).await {
            Ok(()) => "ok".into(),
            Err(e) => format!("error: write failed: {e}"),
        },
        Err(e) => format!("error: serialize failed: {e}"),
    }
}
