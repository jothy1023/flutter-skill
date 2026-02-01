# UI 多会话支持设计

## 🎯 设计目标

支持在 IntelliJ/VSCode 插件 UI 中管理和切换多个 Flutter 应用会话。

---

## 📊 当前 UI 架构

### IntelliJ 插件（Card-based）

```
┌─────────────────────────────────────┐
│  Flutter Skill Tool Window          │
├─────────────────────────────────────┤
│                                     │
│  🔗 Connection Status Card          │
│  ┌──────────────────────────────┐  │
│  │ ● Connected                  │  │
│  │ 📱 Flutter App               │  │
│  │ ⚡ VM Service: :50000        │  │
│  │ [Disconnect] [🔄 Refresh]    │  │
│  └──────────────────────────────┘  │
│                                     │
│  ⚡ Quick Actions Card             │
│  ┌──────────────────────────────┐  │
│  │ [🔄 Hot Reload]              │  │
│  │ [🔥 Hot Restart]             │  │
│  │ [📸 Screenshot]              │  │
│  └──────────────────────────────┘  │
│                                     │
│  🎯 Interactive Elements Card      │
│  ┌──────────────────────────────┐  │
│  │ [Refresh Elements]           │  │
│  │ • button_login               │  │
│  │ • text_field_email          │  │
│  └──────────────────────────────┘  │
│                                     │
│  📜 Recent Activity Card           │
│  ┌──────────────────────────────┐  │
│  │ Hot reload completed         │  │
│  │ Screenshot saved             │  │
│  └──────────────────────────────┘  │
│                                     │
│  🤖 AI Editors Card                │
│  ┌──────────────────────────────┐  │
│  │ [Open in Cursor]             │  │
│  │ [Open in Windsurf]           │  │
│  └──────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

**当前限制**:
- ❌ 只显示一个连接
- ❌ 无法切换会话
- ❌ 无法并排对比

---

## 🎨 多会话 UI 设计

### 方案 1: 标签页模式（推荐 ⭐）

```
┌──────────────────────────────────────────────────────┐
│  Flutter Skill Tool Window                           │
├──────────────────────────────────────────────────────┤
│  [App 1 ●] [App 2 ●] [App 3 ○] [+]  ← Session Tabs  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  🔗 Connection Status                                │
│  ┌─────────────────────────────────────────────┐    │
│  │ ● Connected                                 │    │
│  │ 📱 project1/main_app (iPhone 15)            │    │
│  │ ⚡ VM Service: :50001                       │    │
│  │ 🕐 Connected: 2m ago                        │    │
│  │ [Disconnect] [🔄 Refresh] [⚙️ Settings]     │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  ⚡ Quick Actions                                    │
│  ┌─────────────────────────────────────────────┐    │
│  │ [🔄 Hot Reload] [🔥 Hot Restart]            │    │
│  │ [📸 Screenshot] [🔍 Inspect]                │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  🎯 Interactive Elements (12 found)                  │
│  ┌─────────────────────────────────────────────┐    │
│  │ 🔄 [Refresh] | 🔍 [Search...]               │    │
│  │ ────────────────────────────────────────    │    │
│  │ ▼ Buttons (5)                               │    │
│  │   • login_button → [Tap]                    │    │
│  │   • signup_button → [Tap]                   │    │
│  │ ▼ Text Fields (3)                           │    │
│  │   • email_field → [Enter Text]              │    │
│  │ ▼ Others (4)                                │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**标签页设计细节**:

```
Session Tab 布局:
┌─────────────────────────────┐
│ App 1 ●  ✕                  │ ← Active tab
└─────────────────────────────┘
  │        │  └─ Close button
  │        └─ Status indicator
  └─ Session name

Status indicators:
● Green  = Connected
○ Gray   = Disconnected
⚠️ Yellow = Error
⏳ Blue   = Connecting
```

**优势**:
- ✅ 清晰的会话切换
- ✅ 一次查看一个会话（避免混乱）
- ✅ 熟悉的交互模式（类似浏览器标签）
- ✅ 易于实现

---

### 方案 2: 下拉选择器模式

