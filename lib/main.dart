import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coraldesk/l10n/app_localizations.dart';
import 'package:coraldesk/services/settings_service.dart';
import 'package:coraldesk/theme/app_theme.dart';
import 'package:coraldesk/views/shell/app_shell.dart';
import 'package:coraldesk/providers/providers.dart';
import 'package:coraldesk/bootstrap/app_bootstrapper.dart';

Future<void> main() async {
  await AppBootstrapper.init();
  runApp(const ProviderScope(child: CoralDeskApp()));
}

class CoralDeskApp extends ConsumerWidget {
  const CoralDeskApp({super.key});

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
      title: 'CoralDesk',
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
