package com.aidashboad.flutterskill

import com.aidashboad.flutterskill.model.UIElement
import com.intellij.openapi.Disposable
import com.intellij.openapi.components.Service
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.vfs.VirtualFileManager
import com.intellij.openapi.vfs.newvfs.BulkFileListener
import com.intellij.openapi.vfs.newvfs.events.VFileEvent
import kotlinx.coroutines.*
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    ERROR
}

data class VmServiceInfo(
    val uri: String,
    val port: Int,
    val appName: String? = null
)

data class ScannerOptions(
    val portRangeStart: Int = 50000,
    val portRangeEnd: Int = 50100,
    val scanTimeout: Int = 500,
    val maxConcurrent: Int = 10
)

@Service(Service.Level.PROJECT)
class VmServiceScanner(private val project: Project) : Disposable {
    private val logger = Logger.getInstance(VmServiceScanner::class.java)
    private val options = ScannerOptions()
    private var scanJob: Job? = null
    private var periodicScanJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var currentService: VmServiceInfo? = null
    private var vmClient: VmServiceClient? = null
    private val stateChangeListeners = mutableListOf<(ConnectionState, VmServiceInfo?) -> Unit>()
    private var currentState: ConnectionState = ConnectionState.DISCONNECTED

    companion object {
        @JvmStatic
        fun getInstance(project: Project): VmServiceScanner {
            return project.getService(VmServiceScanner::class.java)
        }
    }

    /**
     * Start watching for VM services
     */
    fun start() {
        watchUriFile()
        startPeriodicScan()
    }

    /**
     * Stop watching for VM services
     */
    fun stop() {
        scanJob?.cancel()
        periodicScanJob?.cancel()
    }

    override fun dispose() {
        stop()
        scope.cancel()
    }

    /**
     * Register a callback for connection state changes
     */
    fun onStateChange(callback: (ConnectionState, VmServiceInfo?) -> Unit) {
        stateChangeListeners.add(callback)
        // Immediately notify of current state
        callback(currentState, currentService)
    }

    /**
     * Get the currently connected service
     */
    fun getCurrentService(): VmServiceInfo? = currentService

    /**
     * Get the current connection state
     */
    fun getState(): ConnectionState = currentState

    /**
     * Watch the .flutter_skill_uri file for changes
     */
    private fun watchUriFile() {
        val basePath = project.basePath ?: return
        val uriFilePath = "$basePath/.flutter_skill_uri"

        // Check file on startup
        checkUriFile(uriFilePath)

        // Watch for file changes
        project.messageBus.connect().subscribe(VirtualFileManager.VFS_CHANGES, object : BulkFileListener {
            override fun after(events: List<VFileEvent>) {
                for (event in events) {
                    if (event.path.endsWith(".flutter_skill_uri")) {
                        checkUriFile(uriFilePath)
                        break
                    }
                }
            }
        })
    }

