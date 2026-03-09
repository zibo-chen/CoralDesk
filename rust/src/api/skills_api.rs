use std::path::PathBuf;

// ──────────────────────── DTOs ────────────────────────────

/// A skill loaded from the skills directory
#[derive(Debug, Clone)]
pub struct SkillDto {
    pub name: String,
    pub description: String,
    pub version: String,
    pub author: String,
    pub tags: Vec<String>,
    pub tools: Vec<SkillToolDto>,
    pub prompts: Vec<String>,
    pub source: String, // "local" or "community"
}

/// A tool defined within a skill
#[derive(Debug, Clone)]
pub struct SkillToolDto {
    pub name: String,
    pub description: String,
    pub kind: String, // "shell", "http", "script"
}

/// Skills configuration overview
#[derive(Debug, Clone)]
pub struct SkillsConfigDto {
    pub open_skills_enabled: bool,
    pub prompt_injection_mode: String,
    pub skills_dir: String,
    pub local_skills_count: u32,
    pub community_skills_count: u32,
}

// ──────────────────── API Functions ──────────────────────────

/// Get skills configuration from zeroclaw config
pub async fn get_skills_config() -> SkillsConfigDto {
    let cs = super::agent_api::config_state().read().await;
    if let Some(config) = &cs.config {
        let skills_dir = config
            .workspace_dir
            .join("skills")
            .to_string_lossy()
            .to_string();

        // Count local skills
        let local_count = count_skills_in_dir(&config.workspace_dir.join("skills"));
        let community_count = if config.skills.open_skills_enabled {
            let open_dir = config
                .skills
                .open_skills_dir
                .as_deref()
                .map(PathBuf::from)
                .unwrap_or_else(|| {
                    dirs::home_dir()
                        .unwrap_or_default()
                        .join(".coraldesk")
                        .join("open-skills")
                });
            count_skills_in_dir(&open_dir)
        } else {
            0
        };

        let mode = match config.skills.prompt_injection_mode {
            zeroclaw::config::SkillsPromptInjectionMode::Compact => "compact",
            _ => "full",
        };

        SkillsConfigDto {
            open_skills_enabled: config.skills.open_skills_enabled,
            prompt_injection_mode: mode.into(),
            skills_dir,
            local_skills_count: local_count,
            community_skills_count: community_count,
        }
    } else {
        SkillsConfigDto {
            open_skills_enabled: false,
            prompt_injection_mode: "full".into(),
            skills_dir: String::new(),
            local_skills_count: 0,
            community_skills_count: 0,
        }
    }
}

/// List all available skills (local + community if enabled)
pub async fn list_skills() -> Vec<SkillDto> {
    let cs = super::agent_api::config_state().read().await;
    let mut skills = Vec::new();

    if let Some(config) = &cs.config {
        // Load local skills
        let local_dir = config.workspace_dir.join("skills");
        load_skills_from_dir(&local_dir, "local", &mut skills);

        // Load community skills if enabled
        if config.skills.open_skills_enabled {
            let open_dir = config
                .skills
                .open_skills_dir
                .as_deref()
                .map(PathBuf::from)
                .unwrap_or_else(|| {
                    dirs::home_dir()
                        .unwrap_or_default()
                        .join(".coraldesk")
                        .join("open-skills")
                });
            load_skills_from_dir(&open_dir, "community", &mut skills);
        }
    }

    skills
}

/// Toggle the open skills feature on/off
pub async fn toggle_open_skills(enabled: bool) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };
        config.skills.open_skills_enabled = enabled;
    }
    // Invalidate agent to pick up change
    super::agent_api::invalidate_all_agents().await;

    // Persist to disk
    let save_result = super::agent_api::save_config_to_disk().await;
    if save_result != "ok" {
        return save_result;
    }

    // If enabling, trigger open-skills repo sync in background
    if enabled {
        let cs = super::agent_api::config_state().read().await;
        if let Some(config) = &cs.config {
            let open_dir = config
                .skills
                .open_skills_dir
                .as_deref()
                .map(std::path::PathBuf::from)
                .unwrap_or_else(|| dirs::home_dir().unwrap_or_default().join("open-skills"));
            drop(cs);
            // Clone the repo if it doesn't exist
            if !open_dir.exists() {
                tokio::task::spawn_blocking(move || {
                    sync_open_skills_repo(&open_dir);
                })
                .await
                .ok();
            }
        }
    }

    "ok".into()
}

