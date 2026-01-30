package com.aidashboad.flutterskill

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
                val uri = uriFile.readText().trim()
                if (uri.isEmpty()) {
                    notifyStateChange(ConnectionState.DISCONNECTED)
                    return@launch
                }

                notifyStateChange(ConnectionState.CONNECTING)

                // Extract port from URI (ws://127.0.0.1:PORT/...)
                val portMatch = Regex(":(\\d+)").find(uri)
                val port = portMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0

                val isValid = validateVmService(port)
                if (isValid) {
                    currentService = VmServiceInfo(uri, port)
                    notifyStateChange(ConnectionState.CONNECTED, currentService)
                    logger.info("Connected to VM service at $uri")
                } else {
                    notifyStateChange(ConnectionState.ERROR)
                    logger.warn("Failed to validate VM service at $uri")
                }
            } catch (e: Exception) {
                notifyStateChange(ConnectionState.ERROR)
                logger.error("Error reading URI file: ${e.message}", e)
            }
        }
    }

    /**
     * Start periodic scanning for VM services
     */
    private fun startPeriodicScan() {
        // Initial scan after a delay
        periodicScanJob = scope.launch {
            delay(2000)
            if (currentService == null) {
                scanForVmServices()
            }

            // Periodic scan every 30 seconds
            while (isActive) {
                delay(30000)
                if (currentService == null) {
                    scanForVmServices()
                }
            }
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
     * Disconnect from current service
     */
    fun disconnect() {
        currentService = null
        notifyStateChange(ConnectionState.DISCONNECTED)
    }
}
