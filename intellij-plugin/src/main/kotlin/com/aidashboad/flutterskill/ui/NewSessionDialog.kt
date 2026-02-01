package com.aidashboad.flutterskill.ui

import com.aidashboad.flutterskill.SessionManager
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.ComboBox
import com.intellij.openapi.ui.DialogWrapper
import com.intellij.openapi.ui.TextFieldWithBrowseButton
import com.intellij.openapi.ui.ValidationInfo
import com.intellij.ui.components.JBCheckBox
import com.intellij.ui.components.JBLabel
import com.intellij.ui.components.JBTextField
import com.intellij.util.ui.JBUI
import java.awt.Component
import java.awt.Dimension
import java.io.BufferedReader
import java.io.InputStreamReader
import javax.swing.*

/**
 * Device information for dropdown selection
 */
data class DeviceInfo(
    val id: String,
    val name: String,
    val platform: String,
    val platformVersion: String? = null
) {
    override fun toString(): String {
        val icon = when {
            platform.contains("ios", ignoreCase = true) -> "📱"
            platform.contains("android", ignoreCase = true) -> "🤖"
            platform.contains("web", ignoreCase = true) -> "🌐"
            platform.contains("macos", ignoreCase = true) -> "💻"
            platform.contains("windows", ignoreCase = true) -> "🪟"
            platform.contains("linux", ignoreCase = true) -> "🐧"
            else -> "📱"
        }
        return "$icon $name ($platform)"
    }
}

/**
 * Dialog for creating a new Flutter app session
 */
class NewSessionDialog(private val project: Project) : DialogWrapper(project) {
    private val sessionManager = SessionManager.getInstance(project)

    // UI Components
    private val sessionNameField = JBTextField()
    private val projectPathField = TextFieldWithBrowseButton()
    private val deviceComboBox = ComboBox<DeviceInfo>()
    private val portField = JBTextField()
    private val autoConnectCheckbox = JBCheckBox("Auto-connect after launch", true)
    private val hotReloadCheckbox = JBCheckBox("Enable hot reload", true)
    private val debugModeCheckbox = JBCheckBox("Debug mode", false)
    private val profileModeCheckbox = JBCheckBox("Profile mode", false)

    private var availableDevices: List<DeviceInfo> = emptyList()
    private var isLoadingDevices = false

    init {
        title = "Create New Session"
        init()
        loadDevices()
        updatePortField()
    }

