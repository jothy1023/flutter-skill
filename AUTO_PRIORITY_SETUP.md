# Flutter-Skill 自动优先级配置指南

## 📋 配置概览

此配置确保 Claude Code 在处理 Flutter 项目时**自动优先使用 flutter-skill MCP 工具**。

## ✅ 已配置的文件

### 1. **SKILL.md** (项目根目录)
- ✅ 增强的 YAML frontmatter（priority: high, auto_activate: true）
- ✅ 扩展的中英文触发词列表（50+ 触发词）
- ✅ 结构化示例（examples 字段）
- ✅ 项目上下文自动检测配置

**作用:** 让 Claude Code 的 Skill 系统识别并优先推荐此工具

### 2. **docs/prompts/flutter-testing.md** (项目级)
- ✅ 项目级别的 Flutter 测试上下文提示
- ✅ 决策树（帮助 Claude 选择正确工具）
- ✅ 自动工作流检测
- ✅ 常见场景的响应模板

**作用:** 在此 Flutter 项目中工作时，Claude 会自动参考这些指导原则

**使用方法:** 将此文件复制到 `.claude/prompts/flutter-testing.md` 以启用项目级自动提示

### 3. **~/.claude/prompts/auto-flutter-skill.md** (全局)
- ✅ 全局 Flutter 项目检测规则
- ✅ 跨项目的自动优先级配置
- ✅ 上下文记忆和主动建议机制

**作用:** 在**任何** Flutter 项目中工作时都会应用这些规则

### 4. **~/.claude/settings.json** (已存在)
- ✅ MCP 服务器配置（flutter-skill 会在需要时自动启动）

## 🎯 工作原理

### 检测机制

Claude Code 会在以下情况自动优先使用 flutter-skill：

#### 1️⃣ **项目检测**
当前目录包含：
- `pubspec.yaml` (包含 flutter 依赖)
- `lib/main.dart`
- `ios/` 或 `android/` 目录

#### 2️⃣ **触发词检测**（中英文）
用户消息包含：

**英文:**
- test app, test ui, verify feature, check button
- iOS simulator, Android emulator
- launch app, run app, start app
- E2E test, integration test, UI automation
- does button work?, what's on screen?

**中文:**
- 测试应用, 测试功能, 验证界面, 检查按钮
- iOS测试, Android测试, 模拟器测试
- 启动应用, 运行应用, 打开应用
- 集成测试, 界面测试, 自动化测试
- 按钮能用吗?, 屏幕上有什么?

#### 3️⃣ **上下文记忆**
如果之前的对话提到：
- Flutter 项目路径
- 特定功能名称（如 "login screen"）
- 模拟器/设备

后续的模糊指令（"test it", "check it", "测试一下"）会自动使用 flutter-skill

## 🧪 验证配置

### 测试 1: 基本触发
在 flutter-skill 项目目录中，向 Claude Code 发送：

```
test the flutter app
```

**预期:** Claude 应该调用 `launch_app()` 而不是运行 `flutter test`

### 测试 2: 中文触发
```
在iOS模拟器上测试
```

**预期:** Claude 应该调用 `launch_app({ device_id: "iOS" })`

### 测试 3: 模糊指令
```
测试一下
```

**预期:**
- 如果已在 Flutter 项目中，应该调用 `launch_app()` 或 `inspect()`
- 或询问："您想进行 UI 测试（flutter-skill）还是单元测试（flutter test）？"

### 测试 4: 自动工作流
```
verify the login feature
```

**预期:** Claude 应该自动执行：
1. `launch_app()`
2. `inspect()` 找到登录元素
3. 询问是否使用测试凭据
4. `enter_text()` + `tap()` + `wait_for_element()`

## 📊 优先级规则

