//! Browser bootstrap: locate bundled `agent-browser` and configure defaults.
//!
//! CoralDesk pre-bundles `agent-browser` (installed via Bun at build time) in
//! the `runtimes/agent-browser/` directory. This module locates the bundled
//! binary and configures the browser tool to use it out-of-the-box, without
//! requiring any runtime installation steps.
//!
//! The Playwright system-browser auto-detection is handled by
//! [`crate::bundled_runtimes::setup_system_browser_for_playwright`] so that
//! agent-browser uses the local Chrome/Chromium/Edge instead of requiring its
//! own browser download.

/// Locate the `agent-browser` CLI binary.
///
/// Search order:
/// 1. **Bundled**: `runtimes/agent-browser/agent-browser` (pre-installed at build time)
/// 2. **PATH fallback**: check if `agent-browser` is available on the system PATH
///
/// Returns the absolute path to the binary, or an error description if not found.
pub fn find_agent_browser() -> String {
    // 1. Check bundled runtimes (preferred — works out-of-the-box)
    if let Some(bundled) = crate::bundled_runtimes::find_bundled_agent_browser() {
        tracing::info!(path = %bundled.display(), "Using bundled agent-browser");
        return bundled.to_string_lossy().to_string();
    }

    // 2. Fallback: check if agent-browser exists on PATH
    if let Some(path_binary) = find_on_path("agent-browser") {
        tracing::info!(path = %path_binary.display(), "Using system agent-browser from PATH");
        return path_binary.to_string_lossy().to_string();
    }

    tracing::warn!(
        "agent-browser not found in bundled runtimes or PATH. \
         Browser automation will be unavailable unless installed manually."
    );
    "error: agent-browser not found".to_string()
}

/// Search for an executable on `PATH`.
fn find_on_path(name: &str) -> Option<std::path::PathBuf> {
    let path_var = std::env::var_os("PATH")?;
    let exe_name = if cfg!(target_os = "windows") {
        format!("{name}.cmd")
    } else {
        name.to_string()
    };
    for dir in std::env::split_paths(&path_var) {
        let candidate = dir.join(&exe_name);
        if candidate.is_file() {
            return Some(candidate);
        }
        // On Windows also check .exe
        if cfg!(target_os = "windows") {
            let exe_candidate = dir.join(format!("{name}.exe"));
            if exe_candidate.is_file() {
                return Some(exe_candidate);
            }
        }
    }
    None
}

/// Apply desktop-friendly browser defaults to the loaded config.
///
/// This sets:
/// - `browser.enabled = true`
/// - `browser.allowed_domains = ["*"]`  (all public domains)
/// - `browser.backend = "agent_browser"`
///
/// Only applies defaults when the user hasn't explicitly configured browser
/// settings in their config.toml (detected by checking if `allowed_domains`
/// is still empty, which is the zeroclaw default).
pub(crate) fn apply_browser_defaults(config: &mut zeroclaw::Config, agent_browser_path: &str) {
    // Only override if the user hasn't customized browser config.
    // The zeroclaw default is enabled=false + empty allowed_domains.
    // If user has explicitly set anything, respect it.
    if config.browser.enabled && !config.browser.allowed_domains.is_empty() {
        tracing::debug!("Browser already configured by user, skipping defaults");
        return;
    }

    config.browser.enabled = true;
    config.browser.backend = "agent_browser".into();

    if config.browser.allowed_domains.is_empty() {
        config.browser.allowed_domains = vec!["*".into()];
    }

    if !agent_browser_path.starts_with("error:") && !agent_browser_path.is_empty() {
        tracing::debug!(
            path = agent_browser_path,
            "Bundled agent-browser is available via PATH"
        );
    }
}
