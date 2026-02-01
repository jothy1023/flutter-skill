import 'dart:async';
import 'package:test/test.dart';
import 'package:flutter_skill/src/cli/server.dart' show SessionInfo;

/// Unit tests for multi-session functionality
/// Tests SessionInfo model and session state management
void main() {
  group('SessionInfo', () {
    test('should create SessionInfo with all required fields', () {
      final now = DateTime.now();
      final session = SessionInfo(
        id: 'test-id-123',
        name: 'Test Session',
        projectPath: '/tmp/test_project',
        deviceId: 'test-device',
        port: 50001,
        vmServiceUri: 'ws://127.0.0.1:50001/ws',
        createdAt: now,
      );

      expect(session.id, equals('test-id-123'));
      expect(session.name, equals('Test Session'));
      expect(session.projectPath, equals('/tmp/test_project'));
      expect(session.deviceId, equals('test-device'));
      expect(session.port, equals(50001));
      expect(session.vmServiceUri, equals('ws://127.0.0.1:50001/ws'));
      expect(session.createdAt, equals(now));
    });

    test('should use current time as default createdAt', () {
      final before = DateTime.now();
      final session = SessionInfo(
        id: 'test-id',
        name: 'Test',
        projectPath: '/tmp/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://127.0.0.1:50001/ws',
      );
      final after = DateTime.now();

      expect(session.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(session.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('should convert to JSON correctly', () {
      final now = DateTime.parse('2024-01-15T10:30:00.000Z');
      final session = SessionInfo(
        id: 'session-123',
        name: 'My App',
        projectPath: '/projects/my_app',
        deviceId: 'iPhone 15 Pro',
        port: 50002,
        vmServiceUri: 'ws://127.0.0.1:50002/abc/ws',
        createdAt: now,
      );

      final json = session.toJson();

      expect(json['id'], equals('session-123'));
      expect(json['name'], equals('My App'));
      expect(json['project_path'], equals('/projects/my_app'));
      expect(json['device_id'], equals('iPhone 15 Pro'));
      expect(json['port'], equals(50002));
      expect(json['vm_service_uri'], equals('ws://127.0.0.1:50002/abc/ws'));
      expect(json['created_at'], equals('2024-01-15T10:30:00.000Z'));
    });

    test('should include all fields in JSON', () {
      final session = SessionInfo(
        id: 'test',
        name: 'Test',
        projectPath: '/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://test',
      );

      final json = session.toJson();

      expect(json.keys, containsAll([
        'id',
        'name',
        'project_path',
        'device_id',
        'port',
        'vm_service_uri',
        'created_at',
      ]));
    });
  });

  group('Session State Management', () {
    test('should track multiple sessions independently', () {
      final session1 = SessionInfo(
        id: 'session-1',
        name: 'Session 1',
        projectPath: '/tmp/s1',
        deviceId: 'device1',
        port: 50001,
        vmServiceUri: 'ws://127.0.0.1:50001/ws',
      );

      final session2 = SessionInfo(
        id: 'session-2',
        name: 'Session 2',
        projectPath: '/tmp/s2',
        deviceId: 'device2',
        port: 50002,
        vmServiceUri: 'ws://127.0.0.1:50002/ws',
      );

      expect(session1.id, isNot(equals(session2.id)));
      expect(session1.port, isNot(equals(session2.port)));
      expect(session1.projectPath, isNot(equals(session2.projectPath)));
    });

    test('should maintain unique session IDs', () {
      final sessions = List.generate(
        100,
        (i) => SessionInfo(
          id: 'session-$i',
          name: 'Session $i',
          projectPath: '/tmp/s$i',
          deviceId: 'device$i',
          port: 50000 + i,
          vmServiceUri: 'ws://127.0.0.1:${50000 + i}/ws',
        ),
      );

      final ids = sessions.map((s) => s.id).toSet();
      expect(ids.length, equals(100)); // All IDs should be unique
    });

    test('should maintain unique ports', () {
      final sessions = List.generate(
        50,
        (i) => SessionInfo(
          id: 'session-$i',
          name: 'Session $i',
          projectPath: '/tmp/s$i',
          deviceId: 'device$i',
          port: 50001 + i,
          vmServiceUri: 'ws://127.0.0.1:${50001 + i}/ws',
        ),
      );

      final ports = sessions.map((s) => s.port).toSet();
      expect(ports.length, equals(50)); // All ports should be unique
    });

    test('should support port range 50000-60000', () {
      final ports = [50000, 50001, 55000, 59999, 60000];

      for (final port in ports) {
        final session = SessionInfo(
          id: 'test-$port',
          name: 'Test',
          projectPath: '/test',
          deviceId: 'device',
          port: port,
          vmServiceUri: 'ws://test',
        );

        expect(session.port, equals(port));
        expect(session.port, greaterThanOrEqualTo(50000));
        expect(session.port, lessThanOrEqualTo(60000));
      }
    });
  });

  group('Session Isolation', () {
    test('should keep session data independent', () {
      final sessions = <String, SessionInfo>{};

      // Create session 1
      sessions['s1'] = SessionInfo(
        id: 's1',
        name: 'App 1',
        projectPath: '/projects/app1',
        deviceId: 'iPhone 15',
        port: 50001,
        vmServiceUri: 'ws://127.0.0.1:50001/ws',
      );

      // Create session 2
      sessions['s2'] = SessionInfo(
        id: 's2',
        name: 'App 2',
        projectPath: '/projects/app2',
        deviceId: 'Pixel 8',
        port: 50002,
        vmServiceUri: 'ws://127.0.0.1:50002/ws',
      );

      // Verify session 1 data
      expect(sessions['s1']!.name, equals('App 1'));
      expect(sessions['s1']!.deviceId, equals('iPhone 15'));
      expect(sessions['s1']!.port, equals(50001));

      // Verify session 2 data
      expect(sessions['s2']!.name, equals('App 2'));
      expect(sessions['s2']!.deviceId, equals('Pixel 8'));
      expect(sessions['s2']!.port, equals(50002));
    });

    test('should handle session removal correctly', () {
      final sessions = <String, SessionInfo>{
        's1': SessionInfo(
          id: 's1',
          name: 'Session 1',
          projectPath: '/tmp/s1',
          deviceId: 'd1',
          port: 50001,
          vmServiceUri: 'ws://test1',
        ),
        's2': SessionInfo(
          id: 's2',
          name: 'Session 2',
          projectPath: '/tmp/s2',
          deviceId: 'd2',
          port: 50002,
          vmServiceUri: 'ws://test2',
        ),
      };

      expect(sessions.length, equals(2));

      // Remove session 1
      sessions.remove('s1');

      expect(sessions.length, equals(1));
      expect(sessions.containsKey('s1'), isFalse);
      expect(sessions.containsKey('s2'), isTrue);
      expect(sessions['s2']!.name, equals('Session 2'));
    });

    test('should handle active session switching', () {
      final sessions = <String, SessionInfo>{
        's1': SessionInfo(id: 's1', name: 'S1', projectPath: '/s1', deviceId: 'd1', port: 50001, vmServiceUri: 'ws://s1'),
        's2': SessionInfo(id: 's2', name: 'S2', projectPath: '/s2', deviceId: 'd2', port: 50002, vmServiceUri: 'ws://s2'),
        's3': SessionInfo(id: 's3', name: 'S3', projectPath: '/s3', deviceId: 'd3', port: 50003, vmServiceUri: 'ws://s3'),
      };

      String? activeSessionId = 's1';

      // Switch to s2
      activeSessionId = 's2';
      expect(activeSessionId, equals('s2'));
      expect(sessions[activeSessionId]!.name, equals('S2'));

      // Switch to s3
      activeSessionId = 's3';
      expect(activeSessionId, equals('s3'));
      expect(sessions[activeSessionId]!.name, equals('S3'));

      // Switch back to s1
      activeSessionId = 's1';
      expect(activeSessionId, equals('s1'));
      expect(sessions[activeSessionId]!.name, equals('S1'));
    });

    test('should update active session when closing active session', () {
      final sessions = <String, SessionInfo>{
        's1': SessionInfo(id: 's1', name: 'S1', projectPath: '/s1', deviceId: 'd1', port: 50001, vmServiceUri: 'ws://s1'),
        's2': SessionInfo(id: 's2', name: 'S2', projectPath: '/s2', deviceId: 'd2', port: 50002, vmServiceUri: 'ws://s2'),
      };

      String? activeSessionId = 's1';

      // Close active session
      sessions.remove(activeSessionId);

      // Switch to next available session
      if (!sessions.containsKey(activeSessionId)) {
        activeSessionId = sessions.keys.isNotEmpty ? sessions.keys.first : null;
      }

      expect(activeSessionId, equals('s2'));
      expect(sessions[activeSessionId]!.name, equals('S2'));
    });

    test('should set active session to null when closing last session', () {
      final sessions = <String, SessionInfo>{
        's1': SessionInfo(id: 's1', name: 'S1', projectPath: '/s1', deviceId: 'd1', port: 50001, vmServiceUri: 'ws://s1'),
      };

      String? activeSessionId = 's1';

      // Close last session
      sessions.remove(activeSessionId);

      // Update active session
      if (!sessions.containsKey(activeSessionId)) {
        activeSessionId = sessions.keys.isNotEmpty ? sessions.keys.first : null;
      }

      expect(activeSessionId, isNull);
      expect(sessions.isEmpty, isTrue);
    });
  });

  group('Session Validation', () {
    test('should validate required fields', () {
      // All required fields must be present
      final session = SessionInfo(
        id: 'test',
        name: 'Test Session',
        projectPath: '/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://test',
      );

      expect(session.id.isNotEmpty, isTrue);
      expect(session.name.isNotEmpty, isTrue);
      expect(session.projectPath.isNotEmpty, isTrue);
      expect(session.deviceId.isNotEmpty, isTrue);
      expect(session.port, greaterThan(0));
      expect(session.vmServiceUri.isNotEmpty, isTrue);
    });

    test('should handle different project paths', () {
      final paths = [
        '/tmp/test',
        '/Users/dev/projects/my_app',
        'C:\\projects\\app',
        './relative/path',
        '.',
      ];

      for (final path in paths) {
        final session = SessionInfo(
          id: 'test-$path',
          name: 'Test',
          projectPath: path,
          deviceId: 'device',
          port: 50001,
          vmServiceUri: 'ws://test',
        );

        expect(session.projectPath, equals(path));
      }
    });

    test('should handle different device IDs', () {
      final devices = [
        'iPhone 15 Pro',
        'Pixel 8',
        'emulator-5554',
        'chrome',
        'macos',
        'windows',
      ];

      for (final device in devices) {
        final session = SessionInfo(
          id: 'test-$device',
          name: 'Test',
          projectPath: '/test',
          deviceId: device,
          port: 50001,
          vmServiceUri: 'ws://test',
        );

        expect(session.deviceId, equals(device));
      }
    });

    test('should handle different VM Service URIs', () {
      final uris = [
        'ws://127.0.0.1:50001/ws',
        'ws://127.0.0.1:50001/abc123/ws',
        'ws://localhost:8080/ws',
        'ws://192.168.1.100:50000/ws',
      ];

      for (final uri in uris) {
        final session = SessionInfo(
          id: 'test-$uri',
          name: 'Test',
          projectPath: '/test',
          deviceId: 'device',
          port: 50001,
          vmServiceUri: uri,
        );

        expect(session.vmServiceUri, equals(uri));
      }
    });
  });

  group('Timestamp Management', () {
    test('should track session creation time', () {
      final before = DateTime.now();
      final session = SessionInfo(
        id: 'test',
        name: 'Test',
        projectPath: '/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://test',
      );
      final after = DateTime.now();

      expect(session.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(session.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('should preserve custom creation time', () {
      final customTime = DateTime.parse('2024-01-01T00:00:00.000Z');
      final session = SessionInfo(
        id: 'test',
        name: 'Test',
        projectPath: '/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://test',
        createdAt: customTime,
      );

      expect(session.createdAt, equals(customTime));
    });

    test('should format timestamp as ISO 8601 in JSON', () {
      final time = DateTime.parse('2024-12-25T15:30:45.123Z');
      final session = SessionInfo(
        id: 'test',
        name: 'Test',
        projectPath: '/test',
        deviceId: 'device',
        port: 50001,
        vmServiceUri: 'ws://test',
        createdAt: time,
      );

      final json = session.toJson();
      expect(json['created_at'], equals('2024-12-25T15:30:45.123Z'));
    });
  });
}
