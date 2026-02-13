import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import java.util.concurrent.CopyOnWriteArrayList
import javax.imageio.ImageIO

// ─── App State ───

data class ElementInfo(
    val key: String,
    val type: String,
    val text: String,
    val bounds: Map<String, Int> = mapOf("x" to 0, "y" to 0, "width" to 100, "height" to 30)
)

object AppState {
    var counter = mutableStateOf(0)
    var inputText = mutableStateOf("")
    var checkboxChecked = mutableStateOf(false)
    var currentPage = mutableStateOf("home") // "home" or "detail"
    val logs = CopyOnWriteArrayList<String>()

    fun log(msg: String) {
        logs.add("[${System.currentTimeMillis()}] $msg")
    }

    fun getElements(): List<ElementInfo> {
        return if (currentPage.value == "home") {
            listOf(
                ElementInfo("counter_text", "Text", "Counter: ${counter.value}"),
                ElementInfo("increment_btn", "Button", "Increment"),
                ElementInfo("input_field", "TextField", inputText.value),
                ElementInfo("checkbox", "Checkbox", if (checkboxChecked.value) "checked" else "unchecked"),
                ElementInfo("detail_btn", "Button", "Go to Detail"),
                ElementInfo("list_item_0", "Text", "Item 0"),
                ElementInfo("list_item_1", "Text", "Item 1"),
                ElementInfo("list_item_2", "Text", "Item 2"),
                ElementInfo("list_item_3", "Text", "Item 3"),
                ElementInfo("list_item_4", "Text", "Item 4"),
            )
        } else {
            listOf(
                ElementInfo("detail_title", "Text", "Detail Page"),
                ElementInfo("detail_content", "Text", "This is the detail page"),
                ElementInfo("back_btn", "Button", "Go Back"),
            )
        }
    }

    fun findByKey(key: String): ElementInfo? = getElements().find { it.key == key }

    fun findByText(text: String): ElementInfo? = getElements().find { it.text.contains(text, ignoreCase = true) }

    fun performTap(key: String): Boolean {
        log("tap: $key")
        return when (key) {
            "increment_btn" -> { counter.value++; true }
            "detail_btn" -> { currentPage.value = "detail"; true }
            "back_btn" -> { currentPage.value = "home"; true }
            "checkbox" -> { checkboxChecked.value = !checkboxChecked.value; true }
            else -> false
        }
    }

    fun performTapByText(text: String): Boolean {
        val el = findByText(text) ?: return false
        return performTap(el.key)
    }

    fun enterText(key: String, text: String): Boolean {
        log("enter_text: $key = $text")
        return when (key) {
            "input_field" -> { inputText.value = text; true }
            else -> false
        }
    }

    fun getText(key: String): String? {
        return when (key) {
            "counter_text" -> "Counter: ${counter.value}"
            "input_field" -> inputText.value
            else -> findByKey(key)?.text
        }
    }

    fun goBack(): Boolean {
        if (currentPage.value != "home") {
            currentPage.value = "home"
            log("go_back")
            return true
        }
        return false
    }
}

// ─── Bridge Server ───

val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

@Serializable
data class RpcRequest(
    val jsonrpc: String = "2.0",
    val method: String,
    val params: JsonObject? = null,
    val id: JsonElement
)

@Serializable
data class RpcResponse(
    val jsonrpc: String = "2.0",
    val result: JsonElement? = null,
    val error: JsonElement? = null,
    val id: JsonElement
)

