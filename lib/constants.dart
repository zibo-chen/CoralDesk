import 'package:flutter/foundation.dart';

/// CoralDesk application constants
class AppConstants {
  AppConstants._();

  static const String appName = 'CoralDesk';
  static const String appVersion = 'v0.1.0';
  static const String appTagline = 'Works for you, grows with you';
  static const String welcomeTitle = 'Hello, how can I help you today?';
  static const String welcomeSubtitle =
      'I am a helpful assistant that can help you with your questions.';

  // Sidebar widths
  static const double sidebarWidth = 220.0;
  static const double sidebarCollapsedWidth = 72.0;
  static const double chatListWidth = 260.0;

  // Input limits
  static const int maxInputLength = 10000;

  // Suggestion cards (all candidates; 2 will be randomly shown per new session)
  static const List<String> defaultSuggestions = [
    '你能做什么？',
    '帮我写一篇关于人工智能的文章。',
    '用简单的语言解释机器学习的基本原理。',
    '帮我写一封专业邮件。',
    '如何提高工作效率？',
    '推荐几本值得阅读的书。',
    '帮我规划一次短途旅行。',
    '帮我头脑风暴一些创意。',
  ];

  // Desktop platform helpers
  static bool get isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Compact top padding on macOS for native traffic-light window controls.
  /// Reduced from 28 to 20 for a more space-efficient layout.
  static const double macOSTopInset = 20.0;

  /// Unified title-bar / top-bar height across all pages.
  static const double titleBarHeight = 48.0;

  /// Window control button dimensions for Windows/Linux
  static const double windowControlWidth = 46.0;
  static const double windowControlHeight = 36.0;
}
