# flutter-skill React Native SDK

> Part of [flutter-skill](https://github.com/ai-dashboad/flutter-skill) — **AI-Powered End-to-End Testing for Any App**

Bridge SDK that lets flutter-skill automate **React Native** apps. Runs an embedded HTTP + WebSocket server inside the app process so AI agents can inspect the UI, tap buttons, enter text, scroll, and more.

## Quick Start

### 1. Install

```bash
npm install flutter-skill-react-native react-native-tcp-socket
# or
yarn add flutter-skill-react-native react-native-tcp-socket
```

For iOS, install the native pods:

```bash
cd ios && pod install
```

### 2. Initialize in your app entry point

```js
// App.js
import { initFlutterSkill, setNavigationRef } from 'flutter-skill-react-native';
import { NavigationContainer, useNavigationContainerRef } from '@react-navigation/native';

export default function App() {
  const navigationRef = useNavigationContainerRef();

  useEffect(() => {
    if (__DEV__) {
      initFlutterSkill({ appName: 'MyApp' });
      setNavigationRef(navigationRef);
    }
  }, []);

  return (
    <NavigationContainer ref={navigationRef}>
      {/* ... */}
    </NavigationContainer>
  );
}
```

### 3. Register interactive elements

The SDK needs to know about your interactive elements. Register them by testID:

```jsx
import { registerComponent, unregisterComponent } from 'flutter-skill-react-native';

function LoginScreen() {
  return (
    <View>
      <TextInput
        testID="email_field"
        ref={ref => registerComponent('email_field', ref, {
          type: 'TextInput',
          accessibilityLabel: 'Email',
        })}
      />
      <TouchableOpacity
        testID="login_button"
        ref={ref => registerComponent('login_button', ref, {
          type: 'TouchableOpacity',
          text: 'Log In',
          interactive: true,
        })}
        onPress={handleLogin}
      >
        <Text>Log In</Text>
      </TouchableOpacity>
    </View>
  );
}
```

### 4. Run flutter-skill

```bash
# Start the flutter-skill server -- it will discover the app on port 18118
flutter_skill server

# Or scan and connect directly
flutter_skill scan
```

## How It Works

1. **Include the SDK** in your React Native app and call `initFlutterSkill()`.
2. The SDK starts a **TCP server on port 18118** inside the app process.
3. The health check endpoint at `GET /.flutter-skill` advertises the app to the flutter-skill proxy.
4. The proxy connects via **WebSocket at `/ws`** and sends **JSON-RPC 2.0** requests.
5. The SDK executes commands (tap, inspect, enter text, etc.) against the live React Native component tree.

```
flutter-skill server
      |
      v  JSON-RPC 2.0 over WebSocket (port 18118)
FlutterSkill.js (embedded in app)
      |
      v  React Native APIs
UIManager / findNodeHandle / Component refs
```

## Supported Methods

### Core Methods

| Method | Description |
|--------|-------------|
| `initialize` | Return framework info and SDK version |
| `inspect` | List all registered interactive elements with positions |
| `tap` | Tap an element by testID, text, or accessibility label |
| `enter_text` | Set text on a TextInput component |
| `swipe` | Dispatch swipe gesture in a direction |
| `scroll` | Scroll a ScrollView or FlatList |
| `find_element` | Check if an element exists and get its bounds |
| `get_text` | Get text content or input value |
| `wait_for_element` | Check element presence (proxy polls) |
| `screenshot` | Delegates to native tooling (returns `_needs_native` flag) |

### Extended Methods

| Method | Description |
|--------|-------------|
| `get_logs` | Retrieve captured console output (max 500 entries) |
| `clear_logs` | Clear the log buffer |
| `get_route` | Get current React Navigation route name and params |
| `go_back` | Navigate back via React Navigation |

## Element Selectors

Elements are found by (in priority order):

1. **`key`** or **`testID`** -- matches the `testID` prop registered via `registerComponent()`
2. **`text`** -- matches the `text` string passed during registration
3. **`accessibilityLabel`** -- matches the accessibility label

### Examples

```json
{ "method": "tap", "params": { "key": "login_button" } }
{ "method": "enter_text", "params": { "key": "email_field", "text": "user@example.com" } }
{ "method": "find_element", "params": { "text": "Log In" } }
{ "method": "scroll", "params": { "key": "main_list", "direction": "down", "distance": 500 } }
{ "method": "get_route" }
```

## API Reference

### `initFlutterSkill(options)`

Start the bridge server.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `appName` | string | `'ReactNativeApp'` | App name shown in health check |
| `port` | number | `18118` | TCP port to listen on |

### `destroyFlutterSkill()`

Shut down the server and disconnect all clients.

### `registerComponent(testID, ref, extras?)`

Register a component so the SDK can find and interact with it.

| Param | Type | Description |
|-------|------|-------------|
| `testID` | string | Unique identifier (should match the `testID` prop) |
| `ref` | React ref | The component ref |
| `extras` | object | Optional: `{ type, text, accessibilityLabel, interactive }` |

### `unregisterComponent(testID)`

Remove a component from the registry (call on unmount).

### `setNavigationRef(ref)`

Set the React Navigation container ref for `get_route` and `go_back` support.

### `setRootRef(ref)`

Set the root component ref for swipe and scroll fallbacks.

## Architecture

The SDK runs entirely in the JavaScript thread. No native modules are required beyond `react-native-tcp-socket` for networking.

```
+---------------------------+
|  React Native App         |
|                           |
|  FlutterSkill.js          |
|    +------------------+   |
|    | TCP Server :18118|   |
|    |   GET /.flutter- |   |
|    |       skill      |   |    <--- Health check (HTTP)
|    |   WS  /ws        |   |    <--- JSON-RPC 2.0 (WebSocket)
|    +------------------+   |
|    | Component        |   |
|    | Registry         |   |    <--- testID -> ref mapping
|    +------------------+   |
|    | Console Capture  |   |    <--- Intercepts console.log/warn/error
|    +------------------+   |
+---------------------------+
```

## Compatibility

- React Native 0.68+ (both Old Architecture and New Architecture / Fabric)
- iOS and Android
- Expo (with development builds that include `react-native-tcp-socket`)
- React Navigation 5+ for route detection

## Notes

- **Development only**: Wrap `initFlutterSkill()` in `if (__DEV__)` to avoid shipping the bridge in production.
- **Screenshots**: The SDK returns `{ _needs_native: true }` for screenshots. The flutter-skill proxy handles this via `xcrun simctl screenshot` (iOS) or `adb screencap` (Android).
- **Element registration**: Unlike the web SDK which can query the DOM, React Native requires explicit registration of interactive elements. Use `registerComponent()` on elements you want the agent to interact with.
- **Port conflicts**: If port 18118 is in use, pass a custom port via `initFlutterSkill({ port: 18119 })`. The proxy scans ports 18118-18128.
