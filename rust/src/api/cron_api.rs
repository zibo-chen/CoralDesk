use rusqlite::{params, Connection};
use std::path::PathBuf;

// ──────────────────────── DTOs ────────────────────────────

/// Cron job summary for UI display
#[derive(Debug, Clone)]
pub struct CronJobDto {
    pub id: String,
    pub name: String,
    pub expression: String,
    pub schedule_type: String, // "cron", "at", "every"
    pub schedule_display: String,
    pub command: String,
    pub prompt: String,
    pub job_type: String,          // "shell" or "agent"
    pub session_target: String,    // "isolated" or "main"
    pub target_session_id: String, // actual session ID when session_target == "main"
    pub model: String,
    pub enabled: bool,
    pub delete_after_run: bool,
    /// Project this cron job belongs to (empty = global)
    pub project_id: String,
    pub created_at: i64,
    pub next_run: i64,
    pub last_run: Option<i64>,
    pub last_status: String,
    pub last_output: String,
}

/// Cron run history entry
#[derive(Debug, Clone)]
pub struct CronRunDto {
    pub id: i64,
    pub job_id: String,
    pub started_at: i64,
    pub finished_at: i64,
    pub status: String,
    pub output: String,
    pub duration_ms: i64,
}

/// Cron system configuration
#[derive(Debug, Clone)]
pub struct CronConfigDto {
    pub enabled: bool,
    pub max_run_history: u32,
    pub total_jobs: u32,
    pub active_jobs: u32,
    pub paused_jobs: u32,
}

// ──────────────────── DB Helpers ──────────────────────────

fn db_path() -> PathBuf {
    let state_dir = dirs::home_dir().unwrap_or_default().join(".coraldesk");
    state_dir.join("workspace").join("cron").join("jobs.db")
}

fn open_db() -> Result<Connection, String> {
    let path = db_path();
    if !path.exists() {
        // Ensure directory
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }
    }
    let conn = Connection::open(&path).map_err(|e| e.to_string())?;
    conn.execute_batch("PRAGMA foreign_keys = ON;")
        .map_err(|e| e.to_string())?;
    // Ensure tables exist
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS cron_jobs (
            id               TEXT PRIMARY KEY,
            expression       TEXT NOT NULL,
            command          TEXT NOT NULL,
            schedule         TEXT,
            job_type         TEXT NOT NULL DEFAULT 'shell',
            prompt           TEXT,
            name             TEXT,
            session_target   TEXT NOT NULL DEFAULT 'isolated',
            model            TEXT,
            enabled          INTEGER NOT NULL DEFAULT 1,
            delivery         TEXT,
            delete_after_run INTEGER NOT NULL DEFAULT 0,
            created_at       TEXT NOT NULL,
            next_run         TEXT NOT NULL,
            last_run         TEXT,
            last_status      TEXT,
            last_output      TEXT
        );
        CREATE TABLE IF NOT EXISTS cron_runs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id      TEXT NOT NULL,
            started_at  TEXT NOT NULL,
            finished_at TEXT NOT NULL,
            status      TEXT NOT NULL,
            output      TEXT,
            duration_ms INTEGER,
            FOREIGN KEY (job_id) REFERENCES cron_jobs(id) ON DELETE CASCADE
        );",
    )
    .map_err(|e| e.to_string())?;

    // Migration: add target_session_id column (ignore error if column already exists)
    let _ = conn.execute(
        "ALTER TABLE cron_jobs ADD COLUMN target_session_id TEXT",
        [],
    );

    // Migration: add project_id column for project-scoped cron jobs
    let _ = conn.execute(
        "ALTER TABLE cron_jobs ADD COLUMN project_id TEXT DEFAULT ''",
        [],
    );

    Ok(conn)
}

fn parse_rfc3339_to_ts(s: &str) -> i64 {
    chrono::DateTime::parse_from_rfc3339(s)
        .map(|d| d.timestamp())
        .unwrap_or(0)
}

fn decode_schedule_info(schedule_json: Option<String>, expression: &str) -> (String, String) {
    if let Some(json) = schedule_json {
        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&json) {
            match val.get("kind").and_then(|k| k.as_str()) {
                Some("cron") => {
                    let expr = val
                        .get("expr")
                        .and_then(|v| v.as_str())
                        .unwrap_or(expression);
                    let tz = val.get("tz").and_then(|v| v.as_str());
                    let display = if let Some(tz) = tz {
                        format!("{expr} ({tz})")
                    } else {
                        expr.to_string()
                    };
                    return ("cron".into(), display);
                }
                Some("at") => {
                    let at = val.get("at").and_then(|v| v.as_str()).unwrap_or("");
                    return ("at".into(), at.to_string());
                }
                Some("every") => {
                    let ms = val.get("every_ms").and_then(|v| v.as_u64()).unwrap_or(0);
                    return ("every".into(), format_interval(ms));
                }
                _ => {}
            }
        }
    }
    // Fallback: treat expression as cron
    ("cron".into(), expression.to_string())
}

