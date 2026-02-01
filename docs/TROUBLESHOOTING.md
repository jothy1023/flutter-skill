# Flutter Skill 连接问题诊断

## 🔍 你遇到的问题

### 错误信息
```
connect_app(uri: "ws://127.0.0.1:54321/ws")
→ Error: Connection refused, port = 62397
```

### 实际情况

**检测结果**:
```bash
# 1. .flutter_skill_uri 文件内容
ws://127.0.0.1:52043/SFErOrpc9AU=/ws  ← 旧的 URI

# 2. 端口 52043 状态
❌ 端口未监听（应用已关闭）

# 3. 当前运行的 Flutter 应用
✅ 有应用在运行
✅ VM Service 端口: 64004
✅ URI: http://127.0.0.1:64004/JNZQunrYU_4=/
```

---

## 🎯 问题根源

### 问题 1: 使用了旧的/错误的 URI

```
你使用的:   ws://127.0.0.1:54321/ws  ← 错误
实际应该是: http://127.0.0.1:64004/JNZQunrYU_4=/  ← 正确
```

**为什么会这样？**
- 应用重启后，VM Service 端口会变化（64004 → 另一个随机端口）
- .flutter_skill_uri 文件保存的是旧的 URI
- 你手动输入的 URI 也不正确

### 问题 2: 应用没有用固定端口启动

当前应用启动命令可能是：
```bash
flutter run  # ❌ 没有指定端口
```

导致：
- VM Service 端口随机分配（64004、52043...每次不同）
- 无法预测连接地址

---

## ✅ 解决方案

### 方案 A: 使用 launch_app（推荐，零配置）

**停止当前应用，使用 flutter-skill 启动**：

```python
# 在 MCP 客户端（Cursor）中调用
launch_app(
  project_path: "/Users/cw/development/opencli/opencli_mobile",
  device_id: "iPhone 16 Pro"  # 或你的设备 ID
)

# 自动完成:
# 1. 启动应用（自动添加 --vm-service-port=50000）
# 2. 自动连接
# 3. 保存 URI 到 .flutter_skill_uri
```

**优势**:
- ✅ 完全自动化
- ✅ 固定端口（50000）
- ✅ 零配置

---

### 方案 B: 手动启动 + 正确的 URI

#### 步骤 1: 重启应用，指定固定端口

```bash
# 停止当前应用
# 然后重新启动，加上参数:
cd /Users/cw/development/opencli/opencli_mobile
flutter run -d "iPhone 16 Pro" --vm-service-port=50000
```

**关键**: 必须加 `--vm-service-port=50000`

#### 步骤 2: 使用正确的 URI 连接

启动后会看到：
```
The Dart VM service is listening on http://127.0.0.1:50000/xxx=/
```

复制这个 URI，然后：
```python
connect_app(uri: "http://127.0.0.1:50000/xxx=/")
```

---

### 方案 C: 自动扫描并连接

```python
# 不需要 URI，自动扫描
scan_and_connect()

# 会自动:
# 1. 扫描端口 50000-50100
# 2. 查找运行的 Flutter 应用
# 3. 自动连接
```

**问题**: 如果应用没有用固定端口启动，可能扫描不到（因为端口是 64004）

---

## 🔍 诊断命令

### 查看当前运行的应用

```bash
# 查看 VM Service 端口
lsof -iTCP -sTCP:LISTEN -n -P | grep dart

# 查看保存的 URI
cat .flutter_skill_uri
```

### 测试连接

```python
# 获取连接状态
get_connection_status()

# 会显示:
# - 是否已连接
# - 当前 URI
# - 可用的应用列表
```

---

## 📋 完整的故障排除流程

### 1️⃣ 检查应用是否运行

```bash
ps aux | grep flutter | grep run
```

如果没有运行 → 使用 `launch_app` 启动

### 2️⃣ 检查 VM Service 是否启用

```bash
# 查看 Flutter 启动日志
# 应该看到:
The Dart VM service is listening on http://...
```

如果没有看到 → 应用没有启用 VM Service，需要重启并加 `--vm-service-port=50000`

### 3️⃣ 获取正确的 URI

**方法 1**: 从启动日志复制
```
The Dart VM service is listening on http://127.0.0.1:50000/xxx=/
```

**方法 2**: 使用 scan_and_connect 自动发现
```python
scan_and_connect()
```

### 4️⃣ 连接

```python
connect_app(uri: "http://127.0.0.1:50000/xxx=/")
```

---

## 🎯 推荐工作流程

### 最简单的方式（推荐）

```python
# 1. 停止当前应用（如果有）
stop_app()

# 2. 使用 launch_app 启动
launch_app(
  project_path: "/Users/cw/development/opencli/opencli_mobile",
  device_id: "iPhone 16 Pro"
)

# 3. 自动连接成功！
# 现在可以使用所有功能:
inspect()
tap(key: "button")
screenshot()
```

**为什么推荐？**
- ✅ 自动添加 `--vm-service-port=50000`
- ✅ 固定端口，下次可以直接 `scan_and_connect()`
- ✅ 零配置，无需手动输入 URI

---

## 🐛 常见错误及解决

### 错误 1: "Connection refused"

**原因**: URI 过期或错误

**解决**:
```python
# 清除旧 URI
rm .flutter_skill_uri

# 重新扫描
scan_and_connect()
```

### 错误 2: "No running Flutter apps found"

**原因**: 应用未运行或未启用 VM Service

**解决**:
```python
launch_app(project_path: ".")
```

### 错误 3: "Found DTD URI but no VM Service URI"

**原因**: 应用启动时没有加 `--vm-service-port`

**解决**:
```bash
# 重启应用，加上参数
flutter run --vm-service-port=50000
```

---

## 📊 URI 格式识别

### ✅ 正确的 VM Service URI

```
http://127.0.0.1:50000/xxx=/
ws://127.0.0.1:50000/xxx=/ws

特征:
- http:// 或 ws://
- 包含随机 token (xxx=)
- 通常在 "Dart VM service is listening" 消息后
```

### ❌ 错误的 URI

```
ws://127.0.0.1:54321/ws  ← 缺少 token，可能是 DTD
ws://127.0.0.1:52043/...  ← 端口已关闭（旧 URI）
```

---

## 🎓 总结

### 你的问题

1. **使用了旧的 URI** (`ws://127.0.0.1:52043/...`)
2. **应用没有固定端口** (当前在 64004，下次可能变)
3. **使用了 connect_app 而不是 launch_app**

### 解决方法

**最简单**:
```python
launch_app(project_path: "/Users/cw/development/opencli/opencli_mobile")
```

**或者**:
```bash
flutter run --vm-service-port=50000
# 然后
scan_and_connect()
```

---

**关键点**: `launch_app` 自动添加 `--vm-service-port=50000` 的功能**只在使用 launch_app 时生效**，手动启动的应用需要自己加参数！