```
┌──────────────────────────────────────────────────────┐
│  Flutter Skill Tool Window                           │
├──────────────────────────────────────────────────────┤
│                                                      │
│  Active Session: [App 1 (iPhone 15) ▼] [+] [⚙️]     │
│                   ┌─────────────────────────────┐    │
│                   │ ● App 1 (iPhone 15)         │ ← Selected
│                   │ ● App 2 (iPhone 16 Pro)     │
│                   │ ○ App 3 (iPad Pro)          │
│                   │ ──────────────────────      │
│                   │ + New Session...            │
│                   └─────────────────────────────┘    │
│                                                      │
│  🔗 Connection Status                                │
│  ┌─────────────────────────────────────────────┐    │
│  │ ● Connected                                 │    │
│  │ 📱 project1/main_app (iPhone 15)            │    │
│  │ ⚡ VM Service: :50001                       │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  ... (其他 Cards)                                    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**优势**:
- ✅ 节省垂直空间
- ✅ 清晰的主从关系
- ✅ 易于添加过滤/搜索

**劣势**:
- ⚠️ 需要点击才能看到所有会话
- ⚠️ 不够直观

---

### 方案 3: 分屏模式（高级）

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter Skill Tool Window                                   │
├──────────────────────────────────────────────────────────────┤
│  Layout: [● Single] [○ Side by Side] [○ Grid] [○ All]        │
├───────────────────────────┬──────────────────────────────────┤
│  App 1 (iPhone 15) ●      │  App 2 (iPhone 16 Pro) ●         │
│  ┌────────────────────┐   │  ┌────────────────────┐          │
│  │ ⚡ VM: :50001      │   │  │ ⚡ VM: :50002      │          │
│  │ [🔄] [🔥] [📸]     │   │  │ [🔄] [🔥] [📸]     │          │
│  └────────────────────┘   │  └────────────────────┘          │
│                           │                                  │
│  🎯 Elements (12)         │  🎯 Elements (8)                 │
│  • login_button           │  • signup_button                 │
│  • email_field            │  • username_field                │
│                           │                                  │
└───────────────────────────┴──────────────────────────────────┘
```

**优势**:
- ✅ 真正的并排对比
- ✅ 同时查看多个会话
- ✅ 适合 A/B 测试

**劣势**:
- ⚠️ 占用大量屏幕空间
- ⚠️ 实现复杂
- ⚠️ 只适合大屏幕

---

## 🎨 推荐实现：方案 1（标签页模式）

### 新增组件：SessionTabBar

```kotlin
/**
 * Session tabs for managing multiple Flutter app connections
 */
class SessionTabBar(private val project: Project) : JPanel() {
    private val sessions = mutableListOf<Session>()
    private var activeSession: Session? = null

    data class Session(
        val id: String,
        val name: String,
        val deviceName: String,
        val port: Int,
        var state: ConnectionState,
        val vmServiceUri: String
    )

    init {
        layout = FlowLayout(FlowLayout.LEFT, 4, 0)
        border = JBUI.Borders.empty(8, 12)

        // Add default session
        addSession(
            Session(
                id = "default",
                name = "App 1",
                deviceName = "iPhone 15",
                port = 50001,
                state = ConnectionState.DISCONNECTED,
                vmServiceUri = ""
            )
        )

        // Add "new session" button
        add(createNewSessionButton())
    }

    fun addSession(session: Session) {
        sessions.add(session)
        val tab = createSessionTab(session)
        add(tab, componentCount - 1) // Insert before "+" button
        revalidate()
        repaint()
    }

    private fun createSessionTab(session: Session): JComponent {
        val panel = JPanel(FlowLayout(FlowLayout.LEFT, 4, 2))
        panel.border = JBUI.Borders.empty(4, 8)

        // Session name label
        val label = JLabel("${session.name} (${session.deviceName})")
        label.font = label.font.deriveFont(11f)

        // Status indicator
        val indicator = JLabel(getStatusIcon(session.state))

        // Close button
        val closeBtn = JButton("✕")
        closeBtn.font = closeBtn.font.deriveFont(9f)
        closeBtn.isOpaque = false
        closeBtn.isBorderPainted = false
        closeBtn.addActionListener {
            removeSession(session)
        }

        // Click to activate
        panel.addMouseListener(object : MouseAdapter() {
            override fun mouseClicked(e: MouseEvent) {
                activateSession(session)
            }
        })

        // Styling
        if (session == activeSession) {
            panel.background = FlutterSkillColors.cardBackground
            panel.border = BorderFactory.createCompoundBorder(
                JBUI.Borders.customLine(FlutterSkillColors.accent, 2),
                JBUI.Borders.empty(2, 6)
            )
        } else {
            panel.background = FlutterSkillColors.backgroundSecondary
        }

        panel.add(indicator)
        panel.add(label)
        panel.add(closeBtn)

        return panel
    }

    private fun getStatusIcon(state: ConnectionState): String {
        return when (state) {
            ConnectionState.CONNECTED -> "●"      // Green
            ConnectionState.DISCONNECTED -> "○"   // Gray
            ConnectionState.CONNECTING -> "⏳"    // Blue
            ConnectionState.ERROR -> "⚠️"         // Yellow
        }
    }

    fun activateSession(session: Session) {
        activeSession = session
        // Notify listeners
        onSessionChange?.invoke(session)
        refresh()
    }

    var onSessionChange: ((Session) -> Unit)? = null
}
```

