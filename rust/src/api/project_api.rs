//! Project API — project-level organization for chat sessions.
//!
//! A Project groups related sessions under a single context,
//! providing persistent context, directory binding, and cross-session
//! knowledge for long-running tasks (e.g. coding projects, daily data
//! processing, automation workflows).

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::OnceLock;
use tokio::sync::Mutex as TokioMutex;

// ──────────────────────── DTOs ────────────────────────────

/// Project type enum exposed to Flutter
#[derive(Debug, Clone)]
pub enum ProjectType {
    /// General-purpose project
    General,
    /// Programming/development project — shows file tree, run commands
    CodeProject,
    /// Data processing/analysis — data preview, scheduled execution
    DataProcessing,
    /// Writing/documentation project
    Writing,
    /// Automation/scheduled task workflow
    Automation,
}

/// Project status enum exposed to Flutter
#[derive(Debug, Clone)]
pub enum ProjectStatus {
    Active,
    Paused,
    Archived,
    Completed,
}

/// Full project DTO for Flutter UI
#[derive(Debug, Clone)]
pub struct ProjectDto {
    pub id: String,
    pub name: String,
    pub description: String,
    pub icon: String,
    pub color_tag: String,
    pub project_type: ProjectType,
    pub status: ProjectStatus,
    /// Bound local filesystem directory (optional)
    pub project_dir: String,
    /// Cross-session persistent context/memo
    pub pinned_context: String,
    /// Bound role (agent workspace) IDs — a project can have multiple roles
    pub role_ids: Vec<String>,
    /// Default role ID for new sessions (empty = no default)
    pub default_role_id: String,
    /// Associated session IDs
    pub session_ids: Vec<String>,
    pub tags: Vec<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

/// Summary for listing projects in sidebar/list
#[derive(Debug, Clone)]
pub struct ProjectSummary {
    pub id: String,
    pub name: String,
    pub description: String,
    pub icon: String,
    pub color_tag: String,
    pub project_type: String,
    pub status: String,
    pub session_count: u32,
    pub role_count: u32,
    pub has_project_dir: bool,
    pub role_ids: Vec<String>,
    pub default_role_id: String,
    pub created_at: i64,
    pub updated_at: i64,
}

// ──────────────────── Persistence State ──────────────────────

#[frb(ignore)]
#[derive(Debug, Clone, Serialize, Deserialize)]
struct PersistedProject {
    id: String,
    name: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    icon: String,
    #[serde(default)]
    color_tag: String,
    #[serde(default = "default_project_type")]
    project_type: String,
    #[serde(default = "default_project_status")]
    status: String,
    #[serde(default)]
    project_dir: String,
    #[serde(default)]
    pinned_context: String,
    /// Legacy field — migrated to role_ids on load
    #[serde(default)]
    agent_workspace_id: String,
    /// Bound role (agent workspace) IDs
    #[serde(default)]
    role_ids: Vec<String>,
    /// Default role ID for new sessions
    #[serde(default)]
    default_role_id: String,
    #[serde(default)]
    session_ids: Vec<String>,
    #[serde(default)]
    tags: Vec<String>,
    created_at: i64,
    updated_at: i64,
}

#[frb(ignore)]
fn default_project_type() -> String {
    "general".into()
}

#[frb(ignore)]
fn default_project_status() -> String {
    "active".into()
}

#[frb(ignore)]
#[derive(Debug, Default, Serialize, Deserialize)]
struct ProjectStore {
    projects: Vec<PersistedProject>,
}

fn project_store() -> &'static TokioMutex<ProjectStore> {
    static STORE: OnceLock<TokioMutex<ProjectStore>> = OnceLock::new();
    STORE.get_or_init(|| TokioMutex::new(ProjectStore::default()))
}

fn store_file_path() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_default()
        .join(".coraldesk")
        .join("coraldesk_projects.json")
}

// ──────────────────── Conversion Helpers ─────────────────────

#[frb(ignore)]
fn project_type_to_string(pt: &ProjectType) -> String {
    match pt {
        ProjectType::General => "general",
        ProjectType::CodeProject => "code_project",
        ProjectType::DataProcessing => "data_processing",
        ProjectType::Writing => "writing",
        ProjectType::Automation => "automation",
    }
    .into()
}

#[frb(ignore)]
fn string_to_project_type(s: &str) -> ProjectType {
    match s {
        "code_project" => ProjectType::CodeProject,
        "data_processing" => ProjectType::DataProcessing,
        "writing" => ProjectType::Writing,
        "automation" => ProjectType::Automation,
        _ => ProjectType::General,
    }
}

#[frb(ignore)]
fn status_to_string(s: &ProjectStatus) -> String {
    match s {
        ProjectStatus::Active => "active",
        ProjectStatus::Paused => "paused",
        ProjectStatus::Archived => "archived",
        ProjectStatus::Completed => "completed",
    }
    .into()
}

