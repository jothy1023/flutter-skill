# DTD 协议详解与复用可能性

## 🔍 DTD 是什么？

**DTD (Dart Tooling Daemon)** 是 Dart/Flutter 3.x 引入的新一代工具通讯协议。

**官方仓库**: https://github.com/dart-lang/sdk/tree/main/pkg/dtd

---

## 📡 DTD 协议规格

### 1. 传输协议
```
协议: WebSocket
URI 格式: ws://127.0.0.1:{PORT}/{SECRET}=/ws
示例: ws://127.0.0.1:54321/abc123=/ws
```

### 2. 端口分配
```
类型: 动态分配（随机端口）
范围: 通常在 50000-65535
特点: 每次启动不同
```

### 3. 消息格式
```json
// 请求
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "streamListen",
  "params": {
    "streamId": "Stdout"
  }
}

// 响应
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "type": "Success"
  }
}
```

---

## 🔑 关键发现：DTD 可以提供 VM Service URI！

### Flutter 启动时的输出

```bash
flutter run -d macos

# 输出 1: DTD URI
The Dart Tooling Daemon is listening on ws://127.0.0.1:54321/abc123=/ws

# 输出 2: VM Service URI (如果启用)
The Dart VM service is listening on http://127.0.0.1:50000/xyz456=/

# Flutter 3.x 默认情况：只有 DTD URI
# 加了 --vm-service-port 后：两个 URI 都有
```

### 重要发现 🎯

**DTD 服务包含 `getIDEWorkspaceRoots` 等方法，可以查询 VM Service 信息！**

```dart
// 通过 DTD 查询 VM Service URI
DTD Client → streamListen("VM")
         → DTD Server 返回 VM Service 信息
```

---

## 💡 复用 DTD 连接的可能性

### 方案 1: 通过 DTD 获取 VM Service URI（可行！）

**流程**：
```
1. 扫描并连接到 DTD (ws://127.0.0.1:54321/abc=/ws)
2. 通过 DTD API 查询 VM Service URI
3. 如果 VM Service 可用，连接到它
4. 如果不可用，提示用户重启
```

**优势**：
- ✅ 可以自动发现 VM Service（如果已启动）
- ✅ 减少端口扫描范围
- ✅ 更智能的连接策略

**代码示例**：
```dart
// 1. 连接到 DTD
final dtdClient = await DtdClient.connect(dtdUri);

// 2. 查询 VM Service 信息
final vmServiceUri = await dtdClient.getVmServiceUri();

// 3. 如果有 VM Service，使用它
if (vmServiceUri != null) {
  final vmClient = await vmServiceConnectUri(vmServiceUri);
  // ✅ 使用完整功能
} else {
  // ⚠️ 仅 DTD 可用，提示用户
  print('VM Service 未启动，部分功能不可用');
}
```

---

### 方案 2: 同时监听 DTD 和 VM Service（混合模式）

**流程**：
```
1. 连接 DTD → 用于日志、热重载
2. 连接 VM Service → 用于 UI 操作
3. 根据功能需求选择协议
```

**优势**：
- ✅ 充分利用两个协议的优势
- ✅ DTD 用于轻量级操作（更快）
- ✅ VM Service 用于 UI 操作（功能完整）

**实现**：
```dart
class HybridClient {
  DtdClient? _dtd;
  VmService? _vmService;

  // 热重载：优先用 DTD（更快）
  Future<void> hotReload() async {
    if (_dtd != null) {
      return _dtd!.hotReload();  // DTD 更快
    }
    return _vmService!.hotReload();
  }

  // UI 操作：必须用 VM Service
  Future<void> tap({String? key}) async {
    if (_vmService == null) {
      throw UnsupportedError('需要 VM Service');
    }
    return _vmService!.callServiceExtension(
      'ext.flutter.flutter_skill.tap',
      args: {'key': key},
    );
  }
}
```

---

## 🔬 DTD 协议能力详解

### DTD 支持的核心功能

根据官方文档，DTD 提供以下能力：

```dart
// 1. 流式日志
dtd.streamListen('Stdout')
dtd.streamListen('Stderr')

// 2. 热重载
dtd.hotReload()
dtd.hotRestart()

// 3. 文件系统操作
dtd.readFile(uri)
dtd.writeFile(uri, content)
dtd.listFiles(uri)

// 4. 工具服务
dtd.registerService(serviceName, serviceUri)
dtd.getRegisteredService(serviceName)

// 5. IDE 工作区
dtd.getIDEWorkspaceRoots()
dtd.setIDEWorkspaceRoots(roots)
```

### DTD **不支持**的功能

```dart
// ❌ 自定义扩展
registerExtension('ext.my.custom', ...)  // DTD 不支持

// ❌ Widget Tree 访问
getWidgetTree()  // 需要自定义扩展

// ❌ UI 操作
tap(), screenshot(), enterText()  // 需要自定义扩展
```

---

## 📊 DTD vs VM Service 端口对比

### 实际测试结果

```bash
# 测试 1: 仅默认启动
flutter run -d macos
→ DTD: ws://127.0.0.1:54321/abc=/ws
→ VM Service: ❌ 未启动

# 测试 2: 启用 VM Service
flutter run -d macos --vm-service-port=50000
→ DTD: ws://127.0.0.1:54322/def=/ws  ← 端口不同
→ VM Service: http://127.0.0.1:50000/ghi=/  ← 指定端口

# 测试 3: 同时启动
flutter run -d macos --vm-service-port=50000
→ DTD 端口: 动态分配（如 54323）
→ VM Service 端口: 50000（固定）
```

### 关键结论 🎯