/// Update prompt injection mode ("full" or "compact")
pub async fn update_prompt_injection_mode(mode: String) -> String {
    {
        let mut cs = super::agent_api::config_state().write().await;
        let config = match cs.config.as_mut() {
            Some(c) => c,
            None => return "error: not initialized".into(),
        };
        config.skills.prompt_injection_mode = match mode.as_str() {
            "compact" => zeroclaw::config::SkillsPromptInjectionMode::Compact,
            _ => zeroclaw::config::SkillsPromptInjectionMode::Full,
        };
    }
    super::agent_api::invalidate_all_agents().await;

    super::agent_api::save_config_to_disk().await
}

/// Install a skill from a Git URL or local path.
/// Returns "ok" on success, or an error message.
pub async fn install_skill(source: String) -> String {
    let cs = super::agent_api::config_state().read().await;
    let workspace_dir = match cs.config.as_ref() {
        Some(c) => c.workspace_dir.clone(),
        None => return "error: not initialized".into(),
    };
    drop(cs);

    let skills_path = workspace_dir.join("skills");
    if let Err(e) = std::fs::create_dir_all(&skills_path) {
        return format!("error: failed to create skills directory: {e}");
    }

    let source_clone = source.clone();
    let skills_path_clone = skills_path.clone();

    let result = tokio::task::spawn_blocking(move || {
        if is_git_source(&source_clone) {
            install_git_skill(&source_clone, &skills_path_clone)
        } else {
            install_local_skill(&source_clone, &skills_path_clone)
        }
    })
    .await;

    match result {
        Ok(Ok(name)) => {
            // Invalidate agent to pick up new skill
            super::agent_api::invalidate_all_agents().await;
            format!("ok:{name}")
        }
        Ok(Err(e)) => format!("error: {e}"),
        Err(e) => format!("error: task failed: {e}"),
    }
}

/// Remove an installed skill by name.
/// Returns "ok" on success, or an error message.
pub async fn remove_skill(name: String) -> String {
    // Reject path traversal
    if name.contains("..") || name.contains('/') || name.contains('\\') {
        return "error: invalid skill name".into();
    }

    let cs = super::agent_api::config_state().read().await;
    let workspace_dir = match cs.config.as_ref() {
        Some(c) => c.workspace_dir.clone(),
        None => return "error: not initialized".into(),
    };
    drop(cs);

    let skills_path = workspace_dir.join("skills");
    let skill_path = skills_path.join(&name);

    // Verify path stays inside skills directory
    let canonical_skills = skills_path
        .canonicalize()
        .unwrap_or_else(|_| skills_path.clone());
    if let Ok(canonical_skill) = skill_path.canonicalize() {
        if !canonical_skill.starts_with(&canonical_skills) {
            return "error: skill path escapes skills directory".into();
        }
    }

    if !skill_path.exists() {
        return format!("error: skill not found: {name}");
    }

    match std::fs::remove_dir_all(&skill_path) {
        Ok(_) => {
            // Invalidate agent to pick up change
            super::agent_api::invalidate_all_agents().await;
            "ok".into()
        }
        Err(e) => format!("error: failed to remove skill: {e}"),
    }
}

// ──────────────────── Helpers ─────────────────────────────────

fn is_git_source(source: &str) -> bool {
    source.starts_with("https://")
        || source.starts_with("http://")
        || source.starts_with("ssh://")
        || source.starts_with("git://")
        || is_git_scp_source(source)
}

fn is_git_scp_source(source: &str) -> bool {
    let Some((user_host, remote_path)) = source.split_once(':') else {
        return false;
    };
    if remote_path.is_empty() || source.contains("://") {
        return false;
    }
    let Some((user, host)) = user_host.split_once('@') else {
        return false;
    };
    !user.is_empty()
        && !host.is_empty()
        && !user.contains('/')
        && !user.contains('\\')
        && !host.contains('/')
        && !host.contains('\\')
}

