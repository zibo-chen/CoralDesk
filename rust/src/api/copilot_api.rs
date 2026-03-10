//! GitHub Copilot OAuth device-flow API exposed to Flutter.
//!
//! Provides a two-step flow for Flutter UI:
//! 1. `copilot_start_device_flow()` → returns user_code + verification_uri for display
//! 2. `copilot_poll_authorization()` → polls GitHub until user completes authorization
//! 3. `copilot_check_status()` → checks if Copilot is already authenticated
//! 4. `copilot_logout()` → clears cached tokens

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// GitHub OAuth client ID for Copilot (VS Code extension).
const GITHUB_CLIENT_ID: &str = "Iv1.b507a08c87ecfe98";
const GITHUB_DEVICE_CODE_URL: &str = "https://github.com/login/device/code";
const GITHUB_ACCESS_TOKEN_URL: &str = "https://github.com/login/oauth/access_token";
const GITHUB_API_KEY_URL: &str = "https://api.github.com/copilot_internal/v2/token";
const GITHUB_USER_API_URL: &str = "https://api.github.com/user";

/// Result of starting the device code flow.
#[derive(Debug, Clone)]
pub struct CopilotDeviceFlowInfo {
    /// The code the user needs to enter at the verification URI.
    pub user_code: String,
    /// The URL the user should visit (e.g. https://github.com/login/device).
    pub verification_uri: String,
    /// The device code used for polling (internal, pass to poll function).
    pub device_code: String,
    /// Polling interval in seconds.
    pub interval: u64,
    /// Flow expires after this many seconds.
    pub expires_in: u64,
}

/// Status of a Copilot authorization poll attempt.
#[derive(Debug, Clone)]
pub struct CopilotPollResult {
    /// "success", "pending", "slow_down", "expired", or "error:<message>"
    pub status: String,
    /// GitHub username (populated on success).
    pub username: Option<String>,
}

/// Overall Copilot authentication status.
#[derive(Debug, Clone)]
pub struct CopilotAuthStatus {
    /// Whether the user has a valid cached token.
    pub authenticated: bool,
    /// GitHub username if authenticated.
    pub username: Option<String>,
    /// Error message if check failed.
    pub error: Option<String>,
}

// ── Internal types ──────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct DeviceCodeResponse {
    device_code: String,
    user_code: String,
    verification_uri: String,
    #[serde(default = "default_interval")]
    interval: u64,
    #[serde(default = "default_expires_in")]
    expires_in: u64,
}

fn default_interval() -> u64 {
    5
}

fn default_expires_in() -> u64 {
    900
}

