import 'package:flutter_test/flutter_test.dart';
import 'package:coraldesk/models/chat_message.dart';
import 'package:coraldesk/models/chat_session.dart';

void main() {
  group('ChatMessage', () {
    test('creates with required fields', () {
      final msg = ChatMessage(
        id: '1',
        role: 'user',
        content: 'hello',
        timestamp: DateTime(2025, 1, 1),
      );
      expect(msg.id, '1');
      expect(msg.isUser, true);
      expect(msg.isAssistant, false);
      expect(msg.isStreaming, false);
      expect(msg.toolCalls, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final msg = ChatMessage(
        id: '1',
        role: 'assistant',
        content: 'hi',
        timestamp: DateTime(2025, 1, 1),
        isStreaming: true,
      );
      final updated = msg.copyWith(content: 'updated', isStreaming: false);
      expect(updated.id, '1');
      expect(updated.role, 'assistant');
      expect(updated.content, 'updated');
      expect(updated.isStreaming, false);
      expect(updated.timestamp, msg.timestamp);
    });

    test('role helpers work correctly', () {
      expect(
        ChatMessage(
          id: '1',
          role: 'user',
          content: '',
          timestamp: DateTime.now(),
        ).isUser,
        true,
      );
      expect(
        ChatMessage(
          id: '2',
          role: 'assistant',
          content: '',
          timestamp: DateTime.now(),
        ).isAssistant,
        true,
      );
      expect(
        ChatMessage(
          id: '3',
          role: 'system',
          content: '',
          timestamp: DateTime.now(),
        ).isSystem,
        true,
      );
    });
  });

  group('ChatSession', () {
    test('creates with defaults', () {
      final session = ChatSession(
        id: 's1',
        title: 'Test',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(session.messageCount, 0);
      expect(session.attachedFiles, isEmpty);
    });

    test('copyWith preserves id and createdAt', () {
      final session = ChatSession(
        id: 's1',
        title: 'Original',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        messageCount: 5,
      );
      final updated = session.copyWith(title: 'Updated', messageCount: 10);
      expect(updated.id, 's1');
      expect(updated.createdAt, DateTime(2025, 1, 1));
      expect(updated.title, 'Updated');
      expect(updated.messageCount, 10);
    });
  });

  group('ToolCallInfo', () {
    test('creates and copies correctly', () {
      const info = ToolCallInfo(
        id: 't1',
        name: 'read_file',
        arguments: '{"path": "/tmp"}',
      );
      expect(info.status, ToolCallStatus.pending);
      expect(info.result, isNull);

      final completed = info.copyWith(
        result: 'file content',
        success: true,
        status: ToolCallStatus.completed,
      );
      expect(completed.id, 't1');
      expect(completed.name, 'read_file');
      expect(completed.result, 'file content');
      expect(completed.success, true);
      expect(completed.status, ToolCallStatus.completed);
    });
  });
}
