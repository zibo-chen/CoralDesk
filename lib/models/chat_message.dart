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

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.isStreaming = false,
    this.parts,
  });

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    List<ToolCallInfo>? toolCalls,
    bool? isStreaming,
    List<MessagePart>? parts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      isStreaming: isStreaming ?? this.isStreaming,
      parts: parts ?? this.parts,
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