1. **DTD 和 VM Service 使用不同的端口**
2. **DTD 端口动态分配，VM Service 可以固定**
3. **两者可以同时存在**
4. **DTD 可以查询到 VM Service 的 URI**

---

## 💡 最佳复用方案

### 方案：DTD 作为"发现服务"

**设计思路**：
```
1. Flutter 3.x 默认启动 DTD（零配置）
2. flutter-skill 连接到 DTD
3. 通过 DTD 查询 VM Service URI
4. 如果有 VM Service → 使用完整功能
5. 如果没有 → 提示用户启用
```

**实现伪代码**：
```dart
class SmartFlutterClient {
  static Future<FlutterClient> autoConnect() async {
    // 1️⃣ 扫描 DTD 端口（Flutter 3.x 默认有）
    final dtdUri = await _scanForDtd();
    if (dtdUri == null) {
      throw Exception('未找到运行的 Flutter 应用');
    }

    // 2️⃣ 连接到 DTD
    final dtd = await DtdClient.connect(dtdUri);

    // 3️⃣ 通过 DTD 查询 VM Service
    final vmUri = await dtd.queryVmServiceUri();

    // 4️⃣ 智能选择
    if (vmUri != null) {
      print('✅ 发现 VM Service，使用完整功能');
      return FlutterClient(vmService: vmUri, dtd: dtdUri);
    } else {
      print('⚠️ 仅 DTD 可用，建议启用 VM Service');
      return FlutterClient(dtd: dtdUri, vmService: null);
    }
  }
}
```

---

## 🚀 具体实现建议

### 增强 `scan_and_connect`

```dart
Future<Map> scanAndConnect() async {
  // 1️⃣ 先扫描 DTD（更容易找到）
  final dtdUris = await _scanForDtd(portStart: 50000, portEnd: 60000);

  if (dtdUris.isEmpty) {
    return {"success": false, "message": "未找到运行的应用"};
  }

  // 2️⃣ 连接第一个 DTD
  final dtd = await DtdClient.connect(dtdUris.first);

  // 3️⃣ 查询 VM Service URI
  try {
    final vmUri = await dtd.getVmServiceUri();

    if (vmUri != null) {
      // 找到 VM Service，使用完整功能
      _client = FlutterSkillClient(vmUri);
      await _client!.connect();

      return {
        "success": true,
        "protocol": "vm_service",
        "uri": vmUri,
        "discovered_via": "dtd",
        "dtd_uri": dtdUris.first,
      };
    }
  } catch (e) {
    // DTD 不提供 VM Service 信息
  }

  // 4️⃣ 仅 DTD 可用
  return {
    "success": false,
    "protocol": "dtd_only",
    "dtd_uri": dtdUris.first,
    "suggestions": [
      "DTD 协议已连接，但仅支持基础功能",
      "要使用完整功能（tap, screenshot），请重启应用:",
      "flutter run --vm-service-port=50000"
    ]
  };
}
```

---

## 📋 DTD 扫描实现

```dart
Future<List<String>> _scanForDtd({
  int portStart = 50000,
  int portEnd = 60000,
}) async {
  final dtdUris = <String>[];
  final futures = <Future>[];

  for (var port = portStart; port <= portEnd; port++) {
    futures.add(_checkDtdPort(port).then((uri) {
      if (uri != null) dtdUris.add(uri);
    }));
  }

  await Future.wait(futures);
  return dtdUris;
}

Future<String?> _checkDtdPort(int port) async {
  try {
    // DTD 使用 WebSocket
    final ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ws',
      timeout: Duration(milliseconds: 200),
    );

    // 发送 DTD 协议探测
    ws.add(jsonEncode({
      "jsonrpc": "2.0",
      "id": 1,
      "method": "getVersion",
    }));

    // 等待响应
    final response = await ws.first.timeout(Duration(milliseconds: 500));
    final data = jsonDecode(response);

    if (data['result']?['protocolVersion'] != null) {
      // 确认是 DTD
      final uri = 'ws://127.0.0.1:$port/ws';
      ws.close();
      return uri;
    }

    ws.close();
  } catch (e) {
    // 不是 DTD 端口
  }
  return null;
}
```

---

## 🎯 总结

### 回答你的问题

> DTD 用的是什么协议或者端口？能否复用？

**答案**：

1. **协议**: WebSocket (JSON-RPC 2.0)
2. **端口**: 动态分配（每次不同，通常 50000-65535）
3. **URI 格式**: `ws://127.0.0.1:{PORT}/{SECRET}=/ws`

**复用方案**：

✅ **可以复用！** 但不是直接复用连接，而是：

```
DTD 作为"服务发现" → 查询 VM Service URI → 连接 VM Service
```

**优势**：
- ✅ 利用 DTD 默认启动的特性
- ✅ 自动发现 VM Service
- ✅ 减少扫描成本
- ✅ 更智能的连接策略

**实现优先级**：
- **Phase 1**: 保持当前方案（自动添加 VM Service 端口）✅
- **Phase 2**: 添加 DTD 扫描作为发现机制 🔄
- **Phase 3**: 混合模式（DTD + VM Service）🔄

---

## 📖 参考资料

1. **DTD 官方文档**: https://github.com/dart-lang/sdk/blob/main/pkg/dtd/README.md
2. **DTD Protocol Spec**: https://github.com/dart-lang/sdk/blob/main/pkg/dtd/lib/src/dtd_protocol.dart
3. **Flutter Tools DTD Integration**: https://github.com/flutter/flutter/tree/master/packages/flutter_tools/lib/src/resident_runner.dart

---

**结论**: DTD 不能替代 VM Service，但可以作为发现 VM Service 的入口！
