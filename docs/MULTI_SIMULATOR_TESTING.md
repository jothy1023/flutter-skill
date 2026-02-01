# 多模拟器并行测试指南

## 🎯 需求场景

在多个 iOS 模拟器上同时测试不同的 Flutter 项目，实现：
- ✅ 并排对比不同版本
- ✅ 同时测试不同平台（iOS + Android）
- ✅ 批量回归测试
- ✅ A/B 测试不同实现

---

## 📊 当前状态

### ✅ 技术可行性

**iOS 模拟器**：
- ✅ 可以同时运行多个模拟器实例
- ✅ 每个模拟器独立的设备 ID
- ✅ 同时显示在 Simulator.app

**Flutter 应用**：
- ✅ 每个应用可以使用独立的 VM Service 端口
- ✅ 多个 `flutter run` 进程可以同时运行
- ✅ 每个应用独立的 isolate

---

### ⚠️ 当前限制

**MCP Server 设计**：
```dart
FlutterSkillClient? _client;  // ❌ 只有一个全局客户端
```

**当前实现**：
- ❌ MCP server 一次只能连接到**一个**应用
- ❌ 切换应用需要断开旧连接，建立新连接
- ❌ 无法同时操作多个应用

---

## 🔧 当前的解决方案

### 方案 1: 多端口启动 + 手动切换（可行 ✅）

#### 步骤 1: 启动多个模拟器

```bash
# 打开模拟器管理器
open -a Simulator

# 或使用命令行启动多个设备
xcrun simctl boot "iPhone 15"
xcrun simctl boot "iPhone 16 Pro"
xcrun simctl boot "iPad Pro"
```

#### 步骤 2: 启动多个应用（不同端口）

```python
# AI Agent 调用 MCP 工具

# 项目 1: 使用端口 50001
launch_app(
  project_path: "/path/to/project1",
  device_id: "iPhone 15",
  extra_args: ["--vm-service-port=50001"]
)

# 项目 2: 使用端口 50002
launch_app(
  project_path: "/path/to/project2",
  device_id: "iPhone 16 Pro",
  extra_args: ["--vm-service-port=50002"]
)

# 项目 3: 使用端口 50003
launch_app(
  project_path: "/path/to/project3",
  device_id: "iPad Pro",
  extra_args: ["--vm-service-port=50003"]
)
```

**结果**:
- ✅ 三个模拟器同时运行
- ✅ 三个应用同时运行
- ✅ 每个应用使用独立的端口

#### 步骤 3: 切换连接进行测试

```python
# 测试项目 1
connect_app(uri: "http://127.0.0.1:50001/...")
inspect()
tap(key: "login_button")

# 切换到项目 2
connect_app(uri: "http://127.0.0.1:50002/...")
inspect()
tap(key: "signup_button")

# 切换到项目 3
connect_app(uri: "http://127.0.0.1:50003/...")
screenshot()
```

**优势**:
- ✅ 简单直接
- ✅ 利用现有工具
- ✅ 无需代码修改

**劣势**:
- ⚠️ 需要手动切换连接
- ⚠️ 无法同时操作多个应用
- ⚠️ 每次切换有延迟

---

### 方案 2: 使用脚本批量测试（推荐 ⭐）

#### 创建测试脚本

```bash
#!/bin/bash
# test-all.sh - 批量测试多个项目

# 1. 启动所有应用
echo "启动应用..."
flutter run -d "iPhone 15" --vm-service-port=50001 --project project1 &
flutter run -d "iPhone 16 Pro" --vm-service-port=50002 --project project2 &
flutter run -d "iPad Pro" --vm-service-port=50003 --project project3 &

# 等待应用启动
sleep 10

# 2. 测试项目 1
echo "测试项目 1..."
flutter-skill connect http://127.0.0.1:50001/xxx=/
flutter-skill act tap "button1"
flutter-skill act screenshot > project1.png

# 3. 测试项目 2
echo "测试项目 2..."
flutter-skill connect http://127.0.0.1:50002/xxx=/
flutter-skill act tap "button2"
flutter-skill act screenshot > project2.png

# 4. 测试项目 3
echo "测试项目 3..."
flutter-skill connect http://127.0.0.1:50003/xxx=/
flutter-skill act tap "button3"
flutter-skill act screenshot > project3.png

echo "所有测试完成！"
```

