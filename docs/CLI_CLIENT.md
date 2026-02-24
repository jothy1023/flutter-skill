# CLI Client Commands

The flutter-skill CLI client provides command-line access to a running `flutter-skill serve` instance. Use it for browser automation, CI/CD pipelines, scripting, and remote access.

## Prerequisites

Start a serve instance first:

```bash
flutter-skill serve https://your-app.com
```

The serve instance runs on `http://127.0.0.1:3000` by default.

## Commands

### `nav` — Navigate to URL

```bash
flutter-skill nav https://google.com
flutter-skill nav https://your-app.com/login
```

Aliases: `navigate`, `go`

### `snap` — Accessibility Tree Snapshot

Returns a compact semantic representation of the page — 99% fewer tokens than a screenshot.

```bash
flutter-skill snap
```

Alias: `snapshot`

### `screenshot` — Take Screenshot

```bash
flutter-skill screenshot                  # Saves to /tmp/screenshot.jpg
flutter-skill screenshot /tmp/login.jpg   # Custom path
```

Alias: `ss`

### `tap` — Tap Element

Three targeting modes:

```bash
flutter-skill tap "Login"           # By visible text
flutter-skill tap e15                # By element ref (from snap)
flutter-skill tap 200 300            # By coordinates (x y)
```

### `type` — Type Text

Types text via keyboard simulation:

```bash
flutter-skill type "hello@example.com"
flutter-skill type "my search query"
```

### `key` — Press Key

```bash
flutter-skill key Enter
flutter-skill key Tab
flutter-skill key a control        # Ctrl+A (select all)
flutter-skill key c meta           # Cmd+C (copy on macOS)
```

Alias: `press`

### `eval` — Execute JavaScript

```bash
flutter-skill eval "document.title"
flutter-skill eval "document.querySelectorAll('a').length"
flutter-skill eval "window.location.href"
```

Alias: `js`

### `title` — Get Page Title

```bash
flutter-skill title
# Output: My App - Dashboard
```

### `text` — Get Visible Text

```bash
flutter-skill text
```

### `hover` — Hover Element

```bash
flutter-skill hover "Menu Item"
flutter-skill hover "Dropdown"
```

### `upload` — Upload File

```bash
flutter-skill upload "input[type=file]" /path/to/image.png
flutter-skill upload auto /path/to/document.pdf    # Auto-detect input
```

### `tools` — List Available Tools

```bash
flutter-skill tools
# Output:
# navigate
# snapshot
# screenshot
# tap
# ...
# 246 tools
```

### `call` — Call Any Tool Directly

For tools not covered by shorthand commands:

```bash
flutter-skill call page_summary
flutter-skill call fill '{"selector": "#email", "value": "test@example.com"}'
flutter-skill call set_viewport '{"width": 375, "height": 812}'
flutter-skill call emulate_device '{"device": "iPhone 14"}'
```

### `wait` — Wait (ms)

```bash
flutter-skill wait 2000    # Wait 2 seconds
flutter-skill wait          # Default: 1000ms
```

## Configuration

### Port and Host

```bash
# Via flags
flutter-skill tap "Login" --port=8080
flutter-skill snap --host=192.168.1.100 --port=4000

# Via environment variables
export FS_PORT=8080
export FS_HOST=192.168.1.100
flutter-skill tap "Login"
```

Priority: environment variables override flags.

### Serve Startup Options

```bash
flutter-skill serve https://your-app.com --port=8080 --host=0.0.0.0
```

## Scripting Examples

### Login Flow

```bash
flutter-skill nav https://app.example.com/login
flutter-skill tap "Email"
flutter-skill type "user@example.com"
flutter-skill tap "Password"
flutter-skill type "secretpass"
flutter-skill tap "Sign In"
flutter-skill wait 2000
flutter-skill screenshot /tmp/after-login.jpg
```

### CI/CD Pipeline

```bash
#!/bin/bash
set -e

# Start serve in background
flutter-skill serve https://staging.example.com &
sleep 3

# Run test sequence
flutter-skill snap
flutter-skill tap "Get Started"
flutter-skill wait 1000
flutter-skill screenshot /tmp/ci-test.jpg
flutter-skill title

# Cleanup
kill %1
```

### Batch Testing with `call`

```bash
# Execute multiple actions in one call
flutter-skill call execute_batch '{
  "actions": [
    {"type": "fill", "target": "input:Email", "value": "test@example.com"},
    {"type": "fill", "target": "input:Password", "value": "password123"},
    {"type": "tap", "target": "button:Login"}
  ]
}'
```

## Troubleshooting

### "flutter-skill serve not running"

The CLI client connects to an existing serve instance. Make sure it's running:

```bash
flutter-skill serve https://your-app.com
```

### Connection refused

Check the port:

```bash
# Default port
curl http://127.0.0.1:3000/tools/list

# Custom port
curl http://127.0.0.1:8080/tools/list
```

### Timeout on commands

The default timeout is 30 seconds. For slow operations, use `call` with longer timeouts or break into smaller steps.

## Command Reference

| Command | Description | Arguments |
|---------|-------------|-----------|
| `nav <url>` | Navigate to URL | URL (required) |
| `snap` | Accessibility tree snapshot | — |
| `screenshot [path]` | Take screenshot | Path (optional, default: `/tmp/screenshot.jpg`) |
| `tap <target>` | Tap element | Text, ref (`e15`), or coordinates (`x y`) |
| `type <text>` | Type via keyboard | Text (required) |
| `key <key> [mod]` | Press key | Key name, optional modifier |
| `eval <js>` | Execute JavaScript | Expression (required) |
| `title` | Get page title | — |
| `text` | Get visible text | — |
| `hover <text>` | Hover element | Text (required) |
| `upload <sel> <file>` | Upload file | Selector + file path |
| `tools` | List all tools | — |
| `call <tool> [json]` | Call any tool | Tool name + optional JSON args |
| `wait [ms]` | Wait | Milliseconds (default: 1000) |
