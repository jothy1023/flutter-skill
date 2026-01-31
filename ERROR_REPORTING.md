# Error Reporting & Bug Fixes

## Recent Bug Fixes

### 1. Fixed LateInitializationError in MCP Server

**Problem:**
- Multiple MCP server instances running simultaneously
- `_service` and `_isolateId` accessed before initialization
- Poor error handling in `getMemoryStats()`

**Solution:**
- Added lock file mechanism (`~/.flutter_skill.lock`) to prevent multiple instances
- Improved connection state checking with clear error messages
- Fixed exception handling in memory stats retrieval

**Files Changed:**
- `lib/src/flutter_skill_client.dart` - Fixed `getMemoryStats()` exception handling
- `lib/src/cli/server.dart` - Added lock mechanism and improved error messages

### 2. Multi-Process Prevention

**How it works:**
```dart
// Lock file created when server starts
~/.flutter_skill.lock contains:
  <PID>
  <Timestamp>

// Auto-cleanup of stale locks (> 10 minutes old)
```

**Manual cleanup if needed:**
```bash
rm ~/.flutter_skill.lock
```

### 3. Better Error Messages

**Before:**
```
Exception: Not connected
```

**After:**
```
Not connected to Flutter app.

Solutions:
1. If app is already running: call scan_and_connect() to auto-detect and connect
2. To start a new app: call launch_app(project_path: "/path/to/project")
3. If you have the VM Service URI: call connect_app(uri: "ws://...")

Tip: Use get_connection_status() to see available running apps.
```

## Automatic Error Reporting

### ✨ Zero-Configuration Setup

**No setup required!** Error reporting works automatically:

```bash
flutter_skill server
# When a critical error occurs:
# 1. Error diagnostics are collected
# 2. Browser opens with pre-filled GitHub issue
# 3. You just click "Submit new issue" ✅
```

**How it works:**
- ✅ **Automatic**: Enabled by default (no env vars needed)
- 🌐 **Browser-based**: Opens GitHub with pre-filled issue template
- 🔒 **Privacy-safe**: No tokens required, no data sent to third parties
- ⚡ **One-click**: Just click "Submit" in the browser

### Advanced Setup (Optional)

For **fully automatic** issue creation (no browser interaction):

1. **Get a GitHub Personal Access Token:**
   - Go to https://github.com/settings/tokens
   - Create a token with `repo` scope
   - Set environment variable:
     ```bash
     export GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
     ```

2. **Disable auto-reporting (if desired):**
   ```bash
   export FLUTTER_SKILL_AUTO_REPORT=false
   ```

3. **Configure repository (if forked):**
   ```bash
   export FLUTTER_SKILL_REPO_OWNER=your-org
   export FLUTTER_SKILL_REPO_NAME=flutter-skill
   ```

### Usage

#### Automatic Reporting

When enabled, critical errors are automatically reported:

```bash
# Run MCP server with auto-reporting
FLUTTER_SKILL_AUTO_REPORT=true flutter_skill server
```

Critical errors include:
- `LateInitializationError`
- `Null check operator used on a null value`
- `UnhandledException`
- `StackOverflowError`
- `OutOfMemoryError`

#### Manual Reporting

Use the CLI to manually report bugs:

```bash
flutter_skill report-error
```

This will:
1. Prompt for error details
2. Collect system diagnostics
3. Search for similar existing issues
4. Create a new GitHub issue with full context

### Error Report Format

Auto-generated issues include:

```markdown
## Error Report

**Type:** `LateInitializationError`
**Message:** Field '_service' has not been initialized

## Environment

- OS: macos (Darwin 25.2.0)
- Dart: 3.x.x
- flutter-skill: 0.2.14

## Stack Trace

```
[Full stack trace]
```

## Context

```json
{
  "method": "tools/call",
  "params": {...},
  "client_connected": false
}
```
```

### Privacy & Security

- **No sensitive data is collected** - Only error types, messages, and stack traces
- **User credentials are never included** - Connection URIs are sanitized
- **GitHub token is local only** - Token is read from environment, never stored
- **Opt-in by default** - Auto-reporting requires explicit `FLUTTER_SKILL_AUTO_REPORT=true`

## Testing the Fixes

### Test Multi-Process Prevention

```bash
# Terminal 1
flutter_skill server &

# Terminal 2 (should fail)
flutter_skill server
# Expected: "ERROR: Another flutter-skill server is already running."
```

### Test Error Reporting

```bash
# Set up token
export GITHUB_TOKEN=ghp_xxxxx
export FLUTTER_SKILL_AUTO_REPORT=true

# Run server and trigger an error
flutter_skill server
# In Claude Code, try to use a tool before connecting
# Check if issue was auto-created in GitHub
```

### Test Manual Error Reporting

```bash
export GITHUB_TOKEN=ghp_xxxxx
flutter_skill report-error
# Follow the interactive prompts
```

## Debugging

### View Lock File Status

```bash
cat ~/.flutter_skill.lock
# Output:
# 12345
# 2026-01-31T14:30:00.000Z
```

### Check Running Processes

```bash
ps aux | grep flutter-skill
```

### Clean Up Stale Processes

```bash
pkill -f flutter-skill-macos-arm64
rm ~/.flutter_skill.lock
```

### Disable Auto-Reporting

```bash
unset FLUTTER_SKILL_AUTO_REPORT
# Or explicitly set to false
export FLUTTER_SKILL_AUTO_REPORT=false
```

## Contributing

When debugging issues:

1. **Check lock file first** - `cat ~/.flutter_skill.lock`
2. **Look for multiple processes** - `ps aux | grep flutter-skill`
3. **Enable auto-reporting** - Set `FLUTTER_SKILL_AUTO_REPORT=true`
4. **Collect diagnostics** - Run `flutter_skill report-error`
5. **Share issue URL** - Auto-generated issues have full context

## Roadmap

Future improvements:

- [ ] Crash dump collection
- [ ] Anonymous telemetry (opt-in)
- [ ] Integration with Sentry/Bugsnag
- [ ] Auto-update notifications
- [ ] Health check endpoint
