# flutter-skill Android SDK

> Part of [flutter-skill](https://github.com/ai-dashboad/flutter-skill) — **AI-Powered End-to-End Testing for Any App**

Lightweight bridge that lets flutter-skill automate **native Android apps** — Kotlin, Jetpack Compose, XML Views, or any combination.

## Quick Start

### Gradle Dependency

Add the library to your app module:

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}

// app/build.gradle.kts
dependencies {
    debugImplementation("com.flutterskill:flutter-skill-android:1.0.0")
}
```

Using `debugImplementation` ensures the bridge is only included in debug builds and completely stripped from release APKs.

### Initialize in Your Application

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()

        // Only start the bridge in debug builds
        if (BuildConfig.DEBUG) {
            FlutterSkillBridge.start(this, appName = "MyApp")
        }
    }
}
```

Or initialize in an Activity if you prefer more granular control:

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (BuildConfig.DEBUG) {
            FlutterSkillBridge.start(application, appName = "MyApp")
        }
    }
}
```

### Forward the Port (for Emulators)

The bridge listens on port `18118`. For the Android emulator, forward the port so the host machine can reach it:

```bash
adb forward tcp:18118 tcp:18118
```

### Use flutter-skill

Start the flutter-skill server and it will auto-discover your app:

```bash
flutter_skill server
```

Then use `scan_and_connect`, `inspect`, `tap`, `screenshot`, etc. as usual.

## How It Works

```
flutter-skill server (host machine)
       |
       v  TCP port 18118 (forwarded via adb)
FlutterSkillBridge (embedded HTTP + WebSocket server)
       |
       v  Main thread handler
View hierarchy / Accessibility tree
```

1. **FlutterSkillBridge** starts a lightweight HTTP server inside your app on port 18118.
2. The **health check** endpoint (`GET /.flutter-skill`) responds with app metadata for auto-discovery.
3. The flutter-skill server connects via **WebSocket** at `/ws` and sends **JSON-RPC 2.0** messages.
4. Each command (tap, inspect, screenshot, etc.) is dispatched to the **main thread** to safely access the View hierarchy.

## Supported Methods

### Core Methods

| Method | Description |
|--------|-------------|
| `initialize` | Return framework info and SDK version |
| `inspect` | Walk the View hierarchy and return interactive elements with bounds |
| `tap` | Find a view by key and perform a click |
| `enter_text` | Find an EditText and set its text content |
| `swipe` | Dispatch a swipe gesture (up/down/left/right) |
| `scroll` | Scroll a ScrollView or RecyclerView |
| `find_element` | Locate an element by key or text |
| `get_text` | Get text content from a TextView or EditText |
| `wait_for_element` | Synchronous check if an element exists (server polls) |
| `screenshot` | Capture the screen as a base64-encoded PNG |

### Extended Methods

| Method | Description |
|--------|-------------|
| `get_logs` | Retrieve captured log entries |
| `clear_logs` | Clear the log buffer |
| `go_back` | Trigger the system back action |

## Element Identification

Views are found by searching in this priority order:

1. **View tag** — Set via `View.tag = "my_key"` or `android:tag="my_key"` in XML.
2. **Content description** — Set via `View.contentDescription` or `android:contentDescription` in XML.
3. **Resource ID name** — The string name of the `android:id` (e.g., `"btn_submit"` for `@+id/btn_submit`).
4. **Text content** — Matches against the visible text of TextView, Button, EditText, etc.

### Best Practices

For reliable automation, set explicit tags or content descriptions on interactive elements:

```kotlin
// XML Views
<Button
    android:id="@+id/btn_login"
    android:tag="login_button"
    android:contentDescription="Login"
    android:text="Log In" />

// Programmatic
button.tag = "login_button"
button.contentDescription = "Login"

// Jetpack Compose
Button(
    onClick = { /* ... */ },
    modifier = Modifier
        .testTag("login_button")
        .semantics { contentDescription = "Login" }
) {
    Text("Log In")
}
```

## Custom Logging

Surface app-specific log messages to the AI agent:

```kotlin
FlutterSkillBridge.log("INFO", "User navigated to settings")
FlutterSkillBridge.log("ERROR", "API call failed: 500")
```

These appear when the agent calls `get_logs`.

## Architecture

### Key Components

| File | Purpose |
|------|---------|
| `FlutterSkillBridge.kt` | HTTP/WebSocket server, JSON-RPC dispatcher, method implementations |
| `ViewTraversal.kt` | View hierarchy walker, element descriptor builder, view finder |

### Threading Model

- The **HTTP/WebSocket server** runs on Kotlin coroutine IO threads.
- All **View operations** (inspect, tap, screenshot, etc.) are dispatched to the **main thread** via `Handler(Looper.getMainLooper())` and block until complete.
- **Log buffer** is a `CopyOnWriteArrayList` for lock-free concurrent access.

### Screenshot Capture

- **API 26+ (Oreo)**: Uses `PixelCopy` for hardware-accelerated capture. Falls back to drawing cache on failure.
- **API 24-25**: Uses the legacy `View.drawingCache` approach.

## Security

The bridge server **only listens on localhost** (port 18118) and is intended for **debug builds only**. Use `debugImplementation` in Gradle and guard initialization with `BuildConfig.DEBUG` to ensure the bridge is never active in production.

## Requirements

- **minSdk**: 24 (Android 7.0)
- **compileSdk**: 34
- **Kotlin**: 1.8+
- **Dependencies**: AndroidX Core KTX, Kotlin Coroutines (typically already in your project)
