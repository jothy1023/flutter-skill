# Flutter Skill 通讯架构

## 🏗️ 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    IDE / AI Agent                           │
│              (Cursor, Claude Code, etc.)                    │
└─────────────────┬───────────────────────────────────────────┘
                  │ JSON-RPC 2.0 over stdin/stdout
                  │ (MCP Protocol)
┌─────────────────▼───────────────────────────────────────────┐
│              MCP Server (Dart Process)                      │
│           lib/src/cli/server.dart                           │
│  • FlutterMcpServer                                         │
│  • Handles MCP protocol                                     │
│  • Translates to VM Service calls                           │
└─────────────────┬───────────────────────────────────────────┘
                  │ WebSocket (VM Service Protocol)
                  │ ws://127.0.0.1:50000/xxx=/ws
┌─────────────────▼───────────────────────────────────────────┐
│            FlutterSkillClient                               │
│        lib/src/flutter_skill_client.dart                    │
│  • VmService wrapper                                        │
│  • Connects via vmServiceConnectUri()                       │
│  • Calls service extensions                                 │
└─────────────────┬───────────────────────────────────────────┘
                  │ Service Extension Protocol
                  │ ext.flutter.flutter_skill.*
┌─────────────────▼───────────────────────────────────────────┐
│         Dart VM Service (Flutter Runtime)                   │
│  • Manages isolates                                         │
│  • Routes extension calls                                   │
│  • Debugging/profiling infrastructure                       │
└─────────────────┬───────────────────────────────────────────┘
                  │ Direct method call in same isolate
┌─────────────────▼───────────────────────────────────────────┐
│           FlutterSkillBinding (Target App)                  │
│              lib/flutter_skill.dart                         │
│  • Registers service extensions                             │
│  • Accesses widget tree                                     │
│  • Performs UI operations                                   │
└─────────────────┬───────────────────────────────────────────┘
                  │ Direct widget tree access
┌─────────────────▼───────────────────────────────────────────┐
│                  Flutter App                                │
│  • Widgets, State, BuildContext                             │
│  • UI rendering                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📡 通讯层次详解

### 第 1 层：IDE ↔ MCP Server (JSON-RPC 2.0)

**协议**: MCP (Model Context Protocol)
**传输**: stdin/stdout
**格式**: JSON-RPC 2.0

#### 请求示例
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "tap",
    "arguments": {
      "key": "login_button"
    }
  }
}
```

#### 响应示例
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"success\": true, \"message\": \"Tapped login_button\"}"
      }
    ]
  }
}
```

**实现位置**: `lib/src/cli/server.dart:FlutterMcpServer.run()`

---

### 第 2 层：MCP Server ↔ VM Service (WebSocket)

**协议**: Dart VM Service Protocol
**传输**: WebSocket
**URI**: `ws://127.0.0.1:50000/xxx=/ws`

#### 连接建立
```dart
// lib/src/flutter_skill_client.dart:14-26
Future<void> connect() async {
  print('DEBUG: Connecting to $wsUri');
  _service = await vmServiceConnectUri(wsUri);  // ← WebSocket 连接
  print('DEBUG: Connected to VM Service');

  final vm = await _service!.getVM();
  final isolates = vm.isolates;
  _isolateId = isolates.first.id!;  // ← 找到主 isolate
}
```

#### VM Service 协议示例
```dart
// 调用 service extension
final response = await _service!.callServiceExtension(
  'ext.flutter.flutter_skill.tap',  // ← 扩展名称
  isolateId: _isolateId!,            // ← 目标 isolate
  args: {'key': 'login_button'},     // ← 参数
);
```

**底层实现**: `package:vm_service/vm_service_io.dart`

---

### 第 3 层：VM Service ↔ FlutterSkillBinding (Service Extension)

**协议**: Service Extension Protocol
**传输**: 内存调用 (同一进程内)
**命名空间**: `ext.flutter.flutter_skill.*`

#### 注册扩展 (Flutter App 端)

```dart
// lib/flutter_skill.dart:24-73
class FlutterSkillBinding {
  static void ensureInitialized() {
    WidgetsFlutterBinding.ensureInitialized();

    // 注册 tap 扩展
    registerExtension(
      'ext.flutter.flutter_skill.tap',  // ← 扩展名称
      (method, parameters) async {      // ← 处理函数
        final key = parameters['key'];
        final text = parameters['text'];

        // 执行 UI 操作
        final result = await _findAndTap(key: key, text: text);

        // 返回结果
        return ServiceExtensionResponse.result(
          json.encode({'success': result})
        );
      },
    );
  }
}
```

