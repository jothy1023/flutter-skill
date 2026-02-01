# 协议智能选择 - 集成示例

## 🎯 目标

在保持 VM Service 为主的同时，支持 DTD 作为补充协议。

---

## 📝 实现示例

### 1. 增强 `scan_and_connect` 工具

```dart
// lib/src/cli/server.dart

if (name == 'scan_and_connect') {
  final portStart = args['port_start'] ?? 50000;
  final portEnd = args['port_end'] ?? 50100;

  // 1️⃣ 扫描所有可用协议
  final protocols = await ProtocolDetector.scanAvailableProtocols(
    portStart: portStart,
    portEnd: portEnd,
  );

  final vmServices = protocols[FlutterProtocol.vmService]!;
  final dtdServices = protocols[FlutterProtocol.dtd]!;

  // 2️⃣ 优先选择 VM Service
  if (vmServices.isNotEmpty) {
    final uri = vmServices.first;
    _client = FlutterSkillClient(uri);
    await _client!.connect();

    return {
      "success": true,
      "protocol": "vm_service",
      "uri": uri,
      "capabilities": "完整功能",
      "available": {
        "vm_service": vmServices,
        "dtd": dtdServices,
      }
    };
  }

  // 3️⃣ 如果只有 DTD，提示用户
  if (dtdServices.isNotEmpty) {
    return {
      "success": false,
      "protocol": "dtd_only",
      "message": "仅检测到 DTD 协议（基础功能）",
      "available_dtd": dtdServices,
      "suggestions": [
        "DTD 仅支持: hot_reload, get_logs",
        "不支持: tap, screenshot, inspect",
        "",
        "获得完整功能的方法:",
        "1. 重启应用: flutter run --vm-service-port=50000",
        "2. 或使用: launch_app() 自动启用 VM Service"
      ],
      "quick_fix": {
        "action": "restart_with_vm_service",
        "command": "flutter run --vm-service-port=50000"
      }
    };
  }

  // 4️⃣ 未找到任何协议
  return {
    "success": false,
    "message": "未找到运行的 Flutter 应用",
    "suggestions": [
      "确保 Flutter 应用正在运行",
      "使用 launch_app() 启动应用"
    ]
  };
}
```

---

### 2. 增强 `launch_app` 工具描述

```dart
{
  "name": "launch_app",
  "description": """⚡ PRIORITY TOOL FOR UI TESTING ⚡

[PROTOCOL STRATEGY]
✅ AUTO-CONFIGURED: Automatically enables VM Service for full functionality
• VM Service: Complete UI automation (tap, screenshot, inspect)
• DTD: Basic functions only (hot reload, logs)
• This tool ensures VM Service is always available

[FLUTTER 3.x COMPATIBILITY]
✅ Auto-adds --vm-service-port=50000 for Flutter 3.x
• Flutter 3.x defaults to DTD protocol
• This tool automatically enables VM Service for complete features
• No manual configuration needed!

[WHY VM SERVICE?]
DTD alone cannot support:
  ❌ tap / click operations
  ❌ screenshot capture
  ❌ Widget Tree inspection
  ❌ text input simulation

VM Service provides:
  ✅ All DTD features (hot reload, logs)
  ✅ Plus: UI automation via Service Extensions
  ✅ Complete testing capabilities
""",
}
```

---

### 3. 新增 `get_protocol_info` 工具

```dart
{
  "name": "get_protocol_info",
  "description": """Get information about the current protocol and available capabilities.

Use this to understand:
• Which protocol is being used (VM Service or DTD)
• What features are available
• Why certain operations might fail
""",
  "inputSchema": {
    "type": "object",
    "properties": {}
  }
}

// 实现
if (name == 'get_protocol_info') {
  if (_client == null) {
    return {
      "connected": false,
      "message": "Not connected to any Flutter app"
    };
  }

  final protocol = ProtocolDetector.detectFromUri(_client!.vmServiceUri);
  final capabilities = ProtocolDetector.getCapabilities(protocol);

  return {
    "connected": true,
    "protocol": protocol.toString().split('.').last,
    "protocol_description": ProtocolDetector.describeProtocol(protocol),
    "uri": _client!.vmServiceUri,
    "capabilities": capabilities,
    "supported_operations": capabilities.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList(),
    "unsupported_operations": capabilities.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList(),
  };
}
```

---

### 4. 工具调用前的能力检查

