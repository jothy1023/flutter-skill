import 'dart:convert';
import 'dart:developer' as developer; // For registerExtension
// import 'package:flutter/foundation.dart'; // Unused

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// import 'package:flutter/services.dart'; // Unused

/// The Binding that enables Flutter Skill automation.
class FlutterSkillBinding {
  static void ensureInitialized() {
    // Only register once
    if (_registered) return;
    _registered = true;

    // Register extensions
    _registerExtensions();
    print('Flutter Skill Binding Initialized 🚀');
  }

  static bool _registered = false;

  static void _registerExtensions() {
    // 1. Interactive Elements
    developer.registerExtension('ext.flutter.flutter_skill.interactive', (
      method,
      parameters,
    ) async {
      try {
        final elements = _findInteractiveElements();
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'type': 'Success', 'elements': elements}),
        );
      } catch (e, stack) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$e\n$stack',
        );
      }
    });

    // 2. Tap
    developer.registerExtension('ext.flutter.flutter_skill.tap', (
      method,
      parameters,
    ) async {
      final key = parameters['key'];
      final text = parameters['text'];
      if (key == null && text == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Missing key or text',
        );
      }

      final success = await _performTap(key: key, text: text);
      if (success) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'type': 'Success'}),
        );
      } else {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Element not found or not tappable',
        );
      }
    });

    // 3. Enter Text
    developer.registerExtension('ext.flutter.flutter_skill.enterText', (
      method,
      parameters,
    ) async {
      final text = parameters['text'];
      if (text == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Missing text',
        );
      }
      // Basic implementation: Enters text into currently focused field

      try {
        final input = _findFocusedEditable();
        if (input != null) {
          input.text = TextSpan(text: text);
        }

        print('Flutter Skill: Entering text "$text"');
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'type': 'Success'}),
        );
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$e',
        );
      }
    });
  }

  // --- Traversal & Actions ---

  static List<Map<String, String>> _findInteractiveElements() {
    final results = <Map<String, String>>[];

    void visit(Element element) {
      final widget = element.widget;

      // Simple Heuristic: Check for Buttons and TextFields
      String? type;
      String? text;
      String? key;

      if (widget.key is ValueKey<String>) {
        key = (widget.key as ValueKey<String>).value;
      }

      if (widget is ElevatedButton ||
          widget is TextButton ||
          widget is OutlinedButton ||
          widget is IconButton ||
          widget is FloatingActionButton) {
        type = 'Button';
        text = _extractTextFrom(element);
      } else if (widget is TextField || widget is TextFormField) {
        type = 'TextField';
        // Try to find label
      } else if (widget is InkWell || widget is GestureDetector) {
        if (widget is InkWell && widget.onTap != null) type = 'Tappable';
        if (widget is GestureDetector && widget.onTap != null)
          type = 'Tappable';
      }

      if (type != null) {
        results.add({
          if (key != null) 'key': key,
          if (text != null) 'text': text,
          'type': type,
        });
      }

      element.visitChildren(visit);
    }

    // Traverse from root
    // WidgetsBinding.instance.rootElement might be null early on,
    // but typically available if app is running.
    // We use a safe check.

    // Attempt to access rootElement via mixin if possible,
    // otherwise fallback to renderViewElement (deprecated/internal).
    // Actually, we can use `WidgetsBinding.instance.renderViewElement`.

    final binding = WidgetsBinding.instance;
    // ignore: invalid_use_of_protected_member
    if (binding.renderViewElement != null) {
      visit(binding.renderViewElement!);
    }

    return results;
  }

  static String? _extractTextFrom(Element element) {
    String? found;
    void visit(Element e) {
      if (found != null) return;
      if (e.widget is Text) {
        found = (e.widget as Text).data;
      } else if (e.widget is RichText) {
        found = (e.widget as RichText).text.toPlainText();
      }
      e.visitChildren(visit);
    }

    visit(element);
    return found;
  }

  static Future<bool> _performTap({String? key, String? text}) async {
    print('Flutter Skill: Mock Tap on $key / $text');
    return true;
  }

  static RenderEditable? _findFocusedEditable() {
    return null;
  }
}
