import 'package:coraldesk/models/project.dart';

/// Pre-built project templates for quick setup.
/// Each template pre-fills project type, icon, color, description,
/// and recommends built-in agent roles.
class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String colorTag;
  final ProjectType projectType;

  /// Built-in role IDs to auto-attach when user creates from template.
  final List<String> recommendedRoleIds;

  const ProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colorTag,
    required this.projectType,
    this.recommendedRoleIds = const [],
  });

  /// All available templates
  static const List<ProjectTemplate> all = [
    blank,
    codeDev,
    desktopAutomation,
    dataAnalysis,
    dailyAssistant,
    writing,
  ];

  /// Blank / custom project
  static const blank = ProjectTemplate(
    id: 'blank',
    name: 'Blank Project',
    description: '',
    icon: '📁',
    colorTag: '#5B6ABF',
    projectType: ProjectType.general,
  );

  /// Software development project
  static const codeDev = ProjectTemplate(
    id: 'code_dev',
    name: 'Code Development',
    description:
        'Software development with coding agent, code review, and testing',
    icon: '💻',
    colorTag: '#4A90D9',
    projectType: ProjectType.codeProject,
    recommendedRoleIds: [
      'preset_architect',
      'preset_coder',
      'preset_critic',
      'preset_validator',
    ],
  );

  /// Desktop automation project
  static const desktopAutomation = ProjectTemplate(
    id: 'desktop_automation',
    name: 'Desktop Automation',
    description:
        'Automate desktop workflows with screen control and browser agents',
    icon: '⚙️',
    colorTag: '#1ABC9C',
    projectType: ProjectType.automation,
    recommendedRoleIds: ['preset_coder', 'preset_integrator'],
  );

  /// Data analysis project
  static const dataAnalysis = ProjectTemplate(
    id: 'data_analysis',
    name: 'Data Analysis',
    description: 'Data processing, analysis, and visualization workflows',
    icon: '📊',
    colorTag: '#F39C12',
    projectType: ProjectType.dataProcessing,
    recommendedRoleIds: ['preset_coder', 'preset_validator'],
  );

  /// Daily assistant project
  static const dailyAssistant = ProjectTemplate(
    id: 'daily_assistant',
    name: 'Daily Assistant',
    description:
        'Personal assistant for scheduling, reminders, and daily tasks',
    icon: '🎯',
    colorTag: '#9B59B6',
    projectType: ProjectType.general,
    recommendedRoleIds: ['preset_context_keeper'],
  );

  /// Writing / content project
  static const writing = ProjectTemplate(
    id: 'writing',
    name: 'Writing & Content',
    description:
        'Blog posts, documentation, creative writing, and content creation',
    icon: '✍️',
    colorTag: '#E74C3C',
    projectType: ProjectType.writing,
    recommendedRoleIds: ['preset_coder', 'preset_critic'],
  );
}