    /**
     * Check the URI file and validate the connection
     */
    private fun checkUriFile(uriFilePath: String) {
        val uriFile = File(uriFilePath)
        if (!uriFile.exists()) {
            if (currentService != null) {
                currentService = null
                notifyStateChange(ConnectionState.DISCONNECTED)
            }
            return
        }

        scope.launch {
            try {
                var uri = uriFile.readText().trim()
                if (uri.isEmpty()) {
                    notifyStateChange(ConnectionState.DISCONNECTED)
                    return@launch
                }

                // Ensure URI ends with /ws for VM Service WebSocket endpoint
                if (!uri.endsWith("/ws")) {
                    uri = if (uri.endsWith("/")) {
                        "${uri}ws"
                    } else {
                        "$uri/ws"
                    }
                }

                notifyStateChange(ConnectionState.CONNECTING)

                // Extract port from URI (ws://127.0.0.1:PORT/...)
                val portMatch = Regex(":(\\d+)").find(uri)
                val port = portMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0

                val isValid = validateVmService(port)
                if (isValid) {
                    // Create and connect VM Service client
                    try {
                        vmClient = VmServiceClient(uri)
                        vmClient?.connect()

                        currentService = VmServiceInfo(uri, port)
                        notifyStateChange(ConnectionState.CONNECTED, currentService)
                        logger.info("Connected to VM service at $uri")
                    } catch (e: Exception) {
                        logger.error("Failed to connect VM client: ${e.message}", e)
                        // Clean up stale URI file
                        uriFile.delete()
                        notifyStateChange(ConnectionState.DISCONNECTED)
                    }
                } else {
                    logger.warn("Failed to validate VM service at $uri - cleaning up stale URI file")
                    // Clean up stale URI file
                    uriFile.delete()
                    notifyStateChange(ConnectionState.DISCONNECTED)
                }
            } catch (e: Exception) {
                logger.error("Error reading URI file: ${e.message}", e)
                // Clean up invalid URI file
                try {
                    uriFile.delete()
                } catch (deleteError: Exception) {
                    logger.error("Failed to delete invalid URI file: ${deleteError.message}")
                }
                notifyStateChange(ConnectionState.DISCONNECTED)
            }
        }
    }

    /**
     * Start periodic scanning for VM services
     */
    private fun startPeriodicScan() {
        val basePath = project.basePath ?: return
        val uriFilePath = "$basePath/.flutter_skill_uri"

        // Initial scan after a delay
        periodicScanJob = scope.launch {
            delay(2000)
            if (currentService == null) {
                // 1. Try to find Flutter process and extract URI
                val processUri = findFlutterProcessUri()
                if (processUri != null) {
                    connectToUri(processUri)
                }
                // 2. Check URI file
                if (currentService == null) {
                    checkUriFile(uriFilePath)
                }
                // 3. Scan ports as last resort
                if (currentService == null) {
                    scanForVmServices()
                }
            }

            // Periodic scan every 5 seconds (faster for better UX)
            while (isActive) {
                delay(5000)
                if (currentService == null) {
                    // 1. Try to find Flutter process and extract URI
                    val processUri = findFlutterProcessUri()
                    if (processUri != null) {
                        connectToUri(processUri)
                    }
                    // 2. Check URI file
                    if (currentService == null) {
                        checkUriFile(uriFilePath)
                    }
                    // 3. Scan ports as last resort
                    if (currentService == null) {
                        scanForVmServices()
                    }
                }
            }
        }
    }

    /**
     * Find Flutter process and extract VM Service URI
     * This automatically detects Flutter running in any terminal/IDE
     */
    private suspend fun findFlutterProcessUri(): String? = withContext(Dispatchers.IO) {
        try {
            // Execute ps command to find Flutter processes
            val process = Runtime.getRuntime().exec(arrayOf(
                "sh", "-c",
                "ps aux | grep -E 'dart.*development-service.*vm-service-uri' | grep -v grep"
            ))

            val output = process.inputStream.bufferedReader().readText()
            process.waitFor()

            if (output.isNotBlank()) {
                // Extract HTTP URI from process arguments
                val httpUriPattern = Regex("--vm-service-uri=(http://[0-9.:]+/[a-zA-Z0-9_=-]+/?)")
                val match = httpUriPattern.find(output)

                if (match != null) {
                    val httpUri = match.groupValues[1]

                    // Convert to WebSocket URI
                    var wsUri = httpUri.replace("http://", "ws://")

                    // Ensure trailing slash is present if auth token exists
                    if (wsUri.contains("=") && !wsUri.endsWith("/")) {
                        wsUri = "$wsUri/"
                    }

                    // Append /ws for VM Service WebSocket endpoint
                    val finalUri = if (wsUri.endsWith("/")) {
                        "${wsUri}ws"
                    } else {
                        "$wsUri/ws"
                    }

                    logger.info("Auto-detected Flutter VM Service: $finalUri")

                    // Optionally save to file for other tools
                    val basePath = project.basePath
                    if (basePath != null) {
                        try {
                            File("$basePath/.flutter_skill_uri").writeText(finalUri)
                        } catch (e: Exception) {
                            // Ignore file write errors
                        }
                    }

                    return@withContext finalUri
                } else {
                    logger.warn("DEBUG: Regex did not match. Output was: $output")
                }
            } else {
                logger.info("DEBUG: ps command returned empty output")
            }
            null
        } catch (e: Exception) {
            logger.error("Failed to scan Flutter processes: ${e.message}", e)
            null
        }
    }

