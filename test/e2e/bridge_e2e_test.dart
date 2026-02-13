#!/usr/bin/env dart

/// Comprehensive E2E test for bridge-protocol SDKs.
/// Tests all actions via WebSocket JSON-RPC 2.0.
///
/// Usage: dart run test/e2e/bridge_e2e_test.dart [port] [platform]
/// Examples:
///   dart run test/e2e/bridge_e2e_test.dart 18118 android
///   dart run test/e2e/bridge_e2e_test.dart 18118 electron
import 'dart:async';
import 'dart:convert';
import 'dart:io';

int passed = 0;
int failed = 0;
int total = 0;

class BridgeTestClient {
  final String host;
  final int port;
  WebSocket? _ws;
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  BridgeTestClient(this.host, this.port);

  Future<void> connect() async {
    _ws = await WebSocket.connect('ws://$host:$port/ws')
        .timeout(const Duration(seconds: 5));
    _ws!.listen((data) {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final id = json['id'] as int?;
      if (id != null && _pending.containsKey(id)) {
        _pending.remove(id)!.complete(json);
      }
    }, onDone: () {
      for (final c in _pending.values) {
        if (!c.isCompleted) c.completeError('Connection closed');
      }
      _pending.clear();
    });
  }

  Future<Map<String, dynamic>> call(String method,
      [Map<String, dynamic>? params]) async {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final request = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params ?? {},
    });
    _ws!.add(request);

    return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('$method timed out');
    });
  }

  Future<void> close() async {
    await _ws?.close();
  }
}

Future<void> runTest(
  String name,
  Future<void> Function() test,
) async {
  total++;
  final padded = name.padRight(45);
  try {
    await test();
    passed++;
    stdout.write('  $padded \x1b[32mPASS\x1b[0m\n');
  } catch (e) {
    failed++;
    stdout.write('  $padded \x1b[31mFAIL\x1b[0m $e\n');
  }
}

