# Flutter Skill 通讯流程详解

## 🎬 实例演示：点击登录按钮

### 场景
用户在 Cursor 中输入：**"测试登录按钮是否可以点击"**

---

## 📡 完整通讯流程

### Step 1: AI 决策 → MCP 调用

```
AI 思考: 需要点击 "login_button"
  ↓
生成 MCP 工具调用
```

**MCP 请求 (JSON-RPC)**:
```json
{
  "jsonrpc": "2.0",
  "id": "msg_123",
  "method": "tools/call",
  "params": {
    "name": "tap",
    "arguments": {
      "key": "login_button"
    }
  }
}
```

**传输方式**: stdin → MCP Server

---

### Step 2: MCP Server 接收 → 翻译为 Dart 调用

**代码位置**: `lib/src/cli/server.dart:1424`

```dart
// MCP Server 的工具路由
case 'tap':
  final key = args['key'];        // "login_button"
  final text = args['text'];       // null

  // 调用 FlutterSkillClient
  final result = await _client!.tap(key: key, text: text);

  // 返回结果
  return result;  // {"success": true}
```

**关键对象**:
```dart
FlutterSkillClient? _client;  // 已连接到 VM Service
```

---

### Step 3: FlutterSkillClient → VM Service 调用

**代码位置**: `lib/src/flutter_skill_client.dart:50`

```dart
Future<Map<String, dynamic>> tap({String? key, String? text}) async {
  // 调用 VM Service 扩展
  final result = await _call('ext.flutter.flutter_skill.tap', {
    'key': key,      // "login_button"
    'text': text,    // null
  });
  return result;
}

// 底层实现
Future<Map<String, dynamic>> _call(String method, [Map<String, dynamic>? args]) async {
  // 1. 检查连接
  if (_service == null || _isolateId == null) {
    throw Exception('Not connected');
  }

  // 2. 调用 VM Service 扩展
  final response = await _service!.callServiceExtension(
    method,              // "ext.flutter.flutter_skill.tap"
    isolateId: _isolateId!,  // "isolates/12345"
    args: args,          // {"key": "login_button"}
  );

  // 3. 解析响应
  return response.json ?? {};
}
```

**WebSocket 通讯**:
```
ws://127.0.0.1:50000/abc123=/ws
  ↓ 发送
{
  "method": "callServiceExtension",
  "params": {
    "method": "ext.flutter.flutter_skill.tap",
    "isolateId": "isolates/12345",
    "args": {"key": "login_button"}
  }
}
```

