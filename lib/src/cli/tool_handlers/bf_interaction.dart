part of '../server.dart';

extension _BfInteraction on FlutterMcpServer {
  Future<dynamic> _handleInteractionTool(
      String name, Map<String, dynamic> args, AppDriver? client) async {
    switch (name) {
      case 'tap':
        // Support three methods: key, text, or coordinates
        final x = args['x'] as num?;
        final y = args['y'] as num?;

        // Method 3: Tap by coordinates
        if (x != null && y != null) {
          if (client is BridgeDriver) {
            await client
                .callMethod('tap_at', {'x': x.toDouble(), 'y': y.toDouble()});
            return {
              "success": true,
              "method": "coordinates",
              "message": "Tapped at ($x, $y)",
              "position": {"x": x, "y": y}
            };
          }
          final fc = _asFlutterClient(client!, 'tap (coordinates)');
          await fc.tapAt(x.toDouble(), y.toDouble());
          return {
            "success": true,
            "method": "coordinates",
            "message": "Tapped at ($x, $y)",
            "position": {"x": x, "y": y},
          };
        }

        // Method 1 & 2: Tap by key, text, or semantic ref
        final result = await client!.tap(
          key: args['key'],
          text: args['text'],
          ref: args['ref'],
        );
        if (result['success'] != true) {
          // Return full error details including suggestions
          return {
            "success": false,
            "error": result['error'] ?? {"message": "Element not found"},
            "target":
                result['target'] ?? {"key": args['key'], "text": args['text']},
            if (result['suggestions'] != null)
              "suggestions": result['suggestions'],
          };
        }
        return {
          "success": true,
          "method": args['key'] != null ? "key" : "text",
          "message": "Tapped",
          if (result['position'] != null) "position": result['position'],
        };

      case 'enter_text':
        final result = await client!.enterText(
          args['key'],
          args['text'],
          ref: args['ref'],
        );
        if (result['success'] != true) {
          return {
            "success": false,
            "error": result['error'] ?? {"message": "TextField not found"},
            "target": result['target'] ?? {"key": args['key']},
            if (result['suggestions'] != null)
              "suggestions": result['suggestions'],
          };
        }
        return {"success": true, "message": "Text entered"};

      case 'scroll_to':
        if (client is BridgeDriver) {
          await client.scroll(
              direction: args['direction'] ?? 'down',
              distance: args['distance'] ?? 300);
          return {"success": true, "message": "Scrolled"};
        }
        final fc = _asFlutterClient(client!, 'scroll_to');
        final result = await fc.scrollTo(key: args['key'], text: args['text']);
        if (result['success'] != true) {
          return {
            "success": false,
            "error": result['message'] ?? "Element not found",
          };
        }
        return {"success": true, "message": "Scrolled"};

      // Advanced Actions
      case 'long_press':
        if (client is BridgeDriver) {
          final success =
              await client.longPress(key: args['key'], text: args['text']);
          return success ? "Long pressed" : "Long press failed";
        }
        final fc = _asFlutterClient(client!, 'long_press');
        final duration = args['duration'] ?? 500;
        final success = await fc.longPress(
            key: args['key'], text: args['text'], duration: duration);
        return success ? "Long pressed" : "Long press failed";
      case 'double_tap':
        if (client is BridgeDriver) {
          final success =
              await client.doubleTap(key: args['key'], text: args['text']);
          return success ? "Double tapped" : "Double tap failed";
        }
        final fc = _asFlutterClient(client!, 'double_tap');
        final success =
            await fc.doubleTap(key: args['key'], text: args['text']);
        return success ? "Double tapped" : "Double tap failed";
      case 'swipe':
        final distance = (args['distance'] ?? 300).toDouble();
        final success = await client!.swipe(
            direction: args['direction'], distance: distance, key: args['key']);
        return success ? "Swiped ${args['direction']}" : "Swipe failed";
      case 'drag':
        if (client is BridgeDriver) {
          final result = await client.callMethod(
              'drag', {'from_key': args['from_key'], 'to_key': args['to_key']});
          return result['success'] == true ? "Dragged" : "Drag failed";
        }
        final fc = _asFlutterClient(client!, 'drag');
        final success =
            await fc.drag(fromKey: args['from_key'], toKey: args['to_key']);
        return success ? "Dragged" : "Drag failed";

      // State & Validation
      case 'get_text_value':
        if (client is BridgeDriver) {
          final text = await client.getText(key: args['key']);
          return {"success": true, "text": text};
        }
        final fc = _asFlutterClient(client!, 'get_text_value');
        return await fc.getTextValue(args['key']);
      case 'get_checkbox_state':
        if (client is BridgeDriver) {
          return await client
              .callMethod('get_checkbox_state', {'key': args['key']});
        }
        final fc = _asFlutterClient(client!, 'get_checkbox_state');
        return await fc.getCheckboxState(args['key']);
      case 'get_slider_value':
        if (client is BridgeDriver) {
          return await client
              .callMethod('get_slider_value', {'key': args['key']});
        }
        final fc = _asFlutterClient(client!, 'get_slider_value');
        return await fc.getSliderValue(args['key']);
      case 'wait_for_element':
        if (client is BridgeDriver) {
          final timeout = args['timeout'] ?? 5000;
          final found = await client.waitForElement(
              key: args['key'], text: args['text'], timeout: timeout);
          return {"found": found};
        }
        final fc = _asFlutterClient(client!, 'wait_for_element');
        final timeout = args['timeout'] ?? 5000;
        final found = await fc.waitForElement(
            key: args['key'], text: args['text'], timeout: timeout);
        return {"found": found};
      case 'wait_for_gone':
        if (client is BridgeDriver) {
          final result = await client.callMethod('wait_for_gone', {
            'key': args['key'],
            'text': args['text'],
            'timeout': args['timeout'] ?? 5000
          });
          return {"gone": result['gone'] ?? true};
        }
        final fc = _asFlutterClient(client!, 'wait_for_gone');
        final timeout = args['timeout'] ?? 5000;
        final gone = await fc.waitForGone(
            key: args['key'], text: args['text'], timeout: timeout);
        return {"gone": gone};

      case 'press_key':
        final key = args['key'] as String? ?? '';
        if (key.isEmpty) {
          return {"success": false, "error": "Missing 'key' argument"};
        }
        if (client is BridgeDriver) {
          await client.callMethod('press_key', {'key': key});
          return {"success": true, "message": "Key pressed: $key"};
        }
        return {
          "success": false,
          "error":
              "press_key not supported on this platform. Use CDP mode or a bridge SDK."
        };

      case 'scroll':
        final direction = args['direction'] as String? ?? 'down';
        final amount = (args['amount'] as num?)?.toDouble() ?? 300;
        if (client is BridgeDriver) {
          await client.callMethod('scroll', {
            'direction': direction,
            'amount': amount,
          });
          return {"success": true, "message": "Scrolled $direction by $amount"};
        }
        // Flutter: use scrollTo with key/text if provided
        if (args['key'] != null || args['text'] != null) {
          final fc = _asFlutterClient(client!, 'scroll');
          await fc.scrollTo(
              key: args['key'] as String?, text: args['text'] as String?);
          return {"success": true, "message": "Scrolled to element"};
        }
        return {
          "success": false,
          "error": "scroll on Flutter requires 'key' or 'text' argument"
        };

      case 'find_element':
        final text = args['text'] as String?;
        final key = args['key'] as String?;
        if (text == null && key == null) {
          return {"success": false, "error": "Provide 'text' or 'key'"};
        }
        if (client is BridgeDriver) {
          final result = await client.callMethod('find_element', {
            if (text != null) 'text': text,
            if (key != null) 'key': key,
          });
          return result;
        }
        final fc2 = _asFlutterClient(client!, 'find_element');
        final elements = await fc2.findByType(text ?? key ?? '');
        return {"found": elements.isNotEmpty, "count": elements.length};

      case 'get_text':
        if (client is BridgeDriver) {
          final result = await client.callMethod('get_text', {
            if (args['ref'] != null) 'ref': args['ref'],
            if (args['key'] != null) 'key': args['key'],
          });
          return result;
        }
        final fc3 = _asFlutterClient(client!, 'get_text');
        final textContent = await fc3.getTextContent();
        return {"text": textContent};

      // Screenshot
      default:
        return null;
    }
  }
}
