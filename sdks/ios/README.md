# flutter-skill iOS SDK

> Part of [flutter-skill](https://github.com/ai-dashboad/flutter-skill) — **AI-Powered End-to-End Testing for Any App**

Lightweight bridge that lets flutter-skill automate **native iOS apps** built with UIKit or SwiftUI. No external dependencies.

## Quick Start

### Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/ai-dashboad/flutter-skill.git
   ```
3. Select the `FlutterSkill` library product.

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ai-dashboad/flutter-skill.git", from: "1.0.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "FlutterSkill", package: "flutter-skill"),
    ]),
]
```

### Integration

**UIKit (AppDelegate):**

```swift
import FlutterSkill

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        #if DEBUG
        FlutterSkillBridge.shared.start(appName: "MyApp")
        #endif
        return true
    }
}
```

**SwiftUI (App):**

```swift
import SwiftUI
import FlutterSkill

@main
struct MyApp: App {
    init() {
        #if DEBUG
        FlutterSkillBridge.shared.start(appName: "MyApp")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Once started, the bridge listens on port **18118**. The flutter-skill server auto-discovers it via the health-check endpoint.

## How It Works

```
flutter-skill server
      |
      v  HTTP GET /.flutter-skill  (health check / discovery)
FlutterSkillBridge (port 18118)
      |
      v  WebSocket /ws  (JSON-RPC 2.0)
UIKit / SwiftUI app
      |
      v  UIView hierarchy traversal
Interactive elements (UIButton, UITextField, etc.)
```

1. **Include the SDK** in your app and call `start()` (see above).
2. **Run your app** in the simulator or on a device.
3. **Run flutter-skill server** -- it scans ports 18118-18128 and finds the bridge.
4. Use `inspect`, `tap`, `enter_text`, `screenshot`, and other tools as usual.

## Supported Methods

### Core Methods

| Method | Description |
|--------|-------------|
| `initialize` | Return framework info and capabilities |
| `inspect` | List interactive UI elements with bounds |
| `tap` | Tap an element by key, text, or type |
| `enter_text` | Type into UITextField, UITextView, or UISearchBar |
| `swipe` | Swipe gesture (up/down/left/right) on an element |
| `scroll` | Scroll a UIScrollView by direction and distance |
| `find_element` | Check if an element exists, return its descriptor |
| `get_text` | Get text content from labels, fields, buttons |
| `wait_for_element` | Synchronous presence check (server polls) |
| `screenshot` | Capture the screen as base64-encoded PNG |

### Extended Methods

| Method | Description |
|--------|-------------|
| `get_logs` | Retrieve captured log entries |
| `clear_logs` | Clear the log buffer |
| `go_back` | Pop the navigation stack or dismiss modal |
| `get_route` | Get the current view controller class name and title |

## Element Identification

Elements are resolved using these parameters (checked in order):

| Parameter | Matches |
|-----------|---------|
| `key` | `accessibilityIdentifier` first, then `accessibilityLabel` |
| `text` | `accessibilityLabel`, then visible text content (UILabel, UIButton title, etc.) |
| `type` | View class name (e.g., `"UIButton"`, `"CustomCell"`) |

### Best Practice: Use accessibilityIdentifier

For reliable element targeting, set `accessibilityIdentifier` on your views:

**UIKit:**

```swift
let submitButton = UIButton()
submitButton.accessibilityIdentifier = "submit_button"
```

**SwiftUI:**

```swift
Button("Submit") { ... }
    .accessibilityIdentifier("submit_button")
```

Then target it from flutter-skill:

```json
{"method": "tap", "params": {"key": "submit_button"}}
```

## Log Capture

The SDK maintains a ring buffer of up to 500 log entries. Add entries programmatically:

```swift
FlutterSkillBridge.shared.appendLog("User tapped checkout")
```

Retrieve logs via the `get_logs` method, or clear them with `clear_logs`.

## Conditional Compilation

Always wrap the bridge in `#if DEBUG` to keep it out of production builds:

```swift
#if DEBUG
FlutterSkillBridge.shared.start()
#endif
```

This ensures zero overhead in release builds -- the SDK code is stripped entirely by the compiler.

## Architecture

The SDK consists of two files:

- **FlutterSkillBridge.swift** -- HTTP + WebSocket server (Network.framework), JSON-RPC dispatch, all method implementations.
- **FlutterSkillBridge+ViewTraversal.swift** -- UIView hierarchy walker, element descriptor builder, search helpers.

Dependencies: **None**. Uses only Foundation, UIKit, and Network (all Apple system frameworks).

### Minimum Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

## Custom Port

If port 18118 is unavailable, specify a different one (must be in the scanned range 18118-18128):

```swift
FlutterSkillBridge.shared.start(appName: "MyApp", port: 18119)
```