    override fun createCenterPanel(): JComponent {
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = JBUI.Borders.empty(10)
        panel.preferredSize = Dimension(500, 400)

        // Session Name
        panel.add(createLabel("Session Name"))
        sessionNameField.text = "My Flutter App"
        sessionNameField.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(sessionNameField)
        panel.add(Box.createVerticalStrut(JBUI.scale(12)))

        // Project Path
        panel.add(createLabel("Project Path"))
        projectPathField.text = project.basePath ?: ""
        projectPathField.addBrowseFolderListener(
            "Select Flutter Project",
            "Choose the root directory of your Flutter project",
            project,
            FileChooserDescriptorFactory.createSingleFolderDescriptor()
        )
        projectPathField.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(projectPathField)
        panel.add(Box.createVerticalStrut(JBUI.scale(12)))

        // Target Device
        panel.add(createLabel("Target Device"))
        deviceComboBox.renderer = object : DefaultListCellRenderer() {
            override fun getListCellRendererComponent(
                list: JList<*>?,
                value: Any?,
                index: Int,
                isSelected: Boolean,
                cellHasFocus: Boolean
            ): Component {
                val component = super.getListCellRendererComponent(list, value, index, isSelected, cellHasFocus)
                if (value is DeviceInfo) {
                    text = value.toString()
                }
                return component
            }
        }
        deviceComboBox.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(deviceComboBox)

        // Refresh devices button
        val refreshPanel = JPanel()
        refreshPanel.layout = BoxLayout(refreshPanel, BoxLayout.X_AXIS)
        refreshPanel.alignmentX = Component.LEFT_ALIGNMENT
        refreshPanel.isOpaque = false

        val refreshButton = JButton("🔄 Refresh Devices")
        refreshButton.addActionListener {
            loadDevices()
        }
        refreshPanel.add(refreshButton)
        refreshPanel.add(Box.createHorizontalGlue())

        panel.add(Box.createVerticalStrut(JBUI.scale(4)))
        panel.add(refreshPanel)
        panel.add(Box.createVerticalStrut(JBUI.scale(12)))

        // VM Service Port
        panel.add(createLabel("VM Service Port"))
        portField.text = getNextAvailablePort().toString()
        portField.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(portField)

        val portHint = JBLabel("ℹ️  Auto-assigned based on existing sessions")
        portHint.foreground = FlutterSkillColors.textSecondary
        portHint.font = portHint.font.deriveFont(10f)
        portHint.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(Box.createVerticalStrut(JBUI.scale(4)))
        panel.add(portHint)
        panel.add(Box.createVerticalStrut(JBUI.scale(12)))

        // Launch Options
        panel.add(createLabel("Launch Options"))
        val optionsPanel = JPanel()
        optionsPanel.layout = BoxLayout(optionsPanel, BoxLayout.Y_AXIS)
        optionsPanel.alignmentX = Component.LEFT_ALIGNMENT
        optionsPanel.isOpaque = false

        autoConnectCheckbox.alignmentX = Component.LEFT_ALIGNMENT
        hotReloadCheckbox.alignmentX = Component.LEFT_ALIGNMENT
        debugModeCheckbox.alignmentX = Component.LEFT_ALIGNMENT
        profileModeCheckbox.alignmentX = Component.LEFT_ALIGNMENT

        // Add mutual exclusion for debug/profile modes
        debugModeCheckbox.addActionListener {
            if (debugModeCheckbox.isSelected) {
                profileModeCheckbox.isSelected = false
            }
        }
        profileModeCheckbox.addActionListener {
            if (profileModeCheckbox.isSelected) {
                debugModeCheckbox.isSelected = false
            }
        }

        optionsPanel.add(autoConnectCheckbox)
        optionsPanel.add(hotReloadCheckbox)
        optionsPanel.add(debugModeCheckbox)
        optionsPanel.add(profileModeCheckbox)

        panel.add(optionsPanel)
        panel.add(Box.createVerticalGlue())

        return panel
    }

    /**
     * Create a label with consistent styling
     */
    private fun createLabel(text: String): JBLabel {
        val label = JBLabel(text)
        label.font = label.font.deriveFont(12f).deriveFont(java.awt.Font.BOLD)
        label.alignmentX = Component.LEFT_ALIGNMENT
        label.border = JBUI.Borders.empty(0, 0, 4, 0)
        return label
    }

    /**
     * Load available Flutter devices
     */
    private fun loadDevices() {
        if (isLoadingDevices) {
            return
        }

        isLoadingDevices = true
        deviceComboBox.removeAllItems()
        deviceComboBox.addItem(DeviceInfo("loading", "Loading devices...", ""))

        Thread {
            try {
                val devices = fetchFlutterDevices()
                SwingUtilities.invokeLater {
                    deviceComboBox.removeAllItems()
                    availableDevices = devices
                    devices.forEach { deviceComboBox.addItem(it) }

                    if (devices.isEmpty()) {
                        deviceComboBox.addItem(DeviceInfo("none", "No devices found", ""))
                    }
                    isLoadingDevices = false
                }
            } catch (e: Exception) {
                SwingUtilities.invokeLater {
                    deviceComboBox.removeAllItems()
                    deviceComboBox.addItem(DeviceInfo("error", "Error loading devices", ""))
                    isLoadingDevices = false
                }
            }
        }.start()
    }

