# DTD 协议支持可行性研究

## 🎯 目标

探索使用 **DTD (Dart Tooling Daemon)** 协议作为 VM Service 的替代方案，实现零配置的 Flutter 应用连接。

---

## 📊 协议对比

### VM Service vs DTD

| 特性 | VM Service | DTD (Dart Tooling Daemon) |
|------|-----------|---------------------------|
| **启动方式** | 需要 `--vm-service-port` | Flutter 3.x 默认启动 ✅ |
| **配置需求** | 需要指定端口 | 零配置 ✅ |
| **Service Extension** | ✅ 完全支持 | ❌ 不支持 |
| **Widget Tree 访问** | ✅ 通过扩展 | ❓ 需要验证 |
| **热重载** | ✅ 支持 | ✅ 支持 |
| **日志获取** | ✅ 支持 | ✅ 支持 |
| **UI 操作** | ✅ 通过自定义扩展 | ❌ 不直接支持 |
| **调试功能** | ✅ 完整 | ⚠️ 部分 |
| **官方支持** | ✅ 稳定 | ✅ 新协议 |

---

## 🔍 DTD 协议分析

### DTD 是什么？

**Dart Tooling Daemon** 是 Dart 3.x 引入的新协议，用于工具与 Dart/Flutter 应用之间的通讯。

**官方文档**: https://github.com/dart-lang/sdk/blob/main/pkg/dtd/README.md

### DTD 的核心能力

```dart
// DTD 支持的主要功能
DTD {
  • Hot Reload / Hot Restart
  • 日志流 (stdout/stderr)
  • 性能分析
  • 调试信息
  • 文件系统操作
  • 包管理
}
```

### DTD 的限制 ⚠️

**关键问题**: DTD **不支持自定义 Service Extension**！

```dart
// ❌ DTD 不支持这个
registerExtension('ext.flutter.flutter_skill.tap', ...);

// ✅ VM Service 支持
registerExtension('ext.flutter.flutter_skill.tap', ...);
```

这意味着：
- ❌ 无法注册自定义的 `tap`、`enterText` 等扩展
- ❌ 无法直接访问 Widget Tree
- ❌ 无法执行自定义 UI 操作

---

## 💡 可行的混合方案

### 方案 A: 双协议支持（推荐）

**设计思路**：
1. **优先使用 VM Service**（功能完整）
2. **备选使用 DTD**（基础功能）
3. **自动降级**：根据可用协议选择

```dart
// 伪代码
class FlutterSkillClient {
  Protocol _protocol;  // VM_SERVICE | DTD

  Future<void> connect(String uri) async {
    if (uri.contains('http://') || uri.contains('observatory')) {
      // VM Service 连接
      _protocol = Protocol.VM_SERVICE;
      _vmService = await vmServiceConnectUri(uri);
    } else if (uri.contains('ws://') && uri.contains('=/ws')) {
      // DTD 连接
      _protocol = Protocol.DTD;
      _dtdClient = await DtdClient.connect(uri);
    }
  }

  // 根据协议选择实现
  Future<void> hotReload() async {
    if (_protocol == Protocol.VM_SERVICE) {
      return _vmService.hotReload();
    } else {
      return _dtdClient.hotReload();  // DTD 也支持热重载
    }
  }

  Future<Map> tap({String? key}) async {
    if (_protocol == Protocol.VM_SERVICE) {
      // 使用自定义扩展
      return _vmService.callServiceExtension('ext.flutter.flutter_skill.tap', ...);
    } else {
      // DTD 不支持，返回错误
      throw UnsupportedError('tap() 需要 VM Service 协议');
    }
  }
}
```

**功能分级**:

| 功能 | VM Service | DTD |
|------|-----------|-----|
| 热重载 | ✅ | ✅ |
| 获取日志 | ✅ | ✅ |
| 性能分析 | ✅ | ✅ |
| **tap/click** | ✅ | ❌ |
| **enterText** | ✅ | ❌ |
| **Widget Tree** | ✅ | ❌ |
| **截图** | ✅ | ❌ |

---

### 方案 B: DTD + Flutter Driver 组合

**设计思路**：
1. **DTD**：用于日志、热重载等基础功能
2. **Flutter Driver**：用于 UI 操作

**问题**：
- Flutter Driver 也需要 VM Service 😅
- 反而增加了复杂度

**结论**：不可行

---

### 方案 C: 自动启动 VM Service

