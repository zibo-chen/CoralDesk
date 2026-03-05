import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:coraldesk/src/rust/frb_generated.dart';
import 'package:coraldesk/src/rust/api/agent_api.dart' as agent_api;
import 'package:coraldesk/src/rust/api/sessions_api.dart' as sessions_api;
import 'package:coraldesk/src/rust/api/cron_api.dart' as cron_api;
import 'package:coraldesk/src/rust/api/channel_runtime_api.dart' as channel_rt;
import 'package:coraldesk/services/settings_service.dart';
import 'package:window_manager/window_manager.dart';

/// Centralises all application startup logic.
///
/// Call [AppBootstrapper.init] once before [runApp].
class AppBootstrapper {
  AppBootstrapper._();

  static bool _initialized = false;

  /// Performs all initialisation in the correct order:
  ///
  /// 1. Flutter bindings
  /// 2. Window manager (desktop only)
  /// 3. Rust FFI bridge
  /// 4. User settings (SharedPreferences)
  /// 5. ZeroClaw runtime
  /// 6. Session store
  /// 7. Cron scheduler (non-critical)
  static Future<void> init() async {
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Desktop window setup
    if (!kIsWeb && _isDesktopPlatform) {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        title: 'CoralDesk',
        titleBarStyle: TitleBarStyle.hidden,
        center: true,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // Rust FFI bridge
    await RustLib.init();

    // Persisted user settings (locale, theme, etc.)
    await SettingsService.init();

    // ZeroClaw runtime (loads config from ~/.zeroclaw/config.toml)
    final status = await agent_api.initRuntime();
    debugPrint('CoralDesk runtime: $status');

    // Session persistence store
    final sessionsStatus = await sessions_api.initSessionStore();
    debugPrint('CoralDesk sessions: $sessionsStatus');

    // Cron scheduler (non-critical — failure should not block startup)
    try {
      final cronStatus = await cron_api.startCronScheduler();
      debugPrint('CoralDesk cron scheduler: $cronStatus');
    } catch (e) {
      debugPrint('CoralDesk cron scheduler failed: $e');
    }

    // Channel listeners (Telegram, Discord, etc. — non-critical)
    try {
      final channelStatus = await channel_rt.startChannelListeners();
      debugPrint('CoralDesk channel listeners: $channelStatus');
    } catch (e) {
      debugPrint('CoralDesk channel listeners failed: $e');
    }

    _initialized = true;
  }

  static bool get _isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return true;
      default:
        return false;
    }
  }
}
