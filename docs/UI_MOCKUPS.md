# UI Mockups - 多会话界面设计

## 🎨 IntelliJ 插件界面

### 单会话模式（当前）vs 多会话模式（新）

```
┌─────────────────── BEFORE (单会话) ───────────────────┐
│  Flutter Skill                                        │
│  ═══════════════════════════════════════════════════ │
│                                                       │
│  🔗 Connection Status                                 │
│  ┌─────────────────────────────────────────────────┐ │
│  │ ● Connected                                     │ │
│  │ 📱 Flutter App                                  │ │
│  │ ⚡ VM Service: :50000                           │ │
│  │ [Disconnect] [🔄 Refresh]                       │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ⚡ Quick Actions                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ [🔄 Hot Reload] [🔥 Hot Restart]                │ │
│  │ [📸 Screenshot] [🔍 Inspect]                    │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
└───────────────────────────────────────────────────────┘
```

```
┌─────────────────── AFTER (多会话) ────────────────────┐
│  Flutter Skill                                        │
│  ═══════════════════════════════════════════════════ │
│  ┌───────────────────────────────────────────────┐   │
│  │ [● App 1] [● App 2] [○ App 3] [+]            │   │  ← 会话标签栏
│  │   ━━━━━                                      │   │
│  └───────────────────────────────────────────────┘   │
│                                                       │
│  🔗 Connection Status - App 1                         │
│  ┌─────────────────────────────────────────────────┐ │
│  │ ● Connected                                     │ │
│  │ 📱 project1/main_app                            │ │
│  │ 📲 iPhone 15 (iOS 17.0)                        │ │
│  │ ⚡ VM Service: :50001                           │ │
│  │ 🕐 Connected: 2m 34s ago                        │ │
│  │                                                 │ │
│  │ [Disconnect] [🔄 Refresh] [⚙️ Settings]         │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  ⚡ Quick Actions                                     │
│  ┌─────────────────────────────────────────────────┐ │
│  │ [🔄 Hot Reload]  [🔥 Hot Restart]              │ │
│  │ [📸 Screenshot]  [🔍 Inspect]                  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  🎯 Interactive Elements (12)                         │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 🔄 [Refresh]  🔍 [Search...]                    │ │
│  │ ───────────────────────────────────────────     │ │
│  │ ▼ Buttons (5)                                   │ │
│  │   • login_button → [Tap]                        │ │
│  │   • signup_button → [Tap]                       │ │
│  │   • forgot_password → [Tap]                     │ │
│  │ ▼ Text Fields (3)                               │ │
│  │   • email_field → [Enter Text]                  │ │
│  │   • password_field → [Enter Text]               │ │
│  │ ▼ Others (4)                                    │ │
│  │   • app_logo → [Long Press]                     │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
│  📜 Recent Activity                                   │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 18:32:15 Hot reload completed (234ms)           │ │
│  │ 18:31:42 Screenshot saved to clipboard          │ │
│  │ 18:30:18 Tapped on login_button                 │ │
│  └─────────────────────────────────────────────────┘ │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 📱 会话标签详细设计

### 标签状态

```
┌────────── Connected ──────────┐
│ ● App 1  ✕                    │
│   ━━━━━                       │  ← Active (has underline)
└───────────────────────────────┘

┌────────── Connected but Inactive ─┐
│ ● App 2  ✕                        │
│                                   │  ← Inactive (no underline)
└───────────────────────────────────┘

┌────────── Disconnected ───────┐
│ ○ App 3  ✕                    │
│                               │  ← Gray indicator
└───────────────────────────────┘

┌────────── Connecting ─────────┐
│ ⏳ App 4  ✕                    │
│                               │  ← Blue indicator
└───────────────────────────────┘

┌────────── Error ──────────────┐
│ ⚠️ App 5  ✕                    │
│                               │  ← Yellow/Red indicator
└───────────────────────────────┘

