# How to Use Flutter Skill

> **One prompt. One shot. Your AI tests the entire app.** 🔥
>
> Inspired by the "AI skills" workflow — give your AI agent the flutter-skill, and it can see, interact with, and test any running app.

---

## ⚡ 30-Second Setup

```bash
# 1. Install
npm install -g flutter-skill

# 2. Init your project (auto-detects framework & patches your app)
cd your-app/
flutter-skill init

# 3. Add to your AI's MCP config
```

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

**Done.** Your AI can now see and control your app.

---

## 🎬 One Prompt, Full Test

Just tell your AI what to test. No test code. No selectors. No boilerplate.

### Example 1: Test Login Flow

**You say:**
> "Launch my app, test the login with test@example.com and password123, verify it reaches the dashboard"

**AI does:**
```
1. launch_app()              → starts your app
2. screenshot()              → sees the login screen
3. inspect()                 → finds email field, password field, login button
4. enter_text("email_field", "test@example.com")
5. enter_text("password_field", "password123")
6. tap("login_button")
7. wait_for_element("dashboard_title")
8. screenshot()              → captures the dashboard
✅ "Login flow works — dashboard loaded successfully"
```

### Example 2: Full Form Validation

**You say:**
> "Submit the registration form empty and check that all validation errors appear"

**AI does:**
```
1. screenshot()              → sees the registration form
2. tap("submit_button")      → submits empty form
3. inspect()                 → finds error messages
4. assert_text("Email is required")
5. assert_text("Password is required")
6. screenshot()              → captures the error state
✅ "All 3 validation errors displayed correctly"
```

### Example 3: Visual Regression

**You say:**
> "Navigate through all 5 tabs and screenshot each one"

**AI does:**
```
1. tap("home_tab")     → screenshot("home.png")
2. tap("search_tab")   → screenshot("search.png")
3. tap("profile_tab")  → screenshot("profile.png")
4. tap("settings_tab") → screenshot("settings.png")
5. tap("inbox_tab")    → screenshot("inbox.png")
✅ "All 5 tab screenshots captured"
```

### Example 4: Complete E2E Flow

**You say:**
> "Test the complete checkout flow — add an item to cart, go to checkout, fill shipping, confirm order"

**AI does:**
```
1. tap("product_1")          → opens product detail
2. tap("add_to_cart")        → adds to cart
3. tap("cart_icon")          → opens cart
4. tap("checkout_button")   → opens checkout
5. enter_text("address", "123 Main St")
6. enter_text("city", "San Francisco")
7. tap("confirm_order")
8. wait_for_element("order_confirmed")
9. screenshot()
✅ "Order #12345 confirmed — full checkout flow verified"
```

---

## 🔧 Two Modes

### Mode 1: CLI (Claude Code / Terminal)

Use flutter-skill directly from the command line:

```bash
# Launch your app
flutter-skill launch /path/to/your/app

# Inspect the screen
flutter-skill inspect

# Interact
flutter-skill act tap "login_button"
flutter-skill act enter_text "email" "hello@example.com"
flutter-skill act scroll_to "bottom_item"

# Screenshot
flutter-skill screenshot ./screen.png
```

### Mode 2: MCP Server (Cursor / Windsurf / Claude Desktop)

Add to your MCP settings and just talk to the AI. It calls the tools automatically.

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

**Works with:** Claude Code, Claude Desktop, Cursor, Windsurf, Cline, Continue, or any MCP client.

---

## 📱 8 Platforms, One Skill

flutter-skill works the same way across all platforms:

| Platform | Add to your app | AI can test it |
|----------|----------------|----------------|
| **Flutter** (iOS/Android/Web) | `FlutterSkillBinding.ensureInitialized()` | ✅ |
| **React Native** | `import FlutterSkill; FlutterSkill.start()` | ✅ |
| **Electron** | `require('flutter-skill-bridge').start()` | ✅ |
| **iOS** (Swift/SwiftUI) | `FlutterSkillBridge.shared.start()` | ✅ |
| **Android** (Kotlin) | `FlutterSkillBridge.start(this)` | ✅ |
| **Tauri** (Rust) | `flutter_skill::init()` | ✅ |
| **KMP** (Kotlin Multiplatform) | `FlutterSkillBridge().start()` | ✅ |
| **.NET MAUI** | `FlutterSkillBridge.Start()` | ✅ |

**Same AI prompts. Same tools. Any framework.**

---

## 🛠️ All 40+ Tools

<details>
<summary><strong>👀 See the Screen</strong></summary>

| Tool | What it does |
|------|-------------|
| `screenshot` | Full app screenshot (base64 PNG) |
| `screenshot_element` | Screenshot a specific element |
| `inspect` | List all interactive elements (buttons, fields, etc.) |
| `get_widget_tree` | Full widget hierarchy |
| `find_by_type` | Find widgets by type (e.g., "ElevatedButton") |
| `get_text_content` | Extract all visible text |