**传输方式**: WebSocket (JSON over ws://)

---

### Step 4: VM Service → Flutter App (Service Extension)

**VM Service 路由**:
```
1. 接收 WebSocket 消息
2. 找到目标 isolate (isolates/12345)
3. 查找已注册的扩展 "ext.flutter.flutter_skill.tap"
4. 调用扩展处理函数
```

**代码位置**: `lib/flutter_skill.dart:27`

```dart
class FlutterSkillBinding {
  static void ensureInitialized() {
    // 注册 tap 扩展
    registerExtension(
      'ext.flutter.flutter_skill.tap',  // ← 扩展名称
      (String method, Map<String, String> parameters) async {
        print('Received tap request: $parameters');

        // 提取参数
        final key = parameters['key'];    // "login_button"
        final text = parameters['text'];  // null

        // 执行点击操作
        final success = await _findAndTap(key: key, text: text);

        // 返回结果
        return ServiceExtensionResponse.result(
          json.encode({'success': success})
        );
      },
    );
  }
}
```

**传输方式**: 内存调用（同一进程内）

---

### Step 5: 查找并点击 Widget

**代码位置**: `lib/flutter_skill.dart:内部实现`

```dart
Future<bool> _findAndTap({String? key, String? text}) async {
  // 1️⃣ 遍历 Widget Tree 查找元素
  Element? targetElement;

  void visitor(Element element) {
    // 检查 widget key
    if (key != null && element.widget.key is ValueKey) {
      final valueKey = element.widget.key as ValueKey;
      if (valueKey.value.toString() == key) {
        targetElement = element;
        return;
      }
    }

    // 递归访问子节点
    element.visitChildren(visitor);
  }

  // 从根节点开始遍历
  WidgetsBinding.instance.renderViewElement?.visitChildren(visitor);

  if (targetElement == null) {
    return false;  // 未找到元素
  }

  // 2️⃣ 获取元素位置
  final renderBox = targetElement!.renderObject as RenderBox;
  final globalPosition = renderBox.localToGlobal(Offset.zero);
  final center = globalPosition + renderBox.size.center(Offset.zero);

  // 3️⃣ 模拟触摸事件
  await _simulateTap(center);

  return true;
}

Future<void> _simulateTap(Offset position) async {
  final binding = WidgetsBinding.instance;

  // 创建触摸事件
  final downEvent = PointerDownEvent(
    position: position,
    pointer: 1,
  );

  final upEvent = PointerUpEvent(
    position: position,
    pointer: 1,
  );

  // 发送事件
  binding.handlePointerEvent(downEvent);
  await Future.delayed(Duration(milliseconds: 50));  // 短暂延迟
  binding.handlePointerEvent(upEvent);
}
```

**访问的数据结构**:
```
WidgetsBinding
  └─ renderViewElement (根 Element)
      └─ child elements (递归)
          └─ ElevatedButton
              └─ key: ValueKey("login_button") ← 找到了！
```

---

### Step 6: 结果返回

**返回路径**: 与请求路径相反

```
Flutter App (Widget 点击成功)
  ↓ ServiceExtensionResponse
VM Service ({"success": true})
  ↓ WebSocket response
FlutterSkillClient (解析 JSON)
  ↓ Dart Future 完成
MCP Server (包装为 MCP 响应)
  ↓ JSON-RPC response
AI Agent (接收结果)
```

**最终 MCP 响应**:
```json
{
  "jsonrpc": "2.0",
  "id": "msg_123",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"success\": true}"
      }
    ]
  }
}
```

**AI 输出给用户**:
```
✅ 登录按钮点击成功！
```

---

## 🔍 关键数据流

### 数据流向图

```
用户输入: "测试登录按钮"
    ↓
AI 理解: 需要调用 tap(key: "login_button")
    ↓
┌─────────────────────────────────────────────┐
│ MCP Protocol (JSON-RPC)                     │
│ {"method": "tools/call", "name": "tap"}     │
└─────────────────┬───────────────────────────┘
                  ↓ stdin
┌─────────────────▼───────────────────────────┐
│ MCP Server (Dart)                           │
│ _client!.tap(key: "login_button")           │
└─────────────────┬───────────────────────────┘
                  ↓ WebSocket
┌─────────────────▼───────────────────────────┐
│ VM Service Protocol                         │
│ callServiceExtension(                       │
│   "ext.flutter.flutter_skill.tap",          │
│   args: {"key": "login_button"}             │
│ )                                           │
└─────────────────┬───────────────────────────┘
                  ↓ Isolate 内存调用
┌─────────────────▼───────────────────────────┐
│ FlutterSkillBinding (Target App)            │
│ registerExtension handler                   │
└─────────────────┬───────────────────────────┘
                  ↓ Widget Tree 访问
┌─────────────────▼───────────────────────────┐
│ Widget Tree 遍历                            │
│ 查找: ValueKey("login_button")              │
└─────────────────┬───────────────────────────┘
                  ↓ 找到 Element
┌─────────────────▼───────────────────────────┐
│ RenderObject                                │
│ 获取位置: (x: 100, y: 200)                  │
└─────────────────┬───────────────────────────┘
                  ↓ 事件模拟
┌─────────────────▼───────────────────────────┐
│ PointerDownEvent + PointerUpEvent           │
│ 模拟触摸事件                                │
└─────────────────┬───────────────────────────┘
                  ↓ UI 响应
┌─────────────────▼───────────────────────────┐
│ onPressed() 回调触发                        │
│ 按钮响应点击 ✅                             │
└─────────────────────────────────────────────┘

结果原路返回:
{"success": true} → AI → 用户
```

---

## 🔄 各层协议详解

### Layer 1: MCP Protocol

**特点**:
- 基于 JSON-RPC 2.0
- stdin/stdout 通讯
- 同步请求-响应模式

**示例**:
```json
// 请求
{"jsonrpc": "2.0", "method": "tools/call", "params": {...}}

// 响应
{"jsonrpc": "2.0", "result": {...}}
```

---

### Layer 2: VM Service Protocol

**特点**:
- WebSocket 持久连接
- 异步通讯
- 支持流式事件

**核心概念**:
```dart
// VM: 虚拟机实例
VM {
  isolates: [Isolate]  // 所有 isolate 列表
}

// Isolate: 独立执行单元
Isolate {
  id: "isolates/12345",
  name: "main",
  extensionRPCs: ["ext.flutter.flutter_skill.tap", ...]
}

// Service Extension: 自定义扩展
Extension {
  name: "ext.flutter.flutter_skill.tap",
  handler: (params) => Response
}
```

---

### Layer 3: Service Extension Protocol

**注册扩展**:
```dart
// Flutter App 内部
registerExtension('ext.my_extension', (method, params) async {
  // 处理逻辑
  return ServiceExtensionResponse.result(jsonEncode(result));
});
```

**调用扩展**:
```dart
// 外部工具
final response = await vmService.callServiceExtension(
  'ext.my_extension',
  isolateId: isolateId,
  args: parameters,
);
```

**传输**: 同一进程内的函数调用（零网络开销）

---

### Layer 4: Flutter Framework API

**直接访问**:
```dart
// 访问 Widget Tree
WidgetsBinding.instance.renderViewElement?.visitChildren(visitor);

// 访问 RenderObject
final renderBox = element.renderObject as RenderBox;
final position = renderBox.localToGlobal(Offset.zero);

// 模拟事件
WidgetsBinding.instance.handlePointerEvent(event);
```

---

## ⚡ 性能分析

### 延迟分解

| 阶段 | 延迟 | 说明 |
|------|------|------|
| MCP 协议序列化 | ~1ms | JSON 编码/解码 |
| WebSocket 传输 | ~5ms | 本地网络 (localhost) |
| VM Service 路由 | ~1ms | Isolate 查找 |
| Widget Tree 遍历 | ~10-50ms | 取决于树的大小 |
| 事件模拟 | ~50ms | PointerDown + Up |
| **总计** | **~70-110ms** | 用户几乎无感知 |

### 吞吐量

- **并发连接**: 单个 MCP Server → 单个 VM Service
- **并发请求**: 串行处理（避免 UI 状态冲突）
- **数据量**: 轻量级 JSON，通常 < 1KB

---

## 🛠️ 调试技巧

### 1. 查看 MCP 通讯

```bash
# 运行 MCP Server 时会打印所有 JSON-RPC 消息
dart run bin/server.dart
```

### 2. 查看 VM Service 连接

```dart
// lib/src/flutter_skill_client.dart
print('DEBUG: Connecting to $wsUri');
print('DEBUG: Connected to VM Service');
```

### 3. 查看扩展调用

```dart
// lib/flutter_skill.dart
registerExtension('ext.flutter.flutter_skill.tap', (method, parameters) async {
  print('📞 Extension called: $method');
  print('📦 Parameters: $parameters');
  // ...
  print('✅ Result: $result');
});
```

### 4. 使用 Dart DevTools

```bash
# 打开 DevTools 查看 VM Service
flutter run --vm-service-port=50000
# 访问: http://127.0.0.1:9100
```

---

## 🎯 总结

### 四层通讯架构

1. **MCP Layer**: IDE ↔ MCP Server (JSON-RPC)
2. **VM Service Layer**: MCP Server ↔ Dart VM (WebSocket)
3. **Extension Layer**: Dart VM ↔ App Binding (内存调用)
4. **Framework Layer**: Binding ↔ Widget Tree (直接访问)

### 关键技术

- ✅ **官方协议**: 使用 Dart VM Service，稳定可靠
- ✅ **低延迟**: 总延迟 ~100ms，用户无感
- ✅ **零侵入**: 只需添加一个 binding
- ✅ **完整访问**: 可以访问和操作整个 UI

### 与传统测试方案对比

| 特性 | flutter-skill | Flutter Driver | Appium |
|------|---------------|----------------|--------|
| 协议 | VM Service | VM Service | WebDriver |
| 延迟 | ~100ms | ~200ms | ~500ms |
| 外部控制 | ✅ | ✅ | ✅ |
| 代码侵入 | 最小 | 需要测试文件 | 零侵入 |
| UI 访问 | 白盒 | 白盒 | 黑盒 |
| AI 友好 | ✅ | ❌ | ⚠️ |

---

**最后更新**: 2026-02-01