┌────────── New Session ────────┐
│ + New                         │
│                               │  ← Create button
└───────────────────────────────┘
```

### 标签悬停效果

```
Hover:
┌────────────────────────────────────────┐
│ ● App 1  ✕                             │
│   ━━━━━                                │
│ ┌──────────────────────────────────┐   │
│ │ 📱 project1/main_app             │   │  ← Tooltip
│ │ 📲 iPhone 15                     │   │
│ │ ⚡ Port: 50001                   │   │
│ │ 🕐 Connected: 2m 34s             │   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
```

### 右键菜单

```
┌────────────────────────────┐
│ ● App 1  ✕                 │
│   ━━━━━                    │
│   └─→ Right Click          │
│       ┌────────────────────┐
│       │ 🔄 Hot Reload      │
│       │ 🔥 Hot Restart     │
│       │ 📸 Screenshot      │
│       │ ────────────────   │
│       │ 📋 Copy VM URI     │
│       │ 🔗 Reconnect       │
│       │ ────────────────   │
│       │ ✏️  Rename Session │
│       │ ⚙️  Settings       │
│       │ ────────────────   │
│       │ ✕ Close Session    │
│       └────────────────────┘
└────────────────────────────┘
```

---

## 🎨 新建会话对话框

```
┌──────────────────────────────────────────────┐
│  Create New Session                      ✕   │
├──────────────────────────────────────────────┤
│                                              │
│  Session Name                                │
│  ┌────────────────────────────────────────┐  │
│  │ My Flutter App                         │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Project Path                                │
│  ┌────────────────────────────────────────┐  │
│  │ /Users/cw/dev/my_app                   │  │
│  └────────────────────────────────────────┘  │
│  [📁 Browse...]                              │
│                                              │
│  Target Device                               │
│  ┌────────────────────────────────────────┐  │
│  │ iPhone 15 (iOS 17.0) ▼                 │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │ 📱 iPhone 15 (iOS 17.0)                │  │
│  │ 📱 iPhone 16 Pro (iOS 17.1)            │  │
│  │ 📱 iPad Pro (iOS 17.0)                 │  │
│  │ 🤖 Pixel 8 (Android 14)                │  │
│  │ 🤖 Samsung Galaxy S23 (Android 14)     │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  VM Service Port                             │
│  ┌────────────────────────────────────────┐  │
│  │ 50001                                  │  │
│  └────────────────────────────────────────┘  │
│  ℹ️  Auto-assigned based on existing sessions │
│                                              │
│  Launch Options                              │
│  ☑ Auto-connect after launch                │
│  ☑ Enable hot reload                         │
│  ☐ Debug mode                                │
│  ☐ Profile mode                              │
│                                              │
│  ──────────────────────────────────────────  │
│                                              │
│              [Cancel]  [Launch & Connect]    │
│                                              │
└──────────────────────────────────────────────┘
```

---

## 🎨 会话管理对话框

```
┌──────────────────────────────────────────────────────┐
│  Manage Sessions                                  ✕  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │ Session Name        Device        Port  Status │ │
│  ├────────────────────────────────────────────────┤ │
│  │ ● App 1             iPhone 15     50001  🟢   │ │ ← Active
│  │ ● App 2             iPhone 16     50002  🟢   │ │
│  │ ○ App 3             iPad Pro      50003  ⚪   │ │
│  │ ⚠️ Feature Branch    Pixel 8       50004  🔴   │ │ ← Error
│  └────────────────────────────────────────────────┘ │
│                                                      │
│  Selected: App 1 (iPhone 15)                         │
│                                                      │
│  Actions:                                            │
│  [🔄 Hot Reload] [🔥 Restart] [📸 Screenshot]       │
│  [🔗 Reconnect]  [✏️ Rename]   [⚙️ Settings]         │
│  [✕ Close]                                           │
│                                                      │
│  Batch Actions:                                      │
│  [Select All] [Select None]                          │
│  [🔄 Reload All] [📸 Screenshot All]                │
│  [✕ Close Selected]                                  │
│                                                      │
│  ───────────────────────────────────────────────     │
│                                         [Close]      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 📊 分屏模式（高级功能）