fun handleRpc(req: RpcRequest): JsonElement {
    val p = req.params ?: buildJsonObject {}
    val key = p["key"]?.jsonPrimitive?.contentOrNull
    val text = p["text"]?.jsonPrimitive?.contentOrNull
    val selector = p["selector"]?.jsonPrimitive?.contentOrNull

    AppState.log("rpc: ${req.method}")

    return when (req.method) {
        "health" -> buildJsonObject {
            put("status", "ok")
            put("platform", "kmp")
        }

        "initialize" -> buildJsonObject {
            put("protocol_version", "1.0")
            put("platform", "kmp")
            put("capabilities", buildJsonArray {
                add("inspect"); add("tap"); add("enter_text"); add("screenshot")
                add("scroll"); add("get_text"); add("find_element"); add("wait_for_element")
                add("go_back"); add("swipe"); add("get_logs"); add("clear_logs")
            })
        }

        "inspect" -> buildJsonObject {
            put("elements", buildJsonArray {
                for (el in AppState.getElements()) {
                    add(buildJsonObject {
                        put("key", el.key)
                        put("type", el.type)
                        put("class", el.type)
                        put("text", el.text)
                        put("bounds", buildJsonObject {
                            for ((k, v) in el.bounds) put(k, v)
                        })
                    })
                }
            })
        }

        "tap" -> {
            val success = if (key != null) {
                AppState.performTap(key)
            } else if (text != null) {
                AppState.performTapByText(text)
            } else if (selector != null) {
                AppState.performTap(selector)
            } else false
            buildJsonObject { put("success", success) }
        }

        "enter_text" -> {
            val k = key ?: selector ?: ""
            val t = text ?: p["value"]?.jsonPrimitive?.contentOrNull ?: ""
            buildJsonObject { put("success", AppState.enterText(k, t)) }
        }

        "get_text" -> {
            val k = key ?: selector ?: ""
            val t = AppState.getText(k)
            buildJsonObject {
                if (t != null) put("text", t) else put("error", "not found")
            }
        }

        "find_element" -> {
            val k = key ?: selector
            val found = if (k != null) AppState.findByKey(k) else if (text != null) AppState.findByText(text) else null
            buildJsonObject {
                put("found", found != null)
                if (found != null) {
                    put("key", found.key)
                    put("type", found.type)
                    put("text", found.text)
                }
            }
        }

        "wait_for_element" -> {
            val k = key ?: selector ?: ""
            val found = AppState.findByKey(k)
            buildJsonObject {
                put("found", found != null)
            }
        }

        "scroll" -> buildJsonObject {
            AppState.log("scroll: ${p["direction"]?.jsonPrimitive?.contentOrNull} ${p["distance"]?.jsonPrimitive?.contentOrNull}")
            put("success", true)
        }

        "swipe" -> buildJsonObject {
            AppState.log("swipe: ${p["direction"]?.jsonPrimitive?.contentOrNull} ${p["distance"]?.jsonPrimitive?.contentOrNull}")
            put("success", true)
        }

        "screenshot" -> {
            // Generate a minimal 1x1 PNG as base64
            val img = BufferedImage(100, 100, BufferedImage.TYPE_INT_RGB)
            val g = img.createGraphics()
            g.fillRect(0, 0, 100, 100)
            g.dispose()
            val baos = ByteArrayOutputStream()
            ImageIO.write(img, "png", baos)
            val b64 = java.util.Base64.getEncoder().encodeToString(baos.toByteArray())
            buildJsonObject { put("image", b64); put("format", "png") }
        }

        "go_back" -> buildJsonObject { put("success", AppState.goBack()) }

        "get_logs" -> buildJsonObject {
            put("logs", buildJsonArray { for (l in AppState.logs) add(l) })
        }

        "clear_logs" -> {
            AppState.logs.clear()
            buildJsonObject { put("success", true) }
        }

        else -> buildJsonObject { put("error", "Unknown method: ${req.method}") }
    }
}

fun startBridgeServer(port: Int) {
    embeddedServer(CIO, port = port) {
        install(WebSockets)
        routing {
            // HTTP health endpoint
            get("/.flutter-skill") {
                call.respondText(
                    json.encodeToString(buildJsonObject {
                        put("status", "ok")
                        put("platform", "kmp")
                        put("framework", "compose-desktop")
                        put("sdk_version", "1.0.0")
                        put("capabilities", buildJsonArray {
                            add("inspect"); add("tap"); add("enter_text"); add("screenshot")
                            add("scroll"); add("get_text"); add("find_element"); add("go_back")
                        })
                    }),
                    contentType = ContentType.Application.Json
                )
            }

            // WebSocket bridge
            webSocket("/ws") {
                println("[bridge] Client connected")
                for (frame in incoming) {
                    if (frame is Frame.Text) {
                        val raw = frame.readText()
                        val response = try {
                            val req = json.decodeFromString<RpcRequest>(raw)
                            val result = handleRpc(req)
                            json.encodeToString(RpcResponse(result = result, id = req.id))
                        } catch (e: Exception) {
                            json.encodeToString(RpcResponse(
                                error = buildJsonObject { put("code", -32700); put("message", e.message ?: "error") },
                                id = JsonNull
                            ))
                        }
                        send(Frame.Text(response))
                    }
                }
                println("[bridge] Client disconnected")
            }
        }
    }.start(wait = false)
    println("[flutter-skill-kmp] Bridge server on port $port (HTTP + WS)")
}

// ─── Compose UI ───

@Composable
@Preview
fun HomePage() {
    val counter by AppState.counter
    val inputText by AppState.inputText
    val checked by AppState.checkboxChecked

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("KMP Test App - Home", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(16.dp))

        // Counter
        Text("Counter: $counter")
        Button(onClick = { AppState.counter.value++ }) {
            Text("Increment")
        }
        Spacer(Modifier.height(16.dp))

        // Text input
        OutlinedTextField(
            value = inputText,
            onValueChange = { AppState.inputText.value = it },
            label = { Text("Input") },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(16.dp))

        // Checkbox
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = checked, onCheckedChange = { AppState.checkboxChecked.value = it })
            Text("Toggle me")
        }
        Spacer(Modifier.height(16.dp))

        // Navigation
        Button(onClick = { AppState.currentPage.value = "detail" }) {
            Text("Go to Detail")
        }
        Spacer(Modifier.height(16.dp))

        // List items
        LazyColumn {
            items((0..4).toList()) { i ->
                Text("Item $i", modifier = Modifier.padding(8.dp))
            }
        }
    }
}

@Composable
@Preview
fun DetailPage() {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Detail Page", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(16.dp))
        Text("This is the detail page")
        Spacer(Modifier.height(16.dp))
        Button(onClick = { AppState.currentPage.value = "home" }) {
            Text("Go Back")
        }
    }
}

@Composable
@Preview
fun App() {
    val page by AppState.currentPage
    MaterialTheme {
        when (page) {
            "home" -> HomePage()
            "detail" -> DetailPage()
        }
    }
}

fun main() {
    // Start bridge server first
    startBridgeServer(18118)

    // Launch Compose Desktop window
    application {
        Window(onCloseRequest = ::exitApplication, title = "KMP Test App") {
            App()
        }
    }
}
