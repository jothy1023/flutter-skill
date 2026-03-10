# pytest-flutter-skill

A pytest plugin for AI-driven Flutter and web app automation using [flutter-skill](https://github.com/ai-dashboad/flutter-skill).

## Installation

```bash
pip install pytest-flutter-skill
```

Requires `flutter_skill` to be installed and on your PATH:

```bash
dart pub global activate flutter_skill
```

## Usage

The plugin provides a `flutter_skill` fixture that starts the flutter-skill MCP server and wraps its tools as Python methods:

```python
def test_login(flutter_skill):
    flutter_skill.connect_app()           # Connect to running Flutter app
    flutter_skill.tap(text="Login")
    flutter_skill.enter_text("test@example.com", key="emailField")
    flutter_skill.tap(text="Submit")
    flutter_skill.assert_visible(text="Dashboard")

def test_web(flutter_skill):
    flutter_skill.connect_cdp(url="https://example.com")
    flutter_skill.tap(text="Sign in")
    assert flutter_skill.find_element("Welcome")

def test_screenshot(flutter_skill, tmp_path):
    flutter_skill.connect_app()
    result = flutter_skill.screenshot(path=str(tmp_path / "screen.png"))
    assert result.get("success")
```

## Available Methods

### Connection
| Method | Description |
|--------|-------------|
| `connect_app(uri=None)` | Connect to a running Flutter app via VM Service |
| `connect_cdp(port=9222, url=None)` | Connect to Chrome/web via CDP |

### Interaction
| Method | Description |
|--------|-------------|
| `tap(key=None, text=None)` | Tap an element |
| `enter_text(text, key=None)` | Type text into a field |
| `press_key(key)` | Press a keyboard key (enter, tab, escape, …) |
| `scroll(direction, amount, key=None, text=None)` | Scroll |
| `go_back()` | Navigate back |
| `navigate(url)` | Navigate to URL (web) |

### Inspection
| Method | Description |
|--------|-------------|
| `snapshot()` | Get full page/screen snapshot |
| `screenshot(path=None)` | Capture screenshot |
| `find_element(text=None, key=None)` | Return `True` if element exists |
| `wait_for_element(key=None, text=None, timeout=5000)` | Wait for element |
| `get_logs()` | Get app logs |

### Assertions
| Method | Description |
|--------|-------------|
| `assert_visible(key=None, text=None)` | Assert element is visible |
| `assert_not_visible(key=None, text=None)` | Assert element is absent |
| `assert_text(expected, key=None)` | Assert element text matches |

### Other
| Method | Description |
|--------|-------------|
| `hot_reload()` | Trigger hot reload |
| `call_tool(name, **kwargs)` | Call any flutter-skill tool directly |

## CLI Options

```
--flutter-skill-executable  Path to flutter_skill binary (default: flutter_skill)
--flutter-skill-timeout     Seconds to wait per tool call (default: 30)
```

## CI Example

```yaml
# .github/workflows/test.yml
- name: Install flutter-skill
  run: dart pub global activate flutter_skill

- name: Run tests
  run: pytest tests/ -v
```