---

### 更新 ConnectionStatusCard

```kotlin
class ConnectionStatusCard(project: Project) : CardComponent(project) {
    private var currentSession: SessionTabBar.Session? = null

    fun updateSession(session: SessionTabBar.Session) {
        currentSession = session
        refresh()
    }

    override fun buildContent() {
        addTitle("Connection Status", "🔗")

        if (currentSession == null) {
            // No session
            val label = JLabel("No session selected")
            label.foreground = FlutterSkillColors.textSecondary
            panel.add(label)
            return
        }

        // Session info
        val nameLabel = createInfoRow("📱", currentSession!!.name)
        val deviceLabel = createInfoRow("📱", currentSession!!.deviceName)
        val portLabel = createInfoRow("⚡", "VM Service: :${currentSession!!.port}")

        panel.add(nameLabel)
        panel.add(deviceLabel)
        panel.add(portLabel)

        // Actions
        val actionsPanel = JPanel(FlowLayout(FlowLayout.LEFT))
        actionsPanel.add(createButton("🔄 Hot Reload") {
            performHotReload(currentSession!!)
        })
        actionsPanel.add(createButton("📸 Screenshot") {
            takeScreenshot(currentSession!!)
        })
        panel.add(actionsPanel)
    }
}
```

---

### 更新主窗口

```kotlin
class FlutterSkillPanel(private val project: Project) : JPanel(BorderLayout()) {
    private val sessionTabBar: SessionTabBar
    private val connectionCard: ConnectionStatusCard
    // ... other cards

    init {
        // Top: Session tabs
        sessionTabBar = SessionTabBar(project)
        sessionTabBar.onSessionChange = { session ->
            switchToSession(session)
        }
        add(sessionTabBar, BorderLayout.NORTH)

        // Center: Cards
        val mainPanel = JPanel()
        mainPanel.layout = BoxLayout(mainPanel, BoxLayout.Y_AXIS)

        connectionCard = ConnectionStatusCard(project)
        quickActionsCard = QuickActionsCard(project)
        elementsCard = InteractiveElementsCard(project)

        mainPanel.add(connectionCard.component)
        mainPanel.add(quickActionsCard.component)
        mainPanel.add(elementsCard.component)

        val scrollPane = JBScrollPane(mainPanel)
        add(scrollPane, BorderLayout.CENTER)
    }

    private fun switchToSession(session: SessionTabBar.Session) {
        // Update all cards with new session
        connectionCard.updateSession(session)
        quickActionsCard.updateSession(session)
        elementsCard.updateSession(session)

        // Reconnect to this session's VM Service
        VmServiceScanner.getInstance(project).connectTo(session.vmServiceUri)
    }
}
```

---

## 🎨 VSCode 扩展 UI

### Sidebar View（侧边栏）

```
FLUTTER SKILL
─────────────────────────
  Sessions
  ├─ ● App 1 (iPhone 15)      ← Active
  │  └─ Port: 50001
  ├─ ● App 2 (iPhone 16 Pro)
  │  └─ Port: 50002
  └─ ○ App 3 (iPad Pro)
     └─ Port: 50003 (disconnected)

  [+ New Session]
─────────────────────────
  Active: App 1
  ├─ 🔄 Hot Reload
  ├─ 🔥 Hot Restart
  ├─ 📸 Screenshot
  └─ 🔍 Inspect
─────────────────────────
  Interactive Elements (12)
  ├─ login_button
  ├─ email_field
  └─ signup_button
─────────────────────────
```

**实现**（package.json）:

```json
{
  "contributes": {
    "viewsContainers": {
      "activitybar": [{
        "id": "flutter-skill",
        "title": "Flutter Skill",
        "icon": "resources/icon.svg"
      }]
    },
    "views": {
      "flutter-skill": [
        {
          "id": "flutter-skill.sessions",
          "name": "Sessions"
        },
        {
          "id": "flutter-skill.quick-actions",
          "name": "Quick Actions"
        },
        {
          "id": "flutter-skill.elements",
          "name": "Interactive Elements"
        }
      ]
    }
  }
}
```