fn install_git_skill(source: &str, skills_path: &std::path::Path) -> Result<String, String> {
    use std::collections::HashSet;

    // Snapshot existing children
    let before: HashSet<std::path::PathBuf> = std::fs::read_dir(skills_path)
        .map(|entries| entries.filter_map(|e| e.ok()).map(|e| e.path()).collect())
        .unwrap_or_default();

    let output = std::process::Command::new("git")
        .args(["clone", "--depth", "1", source])
        .current_dir(skills_path)
        .output()
        .map_err(|e| format!("failed to run git: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("git clone failed: {stderr}"));
    }

    // Detect new directory
    let mut new_dirs: Vec<std::path::PathBuf> = Vec::new();
    if let Ok(entries) = std::fs::read_dir(skills_path) {
        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if !before.contains(&path) && path.is_dir() {
                new_dirs.push(path);
            }
        }
    }

    let installed_dir = match new_dirs.len() {
        1 => new_dirs.remove(0),
        0 => return Err("no new directory found after clone".into()),
        _ => return Err("multiple new directories found after clone".into()),
    };

    // Remove .git metadata
    let git_dir = installed_dir.join(".git");
    if git_dir.exists() {
        let _ = std::fs::remove_dir_all(&git_dir);
    }

    let name = installed_dir
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown".into());

    Ok(name)
}

fn install_local_skill(source: &str, skills_path: &std::path::Path) -> Result<String, String> {
    let source_path = std::path::PathBuf::from(source);
    if !source_path.exists() {
        return Err(format!("source path does not exist: {source}"));
    }

    let source_path = source_path
        .canonicalize()
        .map_err(|e| format!("failed to resolve path: {e}"))?;

    let name = source_path
        .file_name()
        .ok_or_else(|| "source path must include a directory name".to_string())?;
    let dest = skills_path.join(name);
    if dest.exists() {
        return Err(format!("skill already exists: {}", name.to_string_lossy()));
    }

    copy_dir_no_symlinks(&source_path, &dest).map_err(|e| {
        let _ = std::fs::remove_dir_all(&dest);
        format!("copy failed: {e}")
    })?;

    let skill_name = name.to_string_lossy().to_string();
    Ok(skill_name)
}

fn copy_dir_no_symlinks(src: &std::path::Path, dest: &std::path::Path) -> Result<(), String> {
    let meta = std::fs::symlink_metadata(src)
        .map_err(|e| format!("failed to read {}: {e}", src.display()))?;
    if meta.file_type().is_symlink() {
        return Err(format!("refusing to copy symlink: {}", src.display()));
    }
    if !meta.is_dir() {
        return Err(format!("source must be a directory: {}", src.display()));
    }

    std::fs::create_dir_all(dest)
        .map_err(|e| format!("failed to create {}: {e}", dest.display()))?;

    for entry in std::fs::read_dir(src).map_err(|e| format!("read dir fail: {e}"))? {
        let entry = entry.map_err(|e| format!("entry error: {e}"))?;
        let src_path = entry.path();
        let dest_path = dest.join(entry.file_name());
        let file_meta =
            std::fs::symlink_metadata(&src_path).map_err(|e| format!("metadata fail: {e}"))?;

        if file_meta.file_type().is_symlink() {
            return Err(format!("refusing to copy symlink: {}", src_path.display()));
        }
        if file_meta.is_dir() {
            copy_dir_no_symlinks(&src_path, &dest_path)?;
        } else if file_meta.is_file() {
            std::fs::copy(&src_path, &dest_path).map_err(|e| format!("copy fail: {e}"))?;
        }
    }
    Ok(())
}

fn count_skills_in_dir(dir: &std::path::Path) -> u32 {
    count_skills_recursive(dir, 0)
}

fn count_skills_recursive(dir: &std::path::Path, depth: u8) -> u32 {
    if depth > 2 || !dir.exists() {
        return 0;
    }
    std::fs::read_dir(dir)
        .map(|entries| {
            entries
                .filter_map(|e| e.ok())
                .filter(|e| e.path().is_dir())
                .map(|e| {
                    let p = e.path();
                    if p.join("SKILL.toml").exists() || p.join("SKILL.md").exists() {
                        1
                    } else {
                        count_skills_recursive(&p, depth + 1)
                    }
                })
                .sum()
        })
        .unwrap_or(0)
}

fn load_skills_from_dir(dir: &std::path::Path, source: &str, skills: &mut Vec<SkillDto>) {
    load_skills_from_dir_recursive(dir, source, skills, 0);
}

