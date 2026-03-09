import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Result of testing an MCP server connection.
class McpTestResult {
  final bool success;
  final String? error;
  final List<McpToolInfo> tools;
  final String serverName;
  final Duration elapsed;

  const McpTestResult({
    required this.success,
    this.error,
    this.tools = const [],
    required this.serverName,
    required this.elapsed,
  });

  int get toolCount => tools.length;
}

/// Information about a single MCP tool.
class McpToolInfo {
  final String name;
  final String description;

  const McpToolInfo({required this.name, required this.description});
}

/// Pure-Dart MCP test client that can connect to a server, perform the
/// initialize handshake, and fetch the tool list.
///
/// This is used purely for UI feedback — the actual MCP tool execution is
/// handled by the Rust backend.
class McpTestClient {
  static const _protocolVersion = '2024-11-05';
  static const _timeout = Duration(seconds: 30);

  /// Test a stdio-based MCP server.
  static Future<McpTestResult> testStdio({
    required String serverName,
    required String command,
    required List<String> args,
    Map<String, String> env = const {},
  }) async {
    final sw = Stopwatch()..start();
    Process? process;
    _StdioJsonRpcReader? reader;

    try {
      // Resolve full command path
      final resolvedCommand = _resolveCommand(command);

      // Merge environment
      final mergedEnv = Map<String, String>.from(Platform.environment)
        ..addAll(env);

      process = await Process.start(
        resolvedCommand,
        args,
        environment: mergedEnv,
      );

      // Create a single reader for the process stdout — avoids
      // "Stream has already been listened to" errors.
      reader = _StdioJsonRpcReader(process.stdout);

      // Initialize handshake
      final initReq = _buildJsonRpc(1, 'initialize', {
        'protocolVersion': _protocolVersion,
        'capabilities': {},
        'clientInfo': {'name': 'deskclaw-test', 'version': '1.0.0'},
      });

      process.stdin.writeln(jsonEncode(initReq));
      await process.stdin.flush();

      final initResp = await reader.nextResponse().timeout(
        _timeout,
        onTimeout: () => throw TimeoutException(
          'Server timed out during initialize',
          _timeout,
        ),
      );

      if (initResp['error'] != null) {
        throw Exception(
          'Initialize rejected: ${initResp['error']['message'] ?? initResp['error']}',
        );
      }

      // Send initialized notification
      final notif = _buildJsonRpcNotification('notifications/initialized', {});
      process.stdin.writeln(jsonEncode(notif));
      await process.stdin.flush();

      // Small delay for notification to be processed
      await Future.delayed(const Duration(milliseconds: 100));

      // Fetch tools
      final listReq = _buildJsonRpc(2, 'tools/list', {});
      process.stdin.writeln(jsonEncode(listReq));
      await process.stdin.flush();

      final listResp = await reader.nextResponse().timeout(
        _timeout,
        onTimeout: () => throw TimeoutException(
          'Server timed out during tools/list',
          _timeout,
        ),
      );

      if (listResp['error'] != null) {
        throw Exception(
          'tools/list failed: ${listResp['error']['message'] ?? listResp['error']}',
        );
      }

      final result = listResp['result'] as Map<String, dynamic>? ?? {};
      final toolsList = (result['tools'] as List<dynamic>?) ?? [];

      final tools = toolsList.map((t) {
        final tool = t as Map<String, dynamic>;
        return McpToolInfo(
          name: tool['name']?.toString() ?? 'unknown',
          description: tool['description']?.toString() ?? '',
        );
      }).toList();

      sw.stop();
      return McpTestResult(
        success: true,
        tools: tools,
        serverName: serverName,
        elapsed: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      return McpTestResult(
        success: false,
        error: e.toString(),
        serverName: serverName,
        elapsed: sw.elapsed,
      );
    } finally {
      await reader?.dispose();
      process?.kill();
    }
  }

  /// Test an HTTP-based MCP server.
  static Future<McpTestResult> testHttp({
    required String serverName,
    required String url,
    Map<String, String> headers = const {},
  }) async {
    final sw = Stopwatch()..start();
    final client = HttpClient();

    try {
      final uri = Uri.parse(url);

      // Initialize handshake
      final initReq = _buildJsonRpc(1, 'initialize', {
        'protocolVersion': _protocolVersion,
        'capabilities': {},
        'clientInfo': {'name': 'deskclaw-test', 'version': '1.0.0'},
      });

      final initResp = await _httpPost(client, uri, initReq, headers);

      if (initResp['error'] != null) {
        throw Exception(
          'Initialize rejected: ${initResp['error']['message'] ?? initResp['error']}',
        );
      }

      // Extract session ID if present
      final sessionHeaders = Map<String, String>.from(headers);
      // Session ID would be in response headers in a real HTTP transport,
      // but for test purposes we just proceed

      // Fetch tools
      final listReq = _buildJsonRpc(2, 'tools/list', {});
      final listResp = await _httpPost(client, uri, listReq, sessionHeaders);

      if (listResp['error'] != null) {
        throw Exception(
          'tools/list failed: ${listResp['error']['message'] ?? listResp['error']}',
        );
      }

      final result = listResp['result'] as Map<String, dynamic>? ?? {};
      final toolsList = (result['tools'] as List<dynamic>?) ?? [];

      final tools = toolsList.map((t) {
        final tool = t as Map<String, dynamic>;
        return McpToolInfo(
          name: tool['name']?.toString() ?? 'unknown',
          description: tool['description']?.toString() ?? '',
        );
      }).toList();

      sw.stop();
      return McpTestResult(
        success: true,
        tools: tools,
        serverName: serverName,
        elapsed: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      return McpTestResult(
        success: false,
        error: e.toString(),
        serverName: serverName,
        elapsed: sw.elapsed,
      );
    } finally {
      client.close();
    }
  }

  // ── Helpers ──

  static String _resolveCommand(String command) {
    // If it's an absolute path, use it directly
    if (command.startsWith('/')) return command;

    // Try to resolve relative commands via common paths
    final pathDirs = (Platform.environment['PATH'] ?? '').split(':');

    // Also add common locations for node/npx/python etc.
    final extraDirs = [
      '/usr/local/bin',
      '/opt/homebrew/bin',
      '${Platform.environment['HOME']}/.local/bin',
      '${Platform.environment['HOME']}/.nvm/versions/node',
    ];

    for (final dir in [...pathDirs, ...extraDirs]) {
      final fullPath = '$dir/$command';
      if (File(fullPath).existsSync()) return fullPath;
    }

    // Fall back to the command as-is (will fail if not in PATH)
    return command;
  }

  static Map<String, dynamic> _buildJsonRpc(
    int id,
    String method,
    Map<String, dynamic> params,
  ) {
    return {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params};
  }

  static Map<String, dynamic> _buildJsonRpcNotification(
    String method,
    Map<String, dynamic> params,
  ) {
    return {'jsonrpc': '2.0', 'method': method, 'params': params};
  }

  static Future<Map<String, dynamic>> _httpPost(
    HttpClient client,
    Uri uri,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) async {
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json, text/event-stream');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.write(jsonEncode(body));
    final response = await request.close().timeout(_timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }
}

/// Reads JSON-RPC responses from a single-subscription stdout stream.
/// Listens only once and queues incoming JSON-RPC response objects so
/// multiple calls to [nextResponse] work without re-subscribing.
class _StdioJsonRpcReader {
  final StreamSubscription<String> _subscription;
  final List<Map<String, dynamic>> _pending = [];
  final List<Completer<Map<String, dynamic>>> _waiters = [];
  bool _done = false;
  Object? _streamError;
  final StringBuffer _lineBuffer = StringBuffer();

  _StdioJsonRpcReader(Stream<List<int>> stdout)
    : _subscription = stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(null) {
    _subscription.onData(_onLine);
    _subscription.onError(_onError);
    _subscription.onDone(_onDone);
  }

  void _onLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      _lineBuffer.write(trimmed);
      try {
        json = jsonDecode(_lineBuffer.toString()) as Map<String, dynamic>;
        _lineBuffer.clear();
      } catch (_) {
        // continue accumulating
        return;
      }
    }

    // Only queue responses (with id), skip notifications
    if (!json.containsKey('id')) return;

    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(json);
    } else {
      _pending.add(json);
    }
  }

  void _onError(Object error) {
    _streamError = error;
    for (final w in _waiters) {
      w.completeError(error);
    }
    _waiters.clear();
  }

  void _onDone() {
    _done = true;
    final err = Exception('Server closed stdout unexpectedly');
    for (final w in _waiters) {
      w.completeError(err);
    }
    _waiters.clear();
  }

  /// Wait for the next JSON-RPC response object.
  Future<Map<String, dynamic>> nextResponse() {
    if (_pending.isNotEmpty) {
      return Future.value(_pending.removeAt(0));
    }
    if (_streamError != null) {
      return Future.error(_streamError!);
    }
    if (_done) {
      return Future.error(Exception('Server closed stdout unexpectedly'));
    }
    final c = Completer<Map<String, dynamic>>();
    _waiters.add(c);
    return c.future;
  }

  Future<void> dispose() async {
    await _subscription.cancel();
  }
}
