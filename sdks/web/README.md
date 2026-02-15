# Flutter Skill Web SDK

Lightweight browser bridge for vanilla web apps. Zero dependencies.

## Quick Start

```html
<script src="flutter-skill-web.js"></script>
```

The SDK auto-connects to `ws://127.0.0.1:18118` on load.

## Configuration

```html
<script>
  window.FLUTTER_SKILL_PORT = 18119;       // Custom port
  window.FLUTTER_SKILL_APP_NAME = 'MyApp'; // App name for health endpoint
</script>
<script src="flutter-skill-web.js"></script>
```

## API

```js
FlutterSkillWeb.connect();    // Manual connect (auto-called on load)
FlutterSkillWeb.disconnect(); // Disconnect
FlutterSkillWeb.health();     // Get health/capability info
```

## Supported Bridge Methods

| Method | Description |
|--------|-------------|
| `initialize` | Handshake |
| `inspect` | Full DOM tree inspection |
| `inspect_interactive` | Interactive elements with semantic refs |
| `tap` | Click element by ref/selector/text |
| `enter_text` | Type into input fields |
| `get_text` | Read element text/value |
| `get_checkbox_state` | Get checkbox/toggle state |
| `get_slider_value` | Get range input value |
| `scroll_to` | Scroll to element or direction |
| `long_press` | Simulate long press |
| `double_tap` | Double click |
| `swipe` | Swipe gesture + scroll |
| `drag` | Mouse drag |
| `go_back` | Navigate back |
| `screenshot` | Full page screenshot via Canvas |
| `screenshot_region` | Region screenshot |
| `screenshot_element` | Element screenshot |
| `eval` | Execute JavaScript |
| `press_key` | Simulate keyboard input |
| `get_elements_by_type` | Filter elements by type |
| `find_element` | Find single element |
| `wait_for_element` | Wait for element to appear |

## Element Resolution

Elements are resolved in order: `ref` → `selector`/`key` → `text`.

Semantic refs follow `{role}:{content}` format (e.g., `button:Login`, `input:Email`).
