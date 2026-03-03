import 'package:flutter_test/flutter_test.dart';
import 'package:coraldesk/providers/chat_provider.dart';
import 'package:coraldesk/models/chat_message.dart';

ChatMessage _msg(String id, {String role = 'user', String content = ''}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    timestamp: DateTime(2025, 1, 1),
  );
}

void main() {
  late MessagesNotifier notifier;

  setUp(() {
    notifier = MessagesNotifier();
  });

  group('MessagesNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state, isEmpty);
    });

    // ── switchToSession ────────────────────────

    group('switchToSession', () {
      test('switching to null clears state', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.switchToSession(null);
        expect(notifier.state, isEmpty);
      });

      test('switching saves current and loads target', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        expect(notifier.state, hasLength(1));

        notifier.switchToSession('s2');
        expect(notifier.state, isEmpty);

        notifier.addMessageToSession('s2', _msg('m2'));
        notifier.switchToSession('s1');
        expect(notifier.state, hasLength(1));
        expect(notifier.state.first.id, 'm1');
      });

      test('switching to same session is a no-op', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.switchToSession('s1');
        expect(notifier.state, hasLength(1));
      });
    });

    // ── addMessageToSession ────────────────────

    group('addMessageToSession', () {
      test('adds to active session and updates state', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        expect(notifier.state.length, 1);
        expect(notifier.state.first.id, 'm1');
      });

      test('adds to background session without updating state', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s2', _msg('m2'));
        expect(notifier.state, isEmpty);
        // Verify it was cached
        expect(notifier.getSessionMessages('s2'), hasLength(1));
      });
    });

    // ── updateAssistant ────────────────────────

    group('updateAssistant', () {
      test('updates last assistant message content', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession(
          's1',
          _msg('a1', role: 'assistant', content: 'hello'),
        );
        notifier.updateAssistant('s1', 'hello world');
        expect(notifier.state.last.content, 'hello world');
      });

      test('updates streaming flag', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession(
          's1',
          _msg('a1', role: 'assistant', content: ''),
        );
        notifier.updateAssistant('s1', 'streaming...', isStreaming: true);
        expect(notifier.state.last.isStreaming, true);
        notifier.updateAssistant('s1', 'done', isStreaming: false);
        expect(notifier.state.last.isStreaming, false);
      });

      test('does nothing if last message is not assistant', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('u1', role: 'user'));
        notifier.updateAssistant('s1', 'should not apply');
        expect(notifier.state.last.role, 'user');
      });

      test('works on background session', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession(
          's2',
          _msg('a1', role: 'assistant', content: ''),
        );
        notifier.updateAssistant('s2', 'bg update');
        expect(notifier.state, isEmpty); // s1 is active
        expect(notifier.getSessionMessages('s2').last.content, 'bg update');
      });
    });

    // ── getSessionMessages ─────────────────────

    group('getSessionMessages', () {
      test('returns copy of messages for active session', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        final messages = notifier.getSessionMessages('s1');
        expect(messages, hasLength(1));
        // Verify it's a copy (mutating returned list doesn't affect state)
        messages.add(_msg('m2'));
        expect(notifier.state, hasLength(1));
      });

      test('returns empty list for unknown session', () {
        expect(notifier.getSessionMessages('nope'), isEmpty);
      });
    });

    // ── setSessionMessages ─────────────────────

    group('setSessionMessages', () {
      test('replaces messages for active session', () {
        notifier.switchToSession('s1');
        notifier.setSessionMessages('s1', [_msg('a'), _msg('b')]);
        expect(notifier.state, hasLength(2));
        expect(notifier.state.first.id, 'a');
      });

      test('replaces messages for background session', () {
        notifier.switchToSession('s1');
        notifier.setSessionMessages('s2', [_msg('x')]);
        expect(notifier.state, isEmpty);
        expect(notifier.getSessionMessages('s2'), hasLength(1));
      });
    });

    // ── removeSession ──────────────────────────

    group('removeSession', () {
      test('removes active session and clears state', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.removeSession('s1');
        expect(notifier.state, isEmpty);
        expect(notifier.getSessionMessages('s1'), isEmpty);
      });

      test('removes background session silently', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.addMessageToSession('s2', _msg('m2'));
        notifier.removeSession('s2');
        expect(notifier.state, hasLength(1)); // s1 unaffected
        expect(notifier.getSessionMessages('s2'), isEmpty);
      });
    });

    // ── clear ──────────────────────────────────

    group('clear', () {
      test('clears active session messages', () {
        notifier.switchToSession('s1');
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.clear();
        expect(notifier.state, isEmpty);
        expect(notifier.getSessionMessages('s1'), isEmpty);
      });

      test('does nothing when no active session', () {
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.clear(); // no active session
        expect(notifier.getSessionMessages('s1'), hasLength(1));
      });
    });

    // ── syncActiveToCache ──────────────────────

    group('syncActiveToCache', () {
      test('persists current state into cache', () {
        notifier.switchToSession('s1');
        // Directly mutate state (simulating what build() does before calling sync)
        notifier.addMessageToSession('s1', _msg('m1'));
        notifier.syncActiveToCache();
        // Switch away and back to see if it was cached
        notifier.switchToSession('s2');
        notifier.switchToSession('s1');
        expect(notifier.state, hasLength(1));
      });
    });
  });
}
