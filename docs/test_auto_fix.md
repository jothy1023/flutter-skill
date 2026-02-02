# Auto-Fix Testing Guide

## New MCP Tools with Auto-Fix

### 1. `diagnose_project` - NEW Tool

**Purpose:** Comprehensive project configuration diagnostic and auto-fix

**Usage:**
```javascript
// Diagnose and auto-fix
mcp_tool("diagnose_project", {
  "project_path": "/path/to/project",
  "auto_fix": true  // default
})

// Diagnose only (no fixes)
mcp_tool("diagnose_project", {
  "project_path": "/path/to/project",
  "auto_fix": false
})
```

**What it checks:**
- ✅ pubspec.yaml - flutter_skill dependency
- ✅ lib/main.dart - FlutterSkillBinding import and initialization
- ✅ Running Flutter processes
- ✅ VM Service port availability (50000-50002)

**What it fixes (if auto_fix: true):**
- Adds flutter_skill dependency to pubspec.yaml
- Adds FlutterSkillBinding import to lib/main.dart
- Adds FlutterSkillBinding.ensureInitialized() to main()

**Returns:**
```json
{
  "project_path": "/path/to/project",
  "checks": {
    "pubspec_yaml": {
      "status": "ok|missing_dependency|not_found",
      "message": "..."
    },
    "main_dart": {
      "has_import": true|false,
      "has_initialization": true|false,
      "status": "ok|incomplete|not_found"
    },
    "running_processes": {
      "flutter_running": true|false
    },
    "ports": {
      "port_50000": "available|in_use|unknown"
    }
  },
  "issues": ["list of issues found"],
  "fixes_applied": ["list of fixes applied"],
  "recommendations": ["list of recommendations"],
  "summary": {
    "status": "healthy|fixed|needs_attention",
    "issues_found": 0,
    "fixes_applied": 0,
    "message": "..."
  }
}
```

---

### 2. `connect_app` - Enhanced

**New Feature:** Auto-fix configuration before connecting

**Usage:**
```javascript
// With auto-fix
mcp_tool("connect_app", {
  "uri": "ws://127.0.0.1:50000/xxx=/ws",
  "project_path": "/path/to/project"  // NEW: optional
})

// Without auto-fix (legacy)
mcp_tool("connect_app", {
  "uri": "ws://127.0.0.1:50000/xxx=/ws"
})
```

**Behavior:**
- If `project_path` is provided → runs setup before connecting
- If `project_path` is omitted → connects directly (legacy behavior)

---

### 3. `scan_and_connect` - Enhanced

**New Feature:** Auto-fix configuration before scanning

**Usage:**
```javascript
// With auto-fix
mcp_tool("scan_and_connect", {
  "port_start": 50000,
  "port_end": 50100,
  "project_path": "/path/to/project"  // NEW: optional
})

// Without auto-fix (legacy)
mcp_tool("scan_and_connect", {
  "port_start": 50000,
  "port_end": 50100
})
```

**Behavior:**
- If `project_path` is provided → runs setup before scanning
- If `project_path` is omitted → scans directly (legacy behavior)

---

### 4. `launch_app` - Already Has Auto-Fix

**Existing Feature:** Always runs setup before launching

**Usage:**
```javascript
mcp_tool("launch_app", {
  "project_path": "/path/to/project",
  "device_id": "device_id"
})
```

**Behavior:**
- Always calls `runSetup()` before launching
- Automatically adds `--vm-service-port=50000` for Flutter 3.x+
- No changes needed - already works!

---

## Testing Checklist

### Test 1: diagnose_project
- [ ] Run on unconfigured project → should detect missing config
- [ ] Run with auto_fix:true → should fix issues
- [ ] Run again → should show "healthy" status
- [ ] Run with auto_fix:false → should only report issues

### Test 2: connect_app with auto-fix
- [ ] Remove flutter_skill from pubspec.yaml
- [ ] Call connect_app with project_path → should auto-fix
- [ ] Verify dependency was added

### Test 3: scan_and_connect with auto-fix
- [ ] Remove FlutterSkillBinding from main.dart
- [ ] Call scan_and_connect with project_path → should auto-fix
- [ ] Verify initialization was added

### Test 4: launch_app
- [ ] Verify existing auto-fix still works
- [ ] Check that --vm-service-port is added automatically

---

## Example Workflow for Claude Code

When user asks: "Test my Flutter app"

Claude Code can now:

**Option 1: Proactive diagnostic**
```
1. diagnose_project(project_path: ".")
2. If issues found → already fixed (auto_fix: true by default)
3. launch_app(project_path: ".", device_id: "xxx")
4. Test the app...
```

**Option 2: Smart connection**
```
1. scan_and_connect(project_path: ".")  // auto-fixes if needed
2. If no app found → launch_app(project_path: ".")
3. Test the app...
```

**Option 3: Direct connection**
```
1. connect_app(uri: "ws://...", project_path: ".")  // auto-fixes
2. Test the app...
```

---

## Benefits

✅ **Reduced User Friction**: No manual setup required
✅ **Smart Detection**: Automatically detects and fixes issues
✅ **Backward Compatible**: All tools work without project_path (legacy mode)
✅ **Comprehensive Diagnostic**: New diagnose_project tool for troubleshooting
✅ **Claude Code Integration**: Can automatically fix issues during testing

---

## Implementation Details

**Auto-fix logic location:**
- `lib/src/cli/server.dart:1434` - launch_app (existing)
- `lib/src/cli/server.dart:1326` - connect_app (NEW)
- `lib/src/cli/server.dart:1651` - scan_and_connect (NEW)
- `lib/src/cli/server.dart:1841` - diagnose_project (NEW)

**Setup implementation:**
- `lib/src/cli/setup.dart` - runSetup() function

**What runSetup() does:**
1. Checks pubspec.yaml for flutter_skill dependency
2. Runs `flutter pub add flutter_skill` if missing
3. Checks lib/main.dart for import and initialization
4. Adds import and initialization code if missing