    /**
     * Fetch Flutter devices using 'flutter devices' command
     */
    private fun fetchFlutterDevices(): List<DeviceInfo> {
        val devices = mutableListOf<DeviceInfo>()

        try {
            val process = ProcessBuilder("flutter", "devices", "--machine")
                .redirectErrorStream(false)
                .start()

            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()

            process.waitFor()

            // Parse JSON output
            val gson = com.google.gson.Gson()
            val deviceArray = gson.fromJson(output, com.google.gson.JsonArray::class.java)

            deviceArray?.forEach { element ->
                val deviceObj = element.asJsonObject
                val id = deviceObj.get("id")?.asString ?: return@forEach
                val name = deviceObj.get("name")?.asString ?: "Unknown Device"
                val platform = deviceObj.get("platform")?.asString ?: "unknown"
                val platformVersion = deviceObj.get("platformType")?.asString

                devices.add(DeviceInfo(id, name, platform, platformVersion))
            }
        } catch (e: Exception) {
            // Fallback: parse human-readable output
            try {
                val process = ProcessBuilder("flutter", "devices")
                    .redirectErrorStream(true)
                    .start()

                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val lines = reader.readLines()

                process.waitFor()

                // Parse lines like: "iPhone 16 Pro (mobile) • BCCC538A-... • ios • ..."
                lines.forEach { line ->
                    if (line.contains("•") && !line.contains("No devices") && !line.contains("connected devices")) {
                        val parts = line.split("•").map { it.trim() }
                        if (parts.size >= 3) {
                            val namePart = parts[0].trim()
                            val id = parts[1].trim()
                            val platform = parts[2].trim()

                            // Extract name (remove platform type in parentheses)
                            val name = namePart.replace(Regex("\\s*\\([^)]*\\)\\s*$"), "").trim()

                            devices.add(DeviceInfo(id, name, platform))
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore errors in fallback
            }
        }

        return devices
    }

    /**
     * Get next available port for new session
     */
    private fun getNextAvailablePort(): Int {
        val usedPorts = sessionManager.getAllSessions().map { it.port }.toSet()
        var port = 50001
        while (port in usedPorts && port < 60000) {
            port++
        }
        return port
    }

    /**
     * Update port field with next available port
     */
    private fun updatePortField() {
        portField.text = getNextAvailablePort().toString()
    }

    /**
     * Validate form inputs
     */
    override fun doValidate(): ValidationInfo? {
        // Validate session name
        val sessionName = sessionNameField.text.trim()
        if (sessionName.isEmpty()) {
            return ValidationInfo("Session name cannot be empty", sessionNameField)
        }

        // Check for duplicate session names
        val existingSessions = sessionManager.getAllSessions()
        if (existingSessions.any { it.name.equals(sessionName, ignoreCase = true) }) {
            return ValidationInfo("A session with this name already exists", sessionNameField)
        }

        // Validate project path
        val projectPath = projectPathField.text.trim()
        if (projectPath.isEmpty()) {
            return ValidationInfo("Project path cannot be empty", projectPathField)
        }

        val projectDir = java.io.File(projectPath)
        if (!projectDir.exists() || !projectDir.isDirectory) {
            return ValidationInfo("Project path does not exist or is not a directory", projectPathField)
        }

        // Check if it's a Flutter project (has pubspec.yaml)
        val pubspecFile = java.io.File(projectDir, "pubspec.yaml")
        if (!pubspecFile.exists()) {
            return ValidationInfo("Not a valid Flutter project (pubspec.yaml not found)", projectPathField)
        }

        // Validate device selection
        val selectedDevice = deviceComboBox.selectedItem as? DeviceInfo
        if (selectedDevice == null || selectedDevice.id == "loading" || selectedDevice.id == "none" || selectedDevice.id == "error") {
            return ValidationInfo("Please select a valid device", deviceComboBox)
        }

        // Validate port
        val portText = portField.text.trim()
        val port = portText.toIntOrNull()
        if (port == null || port < 1024 || port > 65535) {
            return ValidationInfo("Port must be a number between 1024 and 65535", portField)
        }

        // Check if port is already in use
        val usedPorts = sessionManager.getAllSessions().map { it.port }.toSet()
        if (port in usedPorts) {
            return ValidationInfo("Port $port is already in use by another session", portField)
        }

        return null
    }

    /**
     * Handle OK button click
     */
    override fun doOKAction() {
        val sessionName = sessionNameField.text.trim()
        val projectPath = projectPathField.text.trim()
        val selectedDevice = deviceComboBox.selectedItem as DeviceInfo
        val port = portField.text.toInt()

        // Create the session
        val session = sessionManager.createSession(
            name = sessionName,
            projectPath = projectPath,
            deviceId = selectedDevice.id,
            port = port
        )

        // TODO: Launch the app if auto-connect is enabled
        // This will be implemented in the next phase when we integrate with flutter run

        super.doOKAction()
    }

    /**
     * Customize OK button text
     */
    override fun getOKAction(): Action {
        val action = super.getOKAction()
        action.putValue(Action.NAME, "Launch & Connect")
        return action
    }
}