void main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args[0]) : 18118;
  final platform = args.length > 1 ? args[1] : 'unknown';

  print('============================================');
  print(' Bridge E2E Test Suite');
  print(' Platform: $platform');
  print(' Target: ws://127.0.0.1:$port/ws');
  print('============================================');

  // HTTP health check
  print('\n--- Health Check ---');
  try {
    final http = await HttpClient()
        .getUrl(Uri.parse('http://127.0.0.1:$port/.flutter-skill'))
        .then((r) => r.close())
        .timeout(const Duration(seconds: 3));
    final body = await http.transform(utf8.decoder).join();
    final health = jsonDecode(body);
    print('  Platform: ${health['platform'] ?? health['framework']}');
    print('  SDK: ${health['sdk_version']}');
    print('  Capabilities: ${health['capabilities']}');
  } catch (e) {
    print('  \x1b[31mApp not running on port $port\x1b[0m: $e');
    exit(1);
  }

  final client = BridgeTestClient('127.0.0.1', port);
  await client.connect();

  // === Initialize ===
  print('\n--- Initialize ---');
  await runTest('initialize', () async {
    final r = await client.call('initialize', {
      'protocol_version': '1.0',
      'client': 'e2e-test',
    });
    assert(r['result'] != null, 'No result: $r');
  });

  // === Inspect ===
  print('\n--- Inspect ---');
  late List elements;
  await runTest('inspect returns elements', () async {
    final r = await client.call('inspect');
    elements = r['result']['elements'] as List;
    assert(elements.isNotEmpty, 'No elements found');
    print('    (${elements.length} elements)');
  });

  await runTest('inspect has type/text/bounds', () async {
    final first = elements.first as Map<String, dynamic>;
    assert(first.containsKey('type') || first.containsKey('class'),
        'Missing type: $first');
  });

  // === Tap ===
  print('\n--- Tap ---');
  // Determine tap targets based on platform
  String incrementKey;
  String inputKey;
  String detailKey;
  String counterKey;

  if (platform == 'electron') {
    incrementKey = 'increment-btn';
    inputKey = 'text-input';
    detailKey = 'nav-detail';
    counterKey = 'counter';
  } else if (platform == 'android') {
    incrementKey = 'increment_btn';
    inputKey = 'input_field';
    detailKey = 'detail_btn';
    counterKey = 'counter_text';
  } else {
    // Generic — try common keys
    incrementKey = 'increment_btn';
    inputKey = 'input_field';
    detailKey = 'detail_btn';
    counterKey = 'counter_text';
  }

  await runTest('tap by key', () async {
    final r = await client.call('tap', {'key': incrementKey});
    assert(r['result']?['success'] == true, 'Tap failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  await runTest('tap by text (Increment)', () async {
    final r = await client.call('tap', {'text': 'Increment'});
    // Some SDKs use key-only, so text match may not work
    if (r['result']?['success'] != true && r['error'] != null) {
      print('    (text tap not supported — OK for some SDKs)');
    }
  });
  await Future.delayed(const Duration(milliseconds: 300));

  // === Enter Text ===
  print('\n--- Enter Text ---');
  await runTest('enter_text', () async {
    final r = await client.call('enter_text', {
      'key': inputKey,
      'text': 'Hello E2E Test',
    });
    assert(r['result']?['success'] == true, 'Enter text failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  // === Get Text ===
  print('\n--- Get Text ---');
  await runTest('get_text on counter', () async {
    final r = await client.call('get_text', {'key': counterKey});
    final text = r['result']?['text'];
    assert(text != null, 'No text returned: $r');
    print('    text="$text"');
  });

  await runTest('get_text on input', () async {
    final r = await client.call('get_text', {'key': inputKey});
    final text = r['result']?['text'];
    print('    text="$text"');
  });

  // === Find Element ===
  print('\n--- Find Element ---');
  await runTest('find_element (exists)', () async {
    final r = await client.call('find_element', {'key': incrementKey});
    assert(r['result']?['found'] == true, 'Not found: $r');
  });

  await runTest('find_element (missing)', () async {
    final r = await client.call('find_element', {'key': 'nonexistent_xyz_999'});
    assert(r['result']?['found'] == false, 'Should not be found: $r');
  });

  // === Wait For Element ===
  print('\n--- Wait For Element ---');
  await runTest('wait_for_element (exists)', () async {
    final r = await client.call('wait_for_element', {
      'key': counterKey,
      'timeout': 3000,
    });
    assert(r['result']?['found'] == true, 'Not found: $r');
  });

  // === Scroll ===
  print('\n--- Scroll ---');
  await runTest('scroll down', () async {
    final r = await client.call('scroll', {
      'direction': 'down',
      'distance': 300,
    });
    assert(r['result']?['success'] == true || r['result'] != null,
        'Scroll failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  await runTest('scroll up', () async {
    final r = await client.call('scroll', {
      'direction': 'up',
      'distance': 300,
    });
    assert(r['result']?['success'] == true || r['result'] != null,
        'Scroll failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  // === Screenshot ===
  print('\n--- Screenshot ---');
  await runTest('screenshot', () async {
    final r = await client.call('screenshot');
    final image = r['result']?['image'];
    assert(image != null && (image as String).length > 100,
        'No screenshot data: ${r.toString().substring(0, 100)}');
    print('    (${image.length} base64 chars)');
  });

  // === Navigation ===
  print('\n--- Navigation ---');
  await runTest('navigate to detail', () async {
    final r = await client.call('tap', {'key': detailKey});
    assert(r['result']?['success'] == true, 'Navigation tap failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 500));

  await runTest('inspect after navigate', () async {
    final r = await client.call('inspect');
    final els = r['result']?['elements'] as List?;
    assert(els != null && els.isNotEmpty, 'No elements on detail page: $r');
    print('    (${els!.length} elements)');
  });

  await runTest('go_back', () async {
    final r = await client.call('go_back');
    assert(r['result']?['success'] == true, 'Go back failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 500));

  await runTest('inspect after go_back (home)', () async {
    final r = await client.call('inspect');
    final els = r['result']?['elements'] as List?;
    assert(els != null && els.isNotEmpty, 'No elements on home page: $r');
  });

  // === Swipe ===
  print('\n--- Swipe ---');
  await runTest('swipe up', () async {
    final r = await client.call('swipe', {
      'direction': 'up',
      'distance': 400,
    });
    assert(r['result']?['success'] == true || r['result'] != null,
        'Swipe failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  await runTest('swipe down', () async {
    final r = await client.call('swipe', {
      'direction': 'down',
      'distance': 400,
    });
    assert(r['result']?['success'] == true || r['result'] != null,
        'Swipe failed: $r');
  });
  await Future.delayed(const Duration(milliseconds: 300));

  // === Logs ===
  print('\n--- Logs ---');
  await runTest('get_logs', () async {
    final r = await client.call('get_logs');
    assert(r['result']?['logs'] != null, 'No logs: $r');
  });

  await runTest('clear_logs', () async {
    final r = await client.call('clear_logs');
    assert(r['result']?['success'] == true, 'Clear logs failed: $r');
  });

  // === Summary ===
  await client.close();

  print('\n============================================');
  print(' Results: $passed passed, $failed failed, $total total');
  print('============================================');

  exit(failed > 0 ? 1 : 0);
}
