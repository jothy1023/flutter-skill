# flutter-skill Kotlin Multiplatform SDK

> Part of [flutter-skill](https://github.com/ai-dashboad/flutter-skill) — **AI-Powered End-to-End Testing for Any App**

AI E2E testing bridge for KMP apps (Android, JVM/Desktop, iOS). JSON-RPC 2.0 over WebSocket on port 18118.

## Setup

Add to your KMP project:
```kotlin
dependencies {
    implementation("com.flutterskill:flutter-skill-kmp:1.0.0")
}
```

## Usage — Android

```kotlin
val bridge = FlutterSkillBridge(AndroidBridge(activity))
bridge.start()
```

## Usage — Desktop (JVM)

```kotlin
val bridge = FlutterSkillBridge(DesktopBridge(frame))
bridge.start()
```

## Supported Commands

`health`, `inspect`, `tap`, `enter_text`, `screenshot`, `scroll`, `get_text`, `find_element`, `wait_for_element`