#[derive(Debug, Deserialize)]
struct AccessTokenResponse {
    access_token: Option<String>,
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct ApiKeyInfo {
    token: String,
    expires_at: i64,
    #[serde(default)]
    endpoints: Option<ApiEndpoints>,
}

#[derive(Debug, Serialize, Deserialize)]
struct ApiEndpoints {
    api: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GitHubUser {
    login: Option<String>,
}

// ── Helper functions ────────────────────────────────────────

fn copilot_token_dir() -> PathBuf {
    directories::ProjectDirs::from("", "", "zeroclaw")
        .map(|dir| dir.config_dir().join("copilot"))
        .unwrap_or_else(|| {
            let user = std::env::var("USER")
                .or_else(|_| std::env::var("USERNAME"))
                .unwrap_or_else(|_| "unknown".to_string());
            std::env::temp_dir().join(format!("zeroclaw-copilot-{user}"))
        })
}

fn http_client() -> reqwest::Client {
    zeroclaw::config::build_runtime_proxy_client_with_timeouts("copilot_api", 30, 10)
}

/// Copilot editor headers (required for API calls).
const COPILOT_HEADERS: [(&str, &str); 4] = [
    ("Editor-Version", "vscode/1.85.1"),
    ("Editor-Plugin-Version", "copilot/1.155.0"),
    ("User-Agent", "GithubCopilot/1.155.0"),
    ("Accept", "application/json"),
];

/// Write a file with restricted permissions.
async fn write_file_secure(path: &std::path::Path, content: &str) {
    let path = path.to_path_buf();
    let content = content.to_string();

    let _ = tokio::task::spawn_blocking(move || {
        #[cfg(unix)]
        {
            use std::io::Write;
            use std::os::unix::fs::OpenOptionsExt;

            if let Ok(mut file) = std::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .mode(0o600)
                .open(&path)
            {
                let _ = file.write_all(content.as_bytes());
            }
        }
        #[cfg(not(unix))]
        {
            let _ = std::fs::write(&path, &content);
        }
    })
    .await;
}

async fn fetch_github_username(access_token: &str) -> Option<String> {
    let resp = http_client()
        .get(GITHUB_USER_API_URL)
        .header("Authorization", format!("token {access_token}"))
        .header("Accept", "application/json")
        .header("User-Agent", "GithubCopilot/1.155.0")
        .send()
        .await
        .ok()?;

    if !resp.status().is_success() {
        return None;
    }

    let user: GitHubUser = resp.json().await.ok()?;
    user.login
}

// ── Public API (exposed to Flutter via FRB) ─────────────────

/// Start the GitHub OAuth device code flow for Copilot.
/// Returns device flow info including the user_code and verification_uri.
pub async fn copilot_start_device_flow() -> CopilotDeviceFlowInfo {
    let result = async {
        let response: DeviceCodeResponse = http_client()
            .post(GITHUB_DEVICE_CODE_URL)
            .header("Accept", "application/json")
            .json(&serde_json::json!({
                "client_id": GITHUB_CLIENT_ID,
                "scope": "read:user"
            }))
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        Ok::<_, anyhow::Error>(CopilotDeviceFlowInfo {
            user_code: response.user_code,
            verification_uri: response.verification_uri,
            device_code: response.device_code,
            interval: response.interval.max(5),
            expires_in: response.expires_in,
        })
    }
    .await;

    match result {
        Ok(info) => info,
        Err(e) => CopilotDeviceFlowInfo {
            user_code: String::new(),
            verification_uri: String::new(),
            device_code: format!("error:{e}"),
            interval: 5,
            expires_in: 0,
        },
    }
}

/// Poll GitHub for authorization completion.
/// Call this repeatedly with the device_code from `copilot_start_device_flow`.
/// Returns a status: "success", "pending", "slow_down", "expired", or "error:..."
pub async fn copilot_poll_authorization(device_code: String) -> CopilotPollResult {
    let result = async {
        let token_response: AccessTokenResponse = http_client()
            .post(GITHUB_ACCESS_TOKEN_URL)
            .header("Accept", "application/json")
            .json(&serde_json::json!({
                "client_id": GITHUB_CLIENT_ID,
                "device_code": device_code,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
            }))
            .send()
            .await?
            .json()
            .await?;

        if let Some(token) = token_response.access_token {
            // Got the access token — exchange for Copilot API key to validate subscription
            let mut req = http_client().get(GITHUB_API_KEY_URL);
            for (header, value) in &COPILOT_HEADERS {
                req = req.header(*header, *value);
            }
            req = req.header("Authorization", format!("token {token}"));

            let api_resp = req.send().await?;

            if !api_resp.status().is_success() {
                let status = api_resp.status();
                anyhow::bail!(
                    "Copilot subscription check failed ({status}). \
                     Ensure your GitHub account has an active Copilot subscription."
                );
            }

            let api_key_info: ApiKeyInfo = api_resp.json().await?;

            // Save tokens to disk (shared with zeroclaw runtime)
            let token_dir = copilot_token_dir();
            let _ = std::fs::create_dir_all(&token_dir);

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ =
                    std::fs::set_permissions(&token_dir, std::fs::Permissions::from_mode(0o700));
            }

            // Save access token
            write_file_secure(&token_dir.join("access-token"), &token).await;

            // Save API key info
            if let Ok(json) = serde_json::to_string_pretty(&api_key_info) {
                write_file_secure(&token_dir.join("api-key.json"), &json).await;
            }

            // Fetch GitHub username
            let username = fetch_github_username(&token).await;

            Ok(CopilotPollResult {
                status: "success".into(),
                username,
            })
        } else {
            let status = match token_response.error.as_deref() {
                Some("slow_down") => "slow_down",
                Some("authorization_pending") | None => "pending",
                Some("expired_token") => "expired",
                Some(error) => {
                    return Ok(CopilotPollResult {
                        status: format!("error:{error}"),
                        username: None,
                    })
                }
            };
            Ok(CopilotPollResult {
                status: status.into(),
                username: None,
            })
        }
    }
    .await;

