use std::sync::Once;
use tracing_subscriber::{fmt, EnvFilter};

pub fn init_rust_logging() {
    static INIT: Once = Once::new();

    INIT.call_once(|| {
        if std::env::var_os("RUST_LOG").is_none() {
            // Suppress flutter_rust_bridge "Fail to post message to Dart" warnings.
            // These occur due to benign race conditions when Dart-side stream closes
            // slightly before Rust finishes sending (normal during navigation, etc.).
            std::env::set_var(
                "RUST_LOG",
                "info,rust_lib_coraldesk=debug,zeroclaw=info,flutter_rust_bridge::misc::logs=error",
            );
        }

        let _ = fmt()
            .with_env_filter(
                EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
            )
            .with_target(true)
            .with_ansi(false)
            .try_init();
    });
}
