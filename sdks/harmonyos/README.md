# flutter-skill HarmonyOS SDK

AI-driven testing bridge for HarmonyOS (ArkUI/ArkTS) apps via [flutter-skill](https://github.com/ai-dashboad/flutter-skill).

## Setup

1. Copy `FlutterSkillAbility.ets` into your HarmonyOS project's `entry/src/main/ets/` directory.

2. In your Ability's `onCreate` callback, start the bridge:

```typescript
import { FlutterSkillBridge } from './FlutterSkillAbility';

export default class EntryAbility extends UIAbility {
  private bridge = new FlutterSkillBridge({ appName: 'my-app' });

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.bridge.start();
  }

  onDestroy(): void {
    this.bridge.stop();
  }
}
```

3. Add the required permissions to `module.json5`:

```json
{
  "requestPermissions": [
    { "name": "ohos.permission.INTERNET" },
    { "name": "ohos.permission.INPUT_MONITORING" }
  ]
}
```

## Supported Capabilities

| Tool | Description |
|------|-------------|
| `screenshot` | Capture full-screen PNG (base64) |
| `tap` | Tap at (x, y) coordinates |
| `enter_text` | Type text via key injection |
| `press_key` | Press named key (enter, tab, escape, backspace, arrows…) |
| `scroll` | Swipe to scroll in a direction |
| `go_back` | Navigate back via `router.back()` |
| `get_current_route` | Return current router page path |
| `inspect` | Return current page state |
| `get_logs` / `clear_logs` | Access bridge logs |

## Protocol

The bridge listens on `ws://127.0.0.1:18118` (the same default port as other flutter-skill SDKs) and speaks the flutter-skill JSON-RPC bridge protocol. flutter-skill discovers it automatically via port scanning.

## Requirements

- HarmonyOS API Level 10+
- ArkTS / ArkUI project
- `@ohos.net.webSocket`, `@ohos.multimodalInput.inputSimulator`, `@ohos.multimedia.image` system capabilities