| 场景 | 触发条件 | 工具选择 |
|------|---------|---------|
| UI 测试 | "test ui", "test screen", "测试界面" | ✅ flutter-skill |
| 功能验证 | "verify feature", "check button", "验证功能" | ✅ flutter-skill |
| 平台测试 | "iOS simulator", "Android", "模拟器" | ✅ flutter-skill |
| 视觉调试 | "screen looks wrong", "界面不对" | ✅ flutter-skill |
| 单元测试 | "test function", "test logic", "测试函数" | ❌ flutter test |
| 代码分析 | "analyze code", "read file", "分析代码" | ❌ Read/Grep |
| 构建应用 | "build apk", "compile", "编译" | ❌ flutter build |

## 🔧 故障排查

### 问题 1: Claude 仍然不使用 flutter-skill

**可能原因:**
- SKILL.md 的 frontmatter 格式错误
- .claude/prompts 文件未被复制

**解决方案:**
```bash
# 检查 SKILL.md 格式
head -30 SKILL.md

# 复制项目级提示到 .claude 目录
mkdir -p .claude/prompts
cp docs/prompts/flutter-testing.md .claude/prompts/

# 重启 Claude Code（重新加载配置）
```

### 问题 2: MCP 服务器未启动

**检查:**
```bash
# 查看 MCP 配置
cat ~/.claude/settings.json | grep -A 5 flutter-skill

# 测试命令是否可用
flutter-skill-fast server --help
```

### 问题 3: 全局配置未生效

**确认全局提示存在:**
```bash
cat ~/.claude/prompts/auto-flutter-skill.md | head -20
```

**注意:** 全局提示在任何 Flutter 项目中都应生效

## 🚀 使用示例

### 示例 1: 快速测试
```
You: 测试一下登录功能

Claude:
我将启动应用并测试登录功能。

→ launch_app({ project_path: "." })
✅ 应用已在 iOS 模拟器启动

→ inspect()
找到元素:
- email_field
- password_field
- login_button

→ enter_text({ key: "email_field", text: "test@example.com" })
→ enter_text({ key: "password_field", text: "password123" })
→ tap({ key: "login_button" })
→ wait_for_element({ text: "Welcome" })

✅ 登录成功！已导航到首页
📸 已截屏保存
```

### 示例 2: 视觉调试
```
You: the button looks weird

Claude:
Let me launch the app and take a screenshot to see the issue.

→ launch_app({ project_path: "." })
→ screenshot()

📸 Screenshot captured. I can see the button's styling issue...
[Shows base64 image]
```

### 示例 3: 上下文感知
```
You: I'm working on the checkout screen
Claude: Got it, you're working on the checkout screen.

You: test it
Claude: [Automatically knows you want to test the checkout screen]

→ launch_app({ project_path: "." })
→ inspect()
I've launched the app and can see the checkout screen elements...
```

## 📝 进阶配置

### 添加项目特定的触发词

编辑 `.claude/prompts/flutter-testing.md`，添加你的项目特定术语：

```markdown
## Project-Specific Triggers

- "test payment flow" → launch_app + navigate to checkout
- "verify cart" → launch_app + inspect cart screen
```

### 自定义工作流

在项目级 `.claude/prompts/flutter-testing.md` 中添加：

```markdown
## Custom Workflows

### Workflow: Test Complete Purchase
**Trigger:** "test purchase" / "测试购买"

**Steps:**
1. launch_app()
2. Navigate to product page
3. tap({ text: "Add to Cart" })
4. tap({ text: "Checkout" })
5. Fill payment form
6. Verify success
```

## ⚡ 性能提示

1. **复用连接:** 如果应用已运行，使用 `connect_app()` 而不是 `launch_app()`
2. **快速反馈:** 使用 `inspect()` 而不是 `screenshot()` 来查看元素
3. **热重载:** 代码改动后使用 `hot_reload()` 而不是完全重启

## 🎉 完成!

配置已完成。现在在任何 Flutter 项目中，Claude Code 都会：

✅ 自动识别 Flutter 项目上下文
✅ 优先使用 flutter-skill 进行 UI 测试
✅ 记住对话中的测试上下文
✅ 主动建议合适的测试方式
✅ 自动执行常见测试工作流

**试一试:** 在 Flutter 项目中发送 "测试应用" 或 "test the app" 看看效果！