fn row_to_dto(row: &rusqlite::Row<'_>) -> Result<CronJobDto, rusqlite::Error> {
    let expression: String = row.get(1)?;
    let schedule_json: Option<String> = row.get(3)?;
    let (schedule_type, schedule_display) = decode_schedule_info(schedule_json, &expression);
    let enabled_int: i32 = row.get(9)?;
    let delete_after_run_int: i32 = row.get(11)?;
    let created_at_str: String = row.get(12)?;
    let next_run_str: String = row.get(13)?;
    let last_run_str: Option<String> = row.get(14)?;

    Ok(CronJobDto {
        id: row.get(0)?,
        name: row.get::<_, Option<String>>(6)?.unwrap_or_default(),
        expression,
        schedule_type,
        schedule_display,
        command: row.get(2)?,
        prompt: row.get::<_, Option<String>>(5)?.unwrap_or_default(),
        job_type: row
            .get::<_, Option<String>>(4)?
            .unwrap_or_else(|| "shell".into()),
        session_target: row
            .get::<_, Option<String>>(7)?
            .unwrap_or_else(|| "isolated".into()),
        model: row.get::<_, Option<String>>(8)?.unwrap_or_default(),
        enabled: enabled_int != 0,
        delete_after_run: delete_after_run_int != 0,
        created_at: parse_rfc3339_to_ts(&created_at_str),
        next_run: parse_rfc3339_to_ts(&next_run_str),
        last_run: last_run_str.map(|s| parse_rfc3339_to_ts(&s)),
        last_status: row.get::<_, Option<String>>(15)?.unwrap_or_default(),
        last_output: row.get::<_, Option<String>>(16)?.unwrap_or_default(),
        target_session_id: row.get::<_, Option<String>>(17)?.unwrap_or_default(),
        project_id: row.get::<_, Option<String>>(18)?.unwrap_or_default(),
    })
}

// ──────────────────── API Functions ──────────────────────────

/// Get cron system configuration and stats
pub fn get_cron_config() -> CronConfigDto {
    let conn = match open_db() {
        Ok(c) => c,
        Err(_) => {
            return CronConfigDto {
                enabled: true,
                max_run_history: 50,
                total_jobs: 0,
                active_jobs: 0,
                paused_jobs: 0,
            };
        }
    };

    let total: u32 = conn
        .query_row("SELECT COUNT(*) FROM cron_jobs", [], |r| r.get(0))
        .unwrap_or(0);
    let active: u32 = conn
        .query_row(
            "SELECT COUNT(*) FROM cron_jobs WHERE enabled = 1",
            [],
            |r| r.get(0),
        )
        .unwrap_or(0);

    CronConfigDto {
        enabled: true,
        max_run_history: 50,
        total_jobs: total,
        active_jobs: active,
        paused_jobs: total - active,
    }
}

/// List all cron jobs
pub fn list_cron_jobs() -> Vec<CronJobDto> {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            tracing::error!("Failed to open cron db: {e}");
            return vec![];
        }
    };

    let sql = "SELECT id, expression, command, schedule, job_type, prompt, name, \
               session_target, model, enabled, delivery, delete_after_run, \
               created_at, next_run, last_run, last_status, last_output, target_session_id, \
               project_id \
               FROM cron_jobs ORDER BY next_run ASC";

    let mut stmt = match conn.prepare(sql) {
        Ok(s) => s,
        Err(e) => {
            tracing::error!("Failed to prepare list query: {e}");
            return vec![];
        }
    };

    let rows = stmt.query_map([], |row| row_to_dto(row));
    match rows {
        Ok(mapped) => mapped.filter_map(|r| r.ok()).collect(),
        Err(e) => {
            tracing::error!("Failed to list cron jobs: {e}");
            vec![]
        }
    }
}

