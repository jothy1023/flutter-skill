# DTD vs VM Service 端口和协议详解

## 🎯 核心问题

**Q: DTD 用的是什么协议和端口？能否复用它的连接？**

**A: DTD 使用 WebSocket 协议和动态端口。不能直接复用连接，但可以通过 DTD 发现 VM Service！**

---

## 📊 协议和端口对比

### 并排对比

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter 应用启动                         │
└───────────────────────┬─────────────────────────────────────┘
                        │
        ┌───────────────┴────────────────┐
        │                                │
        ▼                                ▼
┌──────────────────┐          ┌──────────────────┐
│   DTD 服务       │          │  VM Service      │
│   (默认启动)     │          │  (需要参数)      │
└──────────────────┘          └──────────────────┘

协议: WebSocket              协议: HTTP + WebSocket
端口: 动态 (如 54321)        端口: 可指定 (如 50000)
URI:  ws://127.0.0.1:54321/  URI:  http://127.0.0.1:50000/
      abc123=/ws                   xyz456=/

功能:                         功能:
✅ 热重载                     ✅ 热重载
✅ 日志流                     ✅ 日志流
✅ 文件操作                   ✅ 调试功能
❌ 自定义扩展                 ✅ 自定义扩展 ⭐
❌ UI 操作                    ✅ UI 操作 ⭐
```

---

## 🔍 实际端口分配示例

### 场景 1: Flutter 3.x 默认启动

```bash
$ flutter run -d macos

输出:
The Dart Tooling Daemon is listening on ws://127.0.0.1:54321/abc123=/ws
```

**端口使用**:
```
应用进程: 使用端口 54321 (DTD)
         未使用 VM Service 端口 ❌
```

**可用协议**:
- ✅ DTD: `ws://127.0.0.1:54321/abc123=/ws`
- ❌ VM Service: 未启动

---

### 场景 2: 启用 VM Service

```bash
$ flutter run -d macos --vm-service-port=50000

输出:
The Dart Tooling Daemon is listening on ws://127.0.0.1:54322/def456=/ws
The Dart VM service is listening on http://127.0.0.1:50000/ghi789=/
```

**端口使用**:
```
应用进程: 使用端口 54322 (DTD)
         使用端口 50000 (VM Service)
```

**可用协议**:
- ✅ DTD: `ws://127.0.0.1:54322/def456=/ws`
- ✅ VM Service: `http://127.0.0.1:50000/ghi789=/`

**关键发现**:
- DTD 端口每次不同（54321 → 54322）
- VM Service 端口固定（50000）
- **两者同时运行，使用不同端口**

---

## 💡 复用 DTD 的正确方式

### ❌ 错误理解

```
用户可能以为:
DTD 端口 54321 → 也可以用于 VM Service 调用
```

**错误**: DTD 和 VM Service 是完全独立的服务，使用不同端口！

---

### ✅ 正确方式：DTD 作为"服务发现"

```
正确的复用思路:
1. 连接到 DTD (默认启动)
2. 通过 DTD API 查询 VM Service URI
3. 如果有 VM Service → 连接它
4. 如果没有 → 提示用户启用
```

**流程图**:

```
┌──────────────────────────────────────────┐
│  flutter-skill 启动                      │
└─────────────┬────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 1. 扫描端口 50000-60000                 │
│    查找 DTD 服务（WebSocket）           │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 2. 找到 DTD: ws://127.0.0.1:54321/...  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│ 3. 连接 DTD，发送查询:                  │
│    { "method": "getVM" }                │
└─────────────┬───────────────────────────┘
              │
         ┌────┴────┐
         │         │
    有VM Service  无VM Service
         │         │
         ▼         ▼
   ┌─────────┐  ┌──────────────┐
   │ 返回:   │  │ 返回:        │
   │ vmUri   │  │ null         │
   └────┬────┘  └──────┬───────┘
        │              │
        ▼              ▼
   ┌─────────┐  ┌──────────────┐
   │ 连接    │  │ 提示用户:    │
   │ VM      │  │ 重启并加     │
   │ Service │  │ --vm-service │
   │         │  │ -port=50000  │
   └─────────┘  └──────────────┘
        │
        ▼
   ✅ 完整功能
```

---

## 🔬 DTD 查询 VM Service 的实现

### DTD API 可能的方法

根据 DTD 协议规范，以下方法可能返回 VM Service 信息：

#### 方法 1: `getVM`

```json
// 请求
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "getVM",
  "params": {}
}

// 响应（如果 VM Service 启用）
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "vmServiceUri": "http://127.0.0.1:50000/xyz=/",
    "version": "3.11.0"
  }
}

// 响应（如果 VM Service 未启用）
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "vmServiceUri": null
  }
}
```

#### 方法 2: `streamListen` (监听 VM 事件)

```json
// 请求
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "streamListen",
  "params": {
    "streamId": "VM"
  }
}

// 事件通知
{
  "jsonrpc": "2.0",
  "method": "streamNotify",
  "params": {
    "streamId": "VM",
    "event": {
      "kind": "VMServiceConnected",
      "uri": "http://127.0.0.1:50000/xyz=/"
    }
  }
}
```

