// ──────────────── Channel Runtime API ────────────────────────
//
// Manages the lifecycle of zeroclaw channel listeners (Telegram, Discord, etc.).
//
// Architecture:
//   `start_channel_listeners()` reads the current config, clones it, and
//   spawns `zeroclaw::channels::start_channels(config)` as a background
//   tokio task.  The task handle is stored in a global `OnceLock` so that
//   `stop_channel_listeners()` can abort it.
//
//   A restart helper is provided for workspace_api to call after config
//   changes so channels pick up new tokens / enabled flags.

use std::sync::OnceLock;
use tokio::sync::Mutex as TokioMutex;
use tokio::task::JoinHandle;

// ──────────────────── Global State ───────────────────────────

struct ChannelRuntime {
    /// Handle to the background task running `start_channels`.
    handle: Option<JoinHandle<()>>,
    /// Whether channels were explicitly requested to run.
    running: bool,
}

fn channel_runtime() -> &'static TokioMutex<ChannelRuntime> {
    static RT: OnceLock<TokioMutex<ChannelRuntime>> = OnceLock::new();
    RT.get_or_init(|| {
        TokioMutex::new(ChannelRuntime {
            handle: None,
            running: false,
        })
    })
}

// ──────────────────── Public API ─────────────────────────────

/// Start all configured channel listeners in the background.
///
/// Reads the current `config_state`, clones it, and spawns
/// `zeroclaw::channels::start_channels(config)`.
///
/// Returns "ok" on success, or "error: …" on failure.
pub async fn start_channel_listeners() -> String {
    let config = {
        let cs = super::agent_api::config_state().read().await;
        match &cs.config {
            Some(c) => c.clone(),
            None => return "error: runtime not initialized".into(),
        }
    };

    // Check whether any non-CLI channel is configured
    let ch = &config.channels_config;
    let has_channels = ch.telegram.is_some()
        || ch.discord.is_some()
        || ch.slack.is_some()
        || ch.webhook.is_some()
        || ch.email.is_some()
        || ch.matrix.is_some()
        || ch.signal.is_some()
        || ch.whatsapp.is_some()
        || ch.irc.is_some()
        || ch.lark.is_some()
        || ch.feishu.is_some()
        || ch.dingtalk.is_some();

    if !has_channels {
        return "ok: no channels configured".into();
    }

    let mut rt = channel_runtime().lock().await;

    // If already running, stop old task first
    if let Some(handle) = rt.handle.take() {
        handle.abort();
        let _ = handle.await; // wait for abort to complete
    }

    let config_clone = config.clone();
    let handle = tokio::spawn(async move {
        tracing::info!("Channel listeners starting…");
        match zeroclaw::channels::start_channels(config_clone).await {
            Ok(()) => tracing::info!("Channel listeners stopped normally"),
            Err(e) => tracing::error!("Channel listeners exited with error: {e}"),
        }
    });

    rt.handle = Some(handle);
    rt.running = true;

    tracing::info!("Channel listeners spawned");
    "ok".into()
}

/// Stop all running channel listeners.
///
/// Aborts the background task.  Returns "ok" on success.
pub async fn stop_channel_listeners() -> String {
    let mut rt = channel_runtime().lock().await;

    if let Some(handle) = rt.handle.take() {
        handle.abort();
        let _ = handle.await;
        tracing::info!("Channel listeners stopped");
    }

    rt.running = false;
    "ok".into()
}

/// Restart channel listeners (stop + start).
///
/// Useful after config changes so the new tokens / enabled flags take effect.
pub async fn restart_channel_listeners() -> String {
    stop_channel_listeners().await;
    start_channel_listeners().await
}

/// Check whether channel listeners are currently running.
pub async fn is_channel_listeners_running() -> bool {
    let rt = channel_runtime().lock().await;
    if let Some(ref handle) = rt.handle {
        !handle.is_finished()
    } else {
        false
    }
}

/// Get a summary of which channels are currently configured (enabled).
///
/// Returns a list of channel type strings (e.g. `["telegram", "discord"]`).
pub async fn get_active_channel_types() -> Vec<String> {
    let cs = super::agent_api::config_state().read().await;
    let config = match &cs.config {
        Some(c) => c,
        None => return vec![],
    };
    let ch = &config.channels_config;
    let mut active = Vec::new();

    if ch.cli {
        active.push("cli".into());
    }
    if ch.telegram.is_some() {
        active.push("telegram".into());
    }
    if ch.discord.is_some() {
        active.push("discord".into());
    }
    if ch.slack.is_some() {
        active.push("slack".into());
    }
    if ch.webhook.is_some() {
        active.push("webhook".into());
    }
    if ch.email.is_some() {
        active.push("email".into());
    }
    if ch.matrix.is_some() {
        active.push("matrix".into());
    }
    if ch.signal.is_some() {
        active.push("signal".into());
    }
    if ch.whatsapp.is_some() {
        active.push("whatsapp".into());
    }
    if ch.irc.is_some() {
        active.push("irc".into());
    }
    if ch.lark.is_some() {
        active.push("lark".into());
    }
    if ch.feishu.is_some() {
        active.push("feishu".into());
    }
    if ch.dingtalk.is_some() {
        active.push("dingtalk".into());
    }

    active
}