#### 调用流程

```
1. FlutterSkillClient 调用:
   _service.callServiceExtension('ext.flutter.flutter_skill.tap', ...)

2. VM Service 路由:
   找到 isolate → 查找已注册的扩展

3. FlutterSkillBinding 接收:
   执行 registerExtension 的回调函数

4. 返回结果:
   ServiceExtensionResponse → VM Service → FlutterSkillClient
```

---

### 第 4 层：FlutterSkillBinding ↔ Widget Tree (直接访问)

**协议**: Flutter Framework API
**传输**: 内存访问 (同一进程内)

#### Widget 查找

```dart
// lib/flutter_skill.dart:内部实现
Element? _findElement({String? key, String? text}) {
  Element? target;

  // 遍历整个 widget tree
  void visitor(Element element) {
    // 检查 key
    if (key != null && element.widget.key is ValueKey) {
      final valueKey = element.widget.key as ValueKey;
      if (valueKey.value.toString() == key) {
        target = element;
        return;
      }
    }

    // 检查 text
    if (text != null && element.widget is Text) {
      final textWidget = element.widget as Text;
      if (textWidget.data == text) {
        target = element;
        return;
      }
    }

    element.visitChildren(visitor);  // ← 递归遍历
  }

  // 从根节点开始遍历
  WidgetsBinding.instance.renderViewElement?.visitChildren(visitor);
  return target;
}
```

#### UI 操作执行

```dart
// 模拟点击
Future<bool> _performTap(Element element) async {
  final renderObject = element.renderObject as RenderBox;

  // 获取全局坐标
  final offset = renderObject.localToGlobal(Offset.zero);
  final center = offset + renderObject.size.center(Offset.zero);

  // 模拟触摸事件
  await _simulateTap(center);
  return true;
}
```

---

## 🔄 完整通讯流程示例：点击按钮

### 1️⃣ AI Agent 发起请求

```python
# Cursor/Claude Code 调用
tap(key: "login_button")
```

### 2️⃣ MCP Server 接收并翻译

```dart
// lib/src/cli/server.dart:1424-1440
case 'tap':
  final key = args['key'];
  final text = args['text'];

  // 调用 FlutterSkillClient
  final result = await _client!.tap(key: key, text: text);
  return result;
```

### 3️⃣ FlutterSkillClient 调用 VM Service

```dart
// lib/src/flutter_skill_client.dart:50-59
Future<Map<String, dynamic>> tap({String? key, String? text}) async {
  final result = await _call('ext.flutter.flutter_skill.tap', {
    if (key != null) 'key': key,
    if (text != null) 'text': text,
  });
  return result;
}

// 内部调用
Future<Map<String, dynamic>> _call(String method, [Map<String, dynamic>? args]) async {
  final response = await _service!.callServiceExtension(
    method,
    isolateId: _isolateId!,
    args: args,
  );
  return response.json ?? {};
}
```

### 4️⃣ VM Service 路由到扩展

```
VM Service Protocol:
{
  "method": "ext.flutter.flutter_skill.tap",
  "isolate": "isolates/12345",
  "params": {"key": "login_button"}
}
```

### 5️⃣ FlutterSkillBinding 执行操作

```dart
// lib/flutter_skill.dart:tap 扩展处理
registerExtension('ext.flutter.flutter_skill.tap', (method, parameters) async {
  final key = parameters['key'];

  // 1. 查找元素
  final element = _findElement(key: key);

  // 2. 获取坐标
  final renderBox = element.renderObject as RenderBox;
  final position = renderBox.localToGlobal(Offset.zero);

  // 3. 模拟点击
  final result = await _simulateTap(position);

  // 4. 返回结果
  return ServiceExtensionResponse.result(
    json.encode({'success': result})
  );
});
```

### 6️⃣ 结果返回到 AI

```
Flutter App → FlutterSkillBinding → VM Service → FlutterSkillClient → MCP Server → AI
{"success": true}
```

---

## 🔧 关键技术点

### 1. VM Service Protocol

**官方文档**: https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md

**核心概念**:
- **Isolate**: Dart 的独立执行单元，有自己的内存堆
- **Service Extension**: 自定义的调试扩展，允许外部调用应用内部方法
- **WebSocket**: 持久连接，支持双向通讯

### 2. Service Extension 机制