    /**
     * Scan port range for VM services
     */
    suspend fun scanForVmServices(): List<VmServiceInfo> {
        val services = mutableListOf<VmServiceInfo>()
        logger.info("Scanning ports ${options.portRangeStart}-${options.portRangeEnd}...")

        val ports = (options.portRangeStart..options.portRangeEnd).toList()

        // Process ports in batches
        ports.chunked(options.maxConcurrent).forEach { batch ->
            val results = batch.map { port ->
                scope.async { checkPort(port) }
            }.awaitAll()

            services.addAll(results.filterNotNull())
        }

        if (services.isNotEmpty()) {
            logger.info("Found ${services.size} VM service(s)")
            // Use the first found service if not already connected
            if (currentService == null) {
                currentService = services.first()
                notifyStateChange(ConnectionState.CONNECTED, currentService)
            }
        }

        return services
    }

    /**
     * Check if a port has a VM service
     */
    private suspend fun checkPort(port: Int): VmServiceInfo? = withContext(Dispatchers.IO) {
        try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", port), options.scanTimeout)
                // Port is open, assume it's a VM service
                VmServiceInfo("ws://127.0.0.1:$port/ws", port)
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Validate that a port has a valid VM service
     */
    private suspend fun validateVmService(port: Int): Boolean = withContext(Dispatchers.IO) {
        try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", port), options.scanTimeout)
                true
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Notify all callbacks of state change
     */
    private fun notifyStateChange(state: ConnectionState, service: VmServiceInfo? = null) {
        currentState = state
        for (callback in stateChangeListeners) {
            callback(state, service)
        }
    }

    /**
     * Force a manual scan
     */
    fun rescan() {
        logger.info("Manual scan triggered")
        scope.launch {
            scanForVmServices()
        }
    }

    /**
     * Connect to a specific VM Service URI directly (no file, no scan)
     * This is the preferred method for auto-detection from process output
     */
    fun connectToUri(uri: String) {
        logger.info("Direct connection requested to: $uri")

        scope.launch {
            try {
                notifyStateChange(ConnectionState.CONNECTING)

                // Extract port from URI
                val portMatch = Regex(":(\\d+)").find(uri)
                val port = portMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0

                // Create and connect VM Service client
                vmClient?.disconnect()
                vmClient = VmServiceClient(uri)
                vmClient?.connect()

                currentService = VmServiceInfo(uri, port)
                notifyStateChange(ConnectionState.CONNECTED, currentService)
                logger.info("Successfully connected to VM service at $uri")
            } catch (e: Exception) {
                logger.error("Failed to connect to VM service: ${e.message}", e)
                notifyStateChange(ConnectionState.ERROR)
            }
        }
    }

    /**
     * Disconnect from current service
     */
    fun disconnect() {
        vmClient?.disconnect()
        vmClient = null
        currentService = null
        notifyStateChange(ConnectionState.DISCONNECTED)
    }

    /**
     * Get interactive elements from running Flutter app
     */
    suspend fun getInteractiveElements(): List<UIElement> {
        if (vmClient == null) {
            logger.warn("No VM client available")
            return emptyList()
        }

        return try {
            logger.info("Getting interactive elements...")
            val elements: List<UIElement> = vmClient?.getInteractiveElements() ?: emptyList()
            logger.info("Found ${elements.size} interactive elements")
            elements
        } catch (e: Exception) {
            logger.error("Error getting elements: ${e.message}", e)
            emptyList()
        }
    }

    /**
     * Perform tap action on an element
     */
    suspend fun performTap(key: String?, text: String? = null): VmServiceResponse {
        if (vmClient == null) {
            return VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "NO_CONNECTION", message = "No Flutter app connected")
            )
        }

        return try {
            logger.info("Performing tap on ${key ?: text}...")
            val result = vmClient!!.tap(key, text)

            if (!result.success) {
                logger.warn("Tap failed: ${result.error?.message}")
            } else {
                logger.info("Tap successful on ${key ?: text}")
            }

            result
        } catch (e: Exception) {
            logger.error("Error performing tap: ${e.message}", e)
            VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "TAP_FAILED", message = e.message ?: "Failed to tap element")
            )
        }
    }

    /**
     * Perform text input on an element
     */
    suspend fun performEnterText(key: String, text: String): VmServiceResponse {
        if (vmClient == null) {
            return VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "NO_CONNECTION", message = "No Flutter app connected")
            )
        }

        return try {
            logger.info("Entering text in $key: $text")
            val result = vmClient!!.enterText(key, text)

            if (!result.success) {
                logger.warn("Enter text failed: ${result.error?.message}")
            } else {
                logger.info("Text entered successfully in $key")
            }

            result
        } catch (e: Exception) {
            logger.error("Error entering text: ${e.message}", e)
            VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "INPUT_FAILED", message = e.message ?: "Failed to enter text")
            )
        }
    }

    /**
     * Take screenshot of running Flutter app
     */
    suspend fun takeScreenshot(quality: Double = 1.0, maxWidth: Int? = null): String? {
        if (vmClient == null) {
            logger.warn("No VM client available")
            return null
        }

        return try {
            logger.info("Taking screenshot...")
            val base64Image = vmClient?.screenshot(quality, maxWidth)

            if (base64Image != null) {
                logger.info("Screenshot captured successfully")
            } else {
                logger.warn("Screenshot returned null")
            }

            base64Image
        } catch (e: Exception) {
            logger.error("Error taking screenshot: ${e.message}", e)
            null
        }
    }

    /**
     * Take screenshot of a specific element
     */
    suspend fun takeElementScreenshot(key: String): String? {
        if (vmClient == null) {
            logger.warn("No VM client available")
            return null
        }

        return try {
            logger.info("Taking element screenshot for $key...")
            val base64Image = vmClient?.screenshotElement(key)

            if (base64Image != null) {
                logger.info("Element screenshot captured successfully")
            } else {
                logger.warn("Element screenshot returned null")
            }

            base64Image
        } catch (e: Exception) {
            logger.error("Error taking element screenshot: ${e.message}", e)
            null
        }
    }

    /**
     * Trigger hot reload
     */
    suspend fun performHotReload(): VmServiceResponse {
        if (vmClient == null) {
            return VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "NO_CONNECTION", message = "No Flutter app connected")
            )
        }

        return try {
            logger.info("Triggering hot reload...")
            val result = vmClient!!.hotReload()

            if (!result.success) {
                logger.warn("Hot reload failed: ${result.error?.message}")
            } else {
                logger.info("Hot reload completed successfully")
            }

            result
        } catch (e: Exception) {
            logger.error("Error performing hot reload: ${e.message}", e)
            VmServiceResponse(
                success = false,
                error = VmServiceResponse.ErrorInfo(code = "HOT_RELOAD_FAILED", message = e.message ?: "Failed to hot reload")
            )
        }
    }

    /**
     * Get widget tree
     */
    suspend fun getWidgetTree(maxDepth: Int = 10): com.google.gson.JsonObject? {
        if (vmClient == null) {
            logger.warn("No VM client available")
            return null
        }

        return try {
            logger.info("Getting widget tree...")
            vmClient?.getWidgetTree(maxDepth)
        } catch (e: Exception) {
            logger.error("Error getting widget tree: ${e.message}", e)
            null
        }
    }

    /**
     * Get VM Service client (for advanced usage)
     */
    fun getClient(): VmServiceClient? = vmClient
}
