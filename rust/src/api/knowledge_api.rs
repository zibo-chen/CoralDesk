use std::sync::OnceLock;
use tokio::sync::Mutex as TokioMutex;

// ──────────────────────── DTOs ────────────────────────────

/// A memory/knowledge entry for display in the GUI
#[derive(Debug, Clone)]
pub struct KnowledgeEntry {
    pub id: String,
    pub key: String,
    pub content: String,
    pub category: String,
    pub timestamp: String,
    pub session_id: String,
    /// Project this entry belongs to (empty = global)
    pub project_id: String,
    pub score: f64,
}

/// Knowledge base statistics
#[derive(Debug, Clone)]
pub struct KnowledgeStats {
    pub total_entries: u32,
    pub backend: String,
    pub healthy: bool,
    pub embedding_provider: String,
    pub embedding_model: String,
    pub auto_save: bool,
}

// ──────────────────── Cached Memory Backend ──────────────────

fn memory_backend() -> &'static TokioMutex<Option<Box<dyn zeroclaw::memory::Memory>>> {
    static BACKEND: OnceLock<TokioMutex<Option<Box<dyn zeroclaw::memory::Memory>>>> =
        OnceLock::new();
    BACKEND.get_or_init(|| TokioMutex::new(None))
}

async fn ensure_memory_backend() -> Result<(), String> {
    let mut mem = memory_backend().lock().await;
    if mem.is_some() {
        return Ok(());
    }

    let cs = super::agent_api::config_state().read().await;
    let config = cs.config.as_ref().ok_or("not initialized")?;
    let embedding_api_key = super::agent_api::global_config()
        .read()
        .await
        .embedding_api_key
        .clone();
    let fallback_api_key = config
        .providers
        .fallback_provider()
        .and_then(|p| p.api_key.as_deref());

    let backend = zeroclaw::memory::create_memory_with_storage_and_routes(
        &config.memory,
        &config.providers.embedding_routes,
        Some(&config.storage.provider.config),
        &config.workspace_dir,
        embedding_api_key.as_deref().or(fallback_api_key),
    )
    .map_err(|e| format!("memory init failed: {e}"))?;

    *mem = Some(backend);
    Ok(())
}

// ──────────────────── API Functions ──────────────────────────

/// Get knowledge base statistics
pub async fn get_knowledge_stats() -> KnowledgeStats {
    let cs = super::agent_api::config_state().read().await;
    let (backend_name, embedding_provider, embedding_model, auto_save) =
        if let Some(config) = &cs.config {
            (
                config.memory.backend.clone(),
                config.memory.embedding_provider.clone(),
                config.memory.embedding_model.clone(),
                config.memory.auto_save,
            )
        } else {
            ("unknown".into(), "none".into(), "none".into(), false)
        };
    drop(cs);

    let (total, healthy) = match ensure_memory_backend().await {
        Ok(()) => {
            let mem = memory_backend().lock().await;
            if let Some(backend) = mem.as_ref() {
                let count = backend.count().await.unwrap_or(0) as u32;
                let health = backend.health_check().await;
                (count, health)
            } else {
                (0, false)
            }
        }
        Err(_) => (0, false),
    };

    KnowledgeStats {
        total_entries: total,
        backend: backend_name,
        healthy,
        embedding_provider,
        embedding_model,
        auto_save,
    }
}

/// List knowledge entries, optionally filtered by category
pub async fn list_knowledge_entries(category: Option<String>, limit: u32) -> Vec<KnowledgeEntry> {
    if ensure_memory_backend().await.is_err() {
        return vec![];
    }

    let mem = memory_backend().lock().await;
    let backend = match mem.as_ref() {
        Some(b) => b,
        None => return vec![],
    };

    let cat = category.as_deref().map(parse_category);
    let entries = match backend.list(cat.as_ref(), None).await {
        Ok(e) => e,
        Err(_) => return vec![],
    };

    entries
        .into_iter()
        .take(limit as usize)
        .map(entry_to_dto)
        .collect()
}

/// Search knowledge entries by query (semantic search if embeddings available, otherwise keyword)
pub async fn search_knowledge(query: String, limit: u32) -> Vec<KnowledgeEntry> {
    if ensure_memory_backend().await.is_err() {
        return vec![];
    }

    let mem = memory_backend().lock().await;
    let backend = match mem.as_ref() {
        Some(b) => b,
        None => return vec![],
    };

    match backend
        .recall(&query, limit as usize, None, None, None)
        .await
    {
        Ok(entries) => entries.into_iter().map(entry_to_dto).collect(),
        Err(_) => vec![],
    }
}

/// Add a new knowledge entry
pub async fn add_knowledge_entry(key: String, content: String, category: String) -> String {
    if let Err(e) = ensure_memory_backend().await {
        return format!("error: {e}");
    }

    let mem = memory_backend().lock().await;
    let backend = match mem.as_ref() {
        Some(b) => b,
        None => return "error: no backend".into(),
    };

    let cat = parse_category(category.as_str());
    match backend.store(&key, &content, cat, None).await {
        Ok(()) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Delete a knowledge entry by key
pub async fn delete_knowledge_entry(key: String) -> String {
    if let Err(e) = ensure_memory_backend().await {
        return format!("error: {e}");
    }

    let mem = memory_backend().lock().await;
    let backend = match mem.as_ref() {
        Some(b) => b,
        None => return "error: no backend".into(),
    };

    match backend.forget(&key).await {
        Ok(true) => "ok".into(),
        Ok(false) => "not_found".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Get a single knowledge entry by key
pub async fn get_knowledge_entry(key: String) -> Option<KnowledgeEntry> {
    if ensure_memory_backend().await.is_err() {
        return None;
    }

    let mem = memory_backend().lock().await;
    let backend = match mem.as_ref() {
        Some(b) => b,
        None => return None,
    };

    match backend.get(&key).await {
        Ok(Some(entry)) => Some(entry_to_dto(entry)),
        _ => None,
    }
}

// ──────────────────── Helpers ─────────────────────────────────

fn parse_category(s: &str) -> zeroclaw::memory::MemoryCategory {
    match s {
        "core" => zeroclaw::memory::MemoryCategory::Core,
        "daily" => zeroclaw::memory::MemoryCategory::Daily,
        "conversation" => zeroclaw::memory::MemoryCategory::Conversation,
        other => zeroclaw::memory::MemoryCategory::Custom(other.to_string()),
    }
}

fn category_to_string(cat: &zeroclaw::memory::MemoryCategory) -> String {
    match cat {
        zeroclaw::memory::MemoryCategory::Core => "core".into(),
        zeroclaw::memory::MemoryCategory::Daily => "daily".into(),
        zeroclaw::memory::MemoryCategory::Conversation => "conversation".into(),
        zeroclaw::memory::MemoryCategory::Custom(s) => s.clone(),
    }
}

fn entry_to_dto(entry: zeroclaw::memory::MemoryEntry) -> KnowledgeEntry {
    // Derive project_id from session_id if the session belongs to a project.
    // For now, we use an empty string — project scoping is resolved at the
    // Dart layer by filtering entries whose session_id belong to a project.
    KnowledgeEntry {
        id: entry.id,
        key: entry.key,
        content: entry.content,
        category: category_to_string(&entry.category),
        timestamp: entry.timestamp,
        session_id: entry.session_id.unwrap_or_default(),
        project_id: String::new(), // Resolved by Dart layer via session→project mapping
        score: entry.score.unwrap_or(0.0),
    }
}
