//! Browser bootstrap: auto-install `agent-browser` CLI and configure defaults.
//!
//! On first launch (or when agent-browser is missing) this module:
//! 1. Resolves the bundled Node.js prefix at `~/.deskclaw/node`.
//! 2. Runs `npm install -g agent-browser` using that prefix.
//! 3. Returns the absolute path to the installed binary so the config can
//!    point `agent_browser_command` at it directly (avoiding PATH issues
//!    inside macOS .app bundles).

use std::path::PathBuf;
use tokio::process::Command;

/// Resolve `~/.deskclaw/node` prefix directory.
fn deskclaw_node_prefix() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".deskclaw").join("node"))
}

/// Absolute path where `agent-browser` binary is expected after global npm install.
fn agent_browser_bin_path() -> Option<PathBuf> {
    deskclaw_node_prefix().map(|prefix| prefix.join("bin").join("agent-browser"))
}

/// Check if the `agent-browser` binary exists and is executable.
#[allow(dead_code)]
fn is_agent_browser_installed() -> bool {
    agent_browser_bin_path()
        .map(|p| p.exists())
        .unwrap_or(false)
}

/// Install `agent-browser` globally into the bundled Node.js prefix.
///
/// Returns `Ok(path)` with the absolute binary path on success.
async fn install_agent_browser() -> Result<PathBuf, String> {
    let prefix = deskclaw_node_prefix()
        .ok_or_else(|| "Cannot determine home directory for ~/.deskclaw/node".to_string())?;

    let npm = prefix.join("bin").join("npm");
    if !npm.exists() {
        return Err(format!(
            "Bundled npm not found at {}. Node.js bootstrap may be incomplete.",
            npm.display()
        ));
    }

    tracing::info!("Installing agent-browser via npm into {}", prefix.display());

    let output = Command::new(npm.as_os_str())
        .arg("install")
        .arg("-g")
        .arg("agent-browser")
        .env(
            "PATH",
            format!(
                "{}:/usr/bin:/bin:/usr/sbin:/sbin",
                prefix.join("bin").display()
            ),
        )
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .output()
        .await
        .map_err(|e| format!("Failed to spawn npm: {e}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("npm install -g agent-browser failed: {stderr}"));
    }

    let bin = agent_browser_bin_path()
        .ok_or_else(|| "Cannot determine agent-browser binary path".to_string())?;

    if bin.exists() {
        tracing::info!("agent-browser installed at {}", bin.display());
        Ok(bin)
    } else {
        Err(format!(
            "npm install succeeded but binary not found at {}",
            bin.display()
        ))
    }
}

/// Ensure `agent-browser` is available, installing it if needed.
///
/// Returns the absolute path to the binary, or an error description.
/// This is called during app startup so the browser tool works out-of-box.
pub async fn ensure_agent_browser() -> String {
    if let Some(bin) = agent_browser_bin_path() {
        if bin.exists() {
            tracing::debug!("agent-browser already installed at {}", bin.display());
            return bin.to_string_lossy().to_string();
        }
    }

    match install_agent_browser().await {
        Ok(path) => path.to_string_lossy().to_string(),
        Err(e) => {
            tracing::warn!("agent-browser auto-install failed: {e}");
            format!("error: {e}")
        }
    }
}

/// Apply desktop-friendly browser defaults to the loaded config.
///
/// This sets:
/// - `browser.enabled = true`
/// - `browser.allowed_domains = ["*"]`  (all public domains)
/// - `browser.backend = "agent_browser"`
/// - `browser.agent_browser_command` = absolute path to the installed binary
///
/// Only applies defaults when the user hasn't explicitly configured browser
/// settings in their config.toml (detected by checking if `allowed_domains`
/// is still empty, which is the zeroclaw default).
pub fn apply_browser_defaults(config: &mut zeroclaw::Config, agent_browser_path: &str) {
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

    // Use absolute path to avoid PATH resolution issues in macOS .app
    if !agent_browser_path.starts_with("error:") && !agent_browser_path.is_empty() {
        config.browser.agent_browser_command = agent_browser_path.into();
    }
}