```dart
// 在执行 tap 等操作前检查协议能力
case 'tap':
  // 1. 检查是否连接
  _requireConnection();

  // 2. 检查协议能力
  final protocol = ProtocolDetector.detectFromUri(_client!.vmServiceUri);
  final capabilities = ProtocolDetector.getCapabilities(protocol);

  if (!capabilities['tap']!) {
    return {
      "success": false,
      "error": "tap 操作需要 VM Service 协议",
      "current_protocol": ProtocolDetector.describeProtocol(protocol),
      "suggestions": [
        "当前协议不支持 UI 操作",
        "请使用以下方法之一:",
        "1. 使用 launch_app() 重新启动应用",
        "2. 手动重启: flutter run --vm-service-port=50000",
        "3. 使用 scan_and_connect() 查找 VM Service 实例"
      ]
    };
  }

  // 3. 执行操作
  final result = await _client!.tap(key: args['key'], text: args['text']);
  return result;
```

---

## 🎬 用户体验示例

### 场景 1: VM Service 可用（最佳体验）

```
用户: "测试登录按钮"

AI:
  1. scan_and_connect()
     → 找到 VM Service (http://127.0.0.1:50000/...)
     → ✅ 完整功能可用

  2. tap(key: "login_button")
     → ✅ 成功点击

  3. screenshot()
     → ✅ 获取截图

结果: "✅ 登录按钮测试成功！"
```

---

### 场景 2: 仅 DTD 可用（智能提示）

```
用户: "测试登录按钮"

AI:
  1. scan_and_connect()
     → 找到 DTD (ws://127.0.0.1:52049/...)
     → ⚠️ 仅基础功能

响应:
{
  "success": false,
  "protocol": "dtd_only",
  "message": "检测到仅 DTD 协议，无法执行 UI 操作",
  "suggestions": [
    "DTD 仅支持: hot_reload, get_logs",
    "不支持: tap, screenshot, inspect",
    "",
    "要获得完整功能，请选择:",
    "1. 让我重启应用并启用 VM Service（推荐）",
    "2. 继续使用基础功能（仅热重载、日志）"
  ]
}

AI 询问用户:
"检测到应用仅启用了基础协议（DTD），无法执行点击操作。
是否需要我重启应用并启用完整功能？[是/否]"

用户选择 "是":
  → launch_app() 重启应用
  → 自动添加 --vm-service-port=50000
  → ✅ 获得完整功能

用户选择 "否":
  → 仅执行支持的操作（热重载、日志）
```

---

### 场景 3: 无可用协议（引导启动）

```
用户: "测试登录按钮"

AI:
  1. scan_and_connect()
     → ❌ 未找到运行的应用

响应:
{
  "success": false,
  "message": "未找到运行的 Flutter 应用",
  "suggestions": [
    "使用 launch_app() 启动应用",
    "或手动运行: flutter run --vm-service-port=50000"
  ]
}

AI 自动处理:
"未检测到运行的应用，正在启动..."
  → launch_app(device_id: "iPhone 16 Pro")
  → ✅ 应用启动并连接成功
```

---

## 📊 决策流程图

```
用户请求: "测试 UI"
         │
         ▼
  ┌──────────────┐
  │scan_and_connect│
  └──────┬─────────┘
         │
         ▼
  ┌─────────────────┐
  │检测可用协议      │
  └─────┬───────────┘
        │
   ┌────┴────┐
   │         │
VM Service  DTD Only
   │         │
   ▼         ▼
  ✅       ⚠️
完整功能   基础功能
   │         │
   │    ┌────┴────┐
   │    │提示用户  │
   │    └────┬────┘
   │         │
   │    ┌────┴─────┐
   │   重启  │  继续
   │    │         │
   │    ▼         ▼
   │  launch   仅基础
   │   app      功能
   │    │
   └────┴────┐
            │
            ▼
      ✅ 执行操作
```

---

## 🎯 总结

### 当前方案（已实现）
- ✅ 自动添加 `--vm-service-port=50000`
- ✅ 保证 VM Service 可用
- ✅ 零配置，完整功能

### 未来增强（可选）
- 🔄 协议自动检测
- 🔄 DTD 降级支持（基础功能）
- 🔄 智能提示和引导
- 🔄 混合模式（VM Service + DTD）

### 优先级
**当前已足够好！** 自动添加 VM Service 端口已经解决了 99% 的使用场景。

DTD 支持可以作为**未来优化**，不是必需功能。

---

**建议**: 保持当前实现，将 DTD 支持作为 v0.5.0+ 的增强特性。
