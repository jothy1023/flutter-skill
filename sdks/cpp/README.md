# flutter-skill C++ SDK

> Part of [flutter-skill](https://github.com/ai-dashboad/flutter-skill) — **AI-Powered End-to-End Testing for Any App**

Bridge SDK for native C++ desktop applications. Starts a JSON-RPC 2.0 WebSocket server on port 18118 so that AI agents can automate your app via the flutter-skill protocol.

## Platform Support

| Platform | Input Synthesis | Screenshot | Accessibility Inspection |
|----------|----------------|------------|--------------------------|
| macOS    | CGEvent        | CGDisplay  | AXUIElement              |
| Windows  | SendInput      | GDI+       | GetForegroundWindow      |
| Linux    | XTest          | XGetImage + libpng | Xlib EWMH       |

## Requirements

**macOS**: Xcode + ApplicationServices framework (included with Xcode)
**Windows**: Visual Studio 2019+ with C++17
**Linux**: `apt install libx11-dev libxtst-dev libpng-dev`

## Quick Start

### 1. Add to your CMake project

```cmake
add_subdirectory(path/to/flutter-skill/sdks/cpp)
target_link_libraries(your_app PRIVATE flutter_skill)
```

### 2. Start the bridge in your app

```cpp
#include <flutter_skill/bridge.h>

int main() {
    flutter_skill::BridgeOptions opts;
    opts.app_name = "my-cpp-app";
    opts.port     = 18118;  // default

    flutter_skill::FlutterSkillBridge bridge(opts);
    bridge.start();  // non-blocking

    // ... your app code ...

    bridge.wait();  // block until stopped
}
```

### 3. Connect with flutter-skill

```bash
flutter_skill scan_and_connect
flutter_skill act tap --x 100 --y 200
flutter_skill act screenshot
```

Or via MCP (Claude / Cursor):
```json
{
  "tool": "tap",
  "params": { "x": 100, "y": 200 }
}
```

## Build

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Run example server
./build/flutter_skill_bridge

# Run tests
cd build && ctest --verbose
```

## Supported Commands

| Command | Parameters | Description |
|---------|-----------|-------------|
| `ping` | — | Health check → `{"pong": true}` |
| `initialize` | — | Returns capabilities list |
| `screenshot` | — | Captures screen as PNG (base64) |
| `tap` | `x`, `y` | Synthesizes a mouse click |
| `enter_text` | `text` | Types text via keyboard events |
| `press_key` | `key`, `modifiers[]` | Presses a named key (e.g. `"enter"`, `"f5"`) |
| `scroll` | `direction`, `amount` | Scrolls up/down/left/right |
| `inspect` | — | Returns focused window info |
| `get_focused_window_title` | — | Returns title of frontmost window |
| `get_logs` | — | Returns bridge log entries |
| `clear_logs` | — | Clears log buffer |

## Custom Backend

Implement `AutomationBackend` to override platform behaviour:

```cpp
class MyBackend : public flutter_skill::AutomationBackend {
public:
    flutter_skill::ToolResult tap(double x, double y) override {
        // your custom tap implementation
        return {true, "\"message\":\"tapped\""};
    }
    // ... implement remaining methods
};

flutter_skill::FlutterSkillBridge bridge;
bridge.set_backend(std::make_unique<MyBackend>());
bridge.start();
```

## Protocol

All messages are JSON-RPC 2.0 over WebSocket (ws://127.0.0.1:18118).

**Request:**
```json
{"id": 1, "method": "tap", "params": {"x": 100, "y": 200}}
```

**Response:**
```json
{"id": 1, "result": {"success": true, "message": "Tapped at (100,200)"}}
```

## Dependencies

- **C++17** or later
- **No external libraries** for core protocol (SHA-1 and base64 are bundled)
- Platform frameworks: see Requirements above