/// Recursively scan for skills up to 2 levels deep.
/// This handles both single-skill repos (SKILL.toml at root) and
/// collection repos (skills nested in subdirectories).
fn load_skills_from_dir_recursive(
    dir: &std::path::Path,
    source: &str,
    skills: &mut Vec<SkillDto>,
    depth: u8,
) {
    if depth > 2 || !dir.exists() {
        return;
    }

    let entries = match std::fs::read_dir(dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.filter_map(|e| e.ok()) {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let skill_toml = path.join("SKILL.toml");
        let skill_md = path.join("SKILL.md");

        if skill_toml.exists() {
            if let Some(skill) = parse_skill_toml(&skill_toml, source) {
                skills.push(skill);
            }
        } else if skill_md.exists() {
            if let Some(skill) = parse_skill_md(&skill_md, &path, source) {
                skills.push(skill);
            }
        } else {
            // No SKILL.toml/SKILL.md here — this might be a collection repo,
            // recurse into subdirectories to find nested skills.
            load_skills_from_dir_recursive(&path, source, skills, depth + 1);
        }
    }
}

fn parse_skill_toml(path: &std::path::Path, source: &str) -> Option<SkillDto> {
    let content = std::fs::read_to_string(path).ok()?;
    let table: toml::Table = content.parse().ok()?;

    let skill_section = table.get("skill")?.as_table()?;

    let name = skill_section
        .get("name")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown")
        .to_string();
    let description = skill_section
        .get("description")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let version = skill_section
        .get("version")
        .and_then(|v| v.as_str())
        .unwrap_or("0.1.0")
        .to_string();
    let author = skill_section
        .get("author")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let tags = skill_section
        .get("tags")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    // Parse tools
    let tools = table
        .get("tools")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|item| {
                    let t = item.as_table()?;
                    Some(SkillToolDto {
                        name: t.get("name")?.as_str()?.to_string(),
                        description: t
                            .get("description")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        kind: t
                            .get("kind")
                            .and_then(|v| v.as_str())
                            .unwrap_or("shell")
                            .to_string(),
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    // Parse prompts
    let prompts = skill_section
        .get("prompts")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    Some(SkillDto {
        name,
        description,
        version,
        author,
        tags,
        tools,
        prompts,
        source: source.to_string(),
    })
}

fn parse_skill_md(path: &std::path::Path, dir: &std::path::Path, source: &str) -> Option<SkillDto> {
    let content = std::fs::read_to_string(path).ok()?;
    let name = dir
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    // Extract description from first paragraph
    let description = content
        .lines()
        .find(|line| !line.starts_with('#') && !line.trim().is_empty())
        .unwrap_or("")
        .to_string();

    Some(SkillDto {
        name,
        description,
        version: "0.1.0".into(),
        author: String::new(),
        tags: vec![],
        tools: vec![],
        prompts: content
            .lines()
            .filter(|line| !line.starts_with('#') && !line.trim().is_empty())
            .map(|s| s.to_string())
            .collect(),
        source: source.to_string(),
    })
}

/// Clone or pull the open-skills git repository
fn sync_open_skills_repo(repo_dir: &std::path::Path) {
    const OPEN_SKILLS_REPO_URL: &str = "https://github.com/besoeasy/open-skills";

    if let Some(parent) = repo_dir.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    if !repo_dir.exists() {
        let output = std::process::Command::new("git")
            .args(["clone", "--depth", "1", OPEN_SKILLS_REPO_URL])
            .arg(repo_dir)
            .output();
        match output {
            Ok(result) if result.status.success() => {
                eprintln!("open-skills cloned to {}", repo_dir.display());
            }
            Ok(result) => {
                let stderr = String::from_utf8_lossy(&result.stderr);
                eprintln!("failed to clone open-skills: {stderr}");
            }
            Err(err) => {
                eprintln!("failed to run git clone for open-skills: {err}");
            }
        }
    } else if repo_dir.join(".git").exists() {
        let output = std::process::Command::new("git")
            .arg("-C")
            .arg(repo_dir)
            .args(["pull", "--ff-only"])
            .output();
        match output {
            Ok(result) if result.status.success() => {}
            _ => {
                eprintln!("failed to pull open-skills updates");
            }
        }
    }
}