**TreeView（sessions.ts）**:

```typescript
export class SessionsProvider implements vscode.TreeDataProvider<SessionItem> {
  private sessions: Session[] = [];
  private activeSession: Session | null = null;

  getTreeItem(element: SessionItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: SessionItem): SessionItem[] {
    if (!element) {
      // Root level: show all sessions
      return this.sessions.map(s => new SessionItem(s, this.activeSession === s));
    }

    // Child level: show session details
    return [
      new SessionDetailItem(`Port: ${element.session.port}`),
      new SessionDetailItem(`Device: ${element.session.deviceName}`)
    ];
  }

  addSession(session: Session) {
    this.sessions.push(session);
    this._onDidChangeTreeData.fire();
  }

  activateSession(session: Session) {
    this.activeSession = session;
    this._onDidChangeTreeData.fire();

    // Notify extension
    vscode.commands.executeCommand('flutter-skill.switchSession', session.id);
  }
}

class SessionItem extends vscode.TreeItem {
  constructor(
    public readonly session: Session,
    public readonly isActive: boolean
  ) {
    super(
      `${session.name} (${session.deviceName})`,
      vscode.TreeItemCollapsibleState.Collapsed
    );

    this.iconPath = new vscode.ThemeIcon(
      session.state === 'connected' ? 'circle-filled' : 'circle-outline',
      new vscode.ThemeColor(
        session.state === 'connected' ? 'testing.iconPassed' : 'testing.iconQueued'
      )
    );

    this.contextValue = 'session';
    this.command = {
      command: 'flutter-skill.activateSession',
      title: 'Activate Session',
      arguments: [session]
    };

    if (isActive) {
      this.description = '(active)';
    }
  }
}
```

---

## 🔄 会话管理逻辑

### 会话生命周期

```
1. Create Session
   ↓
2. Launch App (auto or manual)
   ↓
3. Connect to VM Service
   ↓
4. Update UI (status, elements, etc.)
   ↓
5. Switch between sessions
   ↓
6. Close Session
```

### 会话状态机

```kotlin
enum class SessionState {
    CREATED,        // Session created, not yet launched
    LAUNCHING,      // App is starting
    CONNECTED,      // Connected to VM Service
    DISCONNECTED,   // Lost connection
    ERROR          // Error state
}

class SessionManager {
    private val sessions = mutableMapOf<String, Session>()
    private var activeSessionId: String? = null

    fun createSession(
        name: String,
        projectPath: String,
        deviceId: String,
        port: Int
    ): Session {
        val id = UUID.randomUUID().toString()
        val session = Session(
            id = id,
            name = name,
            projectPath = projectPath,
            deviceId = deviceId,
            port = port,
            state = SessionState.CREATED
        )
        sessions[id] = session
        return session
    }

    suspend fun launchSession(sessionId: String) {
        val session = sessions[sessionId] ?: return
        session.state = SessionState.LAUNCHING

        // Launch Flutter app
        val process = startFlutterApp(
            session.projectPath,
            session.deviceId,
            session.port
        )

        // Wait for VM Service URI
        val uri = waitForVmServiceUri(process)

        // Connect
        val client = FlutterSkillClient(uri)
        client.connect()

        session.client = client
        session.state = SessionState.CONNECTED
    }

    fun switchToSession(sessionId: String) {
        activeSessionId = sessionId
        notifyListeners(sessions[sessionId])
    }

    fun closeSession(sessionId: String) {
        val session = sessions.remove(sessionId) ?: return
        session.client?.disconnect()
        session.process?.destroy()
    }
}
```

---

## 📊 数据同步

### 每个会话独立管理

```kotlin
class Session(
    val id: String,
    val name: String,
    val projectPath: String,
    val deviceId: String,
    val port: Int,
    var state: SessionState
) {
    // 独立的 VM Service 客户端
    var client: FlutterSkillClient? = null

    // 独立的应用进程
    var process: Process? = null

    // 独立的元素列表
    var interactiveElements: List<Element> = emptyList()

    // 独立的活动日志
    var activityLog: List<ActivityItem> = emptyList()

    // 最后更新时间
    var lastUpdate: Instant = Instant.now()
}
```

### UI 更新策略