/// Add a new shell cron job
pub fn add_shell_cron_job(
    name: Option<String>,
    schedule_type: String,
    expression: String,
    command: String,
) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };

    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now();
    let schedule_json = build_schedule_json(&schedule_type, &expression);
    let next_run = compute_next_run(&schedule_type, &expression, &now);

    let r = conn.execute(
        "INSERT INTO cron_jobs (id, expression, command, schedule, job_type, prompt, name, \
         session_target, model, enabled, delivery, delete_after_run, created_at, next_run) \
         VALUES (?1,?2,?3,?4,'shell',NULL,?5,'isolated',NULL,1,NULL,0,?6,?7)",
        params![
            id,
            expression,
            command,
            schedule_json,
            name,
            now.to_rfc3339(),
            next_run.to_rfc3339(),
        ],
    );

    match r {
        Ok(_) => id,
        Err(e) => format!("error: {e}"),
    }
}

/// Add a new agent cron job
pub fn add_agent_cron_job(
    name: Option<String>,
    schedule_type: String,
    expression: String,
    prompt: String,
    session_target: String,
    model: Option<String>,
    delete_after_run: bool,
    target_session_id: Option<String>,
) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };

    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now();
    let schedule_json = build_schedule_json(&schedule_type, &expression);
    let next_run = compute_next_run(&schedule_type, &expression, &now);
    let target = if session_target == "main" {
        "main"
    } else {
        "isolated"
    };

    // Only store target_session_id when session_target is "main"
    let stored_session_id: Option<&str> = if target == "main" {
        target_session_id.as_deref()
    } else {
        None
    };

    let r = conn.execute(
        "INSERT INTO cron_jobs (id, expression, command, schedule, job_type, prompt, name, \
         session_target, model, enabled, delivery, delete_after_run, created_at, next_run, \
         target_session_id) \
         VALUES (?1,?2,'',?3,'agent',?4,?5,?6,?7,1,NULL,?8,?9,?10,?11)",
        params![
            id,
            expression,
            schedule_json,
            prompt,
            name,
            target,
            model,
            delete_after_run as i32,
            now.to_rfc3339(),
            next_run.to_rfc3339(),
            stored_session_id,
        ],
    );

    match r {
        Ok(_) => id,
        Err(e) => format!("error: {e}"),
    }
}

/// Remove a cron job
pub fn remove_cron_job(job_id: String) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };
    match conn.execute("DELETE FROM cron_jobs WHERE id = ?1", params![job_id]) {
        Ok(_) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Pause a cron job
pub fn pause_cron_job(job_id: String) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };
    match conn.execute(
        "UPDATE cron_jobs SET enabled = 0 WHERE id = ?1",
        params![job_id],
    ) {
        Ok(_) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Resume a cron job
pub fn resume_cron_job(job_id: String) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };
    match conn.execute(
        "UPDATE cron_jobs SET enabled = 1 WHERE id = ?1",
        params![job_id],
    ) {
        Ok(_) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

/// Get run history for a specific job
pub fn list_cron_runs(job_id: String, limit: u32) -> Vec<CronRunDto> {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            tracing::error!("Failed to open cron db: {e}");
            return vec![];
        }
    };

    let sql = "SELECT id, job_id, started_at, finished_at, status, output, duration_ms \
               FROM cron_runs WHERE job_id = ?1 \
               ORDER BY started_at DESC, id DESC LIMIT ?2";

    let mut stmt = match conn.prepare(sql) {
        Ok(s) => s,
        Err(e) => {
            tracing::error!("Failed to prepare runs query: {e}");
            return vec![];
        }
    };

    let rows = stmt.query_map(params![job_id, limit], |row| {
        let started: String = row.get(2)?;
        let finished: String = row.get(3)?;
        Ok(CronRunDto {
            id: row.get(0)?,
            job_id: row.get(1)?,
            started_at: parse_rfc3339_to_ts(&started),
            finished_at: parse_rfc3339_to_ts(&finished),
            status: row.get(4)?,
            output: row.get::<_, Option<String>>(5)?.unwrap_or_default(),
            duration_ms: row.get::<_, Option<i64>>(6)?.unwrap_or(0),
        })
    });

    match rows {
        Ok(mapped) => mapped.filter_map(|r| r.ok()).collect(),
        Err(e) => {
            tracing::error!("Failed to list cron runs: {e}");
            vec![]
        }
    }
}

