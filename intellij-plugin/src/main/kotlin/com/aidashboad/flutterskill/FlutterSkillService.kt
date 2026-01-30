package com.aidashboad.flutterskill

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.OSProcessHandler
import com.intellij.execution.process.ProcessAdapter
import com.intellij.execution.process.ProcessEvent
import com.intellij.notification.NotificationAction
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.components.Service
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.util.Key
import java.io.File

@Service(Service.Level.PROJECT)
class FlutterSkillService(private val project: Project) {

    private var mcpProcess: OSProcessHandler? = null
    private val logger = Logger.getInstance(FlutterSkillService::class.java)
    private var initialized = false

    companion object {
        fun getInstance(project: Project): FlutterSkillService {
            return project.getService(FlutterSkillService::class.java)
        }
    }

    /**
     * Initialize the service - called on project open
     */
    fun initialize() {
        if (initialized) return
        initialized = true

        // Only proceed if this is a Flutter project
        if (!isFlutterProject()) {
            return
        }

        logger.info("Flutter project detected, initializing Flutter Skill")

        // Start VM service scanning
        VmServiceScanner.getInstance(project).start()

        // Auto-start MCP server
        startMcpServer()

        // Check if agents need configuration
        promptConfigureAgentsIfNeeded()
    }

    /**
     * Check if the current project is a Flutter project
     */
    fun isFlutterProject(): Boolean {
        val basePath = project.basePath ?: return false
        val pubspecFile = File("$basePath/pubspec.yaml")

        if (!pubspecFile.exists()) {
            return false
        }

        // Check if pubspec contains flutter dependency
        return try {
            val content = pubspecFile.readText()
            content.contains("flutter:") || content.contains("flutter_test:")
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Prompt to configure AI agents if not already configured
     */
    private fun promptConfigureAgentsIfNeeded() {
        val configManager = McpConfigManager.getInstance()
        val unconfiguredAgents = configManager.getUnconfiguredAgents()

        if (unconfiguredAgents.isEmpty()) {
            logger.info("All detected AI agents already have flutter-skill configured")
            return
        }

        val agentNames = unconfiguredAgents.joinToString(", ") { it.displayName }

        NotificationGroupManager.getInstance()
            .getNotificationGroup("Flutter Skill")
            .createNotification(
                "Configure AI Agents",
                "Flutter Skill detected: $agentNames. Configure MCP integration?",
                NotificationType.INFORMATION
            )
            .addAction(NotificationAction.createSimple("Configure") {
                promptConfigureAgents()
            })
            .addAction(NotificationAction.createSimple("Later") {
                // Do nothing
            })
            .notify(project)
    }

    /**
     * Show configuration dialog for AI agents
     */
    fun promptConfigureAgents() {
        val configManager = McpConfigManager.getInstance()
        val results = configManager.configureAllDetectedAgents()

        val successCount = results.count { it.value.success }
        val failCount = results.count { !it.value.success }
        val alreadyConfigured = results.count { it.value.alreadyConfigured }

        val message = buildString {
            if (successCount > 0) {
                append("Configured $successCount agent(s). ")
            }
            if (alreadyConfigured > 0) {
                append("$alreadyConfigured already configured. ")
            }
            if (failCount > 0) {
                val failedAgents = results.filter { !it.value.success }.keys.joinToString(", ") { it.displayName }
                append("Failed: $failedAgents")
            }
            if (successCount > 0) {
                append("\nRestart your AI agents to use Flutter Skill tools.")
            }
        }

        val type = if (failCount > 0) NotificationType.WARNING else NotificationType.INFORMATION

        notify(message, type)
    }

    fun launchApp() {
        val basePath = project.basePath ?: return
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "launch", "."), basePath)
        notify("Flutter app launching with Flutter Skill...")
    }

    fun inspect() {
        val basePath = project.basePath ?: return
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "inspect"), basePath)
    }

    fun screenshot() {
        val basePath = project.basePath ?: return
        val outputPath = "$basePath/screenshot.png"
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "screenshot", outputPath), basePath)
        notify("Screenshot saved to $outputPath")
    }

    fun startMcpServer() {
        if (mcpProcess != null && !mcpProcess!!.isProcessTerminated) {
            logger.info("MCP Server is already running")
            return
        }

        val commandLine = GeneralCommandLine("dart", "pub", "global", "run", "flutter_skill", "server")
        mcpProcess = OSProcessHandler(commandLine)

        mcpProcess?.addProcessListener(object : ProcessAdapter() {
            override fun processTerminated(event: ProcessEvent) {
                logger.info("MCP Server stopped")
            }

            override fun onTextAvailable(event: ProcessEvent, outputType: Key<*>) {
                // Log output if needed
            }
        })

        mcpProcess?.startNotify()
        logger.info("MCP Server started")
    }

    fun stopMcpServer() {
        mcpProcess?.destroyProcess()
        mcpProcess = null
    }

    private fun runCommand(command: String, args: List<String>, workDir: String) {
        val commandLine = GeneralCommandLine(command)
        commandLine.addParameters(args)
        commandLine.workDirectory = java.io.File(workDir)

        val handler = OSProcessHandler(commandLine)
        handler.startNotify()
    }

    private fun notify(message: String, type: NotificationType = NotificationType.INFORMATION) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Flutter Skill")
            .createNotification(message, type)
            .notify(project)
    }
}