</details>

<details>
<summary><strong>👆 Interact Like a User</strong></summary>

| Tool | What it does |
|------|-------------|
| `tap` | Tap an element by key or text |
| `double_tap` | Double tap |
| `long_press` | Long press |
| `enter_text` | Type into a text field |
| `swipe` | Swipe up/down/left/right |
| `scroll_to` | Scroll an element into view |
| `drag` | Drag from one element to another |
| `go_back` | Navigate back |
| `native_tap` | Tap via native OS (for system dialogs) |
| `native_input_text` | Type via native OS |
| `native_swipe` | Swipe via native OS |

</details>

<details>
<summary><strong>✅ Verify & Assert</strong></summary>

| Tool | What it does |
|------|-------------|
| `assert_text` | Verify text is visible |
| `assert_visible` | Verify element exists |
| `assert_not_visible` | Verify element is gone |
| `assert_element_count` | Verify number of elements |
| `wait_for_element` | Wait for element to appear (with timeout) |
| `wait_for_gone` | Wait for element to disappear |
| `get_checkbox_state` | Get checkbox checked/unchecked |
| `get_slider_value` | Get slider position |
| `get_text_value` | Get text field value |

</details>

<details>
<summary><strong>🚀 Launch & Control</strong></summary>

| Tool | What it does |
|------|-------------|
| `launch_app` | Launch app with flavors/defines |
| `scan_and_connect` | Auto-find running apps |
| `connect_app` | Connect via URI |
| `hot_reload` | Trigger hot reload |
| `hot_restart` | Trigger hot restart |
| `list_sessions` | List connected sessions |
| `switch_session` | Switch between sessions |

</details>

<details>
<summary><strong>🐛 Debug & Logs</strong></summary>

| Tool | What it does |
|------|-------------|
| `get_logs` | Application logs |
| `get_errors` | Error messages |
| `get_performance` | Performance metrics |
| `get_memory_stats` | Memory usage |
| `clear_logs` | Clear log buffer |

</details>

---

## 💡 Best Practices

### 1. Use Widget Keys for Reliable Tests

```dart
ElevatedButton(
  key: const ValueKey('submit_button'),
  onPressed: _submit,
  child: const Text('Submit'),
)
```

**Finding priority:** Key (most reliable) → Text content → Widget type

### 2. Use `flutter-skill init` for Zero-Config Setup

```bash
cd your-app/
flutter-skill init    # Auto-detects framework, patches entry point
```

Supports: Flutter, iOS, Android, React Native, Web — detects and patches automatically.

### 3. Try the Demo First

```bash
flutter-skill demo    # Launches a built-in demo app to try all features
```

### 4. Use Natural Language Prompts

Instead of:
```
tap("login_button")
enter_text("email", "test@example.com")
```

Just say:
> "Log in with test@example.com"

The AI figures out the steps.

---

## 🔧 Flutter 3.x Compatibility

**Automatic** — Flutter Skill handles Flutter 3.x VM Service changes. No configuration needed.

Flutter 3.x moved from VM Service to DTD. Flutter Skill automatically adds `--vm-service-port=50000` when launching.

```bash
# Just use normally:
launch_app(device_id: "iPhone 16 Pro")

# Optional: custom port
launch_app(device_id: "iPhone 16 Pro", extra_args: ["--vm-service-port=8888"])
```

---

## 🔥 Troubleshooting

| Problem | Fix |
|---------|-----|
| "Not connected" | Run `scan_and_connect` to auto-find apps |
| "Unknown method" | Run `flutter pub add flutter_skill` then restart (not hot reload) |
| No VM Service URI | Add `--vm-service-port=50000` to launch args |
| Claude Code priority | Run `flutter_skill setup` for priority rules |
| Slow first run | First launch compiles the SDK — subsequent runs are fast |

📖 **More help:** [Architecture](ARCHITECTURE.md) · [Troubleshooting](TROUBLESHOOTING.md) · [Flutter 3.x Fix](FLUTTER_3X_FIX.md)

---

## 🌟 What Makes This Different?

| Traditional E2E | flutter-skill |
|-----------------|---------------|
| Write test scripts | Describe in natural language |
| Learn testing framework | Just talk to your AI |
| Maintain selectors | AI finds elements automatically |
| One framework at a time | 8 platforms, one tool |
| Tests break on UI changes | AI adapts to new UI |
| Hours of setup | 30 seconds |

---

<p align="center">
  <strong>Give your AI the skill to test your app → <a href="https://github.com/ai-dashboad/flutter-skill">github.com/ai-dashboad/flutter-skill</a></strong>
</p>