#[frb(ignore)]
fn string_to_status(s: &str) -> ProjectStatus {
    match s {
        "paused" => ProjectStatus::Paused,
        "archived" => ProjectStatus::Archived,
        "completed" => ProjectStatus::Completed,
        _ => ProjectStatus::Active,
    }
}

#[frb(ignore)]
fn persisted_to_dto(p: &PersistedProject) -> ProjectDto {
    // Migrate legacy agent_workspace_id → role_ids if needed
    let mut role_ids = p.role_ids.clone();
    if role_ids.is_empty() && !p.agent_workspace_id.is_empty() {
        role_ids.push(p.agent_workspace_id.clone());
    }
    let default_role_id = if p.default_role_id.is_empty() {
        role_ids.first().cloned().unwrap_or_default()
    } else {
        p.default_role_id.clone()
    };
    ProjectDto {
        id: p.id.clone(),
        name: p.name.clone(),
        description: p.description.clone(),
        icon: p.icon.clone(),
        color_tag: p.color_tag.clone(),
        project_type: string_to_project_type(&p.project_type),
        status: string_to_status(&p.status),
        project_dir: p.project_dir.clone(),
        pinned_context: p.pinned_context.clone(),
        role_ids,
        default_role_id,
        session_ids: p.session_ids.clone(),
        tags: p.tags.clone(),
        created_at: p.created_at,
        updated_at: p.updated_at,
    }
}

#[frb(ignore)]
fn persisted_to_summary(p: &PersistedProject) -> ProjectSummary {
    // Resolve effective role_ids (including legacy migration)
    let effective_role_ids = if p.role_ids.is_empty() && !p.agent_workspace_id.is_empty() {
        vec![p.agent_workspace_id.clone()]
    } else {
        p.role_ids.clone()
    };
    let role_count = effective_role_ids.len();
    let default_role_id = if !p.default_role_id.is_empty() {
        p.default_role_id.clone()
    } else if !effective_role_ids.is_empty() {
        effective_role_ids[0].clone()
    } else {
        String::new()
    };
    ProjectSummary {
        id: p.id.clone(),
        name: p.name.clone(),
        description: p.description.clone(),
        icon: p.icon.clone(),
        color_tag: p.color_tag.clone(),
        project_type: p.project_type.clone(),
        status: p.status.clone(),
        session_count: p.session_ids.len() as u32,
        role_count: role_count as u32,
        has_project_dir: !p.project_dir.is_empty(),
        role_ids: effective_role_ids,
        default_role_id,
        created_at: p.created_at,
        updated_at: p.updated_at,
    }
}

// ──────────────────── API Functions ──────────────────────────

/// Initialize project store — load from disk
pub async fn init_project_store() -> String {
    let path = store_file_path();
    let store = if path.exists() {
        match tokio::fs::read_to_string(&path).await {
            Ok(content) => serde_json::from_str::<ProjectStore>(&content).unwrap_or_default(),
            Err(_) => ProjectStore::default(),
        }
    } else {
        ProjectStore::default()
    };

    let count = store.projects.len();
    *project_store().lock().await = store;
    format!("loaded {} projects", count)
}

/// List all projects (summary only)
pub async fn list_projects() -> Vec<ProjectSummary> {
    let store = project_store().lock().await;
    store.projects.iter().map(persisted_to_summary).collect()
}

/// Get full details of a single project
pub async fn get_project(project_id: String) -> Option<ProjectDto> {
    let store = project_store().lock().await;
    store
        .projects
        .iter()
        .find(|p| p.id == project_id)
        .map(persisted_to_dto)
}

/// Create or update a project
pub async fn upsert_project(project: ProjectDto) -> String {
    let id = if project.id.trim().is_empty() {
        uuid::Uuid::new_v4().to_string()
    } else {
        project.id.trim().to_string()
    };
    if project.name.trim().is_empty() {
        return "error: project name must not be empty".into();
    }

    let now = chrono::Utc::now().timestamp();
    let mut store = project_store().lock().await;

    let project_type_str = project_type_to_string(&project.project_type);
    let status_str = status_to_string(&project.status);

    if let Some(existing) = store.projects.iter_mut().find(|p| p.id == id) {
        existing.name = project.name;
        existing.description = project.description;
        existing.icon = project.icon;
        existing.color_tag = project.color_tag;
        existing.project_type = project_type_str;
        existing.status = status_str;
        existing.project_dir = project.project_dir;
        existing.pinned_context = project.pinned_context;
        existing.role_ids = project.role_ids;
        existing.default_role_id = project.default_role_id;
        existing.agent_workspace_id = String::new(); // cleared after migration
        existing.session_ids = project.session_ids;
        existing.tags = project.tags;
        existing.updated_at = now;
    } else {
        store.projects.insert(
            0,
            PersistedProject {
                id: id.clone(),
                name: project.name,
                description: project.description,
                icon: project.icon,
                color_tag: project.color_tag,
                project_type: project_type_str,
                status: status_str,
                project_dir: project.project_dir,
                pinned_context: project.pinned_context,
                agent_workspace_id: String::new(),
                role_ids: project.role_ids,
                default_role_id: project.default_role_id,
                session_ids: project.session_ids,
                tags: project.tags,
                created_at: now,
                updated_at: now,
            },
        );
    }

    drop(store);
    let result = persist_store().await;
    if result == "ok" {
        id
    } else {
        result
    }
}