/// Update a cron job
pub fn update_cron_job(
    job_id: String,
    name: Option<String>,
    schedule_type: Option<String>,
    expression: Option<String>,
    command: Option<String>,
    prompt: Option<String>,
    enabled: Option<bool>,
) -> String {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };

    // Read current job first
    let sql = "SELECT id, expression, command, schedule, job_type, prompt, name, \
               session_target, model, enabled, delivery, delete_after_run, \
               created_at, next_run, last_run, last_status, last_output, target_session_id, \
               project_id \
               FROM cron_jobs WHERE id = ?1";
    let current = conn.query_row(sql, params![job_id], |row| row_to_dto(row));
    let current = match current {
        Ok(c) => c,
        Err(e) => return format!("error: job not found: {e}"),
    };

    let new_name = name.unwrap_or(current.name);
    let new_command = command.unwrap_or(current.command);
    let new_prompt = prompt.or(Some(current.prompt));
    let new_enabled = enabled.unwrap_or(current.enabled);

    let (new_expression, new_schedule_json, new_next_run) =
        if let (Some(st), Some(expr)) = (&schedule_type, &expression) {
            let sj = build_schedule_json(st, expr);
            let nr = compute_next_run(st, expr, &chrono::Utc::now());
            (expr.clone(), sj, nr.to_rfc3339())
        } else {
            // Keep existing
            let existing_schedule = conn
                .query_row(
                    "SELECT schedule, next_run FROM cron_jobs WHERE id = ?1",
                    params![job_id],
                    |row| Ok((row.get::<_, Option<String>>(0)?, row.get::<_, String>(1)?)),
                )
                .unwrap_or((None, chrono::Utc::now().to_rfc3339()));
            (current.expression, existing_schedule.0, existing_schedule.1)
        };

    let r = conn.execute(
        "UPDATE cron_jobs SET expression=?1, command=?2, schedule=?3, \
         prompt=?4, name=?5, enabled=?6, next_run=?7 WHERE id=?8",
        params![
            new_expression,
            new_command,
            new_schedule_json,
            new_prompt,
            new_name,
            new_enabled as i32,
            new_next_run,
            job_id,
        ],
    );

    match r {
        Ok(_) => "ok".into(),
        Err(e) => format!("error: {e}"),
    }
}

// ──────────────────── Helpers ─────────────────────────────────

fn build_schedule_json(schedule_type: &str, expression: &str) -> Option<String> {
    let val = match schedule_type {
        "cron" => serde_json::json!({
            "kind": "cron",
            "expr": expression,
            "tz": null
        }),
        "at" => serde_json::json!({
            "kind": "at",
            "at": expression
        }),
        "every" => {
            let ms: u64 = expression.parse().unwrap_or(60000);
            serde_json::json!({
                "kind": "every",
                "every_ms": ms
            })
        }
        _ => return None,
    };
    Some(val.to_string())
}

fn compute_next_run(
    schedule_type: &str,
    expression: &str,
    now: &chrono::DateTime<chrono::Utc>,
) -> chrono::DateTime<chrono::Utc> {
    match schedule_type {
        "at" => chrono::DateTime::parse_from_rfc3339(expression)
            .map(|d| d.with_timezone(&chrono::Utc))
            .unwrap_or(*now),
        "every" => {
            let ms: i64 = expression.parse().unwrap_or(60000);
            *now + chrono::Duration::milliseconds(ms)
        }
        _ => {
            // For cron expressions, just use now + 1 minute as approximation
            // The actual scheduler in zeroclaw will compute precise next-run
            *now + chrono::Duration::minutes(1)
        }
    }
}

fn format_interval(ms: u64) -> String {
    if ms >= 86_400_000 {
        format!("每 {} 天", ms / 86_400_000)
    } else if ms >= 3_600_000 {
        format!("每 {} 小时", ms / 3_600_000)
    } else if ms >= 60_000 {
        format!("每 {} 分钟", ms / 60_000)
    } else {
        format!("每 {} 秒", ms / 1000)
    }
}

// ──────────────────── Execution ──────────────────────────────