### 2 列布局

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter Skill                                                 │
│  ════════════════════════════════════════════════════════════ │
│  Layout: [○ Single] [● Side by Side] [○ Grid] [○ Stack]        │
│  ════════════════════════════════════════════════════════════ │
│                                                                │
├───────────────────────────┬────────────────────────────────────┤
│  App 1 (iPhone 15) ●      │  App 2 (iPhone 16 Pro) ●           │
│  ───────────────────      │  ───────────────────               │
│  🔗 Connection            │  🔗 Connection                     │
│  ⚡ VM: :50001            │  ⚡ VM: :50002                      │
│  📱 iOS 17.0              │  📱 iOS 17.1                       │
│                           │                                    │
│  ⚡ Quick Actions         │  ⚡ Quick Actions                  │
│  [🔄] [🔥] [📸] [🔍]      │  [🔄] [🔥] [📸] [🔍]               │
│                           │                                    │
│  🎯 Elements (12)         │  🎯 Elements (8)                   │
│  • login_button           │  • signup_button                   │
│  • email_field            │  • username_field                  │
│  • password_field         │  • email_field                     │
│                           │                                    │
│  📜 Activity              │  📜 Activity                       │
│  Hot reload: 234ms        │  Hot reload: 189ms                 │
│  Screenshot saved         │  Screenshot saved                  │
│                           │                                    │
└───────────────────────────┴────────────────────────────────────┘
```

### 4 宫格布局

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter Skill - Grid View                                     │
│  Layout: [○ Single] [○ Side by Side] [● Grid] [○ Stack]        │
├───────────────────────────┬────────────────────────────────────┤
│  App 1 (iPhone 15) ●      │  App 2 (iPhone 16 Pro) ●           │
│  ⚡ :50001 | [🔄] [📸]     │  ⚡ :50002 | [🔄] [📸]              │
│  🎯 Elements: 12          │  🎯 Elements: 8                    │
├───────────────────────────┼────────────────────────────────────┤
│  App 3 (iPad Pro) ○       │  App 4 (Pixel 8) ●                 │
│  ⚡ :50003 | [🔗 Connect] │  ⚡ :50004 | [🔄] [📸]              │
│  🎯 Elements: --          │  🎯 Elements: 15                   │
└───────────────────────────┴────────────────────────────────────┘
```

---

## 🎨 VSCode 侧边栏视图

```
┌────────────────────────────────────┐
│  FLUTTER SKILL                     │
├────────────────────────────────────┤
│                                    │
│  ▼ SESSIONS (3)                    │
│    ├─ ● App 1 (iPhone 15)          │  ← Active
│    │  ├─ 📱 iOS 17.0               │
│    │  ├─ ⚡ Port: 50001            │
│    │  ├─ 🕐 2m 34s                 │
│    │  └─ [🔄] [🔥] [📸] [✕]        │
│    │                               │
│    ├─ ● App 2 (iPhone 16 Pro)      │
│    │  ├─ 📱 iOS 17.1               │
│    │  ├─ ⚡ Port: 50002            │
│    │  └─ 🕐 5m 12s                 │
│    │                               │
│    └─ ○ App 3 (iPad Pro)           │
│       ├─ 📱 iOS 17.0               │
│       ├─ ⚡ Port: 50003            │
│       └─ [🔗 Connect]              │
│                                    │
│  [+ New Session]                   │
│                                    │
│  ──────────────────────────────    │
│                                    │
│  ▼ QUICK ACTIONS                   │
│    • 🔄 Hot Reload                 │
│    • 🔥 Hot Restart                │
│    • 📸 Screenshot                 │
│    • 🔍 Inspect                    │
│                                    │
│  ──────────────────────────────    │
│                                    │
│  ▼ INTERACTIVE ELEMENTS (12)       │
│    🔄 Refresh | 🔍 Search          │
│    ├─ ▼ Buttons (5)                │
│    │  • login_button                │
│    │  • signup_button               │
│    │                                │
│    ├─ ▼ Text Fields (3)            │
│    │  • email_field                 │
│    │  • password_field              │
│    │                                │
│    └─ ▼ Others (4)                 │
│       • app_logo                    │
│                                    │
│  ──────────────────────────────    │
│                                    │
│  ▼ RECENT ACTIVITY                 │
│    • Hot reload: 234ms             │
│    • Screenshot saved              │
│    • Tapped login_button           │
│                                    │
└────────────────────────────────────┘
```

---

## 🎨 状态栏（VSCode）

```
┌────────────────────────────────────────────────────────────────┐
│  ... | Flutter Skill: App 1 (iPhone 15) ● | ...               │
│                        └─────┬─────────┘                       │
│                              │                                 │
│                         Click to switch                        │
│                              ↓                                 │
│                    ┌─────────────────────┐                     │
│                    │ ● App 1 (iPhone 15) │ ← Active           │
│                    │ ● App 2 (iPhone 16) │                    │
│                    │ ○ App 3 (iPad Pro)  │                    │
│                    │ ─────────────────── │                    │
│                    │ + New Session...    │                    │
│                    └─────────────────────┘                     │
└────────────────────────────────────────────────────────────────┘
```

---

## 🎨 命令面板（VSCode）

