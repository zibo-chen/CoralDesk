import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:deskclaw/l10n/app_localizations.dart';
import 'package:deskclaw/src/rust/frb_generated.dart';
import 'package:deskclaw/src/rust/api/agent_api.dart' as agent_api;
import 'package:deskclaw/src/rust/api/sessions_api.dart' as sessions_api;
import 'package:deskclaw/src/rust/api/cron_api.dart' as cron_api;
import 'package:deskclaw/services/settings_service.dart';
import 'package:deskclaw/theme/app_theme.dart';
import 'package:deskclaw/views/shell/app_shell.dart';
import 'package:deskclaw/providers/providers.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && _isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: 'DeskClaw',
      titleBarStyle: TitleBarStyle.hidden,
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await RustLib.init();

  // Load persisted user settings (locale, theme, etc.)
  await SettingsService.init();

  // Initialize Zeroclaw runtime (loads config from ~/.zeroclaw/config.toml)
  final status = await agent_api.initRuntime();
  debugPrint('DeskClaw runtime: $status');

  // Initialize session persistence store
  final sessionsStatus = await sessions_api.initSessionStore();
  debugPrint('DeskClaw sessions: $sessionsStatus');

  // Start cron scheduler in background
  try {
    final cronStatus = await cron_api.startCronScheduler();
    debugPrint('DeskClaw cron scheduler: $cronStatus');
  } catch (e) {
    debugPrint('DeskClaw cron scheduler failed: $e');
  }

  runApp(const ProviderScope(child: DeskClawApp()));
}

bool get _isDesktopPlatform {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return true;
    default:
      return false;
  }
}

class DeskClawApp extends ConsumerWidget {
  const DeskClawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Persist locale & theme whenever they change
    ref.listen<Locale>(localeProvider, (_, next) {
      SettingsService.locale = next.languageCode;
    });
    ref.listen<ThemeMode>(themeModeProvider, (_, next) {
      SettingsService.themeMode = next == ThemeMode.dark ? 'dark' : 'light';
    });

    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'DeskClaw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh')],
      home: const AppShell(),
    );
  }
}