/// Execute a cron job immediately (manual trigger)
pub async fn run_cron_job_now(job_id: String) -> String {
    // 1. Load job from DB
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };

    let sql = "SELECT id, expression, command, schedule, job_type, prompt, name, \
               session_target, model, enabled, delivery, delete_after_run, \
               created_at, next_run, last_run, last_status, last_output, target_session_id, \
               project_id \
               FROM cron_jobs WHERE id = ?1";
    let job = match conn.query_row(sql, params![job_id], |row| row_to_dto(row)) {
        Ok(j) => j,
        Err(e) => return format!("error: job not found: {e}"),
    };
    drop(conn);

    let started = chrono::Utc::now();
    let started_rfc = started.to_rfc3339();

    // 2. Execute based on job type
    let (status, output) = if job.job_type == "agent" {
        run_agent_job(&job).await
    } else {
        run_shell_job(&job).await
    };

    let finished = chrono::Utc::now();
    let duration_ms = (finished - started).num_milliseconds();

    // 3. Record run result
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => return format!("error: {e}"),
    };

    let _ = conn.execute(
        "INSERT INTO cron_runs (job_id, started_at, finished_at, status, output, duration_ms) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        params![
            job_id,
            started_rfc,
            finished.to_rfc3339(),
            &status,
            &output,
            duration_ms,
        ],
    );

    // 4. Update job with last run info and compute next run
    let now = chrono::Utc::now();
    let (schedule_type, _) = decode_schedule_info(
        conn.query_row(
            "SELECT schedule FROM cron_jobs WHERE id = ?1",
            params![job_id],
            |row| row.get::<_, Option<String>>(0),
        )
        .unwrap_or(None),
        &job.expression,
    );
    let next_run = compute_next_run(&schedule_type, &job.expression, &now);

    let _ = conn.execute(
        "UPDATE cron_jobs SET last_run=?1, last_status=?2, last_output=?3, next_run=?4 WHERE id=?5",
        params![started_rfc, &status, &output, next_run.to_rfc3339(), job_id,],
    );

    // 5. Emit notification to Flutter UI
    super::cron_notification_api::emit_notification(
        super::cron_notification_api::CronNotification {
            job_id: job_id.clone(),
            job_name: job.name.clone(),
            job_type: job.job_type.clone(),
            session_target: job.session_target.clone(),
            target_session_id: job.target_session_id.clone(),
            status: status.clone(),
            output: output.clone(),
            prompt: job.prompt.clone(),
            duration_ms,
            finished_at: finished.timestamp(),
        },
    );

    // 6. Handle delete_after_run
    if job.delete_after_run {
        let _ = conn.execute("DELETE FROM cron_jobs WHERE id = ?1", params![job_id]);
    }

    if status == "ok" {
        format!("ok: {output}")
    } else {
        format!("error: {output}")
    }
}

/// Execute a shell command job
async fn run_shell_job(job: &CronJobDto) -> (String, String) {
    use tokio::process::Command;

    let result = Command::new("sh")
        .arg("-lc")
        .arg(&job.command)
        .output()
        .await;

    match result {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let combined = if stderr.is_empty() {
                stdout
            } else if stdout.is_empty() {
                stderr
            } else {
                format!("{stdout}\n{stderr}")
            };
            let truncated = if combined.len() > 2000 {
                format!("{}...(truncated)", &combined[..2000])
            } else {
                combined
            };
            if output.status.success() {
                ("ok".into(), truncated)
            } else {
                ("error".into(), truncated)
            }
        }
        Err(e) => ("error".into(), format!("failed to execute: {e}")),
    }
}

/// Execute an agent job
async fn run_agent_job(job: &CronJobDto) -> (String, String) {
    // Use the existing agent infrastructure
    let config = {
        let cs = super::agent_api::config_state().read().await;
        match &cs.config {
            Some(c) => c.clone(),
            None => return ("error".into(), "runtime not initialized".into()),
        }
    };

    // Create a temporary agent for this job
    let mut agent = match zeroclaw::agent::Agent::from_config(&config) {
        Ok(a) => a,
        Err(e) => return ("error".into(), format!("failed to create agent: {e}")),
    };

    match agent.turn(&job.prompt).await {
        Ok(response) => {
            let truncated = if response.len() > 2000 {
                format!("{}...(truncated)", &response[..2000])
            } else {
                response
            };
            ("ok".into(), truncated)
        }
        Err(e) => ("error".into(), format!("agent error: {e}")),
    }
}

/// Start a background cron scheduler that polls for due jobs
pub async fn start_cron_scheduler() -> String {
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::OnceLock;

    static RUNNING: OnceLock<AtomicBool> = OnceLock::new();
    let flag = RUNNING.get_or_init(|| AtomicBool::new(false));

    if flag.load(Ordering::SeqCst) {
        return "already running".into();
    }
    flag.store(true, Ordering::SeqCst);

    tokio::spawn(async move {
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
            let now = chrono::Utc::now();
            // Find due jobs
            let conn = match open_db() {
                Ok(c) => c,
                Err(_) => continue,
            };
            let sql = "SELECT id FROM cron_jobs WHERE enabled = 1 AND next_run <= ?1";
            let due_ids: Vec<String> = {
                let mut stmt = match conn.prepare(sql) {
                    Ok(s) => s,
                    Err(_) => continue,
                };
                stmt.query_map(params![now.to_rfc3339()], |row| row.get::<_, String>(0))
                    .ok()
                    .map(|rows| rows.filter_map(|r| r.ok()).collect())
                    .unwrap_or_default()
            };
            drop(conn);

            for id in due_ids {
                let _ = run_cron_job_now(id).await;
            }
        }
    });

    "started".into()
}
