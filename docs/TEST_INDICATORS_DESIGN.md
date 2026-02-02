# Test Indicators Design Document

## Overview
Add real-time visual feedback for UI test actions to make testing more observable and debuggable.

## Goals
1. Show visual indicators for all test actions (tap, swipe, long press, enter text)
2. Display action hints at the top of the screen
3. Support enable/disable via VM Service extension
4. Minimal performance impact
5. Works across all platforms
6. Can be recorded in videos

## Architecture

### 1. Components

#### A. TestIndicatorOverlay (Manager)
- Manages the overlay entry
- Controls indicator visibility
- Queues and displays indicators
- Handles animation lifecycles

#### B. TestIndicatorWidget (UI Layer)
- Renders visual effects
- Manages animation controllers
- Displays action hints

#### C. Indicator Types
1. **TapIndicator**: Expanding circle animation
2. **SwipeIndicator**: Arrow with trail
3. **LongPressIndicator**: Filling circle with progress
4. **TextInputIndicator**: Blinking cursor effect
5. **ActionHintIndicator**: Top banner with text

### 2. Visual Effects

#### Tap Indicator
```
- Position: tap location
- Effect: Circle expands from center, fades out
- Duration: 500ms
- Color: Semi-transparent blue (#4CAF50 with 0.3 opacity)
```

#### Swipe Indicator
```
- Position: start → end
- Effect: Arrow with dashed trail
- Duration: 300ms + swipe duration
- Color: Semi-transparent purple (#9C27B0 with 0.3 opacity)
```

#### Long Press Indicator
```
- Position: press location
- Effect: Circle fills up like a progress ring
- Duration: Matches actual press duration
- Color: Semi-transparent orange (#FF9800 with 0.3 opacity)
```

#### Text Input Indicator
```
- Position: Text field bounds
- Effect: Border glow + typing animation
- Duration: Input duration
- Color: Semi-transparent green (#4CAF50 with 0.3 opacity)
```

#### Action Hint
```
- Position: Top of screen (safe area)
- Effect: Slide in from top, fade out
- Duration: 2000ms
- Content: "Tapping 'Submit'", "Swiping left", etc.
```

### 3. Implementation

#### FlutterSkillBinding Changes
```dart
class FlutterSkillBinding {
  static TestIndicatorOverlay? _indicatorOverlay;
  static bool _indicatorsEnabled = false;

  // New VM Service extensions
  // ext.flutter.flutter_skill.enableIndicators
  // ext.flutter.flutter_skill.disableIndicators
  // ext.flutter.flutter_skill.setIndicatorStyle
}
```

#### TestIndicatorOverlay
```dart
class TestIndicatorOverlay {
  OverlayEntry? _entry;
  final List<IndicatorData> _activeIndicators = [];

  void showTap(Offset position, {String? hint});
  void showSwipe(Offset start, Offset end, {String? hint});
  void showLongPress(Offset position, Duration duration, {String? hint});
  void showTextInput(Rect bounds, {String? hint});
  void showHint(String message);

  void enable();
  void disable();
}
```

#### Indicator Data Models
```dart
enum IndicatorType { tap, swipe, longPress, textInput, hint }

class IndicatorData {
  final IndicatorType type;
  final Offset? position;
  final Offset? endPosition;
  final Duration? duration;
  final Rect? bounds;
  final String? message;
  final DateTime timestamp;
}
```

### 4. Integration Points

#### A. In Action Methods
```dart
static Future<Map<String, dynamic>> _performTapWithDetails({...}) async {
  final position = ...; // Calculate tap position

  // Show indicator before tap
  _indicatorOverlay?.showTap(position, hint: "Tapping '$text'");

  // Perform tap
  await _tap(key: key, text: text);

  return result;
}
```

#### B. VM Service Extensions
```dart
// Enable indicators
developer.registerExtension(
  'ext.flutter.flutter_skill.enableIndicators',
  (method, parameters) async {
    _indicatorsEnabled = true;
    _indicatorOverlay ??= TestIndicatorOverlay();
    _indicatorOverlay!.enable();
    return ServiceExtensionResponse.result('{"enabled": true}');
  },
);

// Disable indicators
developer.registerExtension(
  'ext.flutter.flutter_skill.disableIndicators',
  (method, parameters) async {
    _indicatorsEnabled = false;
    _indicatorOverlay?.disable();
    return ServiceExtensionResponse.result('{"enabled": false}');
  },
);
```

#### C. MCP Server Integration
```dart
{
  "name": "enable_test_indicators",
  "description": "Enable visual indicators for test actions (tap, swipe, etc.)",
  "inputSchema": {
    "type": "object",
    "properties": {
      "enabled": {"type": "boolean", "default": true},
      "style": {
        "type": "string",
        "enum": ["minimal", "standard", "detailed"],
        "default": "standard"
      }
    }
  }
}
```

### 5. Performance Considerations

1. **Lazy Initialization**: Only create overlay when enabled
2. **Animation Cleanup**: Remove completed indicators from list
3. **Frame Budget**: Max 3 concurrent indicators
4. **Repaint Boundary**: Isolate indicator layer
5. **Conditional Rendering**: Skip when app is in background

### 6. User Experience

#### Enabling in Tests
```dart
// MCP Server
await enable_test_indicators(enabled: true, style: "standard");

// VM Service Direct
await vmService.callServiceExtension(
  'ext.flutter.flutter_skill.enableIndicators',
);
```

#### Recording Videos
- All indicators are rendered in the app
- Screen recording tools will capture them
- Works on physical devices and simulators

### 7. Configuration Options

#### Style: "minimal"
- Small indicators
- No action hints
- Fast animations (200ms)

#### Style: "standard" (default)
- Medium indicators
- Action hints for 1s
- Normal animations (500ms)

#### Style: "detailed"
- Large indicators
- Action hints for 2s
- Slow animations (800ms)
- Additional debug info (coordinates, timing)

## Implementation Phases

### Phase 1: Core Infrastructure (Current)
- [ ] TestIndicatorOverlay class
- [ ] TestIndicatorWidget with tap indicator
- [ ] Enable/disable VM Service extensions
- [ ] Integration in _performTapWithDetails

### Phase 2: Additional Indicators
- [ ] Swipe indicator
- [ ] Long press indicator
- [ ] Text input indicator
- [ ] Action hint banner

### Phase 3: MCP Integration
- [ ] Add enable_test_indicators MCP tool
- [ ] Add indicator state to session info
- [ ] Update documentation

### Phase 4: Polish & Testing
- [ ] Style configurations
- [ ] Performance optimization
- [ ] Integration tests
- [ ] Documentation with GIFs

## Testing Plan

1. **Visual Testing**: Record videos with indicators enabled
2. **Performance Testing**: Measure frame rate impact
3. **Integration Testing**: Test with real Flutter apps
4. **Cross-platform**: Verify on iOS, Android, Web, Desktop

## Example Usage

```dart
// Enable indicators
await client.enableTestIndicators();

// All actions now show visual feedback
await client.tap(text: "Submit"); // Shows tap ripple + "Tapping 'Submit'"
await client.swipe(direction: "left"); // Shows swipe arrow + "Swiping left"
await client.longPress(text: "Menu"); // Shows filling circle + "Long pressing 'Menu'"
await client.enterText(key: "email", text: "test@example.com"); // Shows text field glow

// Disable indicators
await client.disableTestIndicators();
```

## Future Enhancements

1. Custom colors and styles
2. Screenshot with indicators burnt in
3. Video recording with indicators
4. Indicator replay from test logs
5. Remote indicator control (for CI/CD)
6. Accessibility indicators (TalkBack, VoiceOver)
