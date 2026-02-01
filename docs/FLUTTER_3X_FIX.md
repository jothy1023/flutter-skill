# Flutter 3.x 兼容性修复指南

## 🎉 **已自动修复！（v0.3.2+）**

**好消息：** Flutter Skill 现在**自动处理** Flutter 3.x 兼容性！

从 v0.3.2 开始，`launch_app` 工具会自动添加 `--vm-service-port=50000`，
你**不需要手动指定**这个参数了。

---

## 问题总结（历史背景）
Flutter 3.x 默认使用 DTD 协议，不启动 VM Service。flutter-skill 依赖 VM Service，因此必须强制启动。

## ✅ 解决方案（自动化）

### 现在（v0.3.2+）：自动配置 🎯

**只需正常使用，无需额外参数！**

### ✅ 方法 1: 使用 MCP 工具（推荐，自动配置）
```dart
// 最简单的方式 - VM Service 端口自动添加！
launch_app(
  project_path: "/path/to/project",
  device_id: "iPhone 16 Pro"
)
// ↑ 内部自动变成: flutter run -d "iPhone 16 Pro" --vm-service-port=50000

// 如果需要自定义端口（可选）
launch_app(
  project_path: "/path/to/project",
  device_id: "iPhone 16 Pro",
  extra_args: ["--vm-service-port=8888"]  // 自定义端口
)
```

### ✅ 方法 2: CLI 命令行（自动配置）
```bash
# 简单命令 - 自动添加 --vm-service-port=50000
flutter_skill launch . -d "iPhone 16 Pro"

# 或手动指定端口
flutter_skill launch . -d "iPhone 16 Pro" --vm-service-port=8888
```

### 方法 3: 手动启动 + 连接（高级用户）
```bash
# 1. 启动应用（需手动指定 VM Service）
flutter run -d "iPhone 16 Pro" --vm-service-port=50000

# 2. 复制输出的 VM Service URI，例如:
#    The Dart VM service is listening on http://127.0.0.1:50000/xxxx=/

# 3. 连接
connect_app(uri: "http://127.0.0.1:50000/xxxx=/")
```

---

## 之前的方式（v0.3.1 及更早版本）

### ⚠️ 旧方法: 手动添加参数（已过时）
```dart
// 旧版本需要手动指定（v0.3.1 及更早）
launch_app(
  extra_args: ["--vm-service-port=50000"]  // ← 现在不再需要！
)
```

**现在你不需要这样做了！** 工具会自动处理。

## ❌ 常见错误

### 错误 1: 使用废弃的标志
```bash
flutter run --observatory-port=54321  # ❌ Flutter 3.x 已废弃
```

### 错误 2: 没有指定端口
```bash
flutter run  # ❌ 只会启动 DTD，不会启动 VM Service
```

### 错误 3: 连接到 DTD URI
```bash
connect_app(uri: "ws://127.0.0.1:52049/xxx=/ws")  # ❌ 这是 DTD URI，不是 VM Service
```

## 🔍 如何识别正确的 URI

### VM Service URI（正确）✅
```
http://127.0.0.1:50000/xxxx=/
ws://127.0.0.1:50000/xxxx=/ws
```
- 包含 `http://` 或 `ws://`
- 通常在 "Dart VM service is listening" 消息后出现

### DTD URI（错误）❌
```
ws://127.0.0.1:52049/xxx=/ws
```
- 只包含 `ws://`
- 在 "Dart Tooling Daemon" 消息后出现
- flutter-skill 不支持 DTD

## 验证连接

启动后应该看到：
```
[Flutter]: The Dart VM service is listening on http://127.0.0.1:50000/xxxx=/
✅ Connected to http://127.0.0.1:50000/xxxx=/
```

## 故障排除

### 问题: 仍然显示 "Connection refused"
**原因**: 应用可能未正确启动 VM Service
**解决**:
1. 检查 Flutter 输出中是否有 "Dart VM service is listening" 消息
2. 确认使用了 `--vm-service-port=50000` 标志
3. 重启应用

### 问题: "LateInitializationError: Field '_service' has not been initialized"
**原因**: 连接失败导致 _service 未初始化
**解决**: 修复连接问题（见上）

### 问题: "Found DTD URI but no VM Service URI"
**原因**: 忘记加 `--vm-service-port` 标志
**解决**: 添加 `--vm-service-port=50000` 到启动命令

## Flutter 版本兼容性

| Flutter 版本 | 默认协议 | 需要 --vm-service-port? |
|--------------|----------|-------------------------|
| 2.x          | VM Service | ❌ 不需要 |
| 3.0-3.24     | VM Service | ⚠️ 可选 |
| 3.25+        | DTD      | ✅ **必须** |

## 相关文档
- Flutter VM Service: https://dart.dev/tools/dart-devtools
- DTD Protocol: https://github.com/dart-lang/sdk/blob/main/pkg/dtd/README.md