**优势**:
- ✅ 自动化批量测试
- ✅ 可以记录结果
- ✅ 易于集成 CI/CD

---

### 方案 3: 多终端并行操作（高级用户）

#### 终端 1: 测试项目 1
```bash
export FLUTTER_SKILL_PORT=50001
flutter-skill connect http://127.0.0.1:50001/xxx=/
flutter-skill inspect
flutter-skill act tap "button1"
```

#### 终端 2: 测试项目 2
```bash
export FLUTTER_SKILL_PORT=50002
flutter-skill connect http://127.0.0.1:50002/xxx=/
flutter-skill inspect
flutter-skill act tap "button2"
```

#### 终端 3: 测试项目 3
```bash
export FLUTTER_SKILL_PORT=50003
flutter-skill connect http://127.0.0.1:50003/xxx=/
flutter-skill inspect
flutter-skill act tap "button3"
```

**优势**:
- ✅ 真正的并行操作
- ✅ 实时交互
- ✅ 独立控制每个应用

**劣势**:
- ⚠️ 需要多个终端窗口
- ⚠️ 手动管理复杂

---

## 🚀 未来增强：多连接支持

### 设计目标

**理想体验**:
```python
# 1. 启动并连接多个应用
session1 = launch_app(
  project_path: "project1",
  device_id: "iPhone 15",
  session_name: "app1"  # 🆕 会话名称
)

session2 = launch_app(
  project_path: "project2",
  device_id: "iPhone 16 Pro",
  session_name: "app2"  # 🆕 会话名称
)

# 2. 同时操作多个应用
tap(session: "app1", key: "button1")  # 🆕 指定会话
tap(session: "app2", key: "button2")  # 🆕 指定会话

# 3. 批量操作
for session in ["app1", "app2", "app3"]:
    screenshot(session: session)
```

---

### 实现方案

#### 修改 MCP Server 架构

**当前**:
```dart
FlutterSkillClient? _client;  // 单一连接
```

**改进**:
```dart
Map<String, FlutterSkillClient> _clients = {};  // 多连接管理

// 工具调用时指定 session_id
Future<Map<String, dynamic>> tap({
  String? sessionId,  // 🆕 会话 ID
  String? key,
}) async {
  final client = sessionId != null
    ? _clients[sessionId]  // 使用指定会话
    : _clients.values.first;  // 默认使用第一个

  if (client == null) {
    return {'error': 'Session not found: $sessionId'};
  }

  return await client.tap(key: key);
}
```

---

### 增强的工具定义

```dart
// launch_app 返回 session_id
{
  "name": "launch_app",
  "inputSchema": {
    "session_name": {
      "type": "string",
      "description": "Unique session identifier (e.g., 'app1', 'main', 'feature-branch')"
    },
    "project_path": { ... },
    "device_id": { ... }
  },
  "returns": {
    "session_id": "string",  // 🆕 返回会话 ID
    "vm_service_uri": "string",
    "device_id": "string"
  }
}

// 所有工具添加 session_id 参数
{
  "name": "tap",
  "inputSchema": {
    "session_id": {  // 🆕 可选参数
      "type": "string",
      "description": "Target session (omit to use default/first session)"
    },
    "key": { ... }
  }
}
```

---

### 会话管理工具

```dart
// 列出所有会话
list_sessions() -> {
  "sessions": [
    {
      "id": "app1",
      "project": "project1",
      "device": "iPhone 15",
      "status": "connected",
      "vm_service_uri": "http://127.0.0.1:50001/..."
    },
    {
      "id": "app2",
      "project": "project2",
      "device": "iPhone 16 Pro",
      "status": "connected",
      "vm_service_uri": "http://127.0.0.1:50002/..."
    }
  ]
}

// 切换默认会话
set_active_session(session_id: "app2")

// 关闭指定会话
close_session(session_id: "app1")
```

---

## 📝 实现优先级

### Phase 1: 文档 + 当前方案（已完成 ✅）
- ✅ 记录多模拟器使用方法
- ✅ 提供脚本示例
- ✅ 用户可以立即使用

### Phase 2: 会话管理（计划中）
- 🔄 实现多连接管理
- 🔄 添加 `session_id` 参数
- 🔄 添加会话管理工具

