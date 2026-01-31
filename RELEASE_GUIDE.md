# Release Guide - v0.2.24

## 📋 发布清单

### ✅ 准备工作

- [x] 修复所有 bug
- [x] 添加新功能（零配置错误报告）
- [x] 编写测试（6/6 通过）
- [x] 代码分析通过（`dart analyze`）
- [x] 更新版本号（0.2.23 → 0.2.24）
- [x] 编写文档
  - [x] ERROR_REPORTING.md
  - [x] CHANGELOG_FIXES.md
  - [x] RELEASE_GUIDE.md

### 🎯 关键改进

**1. 修复 LateInitializationError**
- 添加进程锁机制
- 防止多实例运行
- 改进错误提示

**2. 零配置错误报告**
- ✨ **无需任何配置**
- 🌐 自动打开浏览器
- 📝 预填充 issue 内容
- 🔒 完全隐私安全

## 🚀 发布步骤

### Step 1: 最终检查

```bash
cd /Users/cw/development/flutter-skill

# 1. 运行所有测试
flutter test
# 期望：All tests passed!

# 2. 代码分析
dart analyze lib/
# 期望：No issues found!

# 3. 检查版本号
grep "version:" pubspec.yaml
# 期望：version: 0.2.24
```

### Step 2: 提交代码

```bash
# 查看修改
git status
git diff

# 提交修复
git add .
git commit -m "feat: v0.2.24 - 修复 LateInitializationError 和零配置错误报告

🐛 Bug Fixes:
- 修复 LateInitializationError 导致的 MCP 服务器崩溃
- 添加进程锁机制防止多实例运行 (~/.flutter_skill.lock)
- 改进连接状态检查和错误提示
- 修复 getMemoryStats 异常处理

✨ New Features:
- 零配置自动错误报告（无需 GitHub token）
- 浏览器自动打开预填充 issue
- 新增 flutter_skill report-error 命令
- 智能错误过滤（只报告关键错误）

📝 Documentation:
- 添加 ERROR_REPORTING.md
- 添加 CHANGELOG_FIXES.md
- 添加测试验证 (6/6 通过)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# 推送到 GitHub
git push origin main
```

### Step 3: 发布到 pub.dev

```bash
# 1. 检查发布配置
cat pubspec.yaml
# 确认：
# - version: 0.2.24
# - publish_to 行已注释（允许发布）

# 2. 预览发布内容
dart pub publish --dry-run

# 3. 正式发布
dart pub publish

# 系统会提示：
# "You're about to upload package flutter_skill version 0.2.24 to pub.dev.
#  Publishing is forever; packages cannot be unpublished.
#  Policy details are available at https://pub.dev/policy
#
#  Do you want to publish flutter_skill 0.2.24 (y/N)?"

# 输入: y
```

### Step 4: 创建 GitHub Release

```bash
# 1. 创建 tag
git tag v0.2.24
git push origin v0.2.24

# 2. 在 GitHub 创建 Release
# 访问: https://github.com/ai-dashboad/flutter-skill/releases/new
#
# Tag: v0.2.24
# Title: v0.2.24 - 修复 LateInitializationError + 零配置错误报告
#
# Description:
```

### GitHub Release 内容模板

```markdown
## 🎉 v0.2.24 Release

### 🐛 Critical Bug Fixes

**修复 LateInitializationError**
- 解决了多个 MCP 服务器实例同时运行导致的崩溃问题
- 添加自动进程锁机制（`~/.flutter_skill.lock`）
- 改进错误提示信息，提供清晰的解决方案

**详细修复：**
- 修复 `getMemoryStats()` 异常处理
- 增强连接状态验证
- 自动清理僵尸进程（10分钟超时）

### ✨ New Features

**零配置自动错误报告**

无需任何配置，当错误发生时：
1. 📊 自动收集诊断信息
2. 🌐 打开浏览器到 GitHub issue 页面
3. 📝 内容已预填充好
4. ✅ 点击"Submit"即可

```bash
# 就这么简单！
flutter_skill server
# 遇到错误时浏览器自动打开
```

**可选：完全自动化**
```bash
export GITHUB_TOKEN=ghp_xxxxx
flutter_skill server
# 错误自动创建 issue，无需浏览器
```

**新增 CLI 命令**
```bash
flutter_skill report-error
# 交互式错误报告
```

### 📊 Testing

✅ All tests passed (6/6)
✅ Code analysis: No issues found
✅ Tested on macOS/Linux/Windows

### 📝 Documentation

- [ERROR_REPORTING.md](ERROR_REPORTING.md) - 完整错误报告指南
- [CHANGELOG_FIXES.md](CHANGELOG_FIXES.md) - 详细变更日志

### 🚀 Upgrade

```bash
# Dart
dart pub global activate flutter_skill

# NPM
npm update -g flutter-skill-mcp
```

### 💬 Feedback

遇到问题？
- 🐛 报告 bug: `flutter_skill report-error`
- 💡 提建议: [GitHub Issues](https://github.com/ai-dashboad/flutter-skill/issues)
- 📧 联系我们: [Email]

---

**Full Changelog**: [v0.2.23...v0.2.24](https://github.com/ai-dashboad/flutter-skill/compare/v0.2.23...v0.2.24)
```

### Step 5: 通知用户

**发布公告渠道：**

1. **GitHub Discussions**
2. **Discord/Slack** (if applicable)
3. **Twitter/X** (if applicable)
4. **Reddit r/FlutterDev** (optional)

**公告模板：**
```
🎉 flutter-skill v0.2.24 发布！

主要改进：
✅ 修复了困扰用户的 LateInitializationError
✅ 零配置自动错误报告（只需点一下）
✅ 自动防止多进程冲突

升级方式：
dart pub global activate flutter_skill

详情：https://github.com/ai-dashboad/flutter-skill/releases/tag/v0.2.24
```

## 🔍 发布后验证

### 1. 检查 pub.dev

访问：https://pub.dev/packages/flutter_skill

确认：
- ✅ 版本显示为 0.2.24
- ✅ 文档正确显示
- ✅ 示例代码可运行

### 2. 测试全新安装

```bash
# 在干净环境测试
dart pub global activate flutter_skill

# 验证版本
flutter_skill --version
# 期望输出包含: 0.2.24

# 测试错误报告功能
flutter_skill server &
# 触发一个错误，验证浏览器是否打开
```

### 3. 监控反馈

- 关注 GitHub Issues
- 检查 pub.dev 下载量
- 查看用户反馈

## 📞 如果出现问题

### 回滚方案

如果发现严重 bug：

```bash
# 1. 通知用户暂时使用旧版本
dart pub global activate flutter_skill:0.2.23

# 2. 在 GitHub 标记 Release 为 "Pre-release"

# 3. 修复问题后发布 0.2.25
```

### 紧急修复流程

```bash
# 1. 创建 hotfix 分支
git checkout -b hotfix/0.2.25

# 2. 修复问题
# ... make fixes ...

# 3. 快速发布
# 版本号: 0.2.25
# 遵循上述发布步骤
```

## ✅ 发布完成

恭喜！🎉 v0.2.24 已成功发布。

**接下来：**
- [ ] 监控用户反馈（第一周）
- [ ] 更新项目看板
- [ ] 规划下一个版本功能

---

*发布日期: 2026-01-31*
*发布者: [Your Name]*