```
> Flutter Skill: ...

┌─────────────────────────────────────────────┐
│ Flutter Skill: New Session                  │
│ Flutter Skill: Switch Session               │
│ Flutter Skill: Close Current Session        │
│ Flutter Skill: Manage Sessions              │
│ ─────────────────────────────────────────   │
│ Flutter Skill: Hot Reload (App 1)           │
│ Flutter Skill: Hot Reload All Sessions      │
│ Flutter Skill: Screenshot (App 1)           │
│ Flutter Skill: Screenshot All Sessions      │
│ ─────────────────────────────────────────   │
│ Flutter Skill: Inspect (App 1)              │
│ Flutter Skill: Show Connection Info         │
└─────────────────────────────────────────────┘
```

---

## 📊 对比视图（批量截图）

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter Skill - Screenshot Comparison                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ App 1        │  │ App 2        │  │ App 3        │        │
│  │ iPhone 15    │  │ iPhone 16    │  │ iPad Pro     │        │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤        │
│  │              │  │              │  │              │        │
│  │   [Image]    │  │   [Image]    │  │   [Image]    │        │
│  │              │  │              │  │              │        │
│  │              │  │              │  │              │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│  18:32:45          18:32:46          18:32:47                │
│                                                                │
│  [💾 Save All] [📋 Copy All] [🔄 Retake All] [✕ Close]       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 🎨 设置面板

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter Skill Settings                                    ✕   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ▼ Sessions                                                    │
│     ☑ Auto-reconnect on startup                               │
│     ☑ Remember session layout                                 │
│     ☐ Auto-close session when app exits                       │
│                                                                │
│     Default VM Service Port Range                             │
│     From: [50001]  To: [50100]                                │
│                                                                │
│  ▼ UI Preferences                                              │
│     Layout Mode: [● Tabs] [○ List] [○ Grid]                   │
│                                                                │
│     Tab Position: [● Top] [○ Left] [○ Right]                  │
│                                                                │
│     ☑ Show session status in tab                              │
│     ☑ Show device icon                                        │
│     ☑ Show port number                                        │
│                                                                │
│  ▼ Quick Actions                                               │
│     Default Actions (Drag to reorder):                        │
│     1. ☰ Hot Reload                                           │
│     2. ☰ Hot Restart                                          │
│     3. ☰ Screenshot                                           │
│     4. ☰ Inspect                                              │
│                                                                │
│     ☑ Enable right-click actions on tabs                      │
│                                                                │
│  ▼ Advanced                                                    │
│     ☑ Enable batch operations                                 │
│     ☑ Show performance metrics                                │
│     ☐ Enable debug logging                                    │
│                                                                │
│  ────────────────────────────────────────────────────────      │
│                                    [Cancel]  [Save Settings]   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 🎯 交互流程动画

### 创建新会话流程

```
Step 1: 点击 "+" 按钮
┌─────────────────────┐
│ [App 1] [App 2] [+] │
│         Click here ─┘
└─────────────────────┘

Step 2: 对话框出现
┌──────────────────────┐
│ Create New Session   │
│ [Fill form...]       │
│ [Launch & Connect]   │
└──────────────────────┘

Step 3: 新标签出现（Launching...）
┌──────────────────────────────┐
│ [App 1] [App 2] [⏳ App 3] [+]│
│                 ━━━━━━       │
└──────────────────────────────┘

Step 4: 连接成功（Connected）
┌──────────────────────────────┐
│ [App 1] [App 2] [● App 3] [+]│
│                 ━━━━━━       │
└──────────────────────────────┘
```

### 切换会话流程

```
Before:
┌──────────────────────────────┐
│ [● App 1] [● App 2] [○ App 3]│
│   ━━━━━                      │  ← Active: App 1
└──────────────────────────────┘

Click on App 2:
┌──────────────────────────────┐
│ [● App 1] [● App 2] [○ App 3]│
│             ━━━━━            │  ← Active: App 2
└──────────────────────────────┘

UI Updates:
- Connection Status → App 2 info
- Elements → App 2 elements
- Activity → App 2 activity log
```

---

## 📝 配色方案

### Light Theme
```
Background:     #FFFFFF
Card BG:        #F5F5F5
Border:         #E0E0E0
Text Primary:   #212121
Text Secondary: #757575
Accent:         #2196F3
Success:        #4CAF50
Warning:        #FF9800
Error:          #F44336
```

### Dark Theme
```
Background:     #1E1E1E
Card BG:        #2D2D2D
Border:         #3E3E3E
Text Primary:   #E0E0E0
Text Secondary: #9E9E9E
Accent:         #42A5F5
Success:        #66BB6A
Warning:        #FFA726
Error:          #EF5350
```

---

**UI Version**: v1.0
**Last Updated**: 2026-02-01
**Designers**: Flutter Skill Team
