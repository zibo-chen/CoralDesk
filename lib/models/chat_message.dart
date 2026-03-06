/// A segment of message content, rendered in order.
sealed class MessagePart {
  const MessagePart();
}

/// A text content segment.
class TextPart extends MessagePart {
  final String text;
  const TextPart(this.text);
}

/// A tool call content segment.
class ToolCallPart extends MessagePart {
  final ToolCallInfo toolCall;
  const ToolCallPart(this.toolCall);
}

/// A role header segment — marks a role switch in a multi-agent conversation.
class RoleHeaderPart extends MessagePart {
  final String roleName;
  final String roleColor;
  final String roleIcon;
  const RoleHeaderPart({
    required this.roleName,
    required this.roleColor,
    required this.roleIcon,
  });
}

/// A role handoff segment — marks a task handoff between agents.
class RoleHandoffPart extends MessagePart {
  final String fromRole;
  final String toRole;
  final String summary;
  const RoleHandoffPart({
    required this.fromRole,
    required this.toRole,
    required this.summary,
  });
}

/// Represents a single chat message
class ChatMessage {
  final String id;
  final String role; // 'user', 'assistant', 'system', 'tool'
  final String content;
  final DateTime timestamp;
  final List<ToolCallInfo>? toolCalls;
  final bool isStreaming;

  /// Ordered content parts for assistant messages.
  /// When non-null the UI renders parts in order instead of the flat
  /// [toolCalls] + [content] layout.
  final List<MessagePart>? parts;

  /// The agent role name (e.g. 'architect', 'coder') for multi-agent sessions.
  final String? agentRole;

  /// Hex color for the agent role (e.g. '#4A90D9').
  final String? agentColor;

  /// Emoji icon for the agent role (e.g. '🏗️').
  final String? agentIcon;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.isStreaming = false,
    this.parts,
    this.agentRole,
    this.agentColor,
    this.agentIcon,
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    List<ToolCallInfo>? toolCalls,
    bool? isStreaming,
    List<MessagePart>? parts,
    String? agentRole,
    String? agentColor,
    String? agentIcon,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      isStreaming: isStreaming ?? this.isStreaming,
      parts: parts ?? this.parts,
      agentRole: agentRole ?? this.agentRole,
      agentColor: agentColor ?? this.agentColor,
      agentIcon: agentIcon ?? this.agentIcon,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';
}

/// Tool call information displayed in UI
class ToolCallInfo {
  final String id;
  final String name;
  final String arguments;
  final String? result;
  final bool? success;
  final ToolCallStatus status;

  const ToolCallInfo({
    required this.id,
    required this.name,
    required this.arguments,
    this.result,
    this.success,
    this.status = ToolCallStatus.pending,
  });

  ToolCallInfo copyWith({
    String? result,
    bool? success,
    ToolCallStatus? status,
  }) {
    return ToolCallInfo(
      id: id,
      name: name,
      arguments: arguments,
      result: result ?? this.result,
      success: success ?? this.success,
      status: status ?? this.status,
    );
  }
}

enum ToolCallStatus { pending, running, completed, failed }
