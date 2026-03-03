import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'CoralDesk'**
  String get appTitle;

  /// App tagline shown below input bar
  ///
  /// In en, this message translates to:
  /// **'From your desk, master the AI era'**
  String get appTagline;

  /// Chat section label in sidebar
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navSectionChat;

  /// Control section label in sidebar
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get navSectionControl;

  /// Agent section label in sidebar
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get navSectionAgent;

  /// Settings section label in sidebar
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSectionSettings;

  /// Chat nav item
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// Channels nav item
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get navChannels;

  /// Sessions nav item
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// Cron Jobs nav item
  ///
  /// In en, this message translates to:
  /// **'Cron Jobs'**
  String get navCronJobs;

  /// Workspace nav item
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get navWorkspace;

  /// Skills nav item
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get navSkills;

  /// MCP nav item
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get navMcp;

  /// Configuration nav item
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get navConfiguration;

  /// Models nav item
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get navModels;

  /// Environments nav item
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get navEnvironments;

  /// Chat list panel header
  ///
  /// In en, this message translates to:
  /// **'Work with CoralDesk'**
  String get workWithCoralDesk;

  /// New chat button label
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// Chat list empty state title
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// Chat list empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'Start a new chat'**
  String get startNewChat;

  /// Welcome view title
  ///
  /// In en, this message translates to:
  /// **'Hello, how can I help you today?'**
  String get welcomeTitle;

  /// Welcome view subtitle
  ///
  /// In en, this message translates to:
  /// **'I am a helpful assistant that can help you with your questions.'**
  String get welcomeSubtitle;

  /// Suggestion card 1
  ///
  /// In en, this message translates to:
  /// **'What can you do?'**
  String get suggestionWhatCanYouDo;

  /// Suggestion card 2
  ///
  /// In en, this message translates to:
  /// **'Help me write an article about AI.'**
  String get suggestionWriteArticle;

  /// Suggestion card 3
  ///
  /// In en, this message translates to:
  /// **'Explain the basics of machine learning in simple terms.'**
  String get suggestionExplainML;

  /// Suggestion card 4
  ///
  /// In en, this message translates to:
  /// **'Help me write a professional email.'**
  String get suggestionWriteEmail;

  /// Suggestion card 5
  ///
  /// In en, this message translates to:
  /// **'How can I improve my productivity?'**
  String get suggestionImproveProductivity;

  /// Suggestion card 6
  ///
  /// In en, this message translates to:
  /// **'Recommend some books worth reading.'**
  String get suggestionRecommendBooks;

  /// Suggestion card 7
  ///
  /// In en, this message translates to:
  /// **'Help me plan a short trip.'**
  String get suggestionPlanTrip;

  /// Suggestion card 8
  ///
  /// In en, this message translates to:
  /// **'Brainstorm some creative ideas.'**
  String get suggestionBrainstorm;

  /// Thinking indicator
  ///
  /// In en, this message translates to:
  /// **'💭 Thinking...'**
  String get thinking;

  /// Error message with detail
  ///
  /// In en, this message translates to:
  /// **'⚠️ **Error:** {message}\n\nPlease check your API key and provider settings.'**
  String errorOccurred(String message);

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'⚠️ **Error:** {message}\n\nPlease check your settings and try again.'**
  String errorGeneric(String message);

  /// Chat view top bar title
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// Input placeholder when processing
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// Input placeholder
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeYourMessage;

  /// Collapse output button
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// Expand button tooltip
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// Channels page title
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get pageChannels;

  /// Configuration page title
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get pageConfiguration;

  /// Cron Jobs page title
  ///
  /// In en, this message translates to:
  /// **'Cron Jobs'**
  String get pageCronJobs;

  /// Models page title
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get pageModels;

  /// Sessions page title
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get pageSessions;

  /// Skills page title
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get pageSkills;

  /// Tools page title
  ///
  /// In en, this message translates to:
  /// **'Tools & MCP'**
  String get pageTools;

  /// Workspace page title
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get pageWorkspace;

  /// Language selector label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get switchToEnglish;

  /// Chinese language option
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get switchToChinese;

  /// Copy tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get tooltipCopy;

  /// Refresh tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get tooltipRefresh;

  /// Dark mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Light mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// Tool call success status
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get toolCallSuccess;

  /// Tool call failed status
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolCallFailed;

  /// Coming soon badge
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Feature coming soon description
  ///
  /// In en, this message translates to:
  /// **'This feature is coming soon.'**
  String get featureComingSoon;

  /// Environments page description
  ///
  /// In en, this message translates to:
  /// **'Manage environment variables and deployment profiles.'**
  String get environmentsDescription;

  /// Provider config section title
  ///
  /// In en, this message translates to:
  /// **'Provider Configuration'**
  String get providerConfiguration;

  /// Provider dropdown label
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerLabel;

  /// Model dropdown label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelLabel;

  /// API key field label
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKeyLabel;

  /// API key field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your API key...'**
  String get apiKeyHint;

  /// API base URL field label
  ///
  /// In en, this message translates to:
  /// **'API Base URL'**
  String get apiBaseUrlLabel;

  /// Temperature slider label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperatureLabel;

  /// Save button label when saving
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Config saved success message
  ///
  /// In en, this message translates to:
  /// **'Configuration saved!'**
  String get configSaved;

  /// Config save failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to save config'**
  String get configSaveFailed;

  /// Runtime status section title
  ///
  /// In en, this message translates to:
  /// **'Runtime Status'**
  String get runtimeStatus;

  /// Initialized status label
  ///
  /// In en, this message translates to:
  /// **'Initialized'**
  String get initialized;

  /// Yes label
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No label
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Configured status
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configured;

  /// Missing status
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// Active provider label
  ///
  /// In en, this message translates to:
  /// **'Active Provider'**
  String get activeProvider;

  /// Active model label
  ///
  /// In en, this message translates to:
  /// **'Active Model'**
  String get activeModel;

  /// Model name input hint
  ///
  /// In en, this message translates to:
  /// **'Enter model name or select from list...'**
  String get modelNameHint;

  /// Show suggestions tooltip
  ///
  /// In en, this message translates to:
  /// **'Show suggestions'**
  String get showSuggestions;

  /// Workspace info section title
  ///
  /// In en, this message translates to:
  /// **'Workspace Info'**
  String get workspaceInfo;

  /// Workspace directory label
  ///
  /// In en, this message translates to:
  /// **'Workspace Directory'**
  String get workspaceDirectory;

  /// Config file label
  ///
  /// In en, this message translates to:
  /// **'Config File'**
  String get configFile;

  /// Agent settings section title
  ///
  /// In en, this message translates to:
  /// **'Agent Settings'**
  String get agentSettings;

  /// Max tool iterations label
  ///
  /// In en, this message translates to:
  /// **'Max Tool Iterations'**
  String get maxToolIterations;

  /// Max history messages label
  ///
  /// In en, this message translates to:
  /// **'Max History Messages'**
  String get maxHistoryMessages;

  /// Parallel tool execution label
  ///
  /// In en, this message translates to:
  /// **'Parallel Tool Execution'**
  String get parallelToolExecution;

  /// Compact context label
  ///
  /// In en, this message translates to:
  /// **'Compact Context'**
  String get compactContext;

  /// Tool dispatcher label
  ///
  /// In en, this message translates to:
  /// **'Tool Dispatcher'**
  String get toolDispatcher;

  /// Memory section title
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memorySection;

  /// Backend label
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backend;

  /// Auto save label
  ///
  /// In en, this message translates to:
  /// **'Auto Save'**
  String get autoSave;

  /// Enabled status
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// Disabled status
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// Hygiene label
  ///
  /// In en, this message translates to:
  /// **'Hygiene'**
  String get hygiene;

  /// Archive after label
  ///
  /// In en, this message translates to:
  /// **'Archive After'**
  String get archiveAfter;

  /// Days unit
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// Purge after label
  ///
  /// In en, this message translates to:
  /// **'Purge After'**
  String get purgeAfter;

  /// Embedding provider label
  ///
  /// In en, this message translates to:
  /// **'Embedding Provider'**
  String get embeddingProvider;

  /// Embedding model label
  ///
  /// In en, this message translates to:
  /// **'Embedding Model'**
  String get embeddingModel;

  /// Cost tracking section title
  ///
  /// In en, this message translates to:
  /// **'Cost Tracking'**
  String get costTracking;

  /// Daily limit label
  ///
  /// In en, this message translates to:
  /// **'Daily Limit'**
  String get dailyLimit;

  /// Monthly limit label
  ///
  /// In en, this message translates to:
  /// **'Monthly Limit'**
  String get monthlyLimit;

  /// Warn at label
  ///
  /// In en, this message translates to:
  /// **'Warn At'**
  String get warnAt;

  /// Autonomy & security section title
  ///
  /// In en, this message translates to:
  /// **'Autonomy & Security'**
  String get autonomySecurity;

  /// Autonomy level label
  ///
  /// In en, this message translates to:
  /// **'Autonomy Level'**
  String get autonomyLevel;

  /// Read only autonomy level
  ///
  /// In en, this message translates to:
  /// **'Read Only'**
  String get readOnly;

  /// Supervised autonomy level
  ///
  /// In en, this message translates to:
  /// **'Supervised'**
  String get supervised;

  /// Full autonomy level
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get fullAutonomy;

  /// Trust me mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Trust Me Mode'**
  String get trustMeMode;

  /// Trust me mode description
  ///
  /// In en, this message translates to:
  /// **'Auto-approve all tool calls without confirmation. Use with caution.'**
  String get trustMeDescription;

  /// Tool approval dialog title
  ///
  /// In en, this message translates to:
  /// **'Tool Approval Required'**
  String get toolApprovalTitle;

  /// Tool approval dialog body
  ///
  /// In en, this message translates to:
  /// **'The agent wants to execute tool: {toolName}'**
  String toolApprovalBody(String toolName);

  /// Approve button
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Deny button
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// Workspace only setting
  ///
  /// In en, this message translates to:
  /// **'Workspace Only'**
  String get workspaceOnly;

  /// Require approval for medium risk
  ///
  /// In en, this message translates to:
  /// **'Require Approval (Medium Risk)'**
  String get requireApprovalMediumRisk;

  /// Block high risk commands
  ///
  /// In en, this message translates to:
  /// **'Block High Risk'**
  String get blockHighRisk;

  /// Max actions per hour
  ///
  /// In en, this message translates to:
  /// **'Max Actions/Hour'**
  String get maxActionsPerHour;

  /// Max cost per day
  ///
  /// In en, this message translates to:
  /// **'Max Cost/Day'**
  String get maxCostPerDay;

  /// Allowed commands label
  ///
  /// In en, this message translates to:
  /// **'Allowed Commands'**
  String get allowedCommands;

  /// Auto-approved tools label
  ///
  /// In en, this message translates to:
  /// **'Auto-Approved Tools'**
  String get autoApprovedTools;

  /// Tools section title
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolsSection;

  /// Tool count label
  ///
  /// In en, this message translates to:
  /// **'{count} tools'**
  String toolCountLabel(int count);

  /// Core tools category
  ///
  /// In en, this message translates to:
  /// **'Core Tools'**
  String get categoryCoreTools;

  /// Version control category
  ///
  /// In en, this message translates to:
  /// **'Version Control'**
  String get categoryVersionControl;

  /// Web & network category
  ///
  /// In en, this message translates to:
  /// **'Web & Network'**
  String get categoryWebNetwork;

  /// Memory category
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get categoryMemory;

  /// System category
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get categorySystem;

  /// File processing category
  ///
  /// In en, this message translates to:
  /// **'File Processing'**
  String get categoryFileProcessing;

  /// Agent category
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get categoryAgent;

  /// Scheduling category
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get categoryScheduling;

  /// Auto approval label
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get approvalAuto;

  /// Ask approval label
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get approvalAsk;

  /// Delete session dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Session'**
  String get deleteSessionTitle;

  /// Delete session confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this session? This action cannot be undone.'**
  String get deleteSessionConfirm;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Session deleted message
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// Rename session dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename Session'**
  String get renameSessionTitle;

  /// Session title field label
  ///
  /// In en, this message translates to:
  /// **'Session Title'**
  String get sessionTitleLabel;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Session renamed message
  ///
  /// In en, this message translates to:
  /// **'Renamed'**
  String get sessionRenamed;

  /// Clear all sessions dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear All Sessions'**
  String get clearAllSessionsTitle;

  /// Clear all sessions confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all saved sessions? This action cannot be undone.'**
  String get clearAllSessionsConfirm;

  /// Delete all button
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// All sessions cleared message
  ///
  /// In en, this message translates to:
  /// **'All sessions cleared'**
  String get allSessionsCleared;

  /// Session count label
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionCount;

  /// Message count label
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messageCount;

  /// Refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Clear all sessions button
  ///
  /// In en, this message translates to:
  /// **'Clear All Sessions'**
  String get clearAllSessions;

  /// No saved sessions empty state
  ///
  /// In en, this message translates to:
  /// **'No saved sessions'**
  String get noSavedSessions;

  /// Sessions auto save hint
  ///
  /// In en, this message translates to:
  /// **'Sessions will be automatically saved here after you send messages in chat'**
  String get sessionsAutoSaveHint;

  /// Search sessions placeholder
  ///
  /// In en, this message translates to:
  /// **'Search sessions...'**
  String get searchSessions;

  /// Message count with unit
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String messageCountWithUnit(int count);

  /// Rename button
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Select session hint
  ///
  /// In en, this message translates to:
  /// **'Select a session to view details'**
  String get selectSessionToView;

  /// Messages count and created at label
  ///
  /// In en, this message translates to:
  /// **'{count} messages · Created at'**
  String messagesCreatedAt(int count);

  /// You role label
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get roleYou;

  /// AI role label
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get roleAI;

  /// Just now time label
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// Minutes ago time label
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// Hours ago time label
  ///
  /// In en, this message translates to:
  /// **'{count} hr ago'**
  String hoursAgo(int count);

  /// Days ago time label
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// Feature toggles section title
  ///
  /// In en, this message translates to:
  /// **'Feature Toggles'**
  String get featureToggles;

  /// Feature toggles description
  ///
  /// In en, this message translates to:
  /// **'Quickly enable or disable Agent feature modules, select to use directly'**
  String get featureTogglesDesc;

  /// Web search feature name
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get featureWebSearch;

  /// Web search feature description
  ///
  /// In en, this message translates to:
  /// **'Search the internet for latest information'**
  String get featureWebSearchDesc;

  /// Web fetch feature name
  ///
  /// In en, this message translates to:
  /// **'Web Fetch'**
  String get featureWebFetch;

  /// Web fetch feature description
  ///
  /// In en, this message translates to:
  /// **'Fetch web page content and extract text'**
  String get featureWebFetchDesc;

  /// Browser automation feature name
  ///
  /// In en, this message translates to:
  /// **'Browser Automation'**
  String get featureBrowser;

  /// Browser automation feature description
  ///
  /// In en, this message translates to:
  /// **'Automate browser operations and interactions'**
  String get featureBrowserDesc;

  /// HTTP request feature name
  ///
  /// In en, this message translates to:
  /// **'HTTP Request'**
  String get featureHttpRequest;

  /// HTTP request feature description
  ///
  /// In en, this message translates to:
  /// **'Send API requests (GET/POST/PUT/DELETE)'**
  String get featureHttpRequestDesc;

  /// Auto memory feature name
  ///
  /// In en, this message translates to:
  /// **'Auto Memory'**
  String get featureMemory;

  /// Auto memory feature description
  ///
  /// In en, this message translates to:
  /// **'Automatically save important information from conversations'**
  String get featureMemoryDesc;

  /// Cost tracking feature name
  ///
  /// In en, this message translates to:
  /// **'Cost Tracking'**
  String get featureCostTracking;

  /// Cost tracking feature description
  ///
  /// In en, this message translates to:
  /// **'Track API call costs and set limits'**
  String get featureCostTrackingDesc;

  /// Community skills feature name
  ///
  /// In en, this message translates to:
  /// **'Community Skills'**
  String get featureSkillsOpen;

  /// Community skills feature description
  ///
  /// In en, this message translates to:
  /// **'Enable open-source community skill extensions'**
  String get featureSkillsOpenDesc;

  /// Feature enabled status
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get featureEnabled;

  /// Feature disabled status
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get featureDisabled;

  /// Operation failed message
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// Built-in tools section title
  ///
  /// In en, this message translates to:
  /// **'Built-in Tools'**
  String get builtInTools;

  /// Tool approval hint
  ///
  /// In en, this message translates to:
  /// **'Click approval status label to quickly toggle tool permission'**
  String get toolApprovalHint;

  /// Auto approval label
  ///
  /// In en, this message translates to:
  /// **'Auto Approval'**
  String get autoApproval;

  /// Require confirmation label
  ///
  /// In en, this message translates to:
  /// **'Require Confirmation'**
  String get requireConfirmation;

  /// Default approval label
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultApproval;

  /// Core category
  ///
  /// In en, this message translates to:
  /// **'Core Tools'**
  String get categoryCore;

  /// VCS category
  ///
  /// In en, this message translates to:
  /// **'Version Control'**
  String get categoryVcs;

  /// Web category
  ///
  /// In en, this message translates to:
  /// **'Web & Network'**
  String get categoryWeb;

  /// Memory & Storage category
  ///
  /// In en, this message translates to:
  /// **'Memory & Storage'**
  String get categoryMemoryTools;

  /// Cron category
  ///
  /// In en, this message translates to:
  /// **'Scheduling'**
  String get categoryCron;

  /// File category
  ///
  /// In en, this message translates to:
  /// **'File Processing'**
  String get categoryFile;

  /// Agent delegation category
  ///
  /// In en, this message translates to:
  /// **'Agent Delegation'**
  String get categoryAgentTools;

  /// Channel config saved message
  ///
  /// In en, this message translates to:
  /// **'{name} configuration saved'**
  String channelConfigSaved(String name);

  /// Save failed message
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailedWithError(String error);

  /// Disable channel dialog title
  ///
  /// In en, this message translates to:
  /// **'Disable {name}'**
  String disableChannelTitle(String name);

  /// Disable channel confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disable this channel? Configuration will be cleared.'**
  String get disableChannelConfirm;

  /// Disable button
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// Channel disabled message
  ///
  /// In en, this message translates to:
  /// **'{name} disabled'**
  String channelDisabled(String name);

  /// Operation failed with error message
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String operationFailedWithError(String error);

  /// Active count label
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeCount(int count);

  /// No channels available message
  ///
  /// In en, this message translates to:
  /// **'No channels available'**
  String get noChannelsAvailable;

  /// Active channels section
  ///
  /// In en, this message translates to:
  /// **'Active Channels'**
  String get activeChannels;

  /// Available channels section
  ///
  /// In en, this message translates to:
  /// **'Available Channels'**
  String get availableChannels;

  /// Active status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// Inactive status
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// Configure channel tooltip
  ///
  /// In en, this message translates to:
  /// **'Configure {name}'**
  String configureChannel(String name);

  /// Disable channel tooltip
  ///
  /// In en, this message translates to:
  /// **'Disable {name}'**
  String disableChannel(String name);

  /// Skills config section title
  ///
  /// In en, this message translates to:
  /// **'Skills Configuration'**
  String get skillsConfig;

  /// Local skills label
  ///
  /// In en, this message translates to:
  /// **'Local Skills'**
  String get localSkills;

  /// Community skills label
  ///
  /// In en, this message translates to:
  /// **'Community Skills'**
  String get communitySkills;

  /// Open source skills title
  ///
  /// In en, this message translates to:
  /// **'Community Open-Source Skills'**
  String get openSourceSkills;

  /// Open source skills description
  ///
  /// In en, this message translates to:
  /// **'Auto-sync community skills from GitHub when enabled'**
  String get openSourceSkillsDesc;

  /// Prompt injection mode label
  ///
  /// In en, this message translates to:
  /// **'Prompt Injection Mode'**
  String get promptInjectionMode;

  /// Full injection mode
  ///
  /// In en, this message translates to:
  /// **'Full Mode'**
  String get fullMode;

  /// Full mode description
  ///
  /// In en, this message translates to:
  /// **'Inject complete skill instructions and tool info into system prompt'**
  String get fullModeDesc;

  /// Compact injection mode
  ///
  /// In en, this message translates to:
  /// **'Compact Mode'**
  String get compactMode;

  /// Compact mode description
  ///
  /// In en, this message translates to:
  /// **'Inject skill summary only, load details on demand'**
  String get compactModeDesc;

  /// No skills available message
  ///
  /// In en, this message translates to:
  /// **'No skills available'**
  String get noSkillsAvailable;

  /// No skills hint
  ///
  /// In en, this message translates to:
  /// **'Create SKILL.toml or SKILL.md files in the workspace\'s skills/ directory to add custom skills, or enable community open-source skills for more capabilities.'**
  String get noSkillsHint;

  /// Quick start skill button
  ///
  /// In en, this message translates to:
  /// **'Quick Start: Create SKILL.toml'**
  String get quickStartSkill;

  /// Local source label
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get sourceLocal;

  /// Community source label
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get sourceCommunity;

  /// Included tools label
  ///
  /// In en, this message translates to:
  /// **'Included Tools'**
  String get includedTools;

  /// Prompts label
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get prompts;

  /// Prompts with count
  ///
  /// In en, this message translates to:
  /// **'Prompts ({count})'**
  String promptsWithCount(int count);

  /// Community skills toggled message
  ///
  /// In en, this message translates to:
  /// **'Community skills {status}'**
  String communitySkillsToggled(String status);

  /// Injection mode updated message
  ///
  /// In en, this message translates to:
  /// **'Injection mode updated to {mode}'**
  String injectionModeUpdated(String mode);

  /// Install skill button
  ///
  /// In en, this message translates to:
  /// **'Install Skill'**
  String get installSkill;

  /// Install skill input hint
  ///
  /// In en, this message translates to:
  /// **'Enter Git URL or local path'**
  String get installSkillHint;

  /// Install skill input placeholder
  ///
  /// In en, this message translates to:
  /// **'https://github.com/user/skill-repo or /path/to/skill'**
  String get installSkillPlaceholder;

  /// Installing progress text
  ///
  /// In en, this message translates to:
  /// **'Installing...'**
  String get installing;

  /// Skill installed success message
  ///
  /// In en, this message translates to:
  /// **'Skill \'{name}\' installed successfully'**
  String skillInstalled(String name);

  /// Install failed message
  ///
  /// In en, this message translates to:
  /// **'Install failed: {error}'**
  String installFailed(String error);

  /// Remove skill button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeSkill;

  /// Remove skill dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Skill'**
  String get removeSkillTitle;

  /// Remove skill confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove skill \'{name}\'? This cannot be undone.'**
  String removeSkillConfirm(String name);

  /// Skill removed message
  ///
  /// In en, this message translates to:
  /// **'Skill \'{name}\' removed'**
  String skillRemoved(String name);

  /// Remove failed message
  ///
  /// In en, this message translates to:
  /// **'Remove failed: {error}'**
  String removeFailed(String error);

  /// Git URL example
  ///
  /// In en, this message translates to:
  /// **'e.g. https://github.com/user/my-skill'**
  String get gitUrlExample;

  /// Supported sources description
  ///
  /// In en, this message translates to:
  /// **'Supports Git URL (https/ssh) or local directory path'**
  String get supportedSources;

  /// Delete cron job dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Cron Job'**
  String get deleteCronJobTitle;

  /// Delete cron job confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this cron job? This action cannot be undone.'**
  String get deleteCronJobConfirm;

  /// Deleted message
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// Delete failed message
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedWithError(String error);

  /// Cron job enabled message
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get cronJobEnabled;

  /// Cron job paused message
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get cronJobPaused;

  /// Execution success message
  ///
  /// In en, this message translates to:
  /// **'Execution succeeded'**
  String get executionSuccess;

  /// Execution failed message
  ///
  /// In en, this message translates to:
  /// **'Execution failed: {error}'**
  String executionFailedWithError(String error);

  /// Execution error message
  ///
  /// In en, this message translates to:
  /// **'Execution error: {error}'**
  String executionErrorWithError(String error);

  /// Total count label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalCount;

  /// Running status
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// Paused status
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// New task button
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// No cron jobs message
  ///
  /// In en, this message translates to:
  /// **'No cron jobs'**
  String get noCronJobs;

  /// No cron jobs hint
  ///
  /// In en, this message translates to:
  /// **'Click \"New Task\" above to create Shell or AI Agent scheduled tasks'**
  String get noCronJobsHint;

  /// Main session label
  ///
  /// In en, this message translates to:
  /// **'Main Session'**
  String get mainSession;

  /// Run now button
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get runNow;

  /// Tooltip for collapsing chat list panel
  ///
  /// In en, this message translates to:
  /// **'Collapse history'**
  String get collapseHistory;

  /// Run history button
  ///
  /// In en, this message translates to:
  /// **'Run History'**
  String get runHistory;

  /// Next execution label
  ///
  /// In en, this message translates to:
  /// **'Next execution:'**
  String get nextExecution;

  /// Last run label
  ///
  /// In en, this message translates to:
  /// **'Last:'**
  String get lastRun;

  /// One-time schedule label
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get oneTime;

  /// No run history message
  ///
  /// In en, this message translates to:
  /// **'No run history'**
  String get noRunHistory;

  /// Run history recent count
  ///
  /// In en, this message translates to:
  /// **'Run History (recent {count})'**
  String runHistoryRecent(int count);

  /// New cron job dialog title
  ///
  /// In en, this message translates to:
  /// **'New Cron Job'**
  String get newCronJob;

  /// Task name field label
  ///
  /// In en, this message translates to:
  /// **'Task Name (optional)'**
  String get taskNameOptional;

  /// Task type label
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get taskType;

  /// Shell command option
  ///
  /// In en, this message translates to:
  /// **'Shell Command'**
  String get shellCommand;

  /// AI Agent option
  ///
  /// In en, this message translates to:
  /// **'AI Agent'**
  String get aiAgent;

  /// Schedule type label
  ///
  /// In en, this message translates to:
  /// **'Schedule Type'**
  String get scheduleType;

  /// Interval option
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// Scheduled option
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// Cron expression label
  ///
  /// In en, this message translates to:
  /// **'Cron Expression'**
  String get cronExpression;

  /// Interval in milliseconds label
  ///
  /// In en, this message translates to:
  /// **'Interval (milliseconds)'**
  String get intervalMs;

  /// Execution time label
  ///
  /// In en, this message translates to:
  /// **'Execution Time (RFC3339)'**
  String get executionTime;

  /// Shell command input label
  ///
  /// In en, this message translates to:
  /// **'Shell Command'**
  String get shellCommandLabel;

  /// AI prompt input label
  ///
  /// In en, this message translates to:
  /// **'AI Prompt'**
  String get aiPromptLabel;

  /// Model optional field label
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get modelOptional;

  /// Use default model hint
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use default model'**
  String get useDefaultModel;

  /// Session target label
  ///
  /// In en, this message translates to:
  /// **'Session Target'**
  String get sessionTarget;

  /// Isolated session option
  ///
  /// In en, this message translates to:
  /// **'Isolated'**
  String get isolated;

  /// Delete after run option
  ///
  /// In en, this message translates to:
  /// **'Delete After Run'**
  String get deleteAfterRun;

  /// Delete after run description
  ///
  /// In en, this message translates to:
  /// **'Automatically delete task after one execution'**
  String get deleteAfterRunDesc;

  /// Create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Cron job created message
  ///
  /// In en, this message translates to:
  /// **'Cron job created'**
  String get cronJobCreated;

  /// Create failed message
  ///
  /// In en, this message translates to:
  /// **'Create failed: {error}'**
  String createFailedWithError(String error);

  /// Environments page title
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get pageEnvironments;

  /// Knowledge base nav item
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get navKnowledge;

  /// Knowledge base page title
  ///
  /// In en, this message translates to:
  /// **'Knowledge Base'**
  String get pageKnowledge;

  /// Knowledge stats section title
  ///
  /// In en, this message translates to:
  /// **'Knowledge Base Overview'**
  String get knowledgeOverview;

  /// Total entries stat label
  ///
  /// In en, this message translates to:
  /// **'Total Entries'**
  String get totalEntries;

  /// Health status healthy
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// Health status unhealthy
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get unhealthy;

  /// Search knowledge placeholder
  ///
  /// In en, this message translates to:
  /// **'Search knowledge entries...'**
  String get searchKnowledge;

  /// Add knowledge button
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get addKnowledge;

  /// Knowledge entries list title
  ///
  /// In en, this message translates to:
  /// **'Knowledge Entries'**
  String get knowledgeEntries;

  /// Empty knowledge list title
  ///
  /// In en, this message translates to:
  /// **'No knowledge entries yet'**
  String get noKnowledgeEntries;

  /// Empty knowledge list hint
  ///
  /// In en, this message translates to:
  /// **'Add knowledge entries to help your AI assistant remember important information, facts, and context.'**
  String get noKnowledgeHint;

  /// Knowledge entry added message
  ///
  /// In en, this message translates to:
  /// **'Knowledge entry added'**
  String get knowledgeEntryAdded;

  /// Knowledge entry deleted message
  ///
  /// In en, this message translates to:
  /// **'Knowledge entry deleted'**
  String get knowledgeEntryDeleted;

  /// Delete knowledge dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Entry'**
  String get deleteKnowledgeTitle;

  /// Delete knowledge confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this knowledge entry? This cannot be undone.'**
  String get deleteKnowledgeConfirm;

  /// Knowledge key input label
  ///
  /// In en, this message translates to:
  /// **'Key / Title'**
  String get knowledgeKeyLabel;

  /// Knowledge key input hint
  ///
  /// In en, this message translates to:
  /// **'e.g. user-preferences, project-guidelines'**
  String get knowledgeKeyHint;

  /// Knowledge content input label
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get knowledgeContentLabel;

  /// Knowledge content input hint
  ///
  /// In en, this message translates to:
  /// **'Enter the knowledge content...'**
  String get knowledgeContentHint;

  /// Knowledge category input label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get knowledgeCategoryLabel;

  /// All categories filter
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get knowledgeCategoryAll;

  /// Core category
  ///
  /// In en, this message translates to:
  /// **'Core'**
  String get knowledgeCategoryCore;

  /// Daily category
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get knowledgeCategoryDaily;

  /// Conversation category
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get knowledgeCategoryConversation;

  /// Copy message button tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyMessage;

  /// Edit user message button tooltip
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMessage;

  /// Copied confirmation
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Tooltip for expanding chat list panel
  ///
  /// In en, this message translates to:
  /// **'Expand history'**
  String get expandHistory;

  /// Tooltip for collapsing left sidebar
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// Tooltip for expanding left sidebar
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// Save edit button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveEdit;

  /// Cancel edit button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelEdit;

  /// Agents nav item
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get navAgents;

  /// Sub-agents page title
  ///
  /// In en, this message translates to:
  /// **'Sub-Agents'**
  String get pageAgents;

  /// Overview section title
  ///
  /// In en, this message translates to:
  /// **'Sub-Agent Overview'**
  String get agentOverview;

  /// Overview description
  ///
  /// In en, this message translates to:
  /// **'Configure delegate sub-agents for multi-agent workflows. The primary agent can delegate specialized tasks (research, coding, summarization) to these sub-agents.'**
  String get agentOverviewDesc;

  /// Agentic agents count label
  ///
  /// In en, this message translates to:
  /// **'Agentic'**
  String get agentAgenticCount;

  /// New agent button
  ///
  /// In en, this message translates to:
  /// **'New Agent'**
  String get agentNew;

  /// Edit agent dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Agent'**
  String get agentEdit;

  /// Empty state title
  ///
  /// In en, this message translates to:
  /// **'No sub-agents configured'**
  String get agentNoAgents;

  /// Empty state hint
  ///
  /// In en, this message translates to:
  /// **'Create a sub-agent to delegate specialized tasks like research, coding, or summarization to different AI models.'**
  String get agentNoAgentsHint;

  /// Agent name input label
  ///
  /// In en, this message translates to:
  /// **'Agent Name'**
  String get agentNameLabel;

  /// System prompt label
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get agentSystemPrompt;

  /// System prompt hint
  ///
  /// In en, this message translates to:
  /// **'e.g. You are a research assistant.'**
  String get agentSystemPromptHint;

  /// Max depth label
  ///
  /// In en, this message translates to:
  /// **'Max Depth'**
  String get agentMaxDepth;

  /// Max iterations label
  ///
  /// In en, this message translates to:
  /// **'Max Iterations'**
  String get agentMaxIterations;

  /// Agentic mode toggle
  ///
  /// In en, this message translates to:
  /// **'Agentic Mode'**
  String get agentAgenticMode;

  /// Agentic mode description
  ///
  /// In en, this message translates to:
  /// **'Enable multi-turn tool-call loop. The sub-agent can use tools iteratively to complete complex tasks.'**
  String get agentAgenticModeDesc;

  /// Allowed tools label
  ///
  /// In en, this message translates to:
  /// **'Allowed Tools'**
  String get agentAllowedTools;

  /// Agentic badge
  ///
  /// In en, this message translates to:
  /// **'Agentic'**
  String get agentAgentic;

  /// Optional field hint
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get agentOptional;

  /// Delete agent dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Agent'**
  String get agentDeleteTitle;

  /// Delete agent confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete agent \'\'{name}\'\'? This cannot be undone.'**
  String agentDeleteConfirm(String name);

  /// Agent deleted message
  ///
  /// In en, this message translates to:
  /// **'Agent \'\'{name}\'\' deleted'**
  String agentDeleted(String name);

  /// Agent created message
  ///
  /// In en, this message translates to:
  /// **'Agent \'\'{name}\'\' created'**
  String agentCreated(String name);

  /// Agent updated message
  ///
  /// In en, this message translates to:
  /// **'Agent \'\'{name}\'\' updated'**
  String agentUpdated(String name);

  /// Proxy nav item
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get navProxy;

  /// Proxy settings page title
  ///
  /// In en, this message translates to:
  /// **'Proxy Settings'**
  String get proxyPageTitle;

  /// Proxy config section title
  ///
  /// In en, this message translates to:
  /// **'Proxy Configuration'**
  String get proxyConfiguration;

  /// Proxy description
  ///
  /// In en, this message translates to:
  /// **'Route outbound HTTP/HTTPS traffic through a proxy server. Supports HTTP, HTTPS, SOCKS5, and SOCKS5H protocols.'**
  String get proxyDescription;

  /// All proxy field label
  ///
  /// In en, this message translates to:
  /// **'All Proxy (Fallback)'**
  String get proxyAllProxy;

  /// All proxy help text
  ///
  /// In en, this message translates to:
  /// **'Fallback proxy URL used for all schemes when specific proxy is not set.'**
  String get proxyAllProxyHelp;

  /// HTTP proxy field label
  ///
  /// In en, this message translates to:
  /// **'HTTP Proxy'**
  String get proxyHttpProxy;

  /// HTTP proxy help text
  ///
  /// In en, this message translates to:
  /// **'Proxy URL for HTTP requests. Overrides all_proxy for HTTP.'**
  String get proxyHttpProxyHelp;

  /// HTTPS proxy field label
  ///
  /// In en, this message translates to:
  /// **'HTTPS Proxy'**
  String get proxyHttpsProxy;

  /// HTTPS proxy help text
  ///
  /// In en, this message translates to:
  /// **'Proxy URL for HTTPS requests. Overrides all_proxy for HTTPS.'**
  String get proxyHttpsProxyHelp;

  /// No proxy field label
  ///
  /// In en, this message translates to:
  /// **'No Proxy (Bypass List)'**
  String get proxyNoProxy;

  /// No proxy help text
  ///
  /// In en, this message translates to:
  /// **'Comma-separated list of hosts/domains that should bypass the proxy.'**
  String get proxyNoProxyHelp;

  /// Proxy scope section title
  ///
  /// In en, this message translates to:
  /// **'Proxy Scope'**
  String get proxyScope;

  /// Proxy scope description
  ///
  /// In en, this message translates to:
  /// **'Choose which outbound traffic should be routed through the proxy.'**
  String get proxyScopeDescription;

  /// ZeroClaw scope label
  ///
  /// In en, this message translates to:
  /// **'All Traffic'**
  String get proxyScopeZeroclaw;

  /// ZeroClaw scope description
  ///
  /// In en, this message translates to:
  /// **'All ZeroClaw-managed HTTP traffic'**
  String get proxyScopeZeroclawDesc;

  /// Services scope label
  ///
  /// In en, this message translates to:
  /// **'Selected Services'**
  String get proxyScopeServices;

  /// Services scope description
  ///
  /// In en, this message translates to:
  /// **'Only explicitly listed services'**
  String get proxyScopeServicesDesc;

  /// Environment scope label
  ///
  /// In en, this message translates to:
  /// **'System Env'**
  String get proxyScopeEnvironment;

  /// Environment scope description
  ///
  /// In en, this message translates to:
  /// **'Set process env vars (HTTP_PROXY, etc.)'**
  String get proxyScopeEnvironmentDesc;

  /// Service selectors title
  ///
  /// In en, this message translates to:
  /// **'Service Selectors'**
  String get proxyServiceSelectors;

  /// Service selectors help
  ///
  /// In en, this message translates to:
  /// **'Choose which services should use the proxy. Use wildcards like provider.* to match all providers.'**
  String get proxyServiceSelectorsHelp;

  /// Model routes section title
  ///
  /// In en, this message translates to:
  /// **'Model Routes'**
  String get modelRoutes;

  /// Model routes description
  ///
  /// In en, this message translates to:
  /// **'Route tasks to different models based on hints. E.g., use a reasoning model for complex analysis and a fast model for simple queries.'**
  String get modelRoutesDesc;

  /// Add route button
  ///
  /// In en, this message translates to:
  /// **'Add Route'**
  String get addRoute;

  /// Edit route dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Route'**
  String get editRoute;

  /// Route hint label
  ///
  /// In en, this message translates to:
  /// **'Route Hint'**
  String get routeHint;

  /// Route hint placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g., reasoning, fast, code'**
  String get routeHintHint;

  /// Empty routes message
  ///
  /// In en, this message translates to:
  /// **'No model routes configured'**
  String get noModelRoutes;

  /// Empty routes hint
  ///
  /// In en, this message translates to:
  /// **'Routes let you use different models for different tasks. Sub-agents can reference routes by hint instead of configuring provider/model manually.'**
  String get noModelRoutesHint;

  /// Delete route dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Route'**
  String get deleteRouteTitle;

  /// Delete route confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this route? This cannot be undone.'**
  String get deleteRouteConfirm;

  /// Route deleted message
  ///
  /// In en, this message translates to:
  /// **'Route deleted'**
  String get routeDeleted;

  /// Route saved message
  ///
  /// In en, this message translates to:
  /// **'Route saved'**
  String get routeSaved;

  /// Embedding config section title
  ///
  /// In en, this message translates to:
  /// **'Embedding Configuration'**
  String get embeddingConfiguration;

  /// Embedding config description
  ///
  /// In en, this message translates to:
  /// **'Configure the embedding provider for semantic search. This improves knowledge base and memory recall accuracy, especially for non-English text.'**
  String get embeddingConfigDesc;

  /// Embedding dimensions label
  ///
  /// In en, this message translates to:
  /// **'Embedding Dimensions'**
  String get embeddingDimensions;

  /// Vector weight label
  ///
  /// In en, this message translates to:
  /// **'Vector Weight'**
  String get vectorWeight;

  /// Keyword weight label
  ///
  /// In en, this message translates to:
  /// **'Keyword Weight'**
  String get keywordWeight;

  /// Min relevance score label
  ///
  /// In en, this message translates to:
  /// **'Min Relevance Score'**
  String get minRelevanceScore;

  /// Embedding config saved message
  ///
  /// In en, this message translates to:
  /// **'Embedding configuration saved!'**
  String get embeddingSaved;

  /// No embedding provider option
  ///
  /// In en, this message translates to:
  /// **'None (keyword only)'**
  String get embeddingProviderNone;

  /// OpenAI embedding provider
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get embeddingProviderOpenai;

  /// Custom embedding provider
  ///
  /// In en, this message translates to:
  /// **'Custom (OpenAI Compatible)'**
  String get embeddingProviderCustom;

  /// Use default provider toggle
  ///
  /// In en, this message translates to:
  /// **'Use Default Provider'**
  String get agentUseDefault;

  /// Use default provider description
  ///
  /// In en, this message translates to:
  /// **'Use the default provider/model configured in the Models page instead of specifying individually.'**
  String get agentUseDefaultDesc;

  /// Cron success notification
  ///
  /// In en, this message translates to:
  /// **'✅ Cron [{name}] succeeded'**
  String cronNotifSuccess(String name);

  /// Cron failure notification
  ///
  /// In en, this message translates to:
  /// **'❌ Cron [{name}] failed'**
  String cronNotifFailed(String name);

  /// Cron duration info
  ///
  /// In en, this message translates to:
  /// **'Duration: {ms}ms'**
  String cronNotifDuration(String ms);

  /// Cron result injected notification
  ///
  /// In en, this message translates to:
  /// **'Result injected into current session'**
  String get cronNotifInjected;

  /// View output action
  ///
  /// In en, this message translates to:
  /// **'View Output'**
  String get viewOutput;

  /// Notification panel header title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationPanelTitle;

  /// Clear notifications button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearNotifications;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Empty notification list
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// Empty notification hint
  ///
  /// In en, this message translates to:
  /// **'Cron job execution results will appear here'**
  String get noNotificationsHint;

  /// Expand output button
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expandOutput;

  /// Attach file button tooltip
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// Add files menu item
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// Add folder menu item
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// Attached files count
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) attached'**
  String attachedFiles(int count);

  /// Clear all attached files
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// Drop zone title
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get dropFilesHere;

  /// Drop zone hint
  ///
  /// In en, this message translates to:
  /// **'Files and folders will be attached to the current session'**
  String get dropFilesHint;

  /// Button to open session workspace folder in system file manager
  ///
  /// In en, this message translates to:
  /// **'Open workspace folder'**
  String get openWorkspaceFolder;

  /// Session workspace files panel title
  ///
  /// In en, this message translates to:
  /// **'Workspace files'**
  String get workspaceFiles;

  /// Empty state when session workspace has no files
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get noWorkspaceFiles;

  /// Empty state hint
  ///
  /// In en, this message translates to:
  /// **'Files created by the agent will appear here'**
  String get noWorkspaceFilesHint;

  /// Open file button
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openFile;

  /// Save file as button
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveFileAs;

  /// File saved success message
  ///
  /// In en, this message translates to:
  /// **'File saved to {path}'**
  String fileSaved(String path);

  /// File save failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to save file'**
  String get fileSaveFailed;

  /// Refresh file list button
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshFiles;

  /// MCP servers management page title
  ///
  /// In en, this message translates to:
  /// **'MCP Servers'**
  String get pageMcpServers;

  /// MCP enabled toggle label
  ///
  /// In en, this message translates to:
  /// **'MCP Enabled'**
  String get mcpEnabled;

  /// MCP enabled description
  ///
  /// In en, this message translates to:
  /// **'Enable Model Context Protocol to connect external tool servers'**
  String get mcpEnabledDesc;

  /// Empty state for MCP servers
  ///
  /// In en, this message translates to:
  /// **'No MCP servers configured'**
  String get mcpNoServers;

  /// Empty state hint
  ///
  /// In en, this message translates to:
  /// **'Add an MCP server to extend your agent with external tools'**
  String get mcpNoServersHint;

  /// Add MCP server button
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get mcpAddServer;

  /// Edit MCP server dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Server'**
  String get mcpEditServer;

  /// Delete MCP server
  ///
  /// In en, this message translates to:
  /// **'Delete Server'**
  String get mcpDeleteServer;

  /// Delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete server \"{name}\"?'**
  String mcpDeleteConfirm(String name);

  /// Server name field
  ///
  /// In en, this message translates to:
  /// **'Server Name'**
  String get mcpServerName;

  /// Transport type field
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get mcpTransport;

  /// Command field for stdio transport
  ///
  /// In en, this message translates to:
  /// **'Command'**
  String get mcpCommand;

  /// Arguments field
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get mcpArgs;

  /// Arguments hint
  ///
  /// In en, this message translates to:
  /// **'One argument per line'**
  String get mcpArgsHint;

  /// URL field for HTTP/SSE transport
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get mcpUrl;

  /// Tool timeout field
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get mcpTimeout;

  /// Environment variables section
  ///
  /// In en, this message translates to:
  /// **'Environment Variables'**
  String get mcpEnvVars;

  /// HTTP headers section
  ///
  /// In en, this message translates to:
  /// **'HTTP Headers'**
  String get mcpHeaders;

  /// Add key-value pair
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get mcpAddKv;

  /// Key placeholder
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get mcpKeyPlaceholder;

  /// Value placeholder
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get mcpValuePlaceholder;

  /// Server added success
  ///
  /// In en, this message translates to:
  /// **'MCP server added successfully'**
  String get mcpServerAdded;

  /// Server updated success
  ///
  /// In en, this message translates to:
  /// **'MCP server updated successfully'**
  String get mcpServerUpdated;

  /// Server deleted success
  ///
  /// In en, this message translates to:
  /// **'MCP server deleted'**
  String get mcpServerDeleted;

  /// Stdio transport option
  ///
  /// In en, this message translates to:
  /// **'Standard I/O'**
  String get mcpTransportStdio;

  /// HTTP transport option
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get mcpTransportHttp;

  /// SSE transport option
  ///
  /// In en, this message translates to:
  /// **'Server-Sent Events'**
  String get mcpTransportSse;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
