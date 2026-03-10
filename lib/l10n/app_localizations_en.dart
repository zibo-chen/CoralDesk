// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CoralDesk';

  @override
  String get appTagline => 'From your desk, master the AI era';

  @override
  String get navSectionChat => 'Chat';

  @override
  String get navSectionControl => 'Control';

  @override
  String get navSectionAgent => 'Agent';

  @override
  String get navSectionSettings => 'Settings';

  @override
  String get navChat => 'Chat';

  @override
  String get navChannels => 'Channels';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navCronJobs => 'Cron Jobs';

  @override
  String get navWorkspace => 'Workspace';

  @override
  String get navSkills => 'Skills';

  @override
  String get navMcp => 'MCP';

  @override
  String get navConfiguration => 'Configuration';

  @override
  String get navModels => 'Models';

  @override
  String get navEnvironments => 'Environments';

  @override
  String get workWithCoralDesk => 'Work with CoralDesk';

  @override
  String get newChat => 'New Chat';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get startNewChat => 'Start a new chat';

  @override
  String get welcomeTitle => 'Hello, how can I help you today?';

  @override
  String get welcomeSubtitle =>
      'I am a helpful assistant that can help you with your questions.';

  @override
  String get suggestionWhatCanYouDo => 'What can you do?';

  @override
  String get suggestionWriteArticle => 'Help me write an article about AI.';

  @override
  String get suggestionExplainML =>
      'Explain the basics of machine learning in simple terms.';

  @override
  String get suggestionWriteEmail => 'Help me write a professional email.';

  @override
  String get suggestionImproveProductivity =>
      'How can I improve my productivity?';

  @override
  String get suggestionRecommendBooks => 'Recommend some books worth reading.';

  @override
  String get suggestionPlanTrip => 'Help me plan a short trip.';

  @override
  String get suggestionBrainstorm => 'Brainstorm some creative ideas.';

  @override
  String get thinking => '💭 Thinking...';

  @override
  String errorOccurred(String message) {
    return '⚠️ **Error:** $message\n\nPlease check your API key and provider settings.';
  }

  @override
  String errorGeneric(String message) {
    return '⚠️ **Error:** $message\n\nPlease check your settings and try again.';
  }

  @override
  String get chatTitle => 'Chat';

  @override
  String get processing => 'Processing...';

  @override
  String get typeYourMessage => 'Type your message...';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get pageChannels => 'Channels';

  @override
  String get pageConfiguration => 'Configuration';

  @override
  String get pageCronJobs => 'Cron Jobs';

  @override
  String get pageModels => 'Models';

  @override
  String get pageSessions => 'Sessions';

  @override
  String get pageSkills => 'Skills';

  @override
  String get pageTools => 'Tools & MCP';

  @override
  String get pageWorkspace => 'Workspace';

  @override
  String get languageLabel => 'Language';

  @override
  String get switchToEnglish => 'English';

  @override
  String get switchToChinese => '中文';

  @override
  String get tooltipCopy => 'Copy';

  @override
  String get tooltipRefresh => 'Refresh';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get toolCallSuccess => 'Success';

  @override
  String get toolCallFailed => 'Failed';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get featureComingSoon => 'This feature is coming soon.';

  @override
  String get environmentsDescription =>
      'Manage environment variables and deployment profiles.';

  @override
  String get providerConfiguration => 'Provider Configuration';

  @override
  String get providerLabel => 'Provider';

  @override
  String get modelLabel => 'Model';

  @override
  String get apiKeyLabel => 'API Key';

  @override
  String get apiKeyHint => 'Enter your API key...';

  @override
  String get apiBaseUrlLabel => 'API Base URL';

  @override
  String get temperatureLabel => 'Temperature';

  @override
  String get saving => 'Saving...';

  @override
  String get save => 'Save';

  @override
  String get configSaved => 'Configuration saved!';

  @override
  String get configSaveFailed => 'Failed to save config';

  @override
  String get runtimeStatus => 'Runtime Status';

  @override
  String get initialized => 'Initialized';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get configured => 'Configured';

  @override
  String get missing => 'Missing';

  @override
  String get activeProvider => 'Active Provider';

  @override
  String get activeModel => 'Active Model';

  @override
  String get modelNameHint => 'Enter model name or select from list...';

  @override
  String get showSuggestions => 'Show suggestions';

  @override
  String get workspaceInfo => 'Workspace Info';

  @override
  String get workspaceDirectory => 'Workspace Directory';

  @override
  String get configFile => 'Config File';

  @override
  String get agentSettings => 'Agent Settings';

  @override
  String get maxToolIterations => 'Max Tool Iterations';

  @override
  String get maxHistoryMessages => 'Max History Messages';

  @override
  String get parallelToolExecution => 'Parallel Tool Execution';

  @override
  String get compactContext => 'Compact Context';

  @override
  String get toolDispatcher => 'Tool Dispatcher';

  @override
  String get memorySection => 'Memory';

  @override
  String get backend => 'Backend';

  @override
  String get autoSave => 'Auto Save';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get hygiene => 'Hygiene';

  @override
  String get archiveAfter => 'Archive After';

  @override
  String get days => 'days';

  @override
  String get purgeAfter => 'Purge After';

  @override
  String get embeddingProvider => 'Embedding Provider';

  @override
  String get embeddingModel => 'Embedding Model';

  @override
  String get costTracking => 'Cost Tracking';

  @override
  String get dailyLimit => 'Daily Limit';

  @override
  String get monthlyLimit => 'Monthly Limit';

  @override
  String get warnAt => 'Warn At';

  @override
  String get autonomySecurity => 'Autonomy & Security';

  @override
  String get autonomyLevel => 'Autonomy Level';

  @override
  String get readOnly => 'Read Only';

  @override
  String get supervised => 'Supervised';

  @override
  String get fullAutonomy => 'Full';

  @override
  String get trustMeMode => 'Trust Me Mode';

  @override
  String get trustMeDescription =>
      'Auto-approve all tool calls without confirmation. Use with caution.';

  @override
  String get toolApprovalTitle => 'Tool Approval Required';

  @override
  String toolApprovalBody(String toolName) {
    return 'The agent wants to execute tool: $toolName';
  }

  @override
  String get approve => 'Approve';

  @override
  String get deny => 'Deny';

  @override
  String get workspaceOnly => 'Workspace Only';

  @override
  String get requireApprovalMediumRisk => 'Require Approval (Medium Risk)';

  @override
  String get blockHighRisk => 'Block High Risk';

  @override
  String get maxActionsPerHour => 'Max Actions/Hour';

  @override
  String get maxCostPerDay => 'Max Cost/Day';

  @override
  String get allowedCommands => 'Allowed Commands';

  @override
  String get addCommand => 'Add Command';

  @override
  String get commandNameHint => 'Enter command name (e.g., open)';

  @override
  String get noCommandsConfigured => 'No commands configured';

  @override
  String get autoApprovedTools => 'Auto-Approved Tools';

  @override
  String get toolsSection => 'Tools';

  @override
  String toolCountLabel(int count) {
    return '$count tools';
  }

  @override
  String get categoryCoreTools => 'Core Tools';

  @override
  String get categoryVersionControl => 'Version Control';

  @override
  String get categoryWebNetwork => 'Web & Network';

  @override
  String get categoryMemory => 'Memory';

  @override
  String get categorySystem => 'System';

  @override
  String get categoryFileProcessing => 'File Processing';

  @override
  String get categoryAgent => 'Agent';

  @override
  String get categoryScheduling => 'Scheduling';

  @override
  String get approvalAuto => 'Auto';

  @override
  String get approvalAsk => 'Ask';

  @override
  String get deleteSessionTitle => 'Delete Session';

  @override
  String get deleteSessionConfirm =>
      'Are you sure you want to delete this session? This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get back => 'Back';

  @override
  String get edit => 'Edit';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get renameSessionTitle => 'Rename Session';

  @override
  String get sessionTitleLabel => 'Session Title';

  @override
  String get confirm => 'Confirm';

  @override
  String get sessionRenamed => 'Renamed';

  @override
  String get clearAllSessionsTitle => 'Clear All Sessions';

  @override
  String get clearAllSessionsConfirm =>
      'Are you sure you want to delete all saved sessions? This action cannot be undone.';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get allSessionsCleared => 'All sessions cleared';

  @override
  String get sessionCount => 'Sessions';

  @override
  String get messageCount => 'Messages';

  @override
  String get refresh => 'Refresh';

  @override
  String get clearAllSessions => 'Clear All Sessions';

  @override
  String get noSavedSessions => 'No saved sessions';

  @override
  String get sessionsAutoSaveHint =>
      'Sessions will be automatically saved here after you send messages in chat';

  @override
  String get searchSessions => 'Search sessions...';

  @override
  String messageCountWithUnit(int count) {
    return '$count messages';
  }

  @override
  String get rename => 'Rename';

  @override
  String get selectSessionToView => 'Select a session to view details';

  @override
  String messagesCreatedAt(int count) {
    return '$count messages · Created at';
  }

  @override
  String get roleYou => 'You';

  @override
  String get roleAI => 'AI';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hr ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get featureToggles => 'Feature Toggles';

  @override
  String get featureTogglesDesc =>
      'Quickly enable or disable Agent feature modules, select to use directly';

  @override
  String get featureWebSearch => 'Web Search';

  @override
  String get featureWebSearchDesc =>
      'Search the internet for latest information';

  @override
  String get featureWebFetch => 'Web Fetch';

  @override
  String get featureWebFetchDesc => 'Fetch web page content and extract text';

  @override
  String get featureBrowser => 'Browser Automation';

  @override
  String get featureBrowserDesc =>
      'Automate browser operations and interactions';

  @override
  String get featureHttpRequest => 'HTTP Request';

  @override
  String get featureHttpRequestDesc =>
      'Send API requests (GET/POST/PUT/DELETE)';

  @override
  String get featureMemory => 'Auto Memory';

  @override
  String get featureMemoryDesc =>
      'Automatically save important information from conversations';

  @override
  String get featureCostTracking => 'Cost Tracking';

  @override
  String get featureCostTrackingDesc => 'Track API call costs and set limits';

  @override
  String get featureSkillsOpen => 'Community Skills';

  @override
  String get featureSkillsOpenDesc =>
      'Enable open-source community skill extensions';

  @override
  String get featureEnabled => 'Enabled';

  @override
  String get featureDisabled => 'Disabled';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get builtInTools => 'Built-in Tools';

  @override
  String get toolApprovalHint =>
      'Click approval status label to quickly toggle tool permission';

  @override
  String get autoApproval => 'Auto Approval';

  @override
  String get requireConfirmation => 'Require Confirmation';

  @override
  String get defaultApproval => 'Default';

  @override
  String get categoryCore => 'Core Tools';

  @override
  String get categoryVcs => 'Version Control';

  @override
  String get categoryWeb => 'Web & Network';

  @override
  String get categoryMemoryTools => 'Memory & Storage';

  @override
  String get categoryCron => 'Scheduling';

  @override
  String get categoryFile => 'File Processing';

  @override
  String get categoryAgentTools => 'Agent Delegation';

  @override
  String channelConfigSaved(String name) {
    return '$name configuration saved';
  }

  @override
  String saveFailedWithError(String error) {
    return 'Save failed: $error';
  }

  @override
  String disableChannelTitle(String name) {
    return 'Disable $name';
  }

  @override
  String get disableChannelConfirm =>
      'Are you sure you want to disable this channel? Configuration will be cleared.';

  @override
  String get disable => 'Disable';

  @override
  String channelDisabled(String name) {
    return '$name disabled';
  }

  @override
  String operationFailedWithError(String error) {
    return 'Operation failed: $error';
  }

  @override
  String activeCount(int count) {
    return '$count active';
  }

  @override
  String get noChannelsAvailable => 'No channels available';

  @override
  String get activeChannels => 'Active Channels';

  @override
  String get availableChannels => 'Available Channels';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String configureChannel(String name) {
    return 'Configure $name';
  }

  @override
  String disableChannel(String name) {
    return 'Disable $name';
  }

  @override
  String get skillsConfig => 'Skills Configuration';

  @override
  String get localSkills => 'Local Skills';

  @override
  String get communitySkills => 'Community Skills';

  @override
  String get openSourceSkills => 'Community Open-Source Skills';

  @override
  String get openSourceSkillsDesc =>
      'Auto-sync community skills from GitHub when enabled';

  @override
  String get promptInjectionMode => 'Prompt Injection Mode';

  @override
  String get fullMode => 'Full Mode';

  @override
  String get fullModeDesc =>
      'Inject complete skill instructions and tool info into system prompt';

  @override
  String get compactMode => 'Compact Mode';

  @override
  String get compactModeDesc =>
      'Inject skill summary only, load details on demand';

  @override
  String get noSkillsAvailable => 'No skills available';

  @override
  String get noSkillsHint =>
      'Create SKILL.toml or SKILL.md files in the workspace\'s skills/ directory to add custom skills, or enable community open-source skills for more capabilities.';

  @override
  String get quickStartSkill => 'Quick Start: Create SKILL.toml';

  @override
  String get sourceLocal => 'Local';

  @override
  String get sourceCommunity => 'Community';

  @override
  String get includedTools => 'Included Tools';

  @override
  String get prompts => 'Prompts';

  @override
  String promptsWithCount(int count) {
    return 'Prompts ($count)';
  }

  @override
  String communitySkillsToggled(String status) {
    return 'Community skills $status';
  }

  @override
  String injectionModeUpdated(String mode) {
    return 'Injection mode updated to $mode';
  }

  @override
  String get installSkill => 'Install Skill';

  @override
  String get installSkillHint => 'Enter Git URL or local path';

  @override
  String get installSkillPlaceholder =>
      'https://github.com/user/skill-repo or /path/to/skill';

  @override
  String get installing => 'Installing...';

  @override
  String skillInstalled(String name) {
    return 'Skill \'$name\' installed successfully';
  }

  @override
  String installFailed(String error) {
    return 'Install failed: $error';
  }

  @override
  String get removeSkill => 'Remove';

  @override
  String get removeSkillTitle => 'Remove Skill';

  @override
  String removeSkillConfirm(String name) {
    return 'Are you sure you want to remove skill \'$name\'? This cannot be undone.';
  }

  @override
  String skillRemoved(String name) {
    return 'Skill \'$name\' removed';
  }

  @override
  String removeFailed(String error) {
    return 'Remove failed: $error';
  }

  @override
  String get gitUrlExample => 'e.g. https://github.com/user/my-skill';

  @override
  String get supportedSources =>
      'Supports Git URL (https/ssh) or local directory path';

  @override
  String get deleteCronJobTitle => 'Delete Cron Job';

  @override
  String get deleteCronJobConfirm =>
      'Are you sure you want to delete this cron job? This action cannot be undone.';

  @override
  String get deleted => 'Deleted';

  @override
  String deleteFailedWithError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get cronJobEnabled => 'Enabled';

  @override
  String get cronJobPaused => 'Paused';

  @override
  String get executionSuccess => 'Execution succeeded';

  @override
  String executionFailedWithError(String error) {
    return 'Execution failed: $error';
  }

  @override
  String executionErrorWithError(String error) {
    return 'Execution error: $error';
  }

  @override
  String get totalCount => 'Total';

  @override
  String get running => 'Running';

  @override
  String get paused => 'Paused';

  @override
  String get newTask => 'New Task';

  @override
  String get noCronJobs => 'No cron jobs';

  @override
  String get noCronJobsHint =>
      'Click \"New Task\" above to create Shell or AI Agent scheduled tasks';

  @override
  String get mainSession => 'Main Session';

  @override
  String get runNow => 'Run Now';

  @override
  String get collapseHistory => 'Collapse history';

  @override
  String get runHistory => 'Run History';

  @override
  String get nextExecution => 'Next execution:';

  @override
  String get lastRun => 'Last:';

  @override
  String get oneTime => 'One-time';

  @override
  String get noRunHistory => 'No run history';

  @override
  String runHistoryRecent(int count) {
    return 'Run History (recent $count)';
  }

  @override
  String get newCronJob => 'New Cron Job';

  @override
  String get taskNameOptional => 'Task Name (optional)';

  @override
  String get taskType => 'Task Type';

  @override
  String get shellCommand => 'Shell Command';

  @override
  String get aiAgent => 'AI Agent';

  @override
  String get scheduleType => 'Schedule Type';

  @override
  String get interval => 'Interval';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get cronExpression => 'Cron Expression';

  @override
  String get intervalMs => 'Interval (milliseconds)';

  @override
  String get executionTime => 'Execution Time (RFC3339)';

  @override
  String get shellCommandLabel => 'Shell Command';

  @override
  String get aiPromptLabel => 'AI Prompt';

  @override
  String get modelOptional => 'Model (optional)';

  @override
  String get useDefaultModel => 'Leave empty to use default model';

  @override
  String get sessionTarget => 'Session Target';

  @override
  String get isolated => 'Isolated';

  @override
  String get deleteAfterRun => 'Delete After Run';

  @override
  String get deleteAfterRunDesc =>
      'Automatically delete task after one execution';

  @override
  String get create => 'Create';

  @override
  String get cronJobCreated => 'Cron job created';

  @override
  String createFailedWithError(String error) {
    return 'Create failed: $error';
  }

  @override
  String get pageEnvironments => 'Environments';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get pageKnowledge => 'Knowledge Base';

  @override
  String get knowledgeOverview => 'Knowledge Base Overview';

  @override
  String get totalEntries => 'Total Entries';

  @override
  String get healthy => 'Healthy';

  @override
  String get unhealthy => 'Unhealthy';

  @override
  String get searchKnowledge => 'Search knowledge entries...';

  @override
  String get addKnowledge => 'Add Entry';

  @override
  String get knowledgeEntries => 'Knowledge Entries';

  @override
  String get noKnowledgeEntries => 'No knowledge entries yet';

  @override
  String get noKnowledgeHint =>
      'Add knowledge entries to help your AI assistant remember important information, facts, and context.';

  @override
  String get knowledgeEntryAdded => 'Knowledge entry added';

  @override
  String get knowledgeEntryDeleted => 'Knowledge entry deleted';

  @override
  String get deleteKnowledgeTitle => 'Delete Entry';

  @override
  String get deleteKnowledgeConfirm =>
      'Are you sure you want to delete this knowledge entry? This cannot be undone.';

  @override
  String get knowledgeKeyLabel => 'Key / Title';

  @override
  String get knowledgeKeyHint => 'e.g. user-preferences, project-guidelines';

  @override
  String get knowledgeContentLabel => 'Content';

  @override
  String get knowledgeContentHint => 'Enter the knowledge content...';

  @override
  String get knowledgeCategoryLabel => 'Category';

  @override
  String get knowledgeCategoryAll => 'All Categories';

  @override
  String get knowledgeCategoryCore => 'Core';

  @override
  String get knowledgeCategoryDaily => 'Daily';

  @override
  String get knowledgeCategoryConversation => 'Conversation';

  @override
  String get copyMessage => 'Copy';

  @override
  String get editMessage => 'Edit';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get expandHistory => 'Expand history';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get saveEdit => 'Save';

  @override
  String get cancelEdit => 'Cancel';

  @override
  String get navAgents => 'Roles & Agents';

  @override
  String get navAgentWorkspaces => 'Role Workspaces';

  @override
  String get pageAgents => 'Roles & Sub-Agents';

  @override
  String get agentOverview => 'Overview';

  @override
  String get agentOverviewDesc =>
      'Manage team roles and custom sub-agents. Built-in roles delegate tasks and share context; custom sub-agents handle specialized tasks independently.';

  @override
  String get agentAgenticCount => 'Agentic';

  @override
  String get agentNew => 'New Agent';

  @override
  String get agentEdit => 'Edit Agent';

  @override
  String get agentNoAgents => 'No custom sub-agents configured';

  @override
  String get agentNoAgentsHint =>
      'Create a custom sub-agent for specialized tasks like research, coding, or summarization. Built-in roles are already configured.';

  @override
  String get agentNameLabel => 'Name';

  @override
  String get agentSystemPrompt => 'System Prompt';

  @override
  String get agentSystemPromptHint => 'e.g. You are a research assistant.';

  @override
  String get agentMaxDepth => 'Max Depth';

  @override
  String get agentMaxIterations => 'Max Iterations';

  @override
  String get agentAgenticMode => 'Agentic Mode';

  @override
  String get agentAgenticModeDesc =>
      'Enable multi-turn tool-call loop for iterative tool use on complex tasks.';

  @override
  String get agentAllowedTools => 'Allowed Tools';

  @override
  String get agentAgentic => 'Agentic';

  @override
  String get agentOptional => 'optional';

  @override
  String get agentDeleteTitle => 'Delete Agent';

  @override
  String agentDeleteConfirm(String name) {
    return 'Are you sure you want to delete agent \'\'$name\'\'? This cannot be undone.';
  }

  @override
  String agentDeleted(String name) {
    return 'Agent \'\'$name\'\' deleted';
  }

  @override
  String agentCreated(String name) {
    return 'Agent \'\'$name\'\' created';
  }

  @override
  String agentUpdated(String name) {
    return 'Agent \'\'$name\'\' updated';
  }

  @override
  String get rolesSectionTitle => 'Team Roles';

  @override
  String get rolesSectionDesc =>
      'Built-in roles delegate tasks to specialized sub-agents, each with their own workspace, tools, and skills. Roles activate automatically in team mode.';

  @override
  String get subAgentsSectionTitle => 'Custom Sub-Agents';

  @override
  String get subAgentsSectionDesc =>
      'Custom sub-agents handle specialized tasks independently, such as research or summarization.';

  @override
  String get navProxy => 'Proxy';

  @override
  String get proxyPageTitle => 'Proxy Settings';

  @override
  String get proxyConfiguration => 'Proxy Configuration';

  @override
  String get proxyDescription =>
      'Route outbound HTTP/HTTPS traffic through a proxy server. Supports HTTP, HTTPS, SOCKS5, and SOCKS5H protocols.';

  @override
  String get proxyAllProxy => 'All Proxy (Fallback)';

  @override
  String get proxyAllProxyHelp =>
      'Fallback proxy URL used for all schemes when specific proxy is not set.';

  @override
  String get proxyHttpProxy => 'HTTP Proxy';

  @override
  String get proxyHttpProxyHelp =>
      'Proxy URL for HTTP requests. Overrides all_proxy for HTTP.';

  @override
  String get proxyHttpsProxy => 'HTTPS Proxy';

  @override
  String get proxyHttpsProxyHelp =>
      'Proxy URL for HTTPS requests. Overrides all_proxy for HTTPS.';

  @override
  String get proxyNoProxy => 'No Proxy (Bypass List)';

  @override
  String get proxyNoProxyHelp =>
      'Comma-separated list of hosts/domains that should bypass the proxy.';

  @override
  String get proxyScope => 'Proxy Scope';

  @override
  String get proxyScopeDescription =>
      'Choose which outbound traffic should be routed through the proxy.';

  @override
  String get proxyScopeZeroclaw => 'All Traffic';

  @override
  String get proxyScopeZeroclawDesc => 'All CoralDesk-managed HTTP traffic';

  @override
  String get proxyScopeServices => 'Selected Services';

  @override
  String get proxyScopeServicesDesc => 'Only explicitly listed services';

  @override
  String get proxyScopeEnvironment => 'System Env';

  @override
  String get proxyScopeEnvironmentDesc =>
      'Set process env vars (HTTP_PROXY, etc.)';

  @override
  String get proxyServiceSelectors => 'Service Selectors';

  @override
  String get proxyServiceSelectorsHelp =>
      'Choose which services should use the proxy. Use wildcards like provider.* to match all providers.';

  @override
  String get modelRoutes => 'Model Routes';

  @override
  String get modelRoutesDesc =>
      'Route tasks to different models based on hints. E.g., use a reasoning model for complex analysis and a fast model for simple queries.';

  @override
  String get addRoute => 'Add Route';

  @override
  String get editRoute => 'Edit Route';

  @override
  String get routeHint => 'Route Hint';

  @override
  String get routeHintHint => 'e.g., reasoning, fast, code';

  @override
  String get noModelRoutes => 'No model routes configured';

  @override
  String get noModelRoutesHint =>
      'Routes let you use different models for different tasks. Sub-agents can reference routes by hint instead of configuring provider/model manually.';

  @override
  String get deleteRouteTitle => 'Delete Route';

  @override
  String get deleteRouteConfirm =>
      'Are you sure you want to delete this route? This cannot be undone.';

  @override
  String get routeDeleted => 'Route deleted';

  @override
  String get routeSaved => 'Route saved';

  @override
  String get embeddingConfiguration => 'Embedding Configuration';

  @override
  String get embeddingConfigDesc =>
      'Configure the embedding provider for semantic search. This improves knowledge base and memory recall accuracy, especially for non-English text.';

  @override
  String get embeddingDimensions => 'Embedding Dimensions';

  @override
  String get vectorWeight => 'Vector Weight';

  @override
  String get keywordWeight => 'Keyword Weight';

  @override
  String get minRelevanceScore => 'Min Relevance Score';

  @override
  String get embeddingSaved => 'Embedding configuration saved!';

  @override
  String get embeddingProviderNone => 'None (keyword only)';

  @override
  String get embeddingProviderOpenai => 'OpenAI';

  @override
  String get embeddingProviderCustom => 'Custom (OpenAI Compatible)';

  @override
  String get agentUseDefault => 'Use Default Provider';

  @override
  String get agentUseDefaultDesc =>
      'Use the default provider/model configured in the Models page instead of specifying individually.';

  @override
  String cronNotifSuccess(String name) {
    return '✅ Cron [$name] succeeded';
  }

  @override
  String cronNotifFailed(String name) {
    return '❌ Cron [$name] failed';
  }

  @override
  String cronNotifDuration(String ms) {
    return 'Duration: ${ms}ms';
  }

  @override
  String get cronNotifInjected => 'Result injected into current session';

  @override
  String get viewOutput => 'View Output';

  @override
  String get notificationPanelTitle => 'Notifications';

  @override
  String get clearNotifications => 'Clear All';

  @override
  String get close => 'Close';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsHint =>
      'Cron job execution results will appear here';

  @override
  String get expandOutput => 'Expand';

  @override
  String get attachFile => 'Attach file';

  @override
  String get addFiles => 'Add files';

  @override
  String get addFolder => 'Add folder';

  @override
  String attachedFiles(int count) {
    return '$count file(s) attached';
  }

  @override
  String get clearAll => 'Clear all';

  @override
  String get dropFilesHere => 'Drop files here';

  @override
  String get dropFilesHint =>
      'Files and folders will be attached to the current session';

  @override
  String get openWorkspaceFolder => 'Open workspace folder';

  @override
  String get workspaceFiles => 'Workspace files';

  @override
  String get noWorkspaceFiles => 'No files yet';

  @override
  String get noWorkspaceFilesHint =>
      'Files created by the agent will appear here';

  @override
  String get openFile => 'Open';

  @override
  String get saveFileAs => 'Save as…';

  @override
  String fileSaved(String path) {
    return 'File saved to $path';
  }

  @override
  String get fileSaveFailed => 'Failed to save file';

  @override
  String get refreshFiles => 'Refresh';

  @override
  String get pageMcpServers => 'MCP Servers';

  @override
  String get mcpEnabled => 'MCP Enabled';

  @override
  String get mcpEnabledDesc =>
      'Enable Model Context Protocol to connect external tool servers';

  @override
  String get mcpNoServers => 'No MCP servers configured';

  @override
  String get mcpNoServersHint =>
      'Add an MCP server to extend your agent with external tools';

  @override
  String get mcpAddServer => 'Add Server';

  @override
  String get mcpEditServer => 'Edit Server';

  @override
  String get mcpDeleteServer => 'Delete Server';

  @override
  String mcpDeleteConfirm(String name) {
    return 'Are you sure you want to delete server \"$name\"?';
  }

  @override
  String get mcpServerName => 'Server Name';

  @override
  String get mcpTransport => 'Transport';

  @override
  String get mcpCommand => 'Command';

  @override
  String get mcpArgs => 'Arguments';

  @override
  String get mcpArgsHint => 'One argument per line';

  @override
  String get mcpUrl => 'URL';

  @override
  String get mcpTimeout => 'Timeout (seconds)';

  @override
  String get mcpEnvVars => 'Environment Variables';

  @override
  String get mcpHeaders => 'HTTP Headers';

  @override
  String get mcpAddKv => 'Add';

  @override
  String get mcpKeyPlaceholder => 'Key';

  @override
  String get mcpValuePlaceholder => 'Value';

  @override
  String get mcpServerAdded => 'MCP server added successfully';

  @override
  String get mcpServerUpdated => 'MCP server updated successfully';

  @override
  String get mcpServerDeleted => 'MCP server deleted';

  @override
  String get mcpTransportStdio => 'Standard I/O';

  @override
  String get mcpTransportHttp => 'HTTP';

  @override
  String get mcpTransportSse => 'Server-Sent Events';

  @override
  String get mcpTestConnection => 'Test Connection';

  @override
  String get mcpTesting => 'Testing…';

  @override
  String get mcpConnected => 'Connected';

  @override
  String get mcpDisconnected => 'Disconnected';

  @override
  String get mcpConnectionError => 'Connection Error';

  @override
  String get mcpNotTested => 'Not Tested';

  @override
  String mcpToolCount(int count) {
    return '$count tool(s)';
  }

  @override
  String get mcpTools => 'Tools';

  @override
  String get mcpNoToolsFound => 'No tools discovered';

  @override
  String mcpStatusSummary(int toolCount, int serverCount) {
    return '$toolCount tools from $serverCount servers';
  }

  @override
  String mcpTestSuccess(int count, int elapsed) {
    return 'Connection successful — $count tool(s) found in ${elapsed}ms';
  }

  @override
  String mcpTestFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get mcpTestAll => 'Test All';

  @override
  String get mcpShowTools => 'Show Tools';

  @override
  String get mcpHideTools => 'Hide Tools';

  @override
  String get mcpDisabledHint =>
      'Enable MCP to connect to external tool servers and extend your agent\'s capabilities.';

  @override
  String get mcpOverviewTitle => 'Overview';

  @override
  String get retryMessage => 'Retry';

  @override
  String get stopGenerating => 'Stop generating';

  @override
  String get providerProfiles => 'Provider Profiles';

  @override
  String get providerProfile => 'Provider Profile';

  @override
  String get providerProfileSelectHint =>
      'Select a profile or configure manually';

  @override
  String get providerProfileManual => 'Manual configuration';

  @override
  String get providerProfilesDesc =>
      'Configure multiple provider profiles. Each profile can have its own API key, base URL, and default model. Use them in model routes or select in chat.';

  @override
  String get providerProfileNew => 'New Profile';

  @override
  String get providerProfileEdit => 'Edit Profile';

  @override
  String get providerProfileId => 'Profile ID';

  @override
  String get providerProfileIdHint => 'e.g. my-openai, local-ollama';

  @override
  String get providerProfileName => 'Provider Name';

  @override
  String get providerProfileNameHint => 'e.g. openai, anthropic, ollama';

  @override
  String get providerProfileBaseUrl => 'Base URL';

  @override
  String get providerProfileBaseUrlHint => 'e.g. https://api.openai.com/v1';

  @override
  String get providerProfileWireApi => 'Wire API Protocol';

  @override
  String get providerProfileModel => 'Default Model';

  @override
  String get providerProfileModelHint => 'e.g. gpt-4o, claude-sonnet-4-6';

  @override
  String providerProfileDeleted(String id) {
    return 'Profile \'\'$id\'\' deleted';
  }

  @override
  String get providerProfileSaved => 'Profile saved';

  @override
  String get providerProfileDeleteTitle => 'Delete Profile';

  @override
  String providerProfileDeleteConfirm(String id) {
    return 'Are you sure you want to delete profile \'\'$id\'\'?';
  }

  @override
  String get noProviderProfiles => 'No provider profiles configured';

  @override
  String get noProviderProfilesHint =>
      'Add profiles to use multiple providers with different API keys or endpoints.';

  @override
  String get chatModelSelector => 'Switch Model';

  @override
  String chatCurrentModel(String provider, String model) {
    return 'Current: $provider / $model';
  }

  @override
  String get embeddingBaseUrl => 'Embedding Base URL';

  @override
  String get embeddingBaseUrlHint => 'e.g. https://api.openai.com';

  @override
  String get embeddingApiKey => 'Embedding API Key';

  @override
  String get embeddingApiKeyHint => 'API key for embedding provider';

  @override
  String get agentCapabilities => 'Capabilities';

  @override
  String get agentCapabilitiesHint => 'research, coding, summarize';

  @override
  String get agentPriority => 'Priority';

  @override
  String get agentEnabled => 'Enabled';

  @override
  String get agentEnabledDesc =>
      'Whether this agent is active for selection and invocation.';

  @override
  String get wireApiChatCompletions => 'Chat Completions';

  @override
  String get wireApiResponses => 'Responses';

  @override
  String get wireApiAuto => 'Auto';

  @override
  String get defaultLabel => 'Default';

  @override
  String get setAsDefault => 'Set as Default';

  @override
  String providerProfileSetDefault(String id) {
    return 'Profile \'\'$id\'\' set as default';
  }

  @override
  String get trayShow => 'Show CoralDesk';

  @override
  String get trayHide => 'Hide CoralDesk';

  @override
  String get trayQuit => 'Quit CoralDesk';

  @override
  String get trayTooltip => 'CoralDesk – Running in background';

  @override
  String get proxyServiceCategoryProvider => 'AI Providers';

  @override
  String get proxyServiceCategoryChannel => 'Channels';

  @override
  String get proxyServiceCategoryTool => 'Tools';

  @override
  String get proxyServiceCategoryMemory => 'Memory';

  @override
  String get proxyServiceCategoryTunnel => 'Tunnel';

  @override
  String get proxyServiceCategoryTranscription => 'Transcription';

  @override
  String get proxyServiceProviderAnthropic => 'Anthropic (Claude)';

  @override
  String get proxyServiceProviderCompatible => 'OpenAI Compatible';

  @override
  String get proxyServiceProviderCopilot => 'GitHub Copilot';

  @override
  String get proxyServiceProviderGemini => 'Google Gemini';

  @override
  String get proxyServiceProviderGlm => 'GLM (Zhipu)';

  @override
  String get proxyServiceProviderOllama => 'Ollama (Local)';

  @override
  String get proxyServiceProviderOpenai => 'OpenAI';

  @override
  String get proxyServiceProviderOpenrouter => 'OpenRouter';

  @override
  String get proxyServiceChannelBluebubbles => 'BlueBubbles';

  @override
  String get proxyServiceChannelDingtalk => 'DingTalk';

  @override
  String get proxyServiceChannelDiscord => 'Discord';

  @override
  String get proxyServiceChannelFeishu => 'Feishu';

  @override
  String get proxyServiceChannelGithub => 'GitHub';

  @override
  String get proxyServiceChannelLark => 'Lark';

  @override
  String get proxyServiceChannelMatrix => 'Matrix';

  @override
  String get proxyServiceChannelMattermost => 'Mattermost';

  @override
  String get proxyServiceChannelNextcloudTalk => 'Nextcloud Talk';

  @override
  String get proxyServiceChannelNapcat => 'NapCat (QQ)';

  @override
  String get proxyServiceChannelQq => 'QQ';

  @override
  String get proxyServiceChannelSignal => 'Signal';

  @override
  String get proxyServiceChannelSlack => 'Slack';

  @override
  String get proxyServiceChannelTelegram => 'Telegram';

  @override
  String get proxyServiceChannelWati => 'WATI (WhatsApp)';

  @override
  String get proxyServiceChannelWhatsapp => 'WhatsApp';

  @override
  String get proxyServiceToolBrowser => 'Browser Automation';

  @override
  String get proxyServiceToolComposio => 'Composio';

  @override
  String get proxyServiceToolHttpRequest => 'HTTP Request';

  @override
  String get proxyServiceToolMultimodal => 'Multimodal';

  @override
  String get proxyServiceToolPushover => 'Pushover';

  @override
  String get proxyServiceMemoryEmbeddings => 'Embeddings';

  @override
  String get proxyServiceTunnelCustom => 'Custom Tunnel';

  @override
  String get proxyServiceTranscriptionGroq => 'Groq Transcription';

  @override
  String get proxyServiceWildcardProvider => 'All Providers';

  @override
  String get proxyServiceWildcardChannel => 'All Channels';

  @override
  String get proxyServiceWildcardTool => 'All Tools';

  @override
  String get proxyServiceWildcardMemory => 'All Memory';

  @override
  String get proxyServiceWildcardTunnel => 'All Tunnels';

  @override
  String get proxyServiceWildcardTranscription => 'All Transcription';

  @override
  String get proxyResetButton => 'Reset';

  @override
  String get proxyResetConfirmTitle => 'Reset Proxy Settings?';

  @override
  String get proxyResetConfirmBody =>
      'This will clear all proxy settings and disable the proxy. Are you sure?';

  @override
  String get proxyResetSuccess => 'Proxy settings have been reset';

  @override
  String get agentWorkspaces => 'Agent Workspaces';

  @override
  String get agentWorkspaceOverview => 'Agent Workspace Overview';

  @override
  String get agentWorkspaceOverviewDesc =>
      'Configure independent agent workspaces. Each workspace has its own personality (SOUL.md), behavior rules (AGENTS.md), and identity. Sessions can be bound to a specific agent for personalized interactions.';

  @override
  String get agentWorkspaceNew => 'New Workspace';

  @override
  String get agentWorkspaceEdit => 'Edit Workspace';

  @override
  String get agentWorkspaceNoWorkspaces => 'No agent workspaces configured';

  @override
  String get agentWorkspaceNoWorkspacesHint =>
      'Create an agent workspace to give your AI assistant a unique personality, style, and behavior for different tasks.';

  @override
  String get agentWorkspaceNameLabel => 'Name';

  @override
  String get agentWorkspaceNameHint => 'e.g. Product Manager';

  @override
  String get agentWorkspaceDescLabel => 'Description';

  @override
  String get agentWorkspaceDescHint =>
      'Brief description of this agent\'s role';

  @override
  String get agentWorkspaceAvatarLabel => 'Avatar Emoji';

  @override
  String get agentWorkspaceColorLabel => 'Color Tag';

  @override
  String get agentWorkspaceSoulMd => 'SOUL.md — Personality';

  @override
  String get agentWorkspaceSoulMdHint =>
      'Define the agent\'s personality, communication style, and core values...';

  @override
  String get agentWorkspaceAgentsMd => 'AGENTS.md — Behavior Rules';

  @override
  String get agentWorkspaceAgentsMdHint =>
      'Define session startup rules, safety guidelines, and operational procedures...';

  @override
  String get agentWorkspaceUserMd => 'USER.md — User Context';

  @override
  String get agentWorkspaceUserMdHint =>
      'Describe the user this agent is helping — preferences, context, work style...';

  @override
  String get agentWorkspaceIdentityMd => 'IDENTITY.md — Identity Card';

  @override
  String get agentWorkspaceIdentityMdHint =>
      'Agent name, creature type, vibe, emoji — the agent\'s self-description...';

  @override
  String get agentWorkspaceCapabilities => 'Capabilities';

  @override
  String get agentWorkspaceCapabilitiesDesc =>
      'Control which skills, tools, and MCP servers this agent can use. Leave empty to allow all.';

  @override
  String get agentWorkspaceAllowedSkills => 'Allowed Skills';

  @override
  String get agentWorkspaceAllowedTools => 'Allowed Tools';

  @override
  String get agentWorkspaceAllowedMcp => 'Allowed MCP Servers';

  @override
  String get agentWorkspaceAllAllowed => 'All (no restriction)';

  @override
  String agentWorkspaceNSelected(int count) {
    return '$count selected';
  }

  @override
  String get agentWorkspaceSkillsCount => 'Skills';

  @override
  String get agentWorkspaceToolsCount => 'Tools';

  @override
  String get agentWorkspaceMcpCount => 'MCP';

  @override
  String agentWorkspaceSaved(String name) {
    return 'Workspace \'\'$name\'\' saved';
  }

  @override
  String agentWorkspaceCreated(String name) {
    return 'Workspace \'\'$name\'\' created';
  }

  @override
  String get agentWorkspaceDeleteTitle => 'Delete Workspace';

  @override
  String agentWorkspaceDeleteConfirm(String name) {
    return 'Delete workspace \'\'$name\'\'? This will remove all identity files.';
  }

  @override
  String agentWorkspaceDeleted(String name) {
    return 'Workspace \'\'$name\'\' deleted';
  }

  @override
  String get agentWorkspaceEnabled => 'Enabled';

  @override
  String get agentWorkspaceIdentityFiles => 'Identity Files';

  @override
  String get agentSelectorTitle => 'Select Agent';

  @override
  String get agentSelectorDefault => 'Default (No Agent)';

  @override
  String agentSelectorCurrentAgent(String name) {
    return 'Current: $name';
  }

  @override
  String get multiAgentMode => 'Multi-Agent Mode';

  @override
  String get multiAgentTeam => 'Team';

  @override
  String get multiAgentOn => 'Multi-agent ON';

  @override
  String get multiAgentOff => 'Multi-agent';

  @override
  String get multiAgentDesc =>
      'Select which agent roles participate in this session. The orchestrator will automatically delegate tasks to them.';

  @override
  String get multiAgentCancel => 'Cancel';

  @override
  String get multiAgentApply => 'Apply';

  @override
  String get presetBadge => 'Preset';

  @override
  String get navProjects => 'Projects';

  @override
  String get projectCreate => 'New Project';

  @override
  String get projectCreated => 'Project created';

  @override
  String get projectCreateFailed => 'Failed to create project';

  @override
  String get projectDeleted => 'Project deleted';

  @override
  String get projectDeleteTitle => 'Delete Project';

  @override
  String projectDeleteConfirm(String name) {
    return 'Are you sure you want to delete project \"$name\"? Sessions will not be deleted.';
  }

  @override
  String get projectEmpty => 'No projects yet';

  @override
  String get projectEmptyHint =>
      'Create a project to organize your long-running tasks and sessions';

  @override
  String get projectName => 'Project Name';

  @override
  String get projectNameHint => 'Enter project name…';

  @override
  String get projectDescription => 'Description';

  @override
  String get projectDescriptionHint => 'Briefly describe this project…';

  @override
  String get projectType => 'Project Type';

  @override
  String get projectIcon => 'Icon';

  @override
  String get projectColor => 'Color';

  @override
  String get projectDirectory => 'Project Directory (optional)';

  @override
  String get projectDirectoryHint => 'Select or enter a local directory path…';

  @override
  String projectSessionCount(int count) {
    return '$count sessions';
  }

  @override
  String get projectNewSession => 'New Session';

  @override
  String get projectSessions => 'Project Sessions';

  @override
  String get projectNoSessions => 'No sessions in this project yet';

  @override
  String get projectPinnedContext => 'Pinned Context';

  @override
  String get projectContextHint =>
      'Record project background, tech stack, key decisions here. This context is automatically injected when creating new sessions within the project.';

  @override
  String get projectContextEmpty =>
      'No project context yet. Click edit to add background information.';

  @override
  String get projectContextSaved => 'Project context saved';

  @override
  String get projectNotFound => 'Project not found';

  @override
  String get projectEdit => 'Edit Project';

  @override
  String get projectUpdated => 'Project updated';

  @override
  String get projectUpdateFailed => 'Failed to update project';

  @override
  String get projectStatusActive => 'Active';

  @override
  String get projectStatusPaused => 'Paused';

  @override
  String get projectStatusArchived => 'Archived';

  @override
  String get projectStatusCompleted => 'Completed';

  @override
  String get projectFilterAll => 'All';

  @override
  String get projectSearchHint => 'Search projects…';

  @override
  String get projectRoles => 'Roles';

  @override
  String get projectAddRole => 'Add Role';

  @override
  String get projectNoRoles =>
      'No roles assigned. Add roles to customize agent behavior.';

  @override
  String get projectRoleAdded => 'Role added';

  @override
  String get projectRoleRemoved => 'Role removed';

  @override
  String get projectAllRolesAdded => 'All available roles are already added';

  @override
  String get projectSetDefaultRole => 'Set as Default';

  @override
  String get projectDefaultRoleBadge => 'Default';

  @override
  String projectRoleCount(int count) {
    return '$count roles';
  }

  @override
  String get projectTabOverview => 'Overview';

  @override
  String get projectTabSessions => 'Sessions';

  @override
  String get projectTabSettings => 'Settings';

  @override
  String get projectQuickActions => 'Quick Actions';

  @override
  String get projectRemoveSession => 'Remove from Project';

  @override
  String get projectSessionRemoved => 'Session removed from project';

  @override
  String get projectDangerZone => 'Danger Zone';

  @override
  String get projectDangerDeleteHint =>
      'Permanently delete this project. Sessions will not be deleted.';

  @override
  String get projectTemplate => 'Template';

  @override
  String get projectTemplateBlank => 'Blank';

  @override
  String get projectStatusChanged => 'Status updated';

  @override
  String get projectOpenSession => 'Open Session';

  @override
  String get projectSearchSessions => 'Search sessions…';

  @override
  String get navLlmDebug => 'LLM Debug';

  @override
  String get exportConfig => 'Export Config';

  @override
  String get importConfig => 'Import Config';

  @override
  String get configExportedToClipboard => 'Config exported to clipboard';

  @override
  String get configImportSuccess => 'Config imported successfully';

  @override
  String get configImportFailed => 'Import failed: invalid config data';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get configImportConfirmTitle => 'Import Config';

  @override
  String configImportConfirmMessage(int count) {
    return 'Found $count provider profiles in clipboard. Import will add or overwrite existing profiles. Continue?';
  }

  @override
  String get configExportEmpty => 'No provider profiles to export';

  @override
  String get navAppSettings => 'Preferences';

  @override
  String get appSettingsTitle => 'Preferences';

  @override
  String get settingSectionAppearance => 'Appearance';

  @override
  String get settingSectionGeneral => 'General';

  @override
  String get settingSectionAbout => 'About';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingLanguageDesc => 'Choose display language for the interface';

  @override
  String get settingTheme => 'Theme';

  @override
  String get settingThemeDesc => 'Choose color scheme for the interface';

  @override
  String get followSystem => 'Follow System';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingSendShortcut => 'Send Message';

  @override
  String get settingSendShortcutDesc => 'Keyboard shortcut to send a message';

  @override
  String get sendByEnter => 'Enter';

  @override
  String get sendByCtrlEnter => 'Ctrl + Enter';

  @override
  String get settingSidebarDefault => 'Sidebar';

  @override
  String get settingSidebarDefaultDesc => 'Default sidebar state on startup';

  @override
  String get sidebarExpanded => 'Expanded';

  @override
  String get sidebarCollapsed => 'Collapsed';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutBuildWith => 'Built with Flutter & Rust';

  @override
  String get aboutGitHub => 'GitHub Repository';

  @override
  String get aboutGitHubDesc => 'View source code, report issues';

  @override
  String get aboutCheckUpdate => 'Check for Updates';

  @override
  String get aboutCheckUpdateDesc => 'Check if a newer version is available';

  @override
  String aboutUpdateAvailable(String version) {
    return 'New version available: $version';
  }

  @override
  String get aboutUpdateCurrent => 'You are on the latest version';

  @override
  String get aboutUpdateError => 'Failed to check for updates';

  @override
  String get aboutUpdateChecking => 'Checking for updates…';

  @override
  String get aboutUpdateDownload => 'Download';

  @override
  String get aboutLicense => 'License';

  @override
  String get settingsResetTitle => 'Reset Settings';

  @override
  String get settingsResetDesc => 'Reset all preferences to default values';

  @override
  String get settingsResetConfirm =>
      'Are you sure you want to reset all preferences to defaults?';

  @override
  String get reset => 'Reset';

  @override
  String get copilotOAuthTitle => 'GitHub Copilot Authentication';

  @override
  String get copilotOAuthDesc =>
      'Sign in with your GitHub account to use Copilot. Requires an active GitHub Copilot subscription.';

  @override
  String get copilotSignIn => 'Sign in with GitHub';

  @override
  String get copilotSignOut => 'Sign Out';

  @override
  String get copilotAuthenticated => 'Authenticated';

  @override
  String get copilotNotAuthenticated => 'Not authenticated';

  @override
  String copilotAuthenticatedAs(Object username) {
    return 'Signed in as $username';
  }

  @override
  String get copilotDeviceCodeTitle => 'Enter code on GitHub';

  @override
  String get copilotDeviceCodeDesc =>
      'Visit the URL below and enter the code to authorize:';

  @override
  String get copilotDeviceCodeCopied => 'Code copied to clipboard';

  @override
  String get copilotOpenBrowser => 'Open GitHub';

  @override
  String get copilotWaitingAuth => 'Waiting for authorization...';

  @override
  String get copilotAuthSuccess => 'GitHub Copilot connected successfully!';

  @override
  String get copilotAuthExpired => 'Authorization expired. Please try again.';

  @override
  String copilotAuthFailed(Object error) {
    return 'Authentication failed: $error';
  }

  @override
  String get copilotRequiresSubscription =>
      'Requires GitHub Copilot subscription';

  @override
  String get copilotCopyCode => 'Copy Code';

  @override
  String get copilotCheckingStatus => 'Checking Copilot status...';

  @override
  String get copilotSignOutConfirm =>
      'Are you sure you want to sign out of GitHub Copilot?';
}