```kotlin
// 只更新当前激活的会话
fun updateActiveSession() {
    val session = sessionManager.getActiveSession() ?: return

    // Fetch data for active session only
    val elements = session.client?.getInteractiveElements()
    session.interactiveElements = elements ?: emptyList()

    // Update UI
    elementsCard.updateElements(session.interactiveElements)
}

// 后台更新所有会话状态（心跳）
fun backgroundUpdateAllSessions() {
    sessionManager.getAllSessions().forEach { session ->
        GlobalScope.launch {
            val isAlive = session.client?.ping() ?: false
            if (!isAlive) {
                session.state = SessionState.DISCONNECTED
                notifySessionStateChange(session)
            }
        }
    }
}
```

---

## 🎨 UI 交互流程

### 创建新会话

```
用户操作:
1. 点击 "+ New Session" 按钮
2. 弹出对话框
   ┌────────────────────────────────┐
   │  Create New Session            │
   ├────────────────────────────────┤
   │  Session Name: [App 1_____]    │
   │  Project Path: [Browse...]     │
   │  Device: [iPhone 15 ▼]         │
   │  Port: [50001_____]            │
   │                                │
   │  [Cancel]  [Launch & Connect]  │
   └────────────────────────────────┘
3. 填写信息，点击 "Launch & Connect"
4. 新标签页出现，显示 "⏳ Launching..."
5. 应用启动后，状态变为 "● Connected"
```

### 切换会话

```
用户操作:
1. 点击不同的会话标签
2. UI 立即切换到该会话
3. 所有 Cards 更新为该会话的数据
   - Connection Status → 显示该会话的设备信息
   - Quick Actions → 操作该会话的应用
   - Interactive Elements → 显示该会话的元素列表
```

### 关闭会话

```
用户操作:
1. 点击标签页上的 "✕" 按钮
2. 弹出确认对话框
   ┌────────────────────────────────┐
   │  Close Session?                │
   ├────────────────────────────────┤
   │  This will disconnect from     │
   │  "App 1 (iPhone 15)" and stop  │
   │  the Flutter app.              │
   │                                │
   │  [Cancel]  [Close Session]     │
   └────────────────────────────────┘
3. 确认后，标签页消失
4. 如果是最后一个会话，显示欢迎屏幕
```

---

## 🚀 实现计划

### Phase 1: 基础架构（2 周）
- [x] SessionManager 实现
- [x] Session 数据模型
- [ ] 多连接管理（Map<String, FlutterSkillClient>）

### Phase 2: IntelliJ UI（3 周）
- [ ] SessionTabBar 组件
- [ ] 更新所有 Cards 支持会话参数
- [ ] 新建/切换/关闭会话交互

### Phase 3: VSCode UI（2 周）
- [ ] TreeView 会话列表
- [ ] 会话切换命令
- [ ] 状态栏显示当前会话

### Phase 4: 高级功能（3 周）
- [ ] 会话持久化（重启 IDE 恢复会话）
- [ ] 批量操作（同时截图/热重载）
- [ ] 分屏模式（并排查看）

---

## 📝 配置文件

### 会话配置（.flutter_skill_sessions.json）

```json
{
  "sessions": [
    {
      "id": "session-1",
      "name": "Main App",
      "projectPath": "/path/to/project1",
      "deviceId": "iPhone 15",
      "port": 50001,
      "autoReconnect": true,
      "lastConnected": "2026-02-01T18:30:00Z"
    },
    {
      "id": "session-2",
      "name": "Feature Branch",
      "projectPath": "/path/to/project2",
      "deviceId": "iPhone 16 Pro",
      "port": 50002,
      "autoReconnect": false,
      "lastConnected": "2026-02-01T17:45:00Z"
    }
  ],
  "activeSessionId": "session-1"
}
```

---

## 🎯 总结

### 推荐方案

**IntelliJ**: 标签页模式（方案 1）
- ✅ 直观易用
- ✅ 易于实现
- ✅ 符合 IDE 习惯

**VSCode**: TreeView 列表
- ✅ 节省空间
- ✅ 符合 VSCode 设计规范
- ✅ 支持层级结构

### 核心价值

1. **并行测试**: 同时运行多个应用
2. **快速切换**: 一键切换不同会话
3. **独立管理**: 每个会话独立的状态和数据
4. **持久化**: 重启 IDE 后恢复会话

---

**设计版本**: v1.0
**创建时间**: 2026-02-01
**负责人**: Flutter Skill Team