    match result {
        Ok(poll) => poll,
        Err(e) => CopilotPollResult {
            status: format!("error:{e}"),
            username: None,
        },
    }
}

/// Check if Copilot is already authenticated (has valid cached tokens).
pub async fn copilot_check_status() -> CopilotAuthStatus {
    let token_dir = copilot_token_dir();
    let access_token_path = token_dir.join("access-token");

    // Check if we have a cached access token
    let access_token = match tokio::fs::read_to_string(&access_token_path).await {
        Ok(content) => {
            let token = content.trim().to_string();
            if token.is_empty() {
                return CopilotAuthStatus {
                    authenticated: false,
                    username: None,
                    error: None,
                };
            }
            token
        }
        Err(_) => {
            return CopilotAuthStatus {
                authenticated: false,
                username: None,
                error: None,
            };
        }
    };

    // Verify the token is still valid by checking the API key
    let api_key_path = token_dir.join("api-key.json");
    if let Ok(data) = tokio::fs::read_to_string(&api_key_path).await {
        if let Ok(info) = serde_json::from_str::<ApiKeyInfo>(&data) {
            if chrono::Utc::now().timestamp() + 120 < info.expires_at {
                // Token is still valid, fetch username
                let username = fetch_github_username(&access_token).await;
                return CopilotAuthStatus {
                    authenticated: true,
                    username,
                    error: None,
                };
            }
        }
    }

    // API key expired or missing — try to refresh from access token
    let mut req = http_client().get(GITHUB_API_KEY_URL);
    for (header, value) in &COPILOT_HEADERS {
        req = req.header(*header, *value);
    }
    req = req.header("Authorization", format!("token {access_token}"));

    match req.send().await {
        Ok(resp) if resp.status().is_success() => {
            if let Ok(info) = resp.json::<ApiKeyInfo>().await {
                if let Ok(json) = serde_json::to_string_pretty(&info) {
                    write_file_secure(&api_key_path, &json).await;
                }
            }
            let username = fetch_github_username(&access_token).await;
            CopilotAuthStatus {
                authenticated: true,
                username,
                error: None,
            }
        }
        Ok(resp) => {
            let status = resp.status();
            // Token revoked or subscription expired
            CopilotAuthStatus {
                authenticated: false,
                username: None,
                error: Some(format!("Copilot token invalid ({status})")),
            }
        }
        Err(e) => CopilotAuthStatus {
            authenticated: false,
            username: None,
            error: Some(format!("Network error: {e}")),
        },
    }
}

/// Clear all cached Copilot tokens (logout).
pub async fn copilot_logout() -> String {
    let token_dir = copilot_token_dir();

    let mut errors = Vec::new();
    for file in &["access-token", "api-key.json"] {
        let path = token_dir.join(file);
        if path.exists() {
            if let Err(e) = tokio::fs::remove_file(&path).await {
                errors.push(format!("Failed to remove {file}: {e}"));
            }
        }
    }

    if errors.is_empty() {
        "ok".into()
    } else {
        format!("error: {}", errors.join("; "))
    }
}

/// List available models for Copilot.
/// Copilot doesn't have a model list API, so we return commonly available models.
#[frb(sync)]
pub fn copilot_available_models() -> Vec<String> {
    vec![
        "gpt-4o".into(),
        "gpt-4o-mini".into(),
        "gpt-4".into(),
        "gpt-3.5-turbo".into(),
        "claude-sonnet-4-20250514".into(),
        "claude-3.5-haiku-20241022".into(),
        "o1".into(),
        "o1-mini".into(),
        "o3-mini".into(),
    ]
}
