// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CoralDesk';

  @override
  String get appTagline => '从桌面出发，驾驭 AI 新时代';

  @override
  String get navSectionChat => '任务';

  @override
  String get navSectionControl => '控制';

  @override
  String get navSectionAgent => '代理';

  @override
  String get navSectionSettings => '设置';

  @override
  String get navChat => '聊天';

  @override
  String get navChannels => '频道';

  @override
  String get navSessions => '会话';

  @override
  String get navCronJobs => '定时任务';

  @override
  String get navWorkspace => '工作区';

  @override
  String get navSkills => '技能 (Skills)';

  @override
  String get navMcp => 'MCP';

  @override
  String get navConfiguration => '配置';

  @override
  String get navModels => '模型';

  @override
  String get navEnvironments => '环境';

  @override
  String get workWithCoralDesk => '与 CoralDesk 一起工作';

  @override
  String get newChat => '新任务';

  @override
  String get quickTask => '临时任务';

  @override
  String get noConversationsYet => '暂无任务';

  @override
  String get startNewChat => '开始新任务';

  @override
  String get welcomeTitle => '你好，今天我能帮你什么？';

  @override
  String get welcomeSubtitle => '我是一个智能助手，可以帮助你解答各种问题。';

  @override
  String get suggestionWhatCanYouDo => '你能做什么？';

  @override
  String get suggestionWriteArticle => '帮我写一篇关于人工智能的文章。';

  @override
  String get suggestionExplainML => '用简单的语言解释机器学习的基本原理。';

  @override
  String get suggestionWriteEmail => '帮我写一封专业邮件。';

  @override
  String get suggestionImproveProductivity => '如何提高工作效率？';

  @override
  String get suggestionRecommendBooks => '推荐几本值得阅读的书。';

  @override
  String get suggestionPlanTrip => '帮我规划一次短途旅行。';

  @override
  String get suggestionBrainstorm => '帮我头脑风暴一些创意。';

  @override
  String get thinking => '💭 思考中...';

  @override
  String errorOccurred(String message) {
    return '⚠️ **错误：** $message\n\n请检查你的 API 密钥和供应商设置。';
  }

  @override
  String errorGeneric(String message) {
    return '⚠️ **错误：** $message\n\n请检查你的设置后重试。';
  }

  @override
  String get chatTitle => '聊天';

  @override
  String get processing => '处理中...';

  @override
  String get typeYourMessage => '输入消息…';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展开';

  @override
  String get pageChannels => '频道';

  @override
  String get pageConfiguration => '配置';

  @override
  String get pageCronJobs => '定时任务';

  @override
  String get pageModels => '模型';

  @override
  String get pageSessions => '会话';

  @override
  String get pageSkills => '技能 (Skills)';

  @override
  String get pageTools => '工具与 MCP';

  @override
  String get pageWorkspace => '工作区';

  @override
  String get languageLabel => '语言';

  @override
  String get switchToEnglish => 'English';

  @override
  String get switchToChinese => '中文';

  @override
  String get tooltipCopy => '复制';

  @override
  String get tooltipRefresh => '刷新';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get toolCallSuccess => '成功';

  @override
  String get toolCallFailed => '失败';

  @override
  String get comingSoon => '即将推出';

  @override
  String get featureComingSoon => '此功能即将推出。';

  @override
  String get environmentsDescription => '管理环境变量和部署配置。';

  @override
  String get providerConfiguration => '供应商配置';

  @override
  String get providerLabel => '供应商';

  @override
  String get modelLabel => '模型';

  @override
  String get apiKeyLabel => 'API 密钥';

  @override
  String get apiKeyHint => '请输入您的 API 密钥…';

  @override
  String get apiBaseUrlLabel => 'API 基础 URL';

  @override
  String get temperatureLabel => '温度';

  @override
  String get saving => '保存中…';

  @override
  String get save => '保存';

  @override
  String get configSaved => '配置已保存！';

  @override
  String get configSaveFailed => '保存配置失败';

  @override
  String get runtimeStatus => '运行状态';

  @override
  String get initialized => '已初始化';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get configured => '已配置';

  @override
  String get missing => '缺失';

  @override
  String get activeProvider => '当前供应商';

  @override
  String get activeModel => '当前模型';

  @override
  String get modelNameHint => '输入模型名称或从列表中选择…';

  @override
  String get showSuggestions => '显示建议';

  @override
  String get workspaceInfo => '工作区信息';

  @override
  String get workspaceDirectory => '工作区目录';

  @override
  String get configFile => '配置文件';

  @override
  String get agentSettings => 'Agent 设置';

  @override
  String get maxToolIterations => '最大工具迭代次数';

  @override
  String get maxHistoryMessages => '最大历史消息数';

  @override
  String get parallelToolExecution => '并行工具执行';

  @override
  String get compactContext => '紧凑上下文';

  @override
  String get toolDispatcher => '工具调度器';

  @override
  String get memorySection => '记忆';

  @override
  String get backend => '后端';

  @override
  String get autoSave => '自动保存';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '已禁用';

  @override
  String get hygiene => '数据清理';

  @override
  String get archiveAfter => '归档于…之后';

  @override
  String get days => '天';

  @override
  String get purgeAfter => '清除于…之后';

  @override
  String get embeddingProvider => '嵌入供应商';

  @override
  String get embeddingModel => '嵌入模型';

  @override
  String get costTracking => '费用追踪';

  @override
  String get dailyLimit => '每日限额';

  @override
  String get monthlyLimit => '每月限额';

  @override
  String get warnAt => '警告阈值';

  @override
  String get autonomySecurity => '自治与安全';

  @override
  String get autonomyLevel => '自治级别';

  @override
  String get readOnly => '只读';

  @override
  String get supervised => '受监督';

  @override
  String get fullAutonomy => '完全自治';

  @override
  String get trustMeMode => '信任模式';

  @override
  String get trustMeDescription => '自动批准所有工具调用，无需确认。请谨慎使用。';

  @override
  String get toolApprovalTitle => '需要工具审批';

  @override
  String toolApprovalBody(String toolName) {
    return 'Agent 想要执行工具：$toolName';
  }

  @override
  String get approve => '批准';

  @override
  String get deny => '拒绝';

  @override
  String get workspaceOnly => '仅限工作区';

  @override
  String get requireApprovalMediumRisk => '需要审批（中等风险）';

  @override
  String get blockHighRisk => '阻止高风险操作';

  @override
  String get maxActionsPerHour => '每小时最大操作数';

  @override
  String get maxCostPerDay => '每日最大费用';

  @override
  String get allowedCommands => '允许的命令';

  @override
  String get addCommand => '添加命令';

  @override
  String get commandNameHint => '输入命令名称（例如：open）';

  @override
  String get noCommandsConfigured => '未配置允许的命令';

  @override
  String get autoApprovedTools => '自动审批的工具';

  @override
  String get toolsSection => '工具';

  @override
  String toolCountLabel(int count) {
    return '$count 个工具';
  }

  @override
  String get categoryCoreTools => '核心工具';

  @override
  String get categoryVersionControl => '版本控制';

  @override
  String get categoryWebNetwork => '网络 & Web';

  @override
  String get categoryMemory => '记忆';

  @override
  String get categorySystem => '系统';

  @override
  String get categoryFileProcessing => '文件处理';

  @override
  String get categoryAgent => 'Agent';

  @override
  String get categoryScheduling => '定时调度';

  @override
  String get approvalAuto => '自动';

  @override
  String get approvalAsk => '确认';

  @override
  String get deleteSessionTitle => '删除会话';

  @override
  String get deleteSessionConfirm => '确定删除此会话？此操作不可撤销。';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get delete => '删除';

  @override
  String get back => '返回';

  @override
  String get edit => '编辑';

  @override
  String get sessionDeleted => '已删除会话';

  @override
  String get renameSessionTitle => '重命名会话';

  @override
  String get sessionTitleLabel => '会话标题';

  @override
  String get confirm => '确认';

  @override
  String get sessionRenamed => '已重命名';

  @override
  String get clearAllSessionsTitle => '清空所有会话';

  @override
  String get clearAllSessionsConfirm => '确定删除所有已保存的会话？此操作不可撤销。';

  @override
  String get deleteAll => '全部删除';

  @override
  String get allSessionsCleared => '已清空所有会话';

  @override
  String get sessionCount => '会话';

  @override
  String get messageCount => '消息';

  @override
  String get refresh => '刷新';

  @override
  String get clearAllSessions => '清空所有会话';

  @override
  String get noSavedSessions => '暂无已保存的会话';

  @override
  String get sessionsAutoSaveHint => '在任务中发送消息后，会话将自动保存到此处';

  @override
  String get searchSessions => '搜索会话…';

  @override
  String messageCountWithUnit(int count) {
    return '$count 条';
  }

  @override
  String get rename => '重命名';

  @override
  String get selectSessionToView => '选择一个会话查看详情';

  @override
  String messagesCreatedAt(int count) {
    return '$count 条消息 · 创建于';
  }

  @override
  String get roleYou => '你';

  @override
  String get roleAI => 'AI';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get featureToggles => '功能开关';

  @override
  String get featureTogglesDesc => '快速启用或停用 Agent 功能模块，选中即可直接使用';

  @override
  String get featureWebSearch => '网页搜索';

  @override
  String get featureWebSearchDesc => '搜索互联网获取最新信息';

  @override
  String get featureWebFetch => '网页抓取';

  @override
  String get featureWebFetchDesc => '抓取网页内容和提取文本';

  @override
  String get featureBrowser => '浏览器自动化';

  @override
  String get featureBrowserDesc => '自动化浏览器操作和交互';

  @override
  String get featureHttpRequest => 'HTTP 请求';

  @override
  String get featureHttpRequestDesc => '发送 API 请求 (GET/POST/PUT/DELETE)';

  @override
  String get featureMemory => '自动记忆';

  @override
  String get featureMemoryDesc => '自动保存对话中的重要信息';

  @override
  String get featureCostTracking => '费用追踪';

  @override
  String get featureCostTrackingDesc => '追踪 API 调用费用并设置限额';

  @override
  String get featureSkillsOpen => '社区技能';

  @override
  String get featureSkillsOpenDesc => '启用开源社区技能扩展';

  @override
  String get featureEnabled => '已启用';

  @override
  String get featureDisabled => '已停用';

  @override
  String get operationFailed => '操作失败';

  @override
  String get builtInTools => '内置工具';

  @override
  String get toolApprovalHint => '点击审批状态标签快速切换工具权限';

  @override
  String get autoApproval => '自动审批';

  @override
  String get requireConfirmation => '需要确认';

  @override
  String get defaultApproval => '默认';

  @override
  String get categoryCore => '核心工具';

  @override
  String get categoryVcs => '版本控制';

  @override
  String get categoryWeb => '网络 & Web';

  @override
  String get categoryMemoryTools => '记忆 & 存储';

  @override
  String get categoryCron => '定时任务';

  @override
  String get categoryFile => '文件处理';

  @override
  String get categoryAgentTools => 'Agent 委派';

  @override
  String channelConfigSaved(String name) {
    return '$name 配置已保存';
  }

  @override
  String saveFailedWithError(String error) {
    return '保存失败: $error';
  }

  @override
  String disableChannelTitle(String name) {
    return '禁用 $name';
  }

  @override
  String get disableChannelConfirm => '确定要禁用此频道？配置将被清除。';

  @override
  String get disable => '禁用';

  @override
  String channelDisabled(String name) {
    return '$name 已禁用';
  }

  @override
  String operationFailedWithError(String error) {
    return '操作失败: $error';
  }

  @override
  String activeCount(int count) {
    return '$count 个已激活';
  }

  @override
  String get noChannelsAvailable => '暂无可用频道';

  @override
  String get activeChannels => '已激活频道';

  @override
  String get availableChannels => '可用频道';

  @override
  String get statusActive => '已激活';

  @override
  String get statusInactive => '未激活';

  @override
  String configureChannel(String name) {
    return '配置 $name';
  }

  @override
  String disableChannel(String name) {
    return '禁用 $name';
  }

  @override
  String get skillsConfig => '技能配置';

  @override
  String get localSkills => '本地技能';

  @override
  String get communitySkills => '社区技能';

  @override
  String get openSourceSkills => '社区开源技能';

  @override
  String get openSourceSkillsDesc => '启用后将自动从 GitHub 同步社区技能';

  @override
  String get promptInjectionMode => '提示词注入模式';

  @override
  String get fullMode => '完整模式';

  @override
  String get fullModeDesc => '将技能的完整指令和工具信息注入系统提示词';

  @override
  String get compactMode => '精简模式';

  @override
  String get compactModeDesc => '仅注入技能摘要，按需加载详情';

  @override
  String get noSkillsAvailable => '暂无可用技能';

  @override
  String get noSkillsHint =>
      '在工作区的 skills/ 目录下创建 SKILL.toml 或 SKILL.md 文件来添加自定义技能，或启用社区开源技能来获取更多能力。';

  @override
  String get quickStartSkill => '快速开始：创建 SKILL.toml';

  @override
  String get sourceLocal => '本地';

  @override
  String get sourceCommunity => '社区';

  @override
  String get includedTools => '自带工具';

  @override
  String get prompts => '指令';

  @override
  String promptsWithCount(int count) {
    return '指令 ($count)';
  }

  @override
  String communitySkillsToggled(String status) {
    return '社区技能已$status';
  }

  @override
  String injectionModeUpdated(String mode) {
    return '注入模式已更新为 $mode';
  }

  @override
  String get installSkill => '安装技能';

  @override
  String get installSkillHint => '输入 Git URL 或本地路径';

  @override
  String get installSkillPlaceholder =>
      'https://github.com/user/skill-repo 或 /path/to/skill';

  @override
  String get installing => '安装中...';

  @override
  String skillInstalled(String name) {
    return '技能 \'$name\' 安装成功';
  }

  @override
  String installFailed(String error) {
    return '安装失败: $error';
  }

  @override
  String get removeSkill => '移除';

  @override
  String get removeSkillTitle => '移除技能';

  @override
  String removeSkillConfirm(String name) {
    return '确定移除技能 \'$name\'？此操作不可撤销。';
  }

  @override
  String skillRemoved(String name) {
    return '技能 \'$name\' 已移除';
  }

  @override
  String removeFailed(String error) {
    return '移除失败: $error';
  }

  @override
  String get gitUrlExample => '例如 https://github.com/user/my-skill';

  @override
  String get supportedSources => '支持 Git URL（https/ssh）或本地目录路径';

  @override
  String get deleteCronJobTitle => '删除定时任务';

  @override
  String get deleteCronJobConfirm => '确定删除此定时任务？此操作不可撤销。';

  @override
  String get deleted => '已删除';

  @override
  String deleteFailedWithError(String error) {
    return '删除失败: $error';
  }

  @override
  String get cronJobEnabled => '已启用';

  @override
  String get cronJobPaused => '已暂停';

  @override
  String get executionSuccess => '执行成功';

  @override
  String executionFailedWithError(String error) {
    return '执行失败: $error';
  }

  @override
  String executionErrorWithError(String error) {
    return '执行出错: $error';
  }

  @override
  String get totalCount => '总数';

  @override
  String get running => '运行中';

  @override
  String get paused => '已暂停';

  @override
  String get newTask => '新建任务';

  @override
  String get noCronJobs => '暂无定时任务';

  @override
  String get noCronJobsHint => '点击上方「新建任务」来创建 Shell 或 AI Agent 定时任务';

  @override
  String get mainSession => '主会话';

  @override
  String get runNow => '立即执行';

  @override
  String get collapseHistory => '收起历史';

  @override
  String get runHistory => '运行历史';

  @override
  String get nextExecution => '下次执行:';

  @override
  String get lastRun => '上次:';

  @override
  String get oneTime => '一次性';

  @override
  String get noRunHistory => '暂无运行记录';

  @override
  String runHistoryRecent(int count) {
    return '运行历史 (最近 $count 条)';
  }

  @override
  String get newCronJob => '新建定时任务';

  @override
  String get taskNameOptional => '任务名称（可选）';

  @override
  String get taskType => '任务类型';

  @override
  String get shellCommand => 'Shell 命令';

  @override
  String get aiAgent => 'AI Agent';

  @override
  String get scheduleType => '调度方式';

  @override
  String get interval => '间隔';

  @override
  String get scheduled => '定时';

  @override
  String get cronExpression => 'Cron 表达式';

  @override
  String get intervalMs => '间隔（毫秒）';

  @override
  String get executionTime => '执行时间 (RFC3339)';

  @override
  String get shellCommandLabel => 'Shell 命令';

  @override
  String get aiPromptLabel => 'AI 提示词';

  @override
  String get modelOptional => '模型（可选）';

  @override
  String get useDefaultModel => '留空使用默认模型';

  @override
  String get sessionTarget => '会话目标';

  @override
  String get isolated => '隔离';

  @override
  String get deleteAfterRun => '执行后删除';

  @override
  String get deleteAfterRunDesc => '仅执行一次后自动删除任务';

  @override
  String get create => '创建';

  @override
  String get cronJobCreated => '已创建定时任务';

  @override
  String createFailedWithError(String error) {
    return '创建失败: $error';
  }

  @override
  String get pageEnvironments => '环境';

  @override
  String get navKnowledge => '知识库';

  @override
  String get pageKnowledge => '知识库管理';

  @override
  String get knowledgeOverview => '知识库概览';

  @override
  String get totalEntries => '总条目';

  @override
  String get healthy => '健康';

  @override
  String get unhealthy => '异常';

  @override
  String get searchKnowledge => '搜索知识条目…';

  @override
  String get addKnowledge => '添加条目';

  @override
  String get knowledgeEntries => '知识条目';

  @override
  String get noKnowledgeEntries => '暂无知识条目';

  @override
  String get noKnowledgeHint => '添加知识条目可以帮助 AI 助手记住重要信息、事实和上下文。';

  @override
  String get knowledgeEntryAdded => '知识条目已添加';

  @override
  String get knowledgeEntryDeleted => '知识条目已删除';

  @override
  String get deleteKnowledgeTitle => '删除条目';

  @override
  String get deleteKnowledgeConfirm => '确定删除此知识条目？此操作不可撤销。';

  @override
  String get knowledgeKeyLabel => '键 / 标题';

  @override
  String get knowledgeKeyHint => '例如: user-preferences, project-guidelines';

  @override
  String get knowledgeContentLabel => '内容';

  @override
  String get knowledgeContentHint => '输入知识内容…';

  @override
  String get knowledgeCategoryLabel => '分类';

  @override
  String get knowledgeCategoryAll => '全部分类';

  @override
  String get knowledgeCategoryCore => '核心';

  @override
  String get knowledgeCategoryDaily => '日常';

  @override
  String get knowledgeCategoryConversation => '对话';

  @override
  String get copyMessage => '复制';

  @override
  String get editMessage => '编辑';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get expandHistory => '展开历史';

  @override
  String get collapseSidebar => '收起侧边栏';

  @override
  String get expandSidebar => '展开侧边栏';

  @override
  String get saveEdit => '保存';

  @override
  String get cancelEdit => '取消';

  @override
  String get navAgents => '角色与子代理';

  @override
  String get navAgentWorkspaces => '角色工作区';

  @override
  String get pageAgents => '角色与子代理管理';

  @override
  String get agentOverview => '概览';

  @override
  String get agentOverviewDesc =>
      '管理团队角色和自定义子代理。内置角色作为团队成员协作工作，自定义子代理可独立执行专项任务。';

  @override
  String get agentAgenticCount => '自主模式';

  @override
  String get agentNew => '新建子代理';

  @override
  String get agentEdit => '编辑';

  @override
  String get agentNoAgents => '暂无自定义子代理';

  @override
  String get agentNoAgentsHint =>
      '创建自定义子代理可将研究、编码或总结等专项任务交给不同的 AI 模型执行。内置角色已自动配置。';

  @override
  String get agentNameLabel => '名称';

  @override
  String get agentSystemPrompt => '系统提示词';

  @override
  String get agentSystemPromptHint => '例如：你是一个研究助手。';

  @override
  String get agentMaxDepth => '最大深度';

  @override
  String get agentMaxIterations => '最大迭代次数';

  @override
  String get agentAgenticMode => '自主模式';

  @override
  String get agentAgenticModeDesc => '启用多轮工具调用循环，可迭代使用工具完成复杂任务。';

  @override
  String get agentAllowedTools => '允许的工具';

  @override
  String get agentAgentic => '自主';

  @override
  String get agentOptional => '可选';

  @override
  String get agentDeleteTitle => '删除子代理';

  @override
  String agentDeleteConfirm(String name) {
    return '确定删除子代理 \'$name\'？此操作不可撤销。';
  }

  @override
  String agentDeleted(String name) {
    return '子代理 \'$name\' 已删除';
  }

  @override
  String agentCreated(String name) {
    return '已创建 \'$name\'';
  }

  @override
  String agentUpdated(String name) {
    return '已更新 \'$name\'';
  }

  @override
  String get rolesSectionTitle => '团队角色';

  @override
  String get rolesSectionDesc => '内置角色作为团队成员协同工作，各有独立工作区、工具和技能。角色在团队模式下自动激活。';

  @override
  String get subAgentsSectionTitle => '自定义子代理';

  @override
  String get subAgentsSectionDesc => '自定义子代理可接受委派执行专项任务，如研究、总结等。';

  @override
  String get navProxy => '网络代理';

  @override
  String get proxyPageTitle => '代理设置';

  @override
  String get proxyConfiguration => '代理配置';

  @override
  String get proxyDescription =>
      '将出站 HTTP/HTTPS 流量路由到代理服务器。支持 HTTP、HTTPS、SOCKS5 和 SOCKS5H 协议。';

  @override
  String get proxyAllProxy => '统一代理 (回退)';

  @override
  String get proxyAllProxyHelp => '未设置单独代理时，所有协议使用此代理地址。';

  @override
  String get proxyHttpProxy => 'HTTP 代理';

  @override
  String get proxyHttpProxyHelp => 'HTTP 请求的代理地址，优先级高于统一代理。';

  @override
  String get proxyHttpsProxy => 'HTTPS 代理';

  @override
  String get proxyHttpsProxyHelp => 'HTTPS 请求的代理地址，优先级高于统一代理。';

  @override
  String get proxyNoProxy => '不代理列表';

  @override
  String get proxyNoProxyHelp => '逗号分隔的主机/域名列表，这些地址将绕过代理直连。';

  @override
  String get proxyScope => '代理范围';

  @override
  String get proxyScopeDescription => '选择哪些出站流量应通过代理路由。';

  @override
  String get proxyScopeZeroclaw => '全部流量';

  @override
  String get proxyScopeZeroclawDesc => '所有 CoralDesk 管理的 HTTP 流量';

  @override
  String get proxyScopeServices => '指定服务';

  @override
  String get proxyScopeServicesDesc => '仅显式列出的服务';

  @override
  String get proxyScopeEnvironment => '系统环境变量';

  @override
  String get proxyScopeEnvironmentDesc => '设置进程环境变量 (HTTP_PROXY 等)';

  @override
  String get proxyServiceSelectors => '服务选择器';

  @override
  String get proxyServiceSelectorsHelp =>
      '选择哪些服务应使用代理。可使用通配符如 provider.* 匹配所有供应商。';

  @override
  String get modelRoutes => '模型路由';

  @override
  String get modelRoutesDesc =>
      '为不同任务配置不同的模型路由，例如推理用强模型、日常用快速模型。子代理可通过路由提示引用，无需手动配置供应商。';

  @override
  String get addRoute => '新增路由';

  @override
  String get editRoute => '编辑路由';

  @override
  String get routeHint => '路由提示';

  @override
  String get routeHintHint => '例如: reasoning, fast, code';

  @override
  String get noModelRoutes => '暂无模型路由';

  @override
  String get noModelRoutesHint => '路由允许为不同任务使用不同模型，子代理可通过路由提示引用，无需逐个配置供应商和模型。';

  @override
  String get deleteRouteTitle => '删除路由';

  @override
  String get deleteRouteConfirm => '确定删除此路由？此操作不可撤销。';

  @override
  String get routeDeleted => '路由已删除';

  @override
  String get routeSaved => '路由已保存';

  @override
  String get embeddingConfiguration => '向量嵌入配置';

  @override
  String get embeddingConfigDesc =>
      '配置向量嵌入供应商以启用语义搜索，可显著提升知识库和记忆召回的准确性，尤其是中文等非英语文本。';

  @override
  String get embeddingDimensions => '嵌入维度';

  @override
  String get vectorWeight => '向量权重';

  @override
  String get keywordWeight => '关键词权重';

  @override
  String get minRelevanceScore => '最小相关度';

  @override
  String get embeddingSaved => '嵌入配置已保存！';

  @override
  String get embeddingProviderNone => '无 (仅关键词搜索)';

  @override
  String get embeddingProviderOpenai => 'OpenAI';

  @override
  String get embeddingProviderCustom => '自定义 (OpenAI 兼容)';

  @override
  String get agentUseDefault => '使用默认配置';

  @override
  String get agentUseDefaultDesc => '使用模型页面中配置的默认供应商和模型，无需逐个配置。';

  @override
  String cronNotifSuccess(String name) {
    return '✅ 定时任务 [$name] 执行成功';
  }

  @override
  String cronNotifFailed(String name) {
    return '❌ 定时任务 [$name] 执行失败';
  }

  @override
  String cronNotifDuration(String ms) {
    return '耗时 ${ms}ms';
  }

  @override
  String get cronNotifInjected => '结果已注入当前会话';

  @override
  String get viewOutput => '查看输出';

  @override
  String get notificationPanelTitle => '通知中心';

  @override
  String get clearNotifications => '清空通知';

  @override
  String get close => '关闭';

  @override
  String get noNotifications => '暂无通知';

  @override
  String get noNotificationsHint => '定时任务执行后的通知将在此显示';

  @override
  String get expandOutput => '展开';

  @override
  String get attachFile => '添加附件';

  @override
  String get addFiles => '添加文件';

  @override
  String get addFolder => '添加文件夹';

  @override
  String attachedFiles(int count) {
    return '已附加 $count 个文件';
  }

  @override
  String get clearAll => '全部清除';

  @override
  String get dropFilesHere => '将文件拖放到此处';

  @override
  String get dropFilesHint => '文件和文件夹将附加到当前会话';

  @override
  String get openWorkspaceFolder => '打开工作区文件夹';

  @override
  String get workspaceFiles => '工作区文件';

  @override
  String get noWorkspaceFiles => '暂无文件';

  @override
  String get noWorkspaceFilesHint => 'Agent 创建的文件将显示在此处';

  @override
  String get openFile => '打开';

  @override
  String get saveFileAs => '另存为…';

  @override
  String fileSaved(String path) {
    return '文件已保存至 $path';
  }

  @override
  String get fileSaveFailed => '保存文件失败';

  @override
  String get refreshFiles => '刷新';

  @override
  String get pageMcpServers => 'MCP 服务器';

  @override
  String get mcpEnabled => '启用 MCP';

  @override
  String get mcpEnabledDesc => '启用模型上下文协议以连接外部工具服务器';

  @override
  String get mcpNoServers => '暂无 MCP 服务器';

  @override
  String get mcpNoServersHint => '添加 MCP 服务器以扩展 Agent 的外部工具能力';

  @override
  String get mcpAddServer => '添加服务器';

  @override
  String get mcpEditServer => '编辑服务器';

  @override
  String get mcpDeleteServer => '删除服务器';

  @override
  String mcpDeleteConfirm(String name) {
    return '确定要删除服务器 \"$name\" 吗？';
  }

  @override
  String get mcpServerName => '服务器名称';

  @override
  String get mcpTransport => '传输方式';

  @override
  String get mcpCommand => '命令';

  @override
  String get mcpArgs => '参数';

  @override
  String get mcpArgsHint => '每行一个参数';

  @override
  String get mcpUrl => 'URL';

  @override
  String get mcpTimeout => '超时时间（秒）';

  @override
  String get mcpEnvVars => '环境变量';

  @override
  String get mcpHeaders => 'HTTP Headers';

  @override
  String get mcpAddKv => '添加';

  @override
  String get mcpKeyPlaceholder => '键';

  @override
  String get mcpValuePlaceholder => '值';

  @override
  String get mcpServerAdded => 'MCP 服务器添加成功';

  @override
  String get mcpServerUpdated => 'MCP 服务器更新成功';

  @override
  String get mcpServerDeleted => 'MCP 服务器已删除';

  @override
  String get mcpServerEnabled => 'MCP 服务器已启用';

  @override
  String get mcpServerDisabled => 'MCP 服务器已暂停';

  @override
  String get mcpToggleServer => '启用/暂停服务器';

  @override
  String get mcpTransportStdio => '标准 I/O';

  @override
  String get mcpTransportHttp => 'HTTP';

  @override
  String get mcpTransportSse => 'Server-Sent Events';

  @override
  String get mcpTestConnection => '测试连接';

  @override
  String get mcpTesting => '测试中…';

  @override
  String get mcpConnected => '已连接';

  @override
  String get mcpDisconnected => '未连接';

  @override
  String get mcpConnectionError => '连接错误';

  @override
  String get mcpNotTested => '未测试';

  @override
  String mcpToolCount(int count) {
    return '$count 个工具';
  }

  @override
  String get mcpTools => '工具列表';

  @override
  String get mcpNoToolsFound => '未发现工具';

  @override
  String mcpStatusSummary(int toolCount, int serverCount) {
    return '$serverCount 个服务器提供 $toolCount 个工具';
  }

  @override
  String mcpTestSuccess(int count, int elapsed) {
    return '连接成功 — 发现 $count 个工具（耗时 ${elapsed}ms）';
  }

  @override
  String mcpTestFailed(String error) {
    return '连接失败：$error';
  }

  @override
  String get mcpTestAll => '全部测试';

  @override
  String get mcpShowTools => '显示工具';

  @override
  String get mcpHideTools => '隐藏工具';

  @override
  String get mcpDisabledHint => '启用 MCP 以连接外部工具服务器，扩展 Agent 的能力。';

  @override
  String get mcpOverviewTitle => '总览';

  @override
  String get retryMessage => '重试';

  @override
  String get stopGenerating => '停止生成';

  @override
  String get providerProfiles => '供应商配置';

  @override
  String get providerProfile => '供应商配置';

  @override
  String get providerProfileSelectHint => '选择配置或手动输入';

  @override
  String get providerProfileManual => '手动配置';

  @override
  String get providerProfilesDesc =>
      '配置多个供应商。每个配置可拥有独立的 API Key、基础 URL 和默认模型。可在模型路由或聊天中使用。';

  @override
  String get providerProfileNew => '新建配置';

  @override
  String get providerProfileEdit => '编辑配置';

  @override
  String get providerProfileId => '配置 ID';

  @override
  String get providerProfileIdHint => '例如 my-openai, local-ollama';

  @override
  String get providerProfileName => '供应商名称';

  @override
  String get providerProfileNameHint => '例如 openai, anthropic, ollama';

  @override
  String get providerProfileBaseUrl => '基础 URL';

  @override
  String get providerProfileBaseUrlHint => '例如 https://api.openai.com/v1';

  @override
  String get providerProfileWireApi => 'API 协议';

  @override
  String get providerProfileModel => '默认模型';

  @override
  String get providerProfileModelHint => '例如 gpt-4o, claude-sonnet-4-6';

  @override
  String providerProfileDeleted(String id) {
    return '配置 \'\'$id\'\' 已删除';
  }

  @override
  String get providerProfileSaved => '配置已保存';

  @override
  String get providerProfileDeleteTitle => '删除配置';

  @override
  String providerProfileDeleteConfirm(String id) {
    return '确定要删除配置 \'\'$id\'\' 吗？';
  }

  @override
  String get noProviderProfiles => '未配置供应商';

  @override
  String get noProviderProfilesHint => '添加供应商配置以使用多个不同 API Key 或端点的供应商。';

  @override
  String get chatModelSelector => '切换模型';

  @override
  String chatCurrentModel(String provider, String model) {
    return '当前: $provider / $model';
  }

  @override
  String get embeddingBaseUrl => '嵌入基础 URL';

  @override
  String get embeddingBaseUrlHint => '例如 https://api.openai.com';

  @override
  String get embeddingApiKey => '嵌入 API 密钥';

  @override
  String get embeddingApiKeyHint => '嵌入供应商的 API 密钥';

  @override
  String get agentCapabilities => '能力标签';

  @override
  String get agentCapabilitiesHint => 'research, coding, summarize';

  @override
  String get agentPriority => '优先级';

  @override
  String get agentEnabled => '启用';

  @override
  String get agentEnabledDesc => '是否启用此代理进行选择和调用。';

  @override
  String get wireApiChatCompletions => 'Chat Completions';

  @override
  String get wireApiResponses => 'Responses';

  @override
  String get wireApiAuto => '自动';

  @override
  String get defaultLabel => '默认';

  @override
  String get setAsDefault => '设为默认';

  @override
  String providerProfileSetDefault(String id) {
    return '配置 \'\'$id\'\' 已设为默认';
  }

  @override
  String get trayShow => '显示 CoralDesk';

  @override
  String get trayHide => '隐藏 CoralDesk';

  @override
  String get trayQuit => '退出 CoralDesk';

  @override
  String get trayTooltip => 'CoralDesk – 后台运行中';

  @override
  String get proxyServiceCategoryProvider => 'AI 供应商';

  @override
  String get proxyServiceCategoryChannel => '通道';

  @override
  String get proxyServiceCategoryTool => '工具';

  @override
  String get proxyServiceCategoryMemory => '记忆';

  @override
  String get proxyServiceCategoryTunnel => '隧道';

  @override
  String get proxyServiceCategoryTranscription => '语音转写';

  @override
  String get proxyServiceProviderAnthropic => 'Anthropic (Claude)';

  @override
  String get proxyServiceProviderCompatible => 'OpenAI 兼容';

  @override
  String get proxyServiceProviderCopilot => 'GitHub Copilot';

  @override
  String get proxyServiceProviderGemini => 'Google Gemini';

  @override
  String get proxyServiceProviderGlm => '智谱 GLM';

  @override
  String get proxyServiceProviderOllama => 'Ollama (本地)';

  @override
  String get proxyServiceProviderOpenai => 'OpenAI';

  @override
  String get proxyServiceProviderOpenrouter => 'OpenRouter';

  @override
  String get proxyServiceChannelBluebubbles => 'BlueBubbles';

  @override
  String get proxyServiceChannelDingtalk => '钉钉';

  @override
  String get proxyServiceChannelDiscord => 'Discord';

  @override
  String get proxyServiceChannelFeishu => '飞书';

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
  String get proxyServiceToolBrowser => '浏览器自动化';

  @override
  String get proxyServiceToolComposio => 'Composio';

  @override
  String get proxyServiceToolHttpRequest => 'HTTP 请求';

  @override
  String get proxyServiceToolMultimodal => '多模态';

  @override
  String get proxyServiceToolPushover => 'Pushover 通知';

  @override
  String get proxyServiceMemoryEmbeddings => '嵌入向量';

  @override
  String get proxyServiceTunnelCustom => '自定义隧道';

  @override
  String get proxyServiceTranscriptionGroq => 'Groq 语音转写';

  @override
  String get proxyServiceWildcardProvider => '所有供应商';

  @override
  String get proxyServiceWildcardChannel => '所有通道';

  @override
  String get proxyServiceWildcardTool => '所有工具';

  @override
  String get proxyServiceWildcardMemory => '所有记忆服务';

  @override
  String get proxyServiceWildcardTunnel => '所有隧道';

  @override
  String get proxyServiceWildcardTranscription => '所有语音转写';

  @override
  String get proxyResetButton => '重置';

  @override
  String get proxyResetConfirmTitle => '重置代理设置？';

  @override
  String get proxyResetConfirmBody => '这将清除所有代理设置并禁用代理。确定要继续吗？';

  @override
  String get proxyResetSuccess => '代理设置已重置';

  @override
  String get agentWorkspaces => '角色';

  @override
  String get agentWorkspaceOverview => '角色概览';

  @override
  String get agentWorkspaceOverviewDesc =>
      '配置不同的角色，每个角色都有自己的性格（SOUL.md）、行为规则（AGENTS.md）和身份。会话可以绑定到特定的角色，提供个性化交互。';

  @override
  String get agentWorkspaceNew => '新建角色';

  @override
  String get agentWorkspaceEdit => '编辑角色';

  @override
  String get agentWorkspaceNoWorkspaces => '暂无角色';

  @override
  String get agentWorkspaceNoWorkspacesHint =>
      '创建一个角色，为AI助手赋予独特的性格、风格和行为，以适应不同的任务场景。';

  @override
  String get agentWorkspaceNameLabel => '名称';

  @override
  String get agentWorkspaceNameHint => '如：产品经理';

  @override
  String get agentWorkspaceDescLabel => '描述';

  @override
  String get agentWorkspaceDescHint => '简要描述该智能体的角色';

  @override
  String get agentWorkspaceAvatarLabel => '头像 Emoji';

  @override
  String get agentWorkspaceColorLabel => '颜色标签';

  @override
  String get agentWorkspaceSoulMd => 'SOUL.md — 性格特征';

  @override
  String get agentWorkspaceSoulMdHint => '定义智能体的性格、沟通风格和核心价值观...';

  @override
  String get agentWorkspaceAgentsMd => 'AGENTS.md — 行为规则';

  @override
  String get agentWorkspaceAgentsMdHint => '定义会话启动规则、安全准则和操作流程...';

  @override
  String get agentWorkspaceUserMd => 'USER.md — 用户背景';

  @override
  String get agentWorkspaceUserMdHint => '描述该智能体服务的用户——偏好、背景、工作风格...';

  @override
  String get agentWorkspaceIdentityMd => 'IDENTITY.md — 身份卡';

  @override
  String get agentWorkspaceIdentityMdHint => '智能体名称、类型、氛围、emoji——智能体的自我描述...';

  @override
  String get agentWorkspaceCapabilities => '能力权限';

  @override
  String get agentWorkspaceCapabilitiesDesc =>
      '控制此角色可以使用哪些技能、工具和 MCP 服务器。留空表示允许全部。';

  @override
  String get agentWorkspaceAllowedSkills => '允许的技能';

  @override
  String get agentWorkspaceAllowedTools => '允许的工具';

  @override
  String get agentWorkspaceAllowedMcp => '允许的 MCP 服务器';

  @override
  String get agentWorkspaceAllAllowed => '全部（无限制）';

  @override
  String agentWorkspaceNSelected(int count) {
    return '已选 $count 个';
  }

  @override
  String get agentWorkspaceSkillsCount => '技能';

  @override
  String get agentWorkspaceToolsCount => '工具';

  @override
  String get agentWorkspaceMcpCount => 'MCP';

  @override
  String agentWorkspaceSaved(String name) {
    return '角色「$name」已保存';
  }

  @override
  String agentWorkspaceCreated(String name) {
    return '角色「$name」已创建';
  }

  @override
  String get agentWorkspaceDeleteTitle => '删除角色';

  @override
  String agentWorkspaceDeleteConfirm(String name) {
    return '删除角色「$name」？这将移除所有身份文件。';
  }

  @override
  String agentWorkspaceDeleted(String name) {
    return '角色「$name」已删除';
  }

  @override
  String get agentWorkspaceEnabled => '已启用';

  @override
  String get agentWorkspaceIdentityFiles => '身份文件';

  @override
  String get agentSelectorTitle => '选择智能体';

  @override
  String get agentSelectorDefault => '默认（无智能体）';

  @override
  String agentSelectorCurrentAgent(String name) {
    return '当前：$name';
  }

  @override
  String get multiAgentMode => '多智能体模式';

  @override
  String get multiAgentTeam => '团队';

  @override
  String get multiAgentOn => '多智能体已开启';

  @override
  String get multiAgentOff => '多智能体';

  @override
  String get multiAgentDesc => '选择参与本次会话的智能体角色。协调者将自动分配任务给对应的角色。';

  @override
  String get multiAgentCancel => '取消';

  @override
  String get multiAgentApply => '应用';

  @override
  String get presetBadge => '内置';

  @override
  String get navProjects => '项目';

  @override
  String get projectCreate => '新建项目';

  @override
  String get projectCreated => '项目已创建';

  @override
  String get projectCreateFailed => '创建项目失败';

  @override
  String get projectDeleted => '项目已删除';

  @override
  String get projectDeleteTitle => '删除项目';

  @override
  String projectDeleteConfirm(String name) {
    return '确定要删除项目 \"$name\" 吗？关联的会话不会被删除。';
  }

  @override
  String get projectEmpty => '暂无项目';

  @override
  String get projectEmptyHint => '创建一个项目来组织你的长期任务和会话';

  @override
  String get projectName => '项目名称';

  @override
  String get projectNameHint => '输入项目名称…';

  @override
  String get projectDescription => '项目描述';

  @override
  String get projectDescriptionHint => '简要描述这个项目…';

  @override
  String get projectType => '项目类型';

  @override
  String get projectIcon => '图标';

  @override
  String get projectColor => '颜色';

  @override
  String get projectDirectory => '项目目录（可选）';

  @override
  String get projectDirectoryHint => '选择或输入本地目录路径…';

  @override
  String projectSessionCount(int count) {
    return '$count 个会话';
  }

  @override
  String get projectNewSession => '新建会话';

  @override
  String get projectSessions => '项目会话';

  @override
  String get projectNoSessions => '此项目暂无会话';

  @override
  String get projectPinnedContext => '项目上下文';

  @override
  String get projectContextHint =>
      '在此记录项目的背景信息、技术栈、重要决策等。每次在项目中新建会话时，这些内容会自动注入。';

  @override
  String get projectContextEmpty => '暂无项目上下文。点击编辑添加项目背景信息。';

  @override
  String get projectContextSaved => '项目上下文已保存';

  @override
  String get projectNotFound => '项目未找到';

  @override
  String get projectEdit => '编辑项目';

  @override
  String get projectUpdated => '项目已更新';

  @override
  String get projectUpdateFailed => '更新项目失败';

  @override
  String get projectStatusActive => '活跃';

  @override
  String get projectStatusPaused => '暂停';

  @override
  String get projectStatusArchived => '归档';

  @override
  String get projectStatusCompleted => '已完成';

  @override
  String get projectFilterAll => '全部';

  @override
  String get projectSearchHint => '搜索项目…';

  @override
  String get projectRoles => '角色';

  @override
  String get projectAddRole => '添加角色';

  @override
  String get projectNoRoles => '未分配角色。添加角色以自定义 Agent 行为。';

  @override
  String get projectRoleAdded => '角色已添加';

  @override
  String get projectRoleRemoved => '角色已移除';

  @override
  String get projectAllRolesAdded => '所有可用角色均已添加';

  @override
  String get projectSetDefaultRole => '设为默认';

  @override
  String get projectDefaultRoleBadge => '默认';

  @override
  String projectRoleCount(int count) {
    return '$count 个角色';
  }

  @override
  String get projectTabOverview => '概览';

  @override
  String get projectTabSessions => '会话';

  @override
  String get projectTabSettings => '设置';

  @override
  String get projectQuickActions => '快捷操作';

  @override
  String get projectRemoveSession => '从项目移除';

  @override
  String get projectSessionRemoved => '会话已从项目移除';

  @override
  String get projectDangerZone => '危险区域';

  @override
  String get projectDangerDeleteHint => '永久删除此项目。关联的会话不会被删除。';

  @override
  String get projectTemplate => '模板';

  @override
  String get projectTemplateBlank => '空白项目';

  @override
  String get projectStatusChanged => '状态已更新';

  @override
  String get projectOpenSession => '打开会话';

  @override
  String get projectSearchSessions => '搜索会话…';

  @override
  String get navLlmDebug => 'LLM 调试';

  @override
  String get exportConfig => '导出配置';

  @override
  String get importConfig => '导入配置';

  @override
  String get configExportedToClipboard => '配置已导出到剪贴板';

  @override
  String get configImportSuccess => '配置导入成功';

  @override
  String get configImportFailed => '导入失败：配置数据无效';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get configImportConfirmTitle => '导入配置';

  @override
  String configImportConfirmMessage(int count) {
    return '在剪贴板中发现 $count 个模型配置。导入将添加或覆盖现有配置，是否继续？';
  }

  @override
  String get configExportEmpty => '没有可导出的模型配置';

  @override
  String get navAppSettings => '偏好设置';

  @override
  String get appSettingsTitle => '偏好设置';

  @override
  String get settingSectionAppearance => '外观';

  @override
  String get settingSectionGeneral => '通用';

  @override
  String get settingSectionAbout => '关于';

  @override
  String get settingLanguage => '语言';

  @override
  String get settingLanguageDesc => '选择界面显示语言';

  @override
  String get settingTheme => '主题';

  @override
  String get settingThemeDesc => '选择界面配色方案';

  @override
  String get followSystem => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get settingSendShortcut => '发送消息';

  @override
  String get settingSendShortcutDesc => '发送消息的键盘快捷键';

  @override
  String get sendByEnter => 'Enter';

  @override
  String get sendByCtrlEnter => 'Ctrl + Enter';

  @override
  String get settingSidebarDefault => '侧边栏';

  @override
  String get settingSidebarDefaultDesc => '启动时侧边栏的默认状态';

  @override
  String get sidebarExpanded => '展开';

  @override
  String get sidebarCollapsed => '收起';

  @override
  String get aboutVersion => '版本';

  @override
  String get aboutBuildWith => '基于 Flutter 与 Rust 构建';

  @override
  String get aboutGitHub => 'GitHub 仓库';

  @override
  String get aboutGitHubDesc => '查看源码、反馈问题';

  @override
  String get aboutCheckUpdate => '检查更新';

  @override
  String get aboutCheckUpdateDesc => '检查是否有新版本可用';

  @override
  String aboutUpdateAvailable(String version) {
    return '发现新版本：$version';
  }

  @override
  String get aboutUpdateCurrent => '当前已是最新版本';

  @override
  String get aboutUpdateError => '检查更新失败';

  @override
  String get aboutUpdateChecking => '正在检查更新…';

  @override
  String get aboutUpdateDownload => '下载';

  @override
  String get aboutLicense => '许可证';

  @override
  String get settingsResetTitle => '重置设置';

  @override
  String get settingsResetDesc => '将所有偏好设置恢复为默认值';

  @override
  String get settingsResetConfirm => '确定要将所有偏好设置恢复为默认值吗？';

  @override
  String get reset => '重置';

  @override
  String get copilotOAuthTitle => 'GitHub Copilot 认证';

  @override
  String get copilotOAuthDesc =>
      '使用您的 GitHub 账号登录以使用 Copilot。需要有效的 GitHub Copilot 订阅。';

  @override
  String get copilotSignIn => '使用 GitHub 登录';

  @override
  String get copilotSignOut => '退出登录';

  @override
  String get copilotAuthenticated => '已认证';

  @override
  String get copilotNotAuthenticated => '未认证';

  @override
  String copilotAuthenticatedAs(Object username) {
    return '已登录为 $username';
  }

  @override
  String get copilotDeviceCodeTitle => '在 GitHub 上输入验证码';

  @override
  String get copilotDeviceCodeDesc => '访问下方链接并输入验证码以完成授权：';

  @override
  String get copilotDeviceCodeCopied => '验证码已复制到剪贴板';

  @override
  String get copilotOpenBrowser => '打开 GitHub';

  @override
  String get copilotWaitingAuth => '等待授权中...';

  @override
  String get copilotAuthSuccess => 'GitHub Copilot 连接成功！';

  @override
  String get copilotAuthExpired => '授权已过期，请重试。';

  @override
  String copilotAuthFailed(Object error) {
    return '认证失败：$error';
  }

  @override
  String get copilotRequiresSubscription => '需要 GitHub Copilot 订阅';

  @override
  String get copilotCopyCode => '复制验证码';

  @override
  String get copilotCheckingStatus => '正在检查 Copilot 状态...';

  @override
  String get copilotSignOutConfirm => '确定要退出 GitHub Copilot 登录吗？';
}