**设计思路**：
1. 检测到 DTD URI 时，**自动重启应用并加上 `--vm-service-port`**
2. 对用户透明

```dart
if (detectedDtdOnly) {
  print('检测到仅 DTD 协议，正在重启应用并启用 VM Service...');

  // 1. 终止当前应用
  await killFlutterProcess();

  // 2. 重新启动，加上 VM Service 参数
  await Process.start('flutter', [
    'run',
    '--vm-service-port=50000',
    ...originalArgs,
  ]);

  // 3. 等待 VM Service 启动
  await waitForVmService();
}
```

**优势**：
- ✅ 用户无感知
- ✅ 自动配置
- ✅ 获得完整功能

**劣势**：
- ⚠️ 需要重启应用（~10-30 秒）
- ⚠️ 可能打断用户工作流

---

## 🚀 推荐方案：智能协议选择

### 实现策略

```
┌─────────────────────────────────────────────────┐
│         launch_app / scan_and_connect           │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  检测可用协议         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  找到 VM Service?     │
         └───────────┬───────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
         是                    否
          │                     │
          ▼                     ▼
┌─────────────────┐   ┌─────────────────┐
│ 使用 VM Service │   │  仅找到 DTD?    │
│ 功能: 完整 ✅   │   └────────┬────────┘
└─────────────────┘            │
                    ┌──────────┴──────────┐
                    │                     │
                   是                    否
                    │                     │
                    ▼                     ▼
          ┌─────────────────┐   ┌─────────────────┐
          │ 提示用户选择:   │   │  无可用协议     │
          │ 1. 重启+VM      │   │  返回错误       │
          │ 2. 仅基础功能   │   └─────────────────┘
          └─────────────────┘
```

### 用户体验

#### 场景 1: VM Service 可用（最佳）
```
✅ 已连接到 VM Service
✅ 所有功能可用: tap, screenshot, inspect...
```

#### 场景 2: 仅 DTD 可用（降级）
```
⚠️ 检测到仅 DTD 协议，部分功能不可用

可用功能:
  ✅ hot_reload
  ✅ get_logs
  ✅ get_performance

不可用功能:
  ❌ tap / click
  ❌ screenshot
  ❌ inspect

建议:
  选项 1: 重启应用并启用 VM Service（获得完整功能）
  选项 2: 继续使用基础功能

请选择: [1/2]
```

#### 场景 3: 自动重启（智能）
```
🔄 检测到仅 DTD 协议，自动启用 VM Service...

   1. 正在终止当前应用...
   2. 重新启动（加上 --vm-service-port=50000）...
   3. 等待 VM Service 启动...

✅ VM Service 已启动，所有功能已可用！
```

---

## 📋 实现计划

### Phase 1: 协议检测

```dart
// lib/src/protocol_detector.dart
enum Protocol { VM_SERVICE, DTD, NONE }

class ProtocolDetector {
  static Future<Protocol> detect(String uri) async {
    if (uri.startsWith('http://')) {
      // VM Service URI
      return Protocol.VM_SERVICE;
    } else if (uri.startsWith('ws://') && uri.contains('=/ws')) {
      // 可能是 DTD，需要进一步验证
      try {
        final client = await DtdClient.connect(uri);
        return Protocol.DTD;
      } catch (e) {
        return Protocol.NONE;
      }
    }
    return Protocol.NONE;
  }
}
```

### Phase 2: DTD 客户端封装

```dart
// lib/src/dtd_client_wrapper.dart
class DtdClientWrapper {
  final DtdClient _client;

  // 支持的基础功能
  Future<void> hotReload() => _client.hotReload();
  Future<List<String>> getLogs() => _client.streamStdout();

  // 不支持的功能
  Future<void> tap({String? key}) {
    throw UnsupportedError(
      'tap() 需要 VM Service 协议。\n'
      '请使用 launch_app(extra_args: ["--vm-service-port=50000"]) 启动应用'
    );
  }
}
```

### Phase 3: 统一客户端接口

```dart
// lib/src/unified_client.dart
abstract class UnifiedFlutterClient {
  Future<void> hotReload();
  Future<void> tap({String? key});
  Future<List<String>> getLogs();

  // 能力查询
  bool get supportsTap;
  bool get supportsScreenshot;
  Protocol get protocol;
}

class VmServiceClient implements UnifiedFlutterClient {
  bool get supportsTap => true;
  Protocol get protocol => Protocol.VM_SERVICE;
}

class DtdOnlyClient implements UnifiedFlutterClient {
  bool get supportsTap => false;
  Protocol get protocol => Protocol.DTD;

  Future<void> tap({String? key}) {
    throw UnsupportedError('需要 VM Service');
  }
}
```