```dart
// 注册扩展 (应用内)
registerExtension('ext.my_app.custom_method', (method, params) async {
  // 处理逻辑
  return ServiceExtensionResponse.result(jsonEncode(result));
});

// 调用扩展 (外部)
final response = await vmService.callServiceExtension(
  'ext.my_app.custom_method',
  isolateId: isolateId,
  args: {'param': 'value'},
);
```

### 3. Widget Tree 遍历

```dart
// 访问整个 widget tree
void visitWidgetTree(ElementVisitor visitor) {
  WidgetsBinding.instance.renderViewElement?.visitChildren(visitor);
}

// 递归访问
typedef ElementVisitor = void Function(Element element);
```

### 4. UI 事件模拟

```dart
// 模拟触摸事件
Future<void> _simulateTap(Offset position) async {
  final binding = WidgetsBinding.instance;

  // Down 事件
  await binding.handlePointerEvent(
    PointerDownEvent(position: position)
  );

  // Up 事件
  await binding.handlePointerEvent(
    PointerUpEvent(position: position)
  );
}
```

---

## 🔒 安全性考虑

### 1. 仅在 Debug 模式启用

```dart
void main() {
  if (kDebugMode) {  // ← 仅 debug 模式
    FlutterSkillBinding.ensureInitialized();
  }
  runApp(MyApp());
}
```

### 2. VM Service 端口保护

- VM Service 默认只监听 `127.0.0.1` (localhost)
- 不暴露到外部网络
- 需要知道随机生成的 auth token (URI 中的 `xxx=`)

### 3. 扩展命名空间隔离

- 使用 `ext.flutter.flutter_skill.*` 前缀
- 避免与其他扩展冲突
- 明确的功能边界

---

## 📊 性能特性

### 1. 连接复用

```dart
// 单例连接，多次调用共享
VmService? _service;  // ← 复用 WebSocket 连接
```

### 2. 异步操作

```dart
// 所有操作都是异步的，不阻塞 UI
Future<Map<String, dynamic>> tap(...) async {
  return await _call('ext.flutter.flutter_skill.tap', ...);
}
```

### 3. 最小化数据传输

```dart
// 只传输必要的数据
return ServiceExtensionResponse.result(
  json.encode({'success': true})  // ← 简洁的 JSON
);
```

---

## 🔍 调试通讯

### 查看 VM Service 通讯

```dart
// lib/src/flutter_skill_client.dart:15
Future<void> connect() async {
  print('DEBUG: Connecting to $wsUri');  // ← 连接日志
  _service = await vmServiceConnectUri(wsUri);
  print('DEBUG: Connected to VM Service');  // ← 成功日志
}
```

### 查看扩展调用

```dart
// lib/flutter_skill.dart:在扩展内添加日志
registerExtension('ext.flutter.flutter_skill.tap', (method, parameters) async {
  print('Extension called: $method with $parameters');  // ← 调试
  // ...
});
```

### 查看 MCP 协议

```bash
# MCP Server 的 stdin/stdout 日志会显示完整的 JSON-RPC 通讯
```

---

## 🎯 总结

### 通讯链路（从上到下）

1. **MCP Protocol** (JSON-RPC 2.0 over stdin/stdout)
   - IDE ↔ MCP Server

2. **VM Service Protocol** (WebSocket)
   - MCP Server ↔ Dart VM

3. **Service Extension Protocol** (内存调用)
   - Dart VM ↔ FlutterSkillBinding

4. **Flutter Framework API** (直接访问)
   - FlutterSkillBinding ↔ Widget Tree

### 关键优势

- ✅ **官方协议**: 使用 Dart 官方的 VM Service，稳定可靠
- ✅ **零侵入**: 无需修改应用代码，只需添加一个 binding
- ✅ **实时通讯**: WebSocket 持久连接，低延迟
- ✅ **完整访问**: 可以访问整个 widget tree 和 UI 状态
- ✅ **安全隔离**: 仅 debug 模式，localhost 访问

### 与其他方案对比

| 方案 | 协议 | 优势 | 劣势 |
|------|------|------|------|
| **flutter-skill** | VM Service | 完整访问，官方支持 | 需要 debug 模式 |
| **Flutter Driver** | VM Service | Flutter 官方 | API 复杂，需要测试文件 |
| **Integration Test** | 内嵌测试 | 原生 Flutter | 无法外部控制 |
| **Appium** | HTTP/WebDriver | 跨平台 | 慢，黑盒测试 |

---

**最后更新**: 2026-02-01
**架构版本**: v0.3.2+