/// Delete a project (does NOT delete the sessions; only the project container)
pub async fn delete_project(project_id: String) -> String {
    let mut store = project_store().lock().await;
    store.projects.retain(|p| p.id != project_id);
    drop(store);
    persist_store().await
}

/// Add a session to a project
pub async fn add_session_to_project(project_id: String, session_id: String) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        if !project.session_ids.contains(&session_id) {
            project.session_ids.push(session_id);
            project.updated_at = chrono::Utc::now().timestamp();
        }
    } else {
        return "error: project not found".into();
    }
    drop(store);
    persist_store().await
}

/// Remove a session from a project
pub async fn remove_session_from_project(project_id: String, session_id: String) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        project.session_ids.retain(|s| s != &session_id);
        project.updated_at = chrono::Utc::now().timestamp();
    }
    drop(store);
    persist_store().await
}

/// Update project pinned context
pub async fn update_project_context(project_id: String, pinned_context: String) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        project.pinned_context = pinned_context;
        project.updated_at = chrono::Utc::now().timestamp();
    } else {
        return "error: project not found".into();
    }
    drop(store);
    persist_store().await
}

/// Update project status
pub async fn update_project_status(project_id: String, status: ProjectStatus) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        project.status = status_to_string(&status);
        project.updated_at = chrono::Utc::now().timestamp();
    } else {
        return "error: project not found".into();
    }
    drop(store);
    persist_store().await
}

/// Add a role (agent workspace) to a project
pub async fn add_role_to_project(project_id: String, role_id: String) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        if !project.role_ids.contains(&role_id) {
            project.role_ids.push(role_id);
            project.updated_at = chrono::Utc::now().timestamp();
        }
    } else {
        return "error: project not found".into();
    }
    drop(store);
    persist_store().await
}

/// Remove a role from a project
pub async fn remove_role_from_project(project_id: String, role_id: String) -> String {
    let mut store = project_store().lock().await;
    let session_ids_to_unbind;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        project.role_ids.retain(|r| r != &role_id);
        if project.default_role_id == role_id {
            project.default_role_id = project.role_ids.first().cloned().unwrap_or_default();
        }
        project.updated_at = chrono::Utc::now().timestamp();
        // Collect session IDs that need unbinding
        session_ids_to_unbind = project.session_ids.clone();
    } else {
        return "error: project not found".into();
    }
    drop(store);

    // Unbind sessions that were using the removed role
    for sid in &session_ids_to_unbind {
        let binding = super::agent_workspace_api::get_binding_for_session(sid).await;
        if binding.as_deref() == Some(&role_id) {
            super::agent_workspace_api::unbind_session_agent(sid.clone()).await;
        }
    }

    persist_store().await
}

/// Set the default role for a project
pub async fn set_project_default_role(project_id: String, role_id: String) -> String {
    let mut store = project_store().lock().await;
    if let Some(project) = store.projects.iter_mut().find(|p| p.id == project_id) {
        if project.role_ids.contains(&role_id) || role_id.is_empty() {
            project.default_role_id = role_id;
            project.updated_at = chrono::Utc::now().timestamp();
        } else {
            return "error: role not in project".into();
        }
    } else {
        return "error: project not found".into();
    }
    drop(store);
    persist_store().await
}

/// Get the project ID that a session belongs to (if any)
pub async fn get_session_project(session_id: String) -> Option<String> {
    let store = project_store().lock().await;
    store
        .projects
        .iter()
        .find(|p| p.session_ids.contains(&session_id))
        .map(|p| p.id.clone())
}

/// Get the pinned context for a project (used when creating new sessions
/// within the project to inject historical context)
pub async fn get_project_pinned_context(project_id: String) -> String {
    let store = project_store().lock().await;
    store
        .projects
        .iter()
        .find(|p| p.id == project_id)
        .map(|p| p.pinned_context.clone())
        .unwrap_or_default()
}

// ──────────────────── Helpers ─────────────────────────────────

async fn persist_store() -> String {
    let store = project_store().lock().await;
    let path = store_file_path();
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
