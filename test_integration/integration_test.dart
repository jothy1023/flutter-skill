import 'dart:convert';
import 'dart:io';
import 'dart:async';

void main() async {
  print('=== STARTING SANDBOX VERIFICATION ===');

  // 1. Setup Environment
  final cwd = Directory.current.path;
  final mockFlutterPath = '$cwd/test/bin';
  // Add mock flutter to PATH
  final env = Map<String, String>.from(Platform.environment);
  env['PATH'] = '$mockFlutterPath:${env['PATH']}';

  print('Environment PATH prepended with: $mockFlutterPath');

  // 1.5 Setup Test Dummy
  final dummyDir = Directory('test_dummy');
  if (!dummyDir.existsSync()) {
    print('Creating test_dummy project...');
    dummyDir.createSync();
    File('test_dummy/pubspec.yaml').writeAsStringSync('''
name: test_dummy
description: A new Flutter project.
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  flutter_skill:
    path: ../
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    Directory('test_dummy/lib').createSync(recursive: true);
    File('test_dummy/lib/main.dart').writeAsStringSync('''
import 'package:flutter/material.dart';
void main() { runApp(const MyApp()); }
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: Text('Hello')));
  }
}
''');
  }

  // 2. Test "flutter_skill.dart launch" (CLI Automation)
  print('\n[TEST 1] Testing flutter_skill.dart launch ...');
  final launchProcess = await Process.start(
    'dart',
    ['run', 'bin/flutter_skill.dart', 'launch', 'test_dummy'],
    environment: env,
    mode: ProcessStartMode.normal,
  );

  // Pipe stdout/stderr to see what's happening
  launchProcess.stdout.transform(utf8.decoder).listen((data) {
    print('[LAUNCH STDOUT]: $data');
  });
  launchProcess.stderr.transform(utf8.decoder).listen((data) {
    print('[LAUNCH STDERR]: $data');
  });

  // We need to wait for .flutter_skill_uri to appear.
  final uriFile = File('.flutter_skill_uri');
  if (uriFile.existsSync()) uriFile.deleteSync();

  // Poll for file
  int attempts = 0;
  String? uri;
  while (attempts < 20) {
    await Future.delayed(Duration(milliseconds: 500));
    if (uriFile.existsSync()) {
      uri = uriFile.readAsStringSync();
      if (uri.startsWith('ws://')) break;
    }
    attempts++;
  }

  if (uri == null) {
    print('[FAIL] Test 1: flutter_skill.dart launch did not produce URI file.');
    launchProcess.kill();
    exit(1);
  }
  print('[PASS] Test 1: flutter_skill.dart launch produced URI: $uri');

  // 3. Test "flutter_skill.dart inspect" (CLI Interaction)
  print('\n[TEST 2] Testing flutter_skill.dart inspect against running mock...');
  final inspectProcess = await Process.start('dart', [
    'run',
    'bin/flutter_skill.dart',
    'inspect',
  ]);
  final inspectStdout = StringBuffer();

  inspectProcess.stdout.transform(utf8.decoder).listen((data) {
    print('[INSPECT STDOUT]: $data');
    inspectStdout.write(data);
  });
  inspectProcess.stderr
      .transform(utf8.decoder)
      .listen((data) => print('[INSPECT STDERR]: $data'));

  final inspectExitCode = await inspectProcess.exitCode;

  if (inspectExitCode != 0) {
    print('[FAIL] flutter_skill.dart inspect failed');
    inspectProcess.kill();
    exit(1);
  }

  print('[PASS] Test 2: flutter_skill.dart inspect exited with $inspectExitCode');

  if (!inspectStdout.toString().contains('login_btn')) {
    print(
      '[FAIL] flutter_skill.dart inspect did not find "login_btn". Output:\n${inspectStdout.toString()}',
    );
    exit(1);
  }
  print('[PASS] Test 2: flutter_skill.dart inspect found elements.');

  // 4. Test "flutter_skill.dart act" (CLI Action)
  print('\n[TEST 3] Testing flutter_skill.dart act tap...');
  final actRes = await Process.run('dart', [
    'run',
    'bin/flutter_skill.dart',
    'act',
    'tap',
    'login_btn',
  ]);
  if (actRes.exitCode != 0) {
    print('[FAIL] flutter_skill.dart act failed: ${actRes.stderr}');
    exit(1);
  }
  print('[PASS] Test 3: flutter_skill.dart act executed successfully.');

  // 5. Test "server.dart" (MCP Mode)
  print('\n[TEST 4] Testing server.dart (MCP Mode)...');
  // We spawn server.dart
  final serverProcess = await Process.start('dart', ['run', 'bin/server.dart']);

  // We send JSON-RPC commands
  final stdin = serverProcess.stdin;
  final stdoutStream = serverProcess.stdout
      .transform(SystemEncoding().decoder)
      .transform(const LineSplitter())
      .asBroadcastStream();

  // A. Connect
  final connectReq =
      '{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "connect_app", "arguments": {"uri": "$uri"}}}';
  stdin.writeln(connectReq);

  // Listener for server responses
  final completerT4 = Completer<bool>();

  stdoutStream.listen((line) {
    print('[MCP Server Output]: $line');
    if (line.contains('"result"')) {
      try {
        final json = jsonDecode(line);
        final result = json['result'];
        if (result != null) {
          // Check for connection success
          if (result['content'] != null) {
            final content = result['content'][0]['text'];
            final contentJson = jsonDecode(content);

            if (contentJson['success'] == true &&
                contentJson['message']?.contains('Connected') == true) {
              print('[PASS] MCP Connect success');
              // B. Tap via MCP
              final tapReq =
                  '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "tap", "arguments": {"key": "login_btn"}}}';
              stdin.writeln(tapReq);
            } else if (contentJson['success'] == true &&
                contentJson['message']?.contains('Tap') == true) {
              print('[PASS] MCP Tap success');
              completerT4.complete(true);
            }
          }
        }
      } catch (e) {
        // Ignore JSON parse errors, just print the line
      }
    }
  });

  try {
    await completerT4.future.timeout(Duration(seconds: 5));
  } catch (e) {
    print('[FAIL] Test 4: MCP Server timed out or failed.');
    serverProcess.kill();
    launchProcess.kill();
    exit(1);
  }

  // Cleanup
  serverProcess.kill();
  launchProcess.kill();

  print('\n=== ALL TESTS PASSED ===');
  exit(0);
}
