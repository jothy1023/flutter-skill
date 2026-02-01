# Plugin Testing Guide - VSCode & IntelliJ

本指南详细说明如何在本地测试 Flutter Skill 的 VSCode 扩展和 IntelliJ IDEA 插件。

---

## 📋 前置准备

### 1. 安装必要工具

```bash
# Flutter SDK
flutter --version  # 确保已安装 Flutter

# Node.js (VSCode 扩展需要)
node --version     # >= 16.x

# Dart SDK (应该随 Flutter 一起安装)
dart --version
```

### 2. 准备测试用的 Flutter 应用

创建一个简单的测试应用，包含各种可交互的 Widget：

```bash
# 创建测试应用
cd /tmp
flutter create flutter_skill_test_app
cd flutter_skill_test_app
```

#### 修改 `lib/main.dart` 添加测试 Widget

<details>
<summary>点击展开完整测试代码</summary>

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Skill Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _displayText = 'Tap a button or enter text';
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Skill Test App'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Text Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _displayText,
                  key: const Key('display_text'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Buttons', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const Key('primary_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Primary Button Tapped!';
                        });
                      },
                      child: const Text('Primary Button'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('secondary_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Secondary Button Tapped!';
                        });
                      },
                      child: const Text('Secondary Button'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('text_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Text Button Tapped!';
                        });
                      },
                      child: const Text('Text Button'),
                    ),
                    const SizedBox(height: 8),
                    IconButton(
                      key: const Key('icon_button'),
                      icon: const Icon(Icons.favorite),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Icon Button Tapped!';
                        });
                      },
                      tooltip: 'Favorite',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Text Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Text Input', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('text_field'),
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Enter text here',
                        border: OutlineInputBorder(),
                        hintText: 'Type something...',
                      ),
                      onChanged: (value) {
                        setState(() {
                          _displayText = 'You typed: $value';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      key: const Key('submit_button'),
                      onPressed: () {
                        setState(() {
                          _displayText = 'Submitted: ${_controller.text}';
                        });
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Counter
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Counter', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '$_counter',
                      key: const Key('counter_text'),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          key: const Key('decrement_button'),
                          onPressed: () {
                            setState(() {
                              _counter--;
                            });
                          },
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          key: const Key('increment_button'),
                          onPressed: () {
                            setState(() {
                              _counter++;
                            });
                          },
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Switch & Checkbox
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toggles', style: Theme.of(context).textTheme.titleMedium),
                    SwitchListTile(
                      key: const Key('switch_tile'),
                      title: const Text('Enable Feature'),
                      value: _counter > 0,
                      onChanged: (value) {
                        setState(() {
                          _counter = value ? 1 : 0;
                        });
                      },
                    ),
                    CheckboxListTile(
                      key: const Key('checkbox_tile'),
                      title: const Text('Accept Terms'),
                      value: _counter > 5,
                      onChanged: (value) {
                        setState(() {
                          _counter = value! ? 10 : 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('fab'),
        onPressed: () {
          setState(() {
            _displayText = 'FAB Tapped!';
          });
        },
        tooltip: 'Floating Action Button',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

</details>

#### 添加 flutter_skill 依赖

```bash
# 在测试应用目录中
flutter pub add flutter_skill

# 或手动编辑 pubspec.yaml
# dependencies:
#   flutter_skill: ^0.4.1
```

#### 修改 `lib/main.dart` 初始化 Flutter Skill

```dart
import 'package:flutter_skill/flutter_skill.dart';

void main() {
  // 初始化 Flutter Skill
  FlutterSkillBinding.ensureInitialized();

  runApp(const MyApp());
}
```

---

## 🔵 测试 VSCode 扩展

### 方法 1: 使用 Extension Development Host (推荐)

这是调试扩展的最佳方式，可以设置断点和查看日志。

#### 1. 打开 VSCode 扩展项目

```bash
cd /Users/cw/development/flutter-skill
code vscode-extension
```

#### 2. 安装依赖

```bash
cd vscode-extension
npm install
```

#### 3. 编译扩展

```bash
npm run compile
```

#### 4. 启动调试会话

在 VSCode 中：
1. 按 **F5** 或 点击 **Run > Start Debugging**
2. 选择 "Run Extension" 配置
3. 新的 VSCode 窗口（Extension Development Host）将打开

#### 5. 在新窗口中测试

在 Extension Development Host 窗口中：

```bash
# 打开测试应用文件夹
File > Open Folder...
# 选择 /tmp/flutter_skill_test_app

# 查看 Flutter Skill 侧边栏
View > Open View... > Flutter Skill
```

#### 6. 运行 Flutter 应用

在 Extension Development Host 的终端中：

```bash
# 方式 1: 使用 Flutter Skill 的 launch 命令（推荐）
flutter_skill launch .

# 方式 2: 使用标准 Flutter 命令
flutter run --vm-service-port=50000
```

**重要:** 必须使用 `--vm-service-port=50000` 确保 VM Service 可访问。

#### 7. 测试功能清单

等待应用启动并显示 `.flutter_skill_uri` 文件创建：

**连接状态：**
- [ ] 侧边栏显示 "Connected" 绿色徽章
- [ ] 显示设备信息（应用名称或端口号）
- [ ] 端口显示为 50000

**Inspect 功能：**
- [ ] 点击 "Inspect" 按钮
- [ ] 等待元素列表加载
- [ ] 应该看到多个元素（primary_button, text_field, counter_text 等）
- [ ] 搜索框输入 "button" 应该过滤显示只含 button 的元素

**Tap 功能：**
- [ ] 选择 "primary_button" 元素
- [ ] 点击 "👆 Tap" 按钮
- [ ] Flutter 应用应该显示 "Primary Button Tapped!"
- [ ] 活动历史显示 "Tapped element: primary_button"

**Input 功能：**
- [ ] 选择 "text_field" 元素
- [ ] 点击 "⌨️ Input" 按钮
- [ ] 输入对话框出现，输入 "Hello Flutter Skill"
- [ ] Flutter 应用的文本框应该显示输入的文本

**Screenshot 功能：**
- [ ] 点击 "📸 Screenshot" 按钮
- [ ] 选择保存位置
- [ ] 截图应该保存为 PNG 文件
- [ ] 活动历史显示 "Screenshot saved"

**Hot Reload 功能：**
- [ ] 修改 `lib/main.dart` 中的某些文本
- [ ] 点击 "🔄 Hot Reload" 按钮
- [ ] Flutter 应用应该刷新并显示新文本

**活动历史：**
- [ ] 显示最近 5 条活动
- [ ] 时间戳格式正确
- [ ] 成功/失败图标正确
- [ ] "View All" 显示完整历史
- [ ] "Clear" 按钮清空历史

**主题切换：**
- [ ] 切换到 Dark 主题（Preferences > Color Theme > Dark+）
- [ ] 侧边栏颜色正确适配
- [ ] 切换回 Light 主题验证

#### 8. 查看调试日志

在原 VSCode 窗口（不是 Extension Development Host）：
- **Debug Console** 标签页显示扩展日志
- **Output** 选择 "Flutter Skill" 频道查看详细日志

---

### 方法 2: 打包安装本地 VSIX

如果想测试生产环境的体验：

#### 1. 打包扩展

```bash
cd vscode-extension

# 安装 vsce（如果未安装）
npm install -g @vscode/vsce

# 打包
vsce package
# 生成 flutter-skill-0.4.1.vsix
```

#### 2. 安装 VSIX

在 VSCode 中：
1. **Extensions** 侧边栏
2. 点击 "..." 菜单
3. 选择 "Install from VSIX..."
4. 选择生成的 `flutter-skill-0.4.1.vsix`

#### 3. 重新加载窗口

按 **Cmd+Shift+P** (Mac) 或 **Ctrl+Shift+P** (Windows/Linux)
输入 "Reload Window"

#### 4. 按照方法 1 的步骤 5-7 测试

---

## 🟢 测试 IntelliJ IDEA 插件

### 方法 1: 使用 Gradle runIde 任务（推荐）

这会启动一个独立的 IntelliJ 实例，加载你的插件。

#### 1. 构建插件

```bash
cd /Users/cw/development/flutter-skill/intellij-plugin
./gradlew buildPlugin
```

#### 2. 运行插件开发沙箱

```bash
./gradlew runIde
```

这将：
- 下载 IntelliJ IDEA Community Edition（如果需要）
- 启动新的 IntelliJ 实例，插件已加载
- 等待几分钟直到窗口出现

#### 3. 在沙箱中打开测试应用

1. 新的 IntelliJ 窗口打开后
2. **File > Open...**
3. 选择 `/tmp/flutter_skill_test_app`
4. 等待项目索引完成

#### 4. 打开 Flutter Skill Tool Window

- **View > Tool Windows > Flutter Skill**
- 或点击右侧工具栏的 "Flutter Skill" 图标

#### 5. 运行 Flutter 应用

在 IntelliJ 终端中：

```bash
# 方式 1: 使用 Flutter Skill CLI
flutter_skill launch .

# 方式 2: 使用标准命令
flutter run --vm-service-port=50000
```

或者创建 Run Configuration：
1. **Run > Edit Configurations...**
2. 点击 **+** > **Flutter**
3. **Additional run args:** `--vm-service-port=50000`
4. 点击 **Run**

#### 6. 测试功能清单

**连接状态卡片：**
- [ ] 显示绿色 "Connected" 状态
- [ ] 显示应用名称或端口 50000
- [ ] "Disconnect" 和 "Refresh" 按钮可用

**快速操作卡片（2x2 网格）：**
- [ ] "▶️ Launch App" 按钮
- [ ] "🔍 Inspect" 按钮
- [ ] "📸 Screenshot" 按钮
- [ ] "🔄 Hot Reload" 按钮
- [ ] 连接后所有按钮启用

**Inspect 功能：**
- [ ] 点击 "🔍 Inspect" 按钮
- [ ] 通知显示找到的元素数量
- [ ] 交互元素卡片显示树形视图
- [ ] 树根节点显示 "Elements (N)"
- [ ] 展开节点显示各个元素

**元素操作：**
- [ ] 在树中选择 "primary_button"
- [ ] 点击 "👆 Tap" 按钮
- [ ] 成功对话框出现
- [ ] Flutter 应用显示 "Primary Button Tapped!"

**文本输入：**
- [ ] 选择 "text_field" 元素
- [ ] 点击 "⌨️ Input" 按钮
- [ ] 输入对话框出现
- [ ] 输入 "Test Input"
- [ ] Flutter 应用文本框显示内容

**元素详情：**
- [ ] 选择任意元素
- [ ] 点击 "🔍 Inspect" 按钮
- [ ] 对话框显示元素属性（key, type, text 等）

**搜索过滤：**
- [ ] 在搜索框输入 "button"
- [ ] 树视图只显示包含 "button" 的元素

**Screenshot 功能：**
- [ ] 点击快速操作中的 "📸 Screenshot"
- [ ] 通知显示截图保存路径
- [ ] 文件保存到 `screenshots/` 文件夹
- [ ] 打开文件确认截图正确

**Hot Reload 功能：**
- [ ] 修改 `lib/main.dart` 文件
- [ ] 点击 "🔄 Hot Reload"
- [ ] 成功通知出现
- [ ] Flutter 应用刷新显示更改

**最近活动卡片：**
- [ ] 显示最近 5 条活动
- [ ] 图标匹配活动类型（👆 🔍 📸 等）
- [ ] 时间戳显示正确
- [ ] "View All" 显示完整历史对话框
- [ ] "Clear" 按钮清空列表

**AI 编辑器卡片：**
- [ ] 显示检测到的 AI 工具
- [ ] 显示配置状态（已配置/未配置）
- [ ] "Configure" 按钮打开配置对话框

**主题测试：**
- [ ] 切换到 Darcula 主题（Settings > Appearance > Theme > Darcula）
- [ ] 所有卡片颜色正确适配
- [ ] 切换到 High Contrast 主题验证
- [ ] 切换回 Light 主题

#### 7. 查看日志

**Idea Log:**
- **Help > Show Log in Finder/Explorer**
- 查看 `idea.log` 获取详细日志

**Flutter Skill 日志:**
日志会显示在 IntelliJ 的控制台中，包含：
- `[Scanner] ...` - VM Service 扫描日志
- `[FlutterSkillService] ...` - 服务操作日志

---

### 方法 2: 打包安装 JAR 插件

如果想测试生产版本：

#### 1. 构建插件 JAR

```bash
cd intellij-plugin
./gradlew buildPlugin

# JAR 文件位置：
# build/distributions/flutter-skill-0.4.1.jar
```

#### 2. 安装插件

在你的主 IntelliJ IDEA 中：
1. **Settings/Preferences > Plugins**
2. 点击齿轮图标 ⚙️
3. 选择 "Install Plugin from Disk..."
4. 选择 `build/distributions/flutter-skill-0.4.1.jar`
5. 点击 **OK** 并重启 IntelliJ

#### 3. 按照方法 1 的步骤 3-7 测试

---

## 🔬 高级测试场景

### 测试大量元素

修改测试应用，生成 100+ 个元素：

```dart
ListView.builder(
  itemCount: 100,
  itemBuilder: (context, index) {
    return ListTile(
      key: Key('list_item_$index'),
      title: Text('Item $index'),
      trailing: IconButton(
        key: Key('icon_$index'),
        icon: Icon(Icons.delete),
        onPressed: () {},
      ),
    );
  },
)
```

测试：
- [ ] Inspect 返回所有 100+ 元素
- [ ] 搜索性能（< 300ms）
- [ ] 滚动流畅度
- [ ] 内存使用正常

### 测试连接断开

1. 启动 Flutter 应用并连接
2. 强制关闭 Flutter 应用（热键 `q` 或关闭模拟器）
3. 验证：
   - [ ] VSCode 侧边栏显示 "Disconnected"
   - [ ] IntelliJ 连接状态卡片显示 "Disconnected"
   - [ ] 操作按钮禁用
   - [ ] 无崩溃或异常

### 测试多设备切换

1. 启动应用在设备 A（如 iPhone 模拟器）
2. 验证连接
3. 停止应用
4. 启动应用在设备 B（如 Android 模拟器）
5. 验证：
   - [ ] 自动检测到新设备
   - [ ] 设备信息更新
   - [ ] 功能正常工作

### 测试错误处理

#### 无效 URI
```bash
# 创建无效的 .flutter_skill_uri
echo "invalid-uri" > .flutter_skill_uri
```
- [ ] 插件显示错误状态
- [ ] 不会崩溃
- [ ] 日志记录错误信息

#### 端口占用
```bash
# 启动两个应用在相同端口（会失败）
flutter run --vm-service-port=50000
```
- [ ] 错误提示清晰
- [ ] 不会无限重试

---

## 📊 性能基准测试

### 加载时间

**VSCode:**
- [ ] 扩展激活时间 < 500ms
- [ ] 侧边栏渲染 < 100ms
- [ ] VM Service 连接 < 2s

**IntelliJ:**
- [ ] 插件初始化 < 1s
- [ ] Tool Window 渲染 < 200ms
- [ ] VM Service 连接 < 2s

### 内存使用

使用 VSCode/IntelliJ 的性能分析工具：

**VSCode:**
- 按 **Cmd+Shift+P** > "Developer: Show Running Extensions"
- 查看 flutter-skill 的内存使用

**IntelliJ:**
- **Help > Diagnostic Tools > Activity Monitor**
- 查看插件内存占用

### 响应性测试

- [ ] Inspect 100+ 元素 < 3s
- [ ] 搜索响应 < 300ms
- [ ] UI 操作不阻塞 IDE

---

## 🐛 常见问题排查

### VSCode 扩展无法连接

**检查清单：**
1. Flutter 应用是否运行？
   ```bash
   flutter devices  # 查看连接的设备
   ```

2. `.flutter_skill_uri` 文件是否存在？
   ```bash
   cat .flutter_skill_uri
   # 应该显示 ws://127.0.0.1:50000/ws 或类似
   ```

3. 端口是否可访问？
   ```bash
   nc -zv 127.0.0.1 50000
   # 应该显示 "Connection to 127.0.0.1 port 50000 [tcp/*] succeeded!"
   ```

4. 查看 Output 日志：
   - VSCode: **View > Output** > 选择 "Flutter Skill"
   - 查找错误消息

### IntelliJ 插件无法启动

**检查清单：**
1. 插件是否正确安装？
   - **Settings > Plugins** 中查找 "Flutter Skill"

2. IntelliJ 版本兼容？
   - 需要 IntelliJ IDEA 2023.3+

3. 查看日志：
   ```bash
   # macOS
   tail -f ~/Library/Logs/JetBrains/IdeaIC2023.3/idea.log

   # Linux
   tail -f ~/.cache/JetBrains/IdeaIC2023.3/log/idea.log

   # Windows
   type %USERPROFILE%\AppData\Local\JetBrains\IdeaIC2023.3\log\idea.log
   ```

### Inspect 返回空列表

**可能原因：**
1. Flutter 应用未添加 `FlutterSkillBinding.ensureInitialized()`
2. VM Service 扩展未注册
3. Flutter 应用版本太旧

**解决方法：**
```dart
// 在 lib/main.dart 顶部
import 'package:flutter_skill/flutter_skill.dart';

void main() {
  FlutterSkillBinding.ensureInitialized();  // ← 必须添加
  runApp(const MyApp());
}
```

重新运行应用。

### Screenshot 失败

**检查：**
1. 是否有权限保存文件？
2. 磁盘空间是否充足？
3. Flutter 应用是否在前台？

---

## 📝 测试报告模板

完成测试后，填写以下报告：

```markdown
# Flutter Skill v0.4.1 手动测试报告

**测试人员:** [你的名字]
**测试日期:** [日期]
**测试环境:**
- macOS/Windows/Linux: [版本]
- VSCode: [版本]
- IntelliJ IDEA: [版本]
- Flutter: [版本]

## VSCode 扩展测试

### 功能测试
- [ ] 连接状态显示正确
- [ ] Inspect 获取元素
- [ ] Tap 操作成功
- [ ] Input 操作成功
- [ ] Screenshot 保存成功
- [ ] Hot Reload 触发成功
- [ ] 活动历史记录正确
- [ ] 主题适配正确

### 性能测试
- 扩展激活时间: ___ ms
- Inspect 100 元素耗时: ___ s
- 搜索响应时间: ___ ms

### 问题记录
1. [描述发现的问题]
2. ...

## IntelliJ 插件测试

### 功能测试
- [ ] 连接状态显示正确
- [ ] 快速操作按钮可用
- [ ] Inspect 树形视图正确
- [ ] 元素操作成功（Tap/Input）
- [ ] Screenshot 保存成功
- [ ] Hot Reload 成功
- [ ] 活动历史显示正确
- [ ] 主题适配正确

### 性能测试
- 插件初始化时间: ___ ms
- Inspect 100 元素耗时: ___ s
- 树搜索响应时间: ___ ms

### 问题记录
1. [描述发现的问题]
2. ...

## 跨平台一致性

- [ ] VSCode 和 IntelliJ 元素列表一致
- [ ] 操作结果在两边相同
- [ ] 颜色语义统一
- [ ] 错误消息一致

## 总体评价

- 稳定性: ⭐⭐⭐⭐⭐
- 易用性: ⭐⭐⭐⭐⭐
- 性能: ⭐⭐⭐⭐⭐

## 建议改进
1. [改进建议]
2. ...
```

---

## 🎓 测试技巧

### 使用 Flutter DevTools

在 Flutter 应用运行时：
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

可以：
- 查看 Widget 树
- 验证 Flutter Skill 获取的元素是否正确
- 调试 VM Service 连接

### 录制测试视频

使用屏幕录制工具记录测试过程：
- **macOS:** QuickTime Player (Cmd+Shift+5)
- **Windows:** Xbox Game Bar (Win+G)
- **Linux:** OBS Studio

### 自动化测试脚本

创建自动测试脚本：

```bash
#!/bin/bash
# test_plugin.sh

echo "🧪 Starting Flutter Skill Plugin Tests"

# 1. 启动 Flutter 应用
cd /tmp/flutter_skill_test_app
flutter run --vm-service-port=50000 &
FLUTTER_PID=$!

# 2. 等待应用启动
sleep 10

# 3. 运行 CLI 命令测试
flutter_skill inspect > inspect_result.json

# 4. 验证结果
if [ -s inspect_result.json ]; then
  echo "✅ Inspect test passed"
else
  echo "❌ Inspect test failed"
fi

# 5. 清理
kill $FLUTTER_PID
```

---

## 📚 更多资源

- **VSCode Extension API:** https://code.visualstudio.com/api
- **IntelliJ Platform SDK:** https://plugins.jetbrains.com/docs/intellij/
- **Flutter VM Service Protocol:** https://github.com/dart-lang/sdk/blob/main/runtime/vm/service/service.md
- **Flutter Skill 文档:** https://github.com/ai-dashboad/flutter-skill

---

**Happy Testing! 🎉**

如有问题，请提交 Issue 到 https://github.com/ai-dashboad/flutter-skill/issues
