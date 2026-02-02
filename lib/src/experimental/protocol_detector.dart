import 'dart:io';
import 'dart:async';
import 'dart:convert';

/// Protocol Type
enum FlutterProtocol {
  /// VM Service Protocol (full functionality)
  vmService,

  /// DTD Protocol (basic functionality)
  dtd,

  /// No available protocol
  none,
}

/// Protocol Detector
class ProtocolDetector {
  /// Detect protocol type from URI
  static FlutterProtocol detectFromUri(String uri) {
    // VM Service URI format:
    // http://127.0.0.1:50000/xxx=/
    // ws://127.0.0.1:50000/xxx=/ws
    if (uri.startsWith('http://') ||
        (uri.startsWith('ws://') && uri.contains('/ws') && !uri.contains('dtd'))) {
      return FlutterProtocol.vmService;
    }

    // DTD URI format:
    // ws://127.0.0.1:52049/xxx=/ws (usually different port)
    // or explicitly contains 'dtd' identifier
    if (uri.startsWith('ws://') && uri.contains('=/ws')) {
      return FlutterProtocol.dtd;
    }

    return FlutterProtocol.none;
  }

  /// Scan local ports for available protocols
  static Future<Map<FlutterProtocol, List<String>>> scanAvailableProtocols({
    int portStart = 50000,
    int portEnd = 50100,
  }) async {
    final result = <FlutterProtocol, List<String>>{
      FlutterProtocol.vmService: [],
      FlutterProtocol.dtd: [],
    };

    final futures = <Future>[];

    for (var port = portStart; port <= portEnd; port++) {
      futures.add(_checkPort(port).then((uri) {
        if (uri != null) {
          final protocol = detectFromUri(uri);
          if (protocol != FlutterProtocol.none) {
            result[protocol]!.add(uri);
          }
        }
      }));
    }

    await Future.wait(futures);
    return result;
  }

  /// Check if a specific port has available service
  static Future<String?> _checkPort(int port) async {
    try {
      // Try to connect to the port
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 200),
      );

      // Try HTTP request (VM Service)
      try {
        final request = await HttpClient()
            .getUrl(Uri.parse('http://127.0.0.1:$port'))
            .timeout(const Duration(milliseconds: 200));
        final response = await request.close();

        if (response.statusCode == 200) {
          // Read response body to find VM Service URI
          final body = await response.transform(utf8.decoder).join();
          final uriMatch = RegExp(r'ws://[^\s"]+').firstMatch(body);
          if (uriMatch != null) {
            socket.destroy();
            return uriMatch.group(0);
          }
        }
      } catch (e) {
        // Not an HTTP service, might be WebSocket
      }

      // Assume it's a WebSocket service
      socket.destroy();
      return 'ws://127.0.0.1:$port/ws';
    } catch (e) {
      return null;
    }
  }

  /// Get protocol capabilities description
  static Map<String, bool> getCapabilities(FlutterProtocol protocol) {
    switch (protocol) {
      case FlutterProtocol.vmService:
        return {
          'tap': true,
          'screenshot': true,
          'inspect': true,
          'hot_reload': true,
          'get_logs': true,
          'enter_text': true,
          'swipe': true,
        };

      case FlutterProtocol.dtd:
        return {
          'tap': false,
          'screenshot': false,
          'inspect': false,
          'hot_reload': true,
          'get_logs': true,
          'enter_text': false,
          'swipe': false,
        };

      case FlutterProtocol.none:
        return {};
    }
  }

  /// Generate friendly protocol description
  static String describeProtocol(FlutterProtocol protocol) {
    switch (protocol) {
      case FlutterProtocol.vmService:
        return 'VM Service (Full functionality)';
      case FlutterProtocol.dtd:
        return 'DTD (Basic: hot reload, logs)';
      case FlutterProtocol.none:
        return 'No available protocol';
    }
  }
}