### Phase 3: 批量操作（未来）
- ⏳ 批量执行相同操作
- ⏳ 并行截图对比
- ⏳ 同步测试流程

---

## 🎓 最佳实践

### 推荐端口分配

```
项目 1: --vm-service-port=50001
项目 2: --vm-service-port=50002
项目 3: --vm-service-port=50003
...
项目 N: --vm-service-port=5000N
```

### 命名约定

```python
# 使用有意义的名称
launch_app(
  project_path: "main_app",
  extra_args: ["--vm-service-port=50001"]
)  # 主分支版本

launch_app(
  project_path: "feature_branch",
  extra_args: ["--vm-service-port=50002"]
)  # 功能分支版本

launch_app(
  project_path: "stable_release",
  extra_args: ["--vm-service-port=50003"]
)  # 稳定版本
```

### 日志记录

```bash
# 保存每个应用的输出
flutter run --vm-service-port=50001 2>&1 | tee app1.log &
flutter run --vm-service-port=50002 2>&1 | tee app2.log &
flutter run --vm-service-port=50003 2>&1 | tee app3.log &
```

---

## 💡 实际应用场景

### 场景 1: A/B 测试

```python
# 启动两个版本
launch_app(project_path: "version_a", extra_args: ["--vm-service-port=50001"])
launch_app(project_path: "version_b", extra_args: ["--vm-service-port=50002"])

# 执行相同操作
connect_app(uri: "http://127.0.0.1:50001/...")
tap(key: "checkout_button")
screenshot()  # 保存为 version_a.png

connect_app(uri: "http://127.0.0.1:50002/...")
tap(key: "checkout_button")
screenshot()  # 保存为 version_b.png

# 对比结果
```

### 场景 2: 多平台测试

```python
# iOS
launch_app(
  project_path: ".",
  device_id: "iPhone 16 Pro",
  extra_args: ["--vm-service-port=50001"]
)

# Android
launch_app(
  project_path: ".",
  device_id: "Pixel 8",
  extra_args: ["--vm-service-port=50002"]
)

# iPad
launch_app(
  project_path: ".",
  device_id: "iPad Pro",
  extra_args: ["--vm-service-port=50003"]
)
```

### 场景 3: 回归测试

```bash
#!/bin/bash
# 测试 3 个版本的相同功能

for version in v1.0 v2.0 v3.0; do
  port=$((50000 + ${version//[^0-9]/}))

  cd $version
  flutter run --vm-service-port=$port &

  sleep 10

  flutter-skill connect http://127.0.0.1:$port/xxx=/
  flutter-skill act tap "login"
  flutter-skill act screenshot > ${version}_login.png
done
```

---

## 📊 对比：当前 vs 未来

| 功能 | 当前状态 | 未来增强 |
|------|---------|---------|
| **同时启动多个应用** | ✅ 支持（手动端口） | ✅ 自动端口分配 |
| **管理多个连接** | ❌ 需要手动切换 | ✅ 会话管理 |
| **同时操作多个应用** | ❌ 不支持 | ✅ session_id 参数 |
| **批量截图** | ⚠️ 需要脚本 | ✅ 内置批量工具 |
| **并行测试** | ⚠️ 多终端 | ✅ 原生支持 |

---

## 🎯 总结

### 当前可以做到（立即可用）

✅ **多模拟器启动**: 使用不同端口和设备 ID
```python
launch_app(device_id: "iPhone 15", extra_args: ["--vm-service-port=50001"])
launch_app(device_id: "iPhone 16", extra_args: ["--vm-service-port=50002"])
```

✅ **切换测试**: 使用 `connect_app` 切换连接
```python
connect_app(uri: "http://127.0.0.1:50001/...")  # 测试应用 1
connect_app(uri: "http://127.0.0.1:50002/...")  # 测试应用 2
```

✅ **批量测试**: 使用 shell 脚本自动化

---

### 未来将支持（计划中）

🔄 **会话管理**: 命名和管理多个连接
```python
launch_app(session_name: "app1", ...)
tap(session: "app1", key: "button")
```

🔄 **并行操作**: 同时操作多个应用
```python
batch_tap(sessions: ["app1", "app2", "app3"], key: "button")
```

---

**当前推荐方案**: 使用方案 1（多端口 + 手动切换）或方案 2（脚本批量测试）✅

**文档版本**: v1.0
**更新时间**: 2026-02-01
