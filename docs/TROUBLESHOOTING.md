# Troubleshooting Guide

## Quick Fix for "Cannot Connect to VM Service"

### Step 1: Run Diagnostic (NEW - Recommended!)

**Option A: Using MCP Tool (from Claude Code)**
```
Use the diagnose_project MCP tool:
- Project path: /path/to/your/project
- Auto-fix: true (default)

This will automatically detect and fix all configuration issues!
```

**Option B: Using CLI**
```bash
cd /path/to/your/flutter/project
/path/to/flutter-skill/scripts/diagnose.sh
```

### Step 2: Auto-Fix Configuration

**Auto-fix is now built into ALL MCP connection tools!**

```javascript
// NEW: diagnose_project - comprehensive diagnostic
mcp_tool("diagnose_project", {
  "project_path": ".",
  "auto_fix": true
})

// launch_app - always auto-fixes (no change)
mcp_tool("launch_app", {
  "project_path": ".",
  "device_id": "device_id"
})

// connect_app - now supports auto-fix
mcp_tool("connect_app", {
  "uri": "ws://...",
  "project_path": "."  // Add this for auto-fix
})

// scan_and_connect - now supports auto-fix
mcp_tool("scan_and_connect", {
  "project_path": "."  // Add this for auto-fix
})
```

**Or use CLI:**
```bash
# Automatic setup
flutter_skill setup

# Or launch (automatically runs setup)
flutter_skill launch . -d device_id
```

### Step 3: Verify
```bash
# Check if everything is configured
flutter_skill inspect
```

## Common Issues and Solutions

### Issue 1: "No VM Service URI found"

**Cause:** App not launched with `--vm-service-port` flag

**Solution:**
```bash
# ✅ Use flutter_skill launch (auto-adds flag)
flutter_skill launch . -d device_id

# ✅ Or add flag manually
flutter run -d device_id --vm-service-port=50000
```

### Issue 2: "Connection refused"

**Cause:**
- Port already in use
- VM Service not enabled
- Flutter app not running

**Solution:**
```bash
# Check port usage
lsof -i :50000

# Kill existing Flutter processes
pkill -f "flutter run"

# Restart with flutter_skill
flutter_skill launch . -d device_id
```

### Issue 3: "FlutterSkillBinding not initialized"

**Cause:** Missing setup in main.dart

**Solution:**
```bash
# Auto-fix
flutter_skill setup

# Or manually add to lib/main.dart:
# import 'package:flutter_skill/flutter_skill.dart';
# import 'package:flutter/foundation.dart';
#
# void main() {
#   if (kDebugMode) {
#     FlutterSkillBinding.ensureInitialized();
#   }
#   runApp(const MyApp());
# }
```

### Issue 4: "DTD URI found but no VM Service"

**Cause:** Flutter 3.x+ only enables DTD by default

**Solution:**
Always use `--vm-service-port` flag (flutter_skill does this automatically)

```bash
flutter_skill launch . -d device_id
```

## Diagnostic Output Examples

### ✅ Healthy Configuration
```
=== Flutter Skill Configuration Check ===
✅ pubspec.yaml has flutter_skill dependency
✅ main.dart has FlutterSkillBinding initialization
✅ Port 50000 is available
```

### ❌ Needs Fix
```
=== Flutter Skill Configuration Check ===
❌ pubspec.yaml missing flutter_skill dependency
   Fix: Add flutter_skill: ^0.4.4
❌ main.dart missing initialization
   Fix: Add FlutterSkillBinding.ensureInitialized()
```

## Get Help

If automatic fixes don't work:

1. Run diagnostic script: `./scripts/diagnose.sh`
2. Check the output for specific errors
3. Review [CLAUDE.md](CLAUDE.md) for project rules
4. Open an issue with diagnostic output

## Flutter Version Compatibility

- **Flutter 3.x**: Requires `--vm-service-port=50000`
- **Flutter 3.41+**: Requires `--vm-service-port=50000` (new URI format `#` supported)

The plugin automatically handles both URI formats:
- Old: `http://127.0.0.1:port/token=/`
- New: `http://127.0.0.1:port/token#/`