#### 方法 3: `getRegisteredService`

```json
// 请求
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "getRegisteredService",
  "params": {
    "service": "vm_service"
  }
}

// 响应
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "uri": "http://127.0.0.1:50000/xyz=/"
  }
}
```

---

## 📋 实现策略对比

### 策略 A: 直接扫描 VM Service 端口（当前实现）

```dart
// 扫描 50000-50100 端口
for (port in 50000..50100) {
  if (isVmService(port)) {
    connect(port);
    break;
  }
}
```

**优势**:
- ✅ 简单直接
- ✅ 不依赖 DTD

**劣势**:
- ⚠️ 需要扫描多个端口（慢）
- ⚠️ 如果 VM Service 未启动，无法发现

---

### 策略 B: 通过 DTD 发现（推荐增强）

```dart
// 1. 扫描 DTD 端口（通常只有 1 个）
final dtdUri = await scanForDtd();

// 2. 查询 VM Service URI
final vmUri = await dtd.getVmServiceUri();

// 3. 连接
if (vmUri != null) {
  connect(vmUri);
} else {
  promptUserToEnableVmService();
}
```

**优势**:
- ✅ 更快（只需找到 1 个 DTD）
- ✅ 智能提示（知道 VM Service 未启动）
- ✅ 利用 Flutter 3.x 的 DTD 默认启动

**劣势**:
- ⚠️ 依赖 DTD API（需要验证兼容性）

---

### 策略 C: 混合策略（最佳）

```dart
// 1. 优先通过 DTD 发现
final vmUri = await discoverViaDtd();

if (vmUri != null) {
  return connect(vmUri);
}

// 2. 回退到端口扫描
final vmServices = await scanVmServicePorts();

if (vmServices.isNotEmpty) {
  return connect(vmServices.first);
}

// 3. 未找到
throw NoVmServiceError();
```

**优势**:
- ✅ 最快的发现速度
- ✅ 最高的成功率
- ✅ 友好的错误提示

---

## 🎯 推荐实现路线

### Phase 1: 当前方案（已完成 ✅）

```dart
// 自动添加 --vm-service-port=50000
launch_app(device_id: "iPhone 16 Pro")
```

**优势**: 简单、可靠、零配置

---

### Phase 2: DTD 发现增强（可选实现）

```dart
// scan_and_connect 增强版
Future<Result> scanAndConnect() async {
  // 1. 先通过 DTD 发现
  final dtdResult = await DtdServiceDiscovery.discover();

  if (dtdResult.vmServiceUri != null) {
    return connectTo(dtdResult.vmServiceUri);
  }

  // 2. 回退到端口扫描
  return scanVmServicePorts();
}
```

**优势**: 更快、更智能

---

### Phase 3: 混合客户端（未来）

```dart
class HybridClient {
  final DtdClient? dtd;
  final VmService? vmService;

  // 热重载：优先用 DTD（更快）
  Future<void> hotReload() async {
    return dtd?.hotReload() ?? vmService!.hotReload();
  }

  // UI 操作：只能用 VM Service
  Future<void> tap({String? key}) async {
    if (vmService == null) {
      throw UnsupportedError('需要 VM Service');
    }
    return vmService!.tap(key: key);
  }
}
```

**优势**: 充分利用两个协议

---

## 📊 端口使用总结表

| 场景 | DTD 端口 | VM Service 端口 | 说明 |
|------|----------|-----------------|------|
| **默认启动** | 54321 (动态) | ❌ 未启动 | Flutter 3.x 默认 |
| **启用 VM** | 54322 (动态) | 50000 (指定) | 加 --vm-service-port |
| **flutter-skill launch** | 54323 (动态) | 50000 (固定) | 自动添加参数 |

**关键点**:
- DTD 端口**每次不同**，无法预测
- VM Service 端口**可以指定**，建议用 50000
- 两个服务**同时运行**，互不冲突

---

## 🎓 结论

### 回答你的问题

**Q: DTD 用的是什么协议/端口？能否复用？**

**A:**

1. **协议**: WebSocket (JSON-RPC 2.0)
2. **端口**: 动态分配（每次不同，如 54321、54322...）
3. **URI**: `ws://127.0.0.1:{PORT}/{SECRET}=/ws`

**复用方式**:

❌ **不能直接复用连接**（DTD ≠ VM Service）

✅ **可以通过 DTD 发现 VM Service**:
```
DTD (ws://...:54321/ws)
  → 查询 VM Service URI
  → 返回 http://...:50000/
  → 连接 VM Service
```

**最佳实践**:

**当前**: 自动添加 `--vm-service-port=50000`（已实现 ✅）

**未来**: DTD 作为服务发现入口（可选增强）

---

**文档创建**: 2026-02-01
**核心发现**: DTD 是发现 VM Service 的桥梁，不是替代品