---

## 🎯 最终建议

### ✅ 推荐实现：三级策略

#### Level 1: 优先 VM Service（默认）
```dart
// 自动添加 --vm-service-port=50000
launch_app(device_id: "iPhone 16 Pro")
```

#### Level 2: 智能降级到 DTD（备选）
```dart
// 如果检测到仅 DTD，提示用户
if (onlyDtdAvailable) {
  askUser([
    "重启并启用 VM Service（推荐）",
    "仅使用基础功能（热重载、日志）"
  ]);
}
```

#### Level 3: 手动指定协议（高级）
```dart
// 新增参数
launch_app(
  device_id: "iPhone 16 Pro",
  protocol: "dtd-only"  // 强制仅使用 DTD
)
```

---

## ⚠️ DTD 的根本限制

### 为什么 DTD 不适合 UI 自动化？

**DTD 的设计目标**：
- ✅ 工具与应用之间的**调试通讯**
- ✅ 热重载、日志、性能分析
- ❌ **不是** UI 自动化框架

**关键问题**：
```dart
// DTD 没有这个能力！
registerExtension('ext.my.custom.method', ...);  // ❌ 不支持

// VM Service 支持
registerExtension('ext.my.custom.method', ...);  // ✅ 支持
```

**结论**：
- DTD 可以作为**补充**（基础功能）
- VM Service 仍是**核心**（UI 操作）
- 两者**混合使用**是最佳方案

---

## 📊 功能支持矩阵

### 当前实现（仅 VM Service）

| 功能 | 支持 | 说明 |
|------|------|------|
| tap | ✅ | Service Extension |
| screenshot | ✅ | Service Extension |
| inspect | ✅ | Service Extension |
| hot_reload | ✅ | VM Service API |
| get_logs | ✅ | VM Service API |

### 未来实现（VM Service + DTD）

| 功能 | VM Service | DTD | 备注 |
|------|-----------|-----|------|
| tap | ✅ | ❌ | 需要自定义扩展 |
| screenshot | ✅ | ❌ | 需要自定义扩展 |
| inspect | ✅ | ❌ | 需要自定义扩展 |
| hot_reload | ✅ | ✅ | 两者都支持 |
| get_logs | ✅ | ✅ | 两者都支持 |
| **覆盖率** | **100%** | **40%** | DTD 仅适合基础功能 |

---

## 🚦 实施路线图

### v0.4.0: 协议检测
- [ ] 实现 `ProtocolDetector`
- [ ] 自动检测 VM Service / DTD
- [ ] 友好的错误提示

### v0.5.0: DTD 基础支持
- [ ] 实现 `DtdClientWrapper`
- [ ] 支持 `hot_reload` via DTD
- [ ] 支持 `get_logs` via DTD

### v0.6.0: 智能降级
- [ ] 自动选择最佳协议
- [ ] 提示用户是否重启（当仅 DTD 可用时）
- [ ] 统一的 `UnifiedFlutterClient` 接口

### v1.0.0: 混合模式
- [ ] 同时支持 VM Service + DTD
- [ ] 根据功能需求自动选择协议
- [ ] 完整的文档和示例

---

## 🎓 结论

### ✅ 可行性评估

**DTD 作为完全替代方案**: ❌ **不可行**
- DTD 不支持自定义 Service Extension
- 无法实现 UI 自动化核心功能

**DTD 作为补充方案**: ✅ **可行**
- DTD 支持热重载、日志等基础功能
- 可以作为降级方案

### 🎯 最佳方案

**混合模式**：
1. **默认**：自动添加 `--vm-service-port=50000`（已实现 ✅）
2. **智能检测**：如果仅 DTD 可用，提示用户选择（未来）
3. **基础功能**：通过 DTD 提供热重载、日志（未来）
4. **高级功能**：通过 VM Service 提供 UI 操作（当前）

**用户体验**：
- ✅ 零配置（自动添加 VM Service 参数）
- ✅ 智能降级（DTD 备选）
- ✅ 功能完整（VM Service 核心）

---

**最后更新**: 2026-02-01
**结论**: DTD 可以作为补充，但不能替代 VM Service
