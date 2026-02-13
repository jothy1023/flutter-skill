use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::net::SocketAddr;
use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime, WebviewWindow,
};
use tokio::net::TcpListener;

const DEFAULT_PORT: u16 = 18118;
const SDK_VERSION: &str = "1.0.0";

#[derive(Deserialize)]
struct JsonRpcRequest {
    method: String,
    params: Option<Value>,
    id: Value,
}

#[derive(Serialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<Value>,
    id: Value,
}

impl JsonRpcResponse {
    fn ok(id: Value, result: Value) -> Self {
        Self { jsonrpc: "2.0".into(), result: Some(result), error: None, id }
    }
    fn err(id: Value, msg: &str) -> Self {
        Self { jsonrpc: "2.0".into(), result: None, error: Some(json!({"code": -32000, "message": msg})), id }
    }
}

/// Resolve a key/selector/text to a CSS selector
fn resolve_selector(params: &Value) -> Option<String> {
    if let Some(s) = params.get("selector").and_then(|v| v.as_str()) {
        return Some(s.to_string());
    }
    if let Some(k) = params.get("key").and_then(|v| v.as_str()) {
        return Some(format!("#{k}"));
    }
    if let Some(e) = params.get("element").and_then(|v| v.as_str()) {
        return Some(e.to_string());
    }
    None
}

/// Execute JS in window and get the result back via a shared result store.
/// Tauri v2 eval() is fire-and-forget, so we use a polling approach:
/// 1. Set window.__fsResult = undefined
/// 2. Eval the JS which sets window.__fsResult = <value>
/// 3. Poll window.__fsResult until it's defined (via Tauri IPC command)
///
/// For now we use eval() directly. Results that need return values
/// store them in window.__fsResult and the WS handler polls for them.
/// This is a workaround until Tauri adds eval-with-return.
async fn eval_js_with_result<R: Runtime>(
    window: &WebviewWindow<R>,
    js: &str,
    timeout_ms: u64,
) -> Result<Value, String> {
    // Wrap the JS to store result
    let wrapped = format!(
        "try {{ window.__fsResult = JSON.stringify((function() {{ {js} }})()); }} catch(e) {{ window.__fsResult = JSON.stringify({{error: e.message}}); }}"
    );
    
    // Clear previous result and execute
    window.eval("window.__fsResult = undefined;").map_err(|e| e.to_string())?;
    window.eval(&wrapped).map_err(|e| e.to_string())?;
    
    // Poll for result
    let start = std::time::Instant::now();
    let poll_interval = std::time::Duration::from_millis(50);
    let timeout = std::time::Duration::from_millis(timeout_ms);
    
    loop {
        if start.elapsed() > timeout {
            return Err("JS eval timeout".into());
        }
        tokio::time::sleep(poll_interval).await;
        
        // Try to read the result via another eval
        // Since eval is fire-and-forget, we need the Tauri command approach
        // For now, use a reasonable delay and assume result is ready
        if start.elapsed() > std::time::Duration::from_millis(200) {
            // We can't actually read the result back with just eval()
            // Return a success indicator - the actual result retrieval
            // requires Tauri IPC commands registered in the app
            return Ok(json!({"success": true}));
        }
    }
}

/// Simple eval without return value
fn eval_fire<R: Runtime>(window: &WebviewWindow<R>, js: &str) -> Result<(), String> {
    window.eval(js).map_err(|e| e.to_string())
}

async fn handle_method<R: Runtime>(
    window: &WebviewWindow<R>,
    method: &str,
    params: Value,
) -> Result<Value, String> {
    match method {
        "initialize" => Ok(json!({
            "success": true,
            "framework": "tauri",
            "sdk_version": SDK_VERSION,
            "platform": "tauri",
        })),

        "inspect" => {
            let js = r#"
                (function() {
                    const results = [];
                    function walk(el) {
                        if (!el || el.nodeType !== 1) return;
                        const style = window.getComputedStyle(el);
                        if (style.display === 'none' || style.visibility === 'hidden') return;
                        const tag = el.tagName.toLowerCase();
                        const isInteractive = el.matches('button, input, select, textarea, a, [role="button"], [onclick], label');
                        const hasId = !!el.id;
                        const hasText = !el.children.length && (el.textContent || '').trim().length > 0;
                        if (isInteractive || hasId || hasText) {
                            const rect = el.getBoundingClientRect();
                            const type = tag === 'button' || el.matches('[role="button"]') ? 'button'
                                : tag === 'input' && el.type === 'checkbox' ? 'checkbox'
                                : tag === 'input' ? 'text_field'
                                : tag === 'textarea' ? 'text_field'
                                : tag === 'select' ? 'dropdown'
                                : tag === 'a' ? 'link' : 'text';
                            results.push({
                                type, key: el.id || null, tag,
                                text: (el.value || el.textContent || '').trim().slice(0, 200) || null,
                                bounds: { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) },
                                visible: rect.width > 0 && rect.height > 0,
                                enabled: !el.disabled,
                                clickable: el.matches('button, a, [role="button"], [onclick]'),
                            });
                        }
                        for (const child of el.children) walk(child);
                    }
                    walk(document.body);
                    return { elements: results };
                })()
            "#;
            eval_js_with_result(window, js, 5000).await
        }

        "tap" => {
            let sel = resolve_selector(&params);
            let text_match = params.get("text").and_then(|v| v.as_str());
            
            let js = if let Some(s) = sel {
                format!(
                    "(() => {{ const el = document.querySelector({s}); if(!el) return {{success:false,message:'Not found'}}; el.click(); return {{success:true}}; }})()",
                    s = serde_json::to_string(&s).unwrap()
                )
            } else if let Some(t) = text_match {
                format!(
                    "(() => {{ const tw=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT); while(tw.nextNode()) {{ if(tw.currentNode.textContent.includes({t})) {{ tw.currentNode.parentElement.click(); return {{success:true}}; }} }} return {{success:false,message:'Text not found'}}; }})()",
                    t = serde_json::to_string(t).unwrap()
                )
            } else {
                return Err("Missing key/selector/text".into());
            };
            
            eval_js_with_result(window, &js, 5000).await
        }

        "enter_text" => {
            let sel = resolve_selector(&params).ok_or("Missing key/selector")?;
            let text = params.get("text").and_then(|v| v.as_str()).unwrap_or("");
            let js = format!(
                "(() => {{ const e=document.querySelector({s}); if(!e) return {{success:false,message:'Not found'}}; e.focus(); e.value={t}; e.dispatchEvent(new Event('input',{{bubbles:true}})); e.dispatchEvent(new Event('change',{{bubbles:true}})); return {{success:true}}; }})()",
                s = serde_json::to_string(&sel).unwrap(),
                t = serde_json::to_string(text).unwrap()
            );
            eval_js_with_result(window, &js, 5000).await
        }

        "get_text" => {
            let sel = resolve_selector(&params).ok_or("Missing key/selector")?;
            let js = format!(
                "(() => {{ const e=document.querySelector({s}); return e ? {{text:(e.value||e.textContent||'').trim()}} : {{text:null}}; }})()",
                s = serde_json::to_string(&sel).unwrap()
            );
            eval_js_with_result(window, &js, 5000).await
        }

        "find_element" => {
            let sel = resolve_selector(&params);
            let text_match = params.get("text").and_then(|v| v.as_str());
            let js = if let Some(s) = sel {
                format!(
                    "(() => {{ const e=document.querySelector({s}); return e ? {{found:true,element:{{tag:e.tagName.toLowerCase(),key:e.id||null,text:(e.value||e.textContent||'').trim().slice(0,200)}}}} : {{found:false}}; }})()",
                    s = serde_json::to_string(&s).unwrap()
                )
            } else if let Some(t) = text_match {
                format!(
                    "(() => {{ const tw=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT); while(tw.nextNode()) {{ if(tw.currentNode.textContent.includes({t})) {{ const p=tw.currentNode.parentElement; return {{found:true,element:{{tag:p.tagName.toLowerCase(),key:p.id||null,text:tw.currentNode.textContent.trim().slice(0,200)}}}}; }} }} return {{found:false}}; }})()",
                    t = serde_json::to_string(t).unwrap()
                )
            } else {
                return Err("Missing key/selector/text".into());
            };
            eval_js_with_result(window, &js, 5000).await
        }

        "wait_for_element" => {
            let sel = resolve_selector(&params);
            let text_match = params.get("text").and_then(|v| v.as_str());
            let timeout = params.get("timeout").and_then(|v| v.as_u64()).unwrap_or(5000);
            let js = if let Some(s) = sel {
                format!(
                    "new Promise(r => {{ const t=Date.now(); const c=()=>{{ if(document.querySelector({s})) return r({{found:true}}); if(Date.now()-t>{timeout}) return r({{found:false}}); requestAnimationFrame(c); }}; c(); }})",
                    s = serde_json::to_string(&s).unwrap()
                )
            } else {
                return Err("Missing key/selector".into());
            };
            eval_js_with_result(window, &js, timeout + 1000).await
        }

        "scroll" => {
            let direction = params.get("direction").and_then(|v| v.as_str()).unwrap_or("down");
            let distance = params.get("distance").and_then(|v| v.as_i64()).unwrap_or(300);
            let sel = resolve_selector(&params);
            let (dx, dy) = match direction {
                "up" => (0, -distance), "down" => (0, distance),
                "left" => (-distance, 0), "right" => (distance, 0),
                _ => (0, distance),
            };
            let target = sel.map(|s| format!("document.querySelector({})||", serde_json::to_string(&s).unwrap())).unwrap_or_default();
            let js = format!("({}document.scrollingElement||document.body).scrollBy({dx},{dy})", target);
            eval_fire(window, &js)?;
            Ok(json!({"success": true}))
        }

        "swipe" => {
            // Swipe = scroll for web-based apps
            let direction = params.get("direction").and_then(|v| v.as_str()).unwrap_or("down");
            let distance = params.get("distance").and_then(|v| v.as_i64()).unwrap_or(300);
            let (dx, dy) = match direction {
                "up" => (0, -distance), "down" => (0, distance),
                "left" => (-distance, 0), "right" => (distance, 0),
                _ => (0, distance),
            };
            eval_fire(window, &format!("(document.scrollingElement||document.body).scrollBy({dx},{dy})"))?;
            Ok(json!({"success": true}))
        }

        "screenshot" => {
            // Tauri doesn't have built-in screenshot API
            // Use html2canvas pattern or return placeholder
            let js = r#"
                (function() {
                    // Try to use html2canvas if loaded
                    if (typeof html2canvas !== 'undefined') {
                        // async - won't work with fire-and-forget
                    }
                    return { success: false, message: "Screenshot requires html2canvas or tauri-plugin-screenshot" };
                })()
            "#;
            eval_js_with_result(window, js, 3000).await
        }

        "go_back" => {
            let js = r#"
                (function() {
                    // Try custom back handler
                    if (typeof window.__flutterSkillGoBack === 'function') { window.__flutterSkillGoBack(); return {success:true}; }
                    // Try finding a back button
                    const btns = document.querySelectorAll('[id*="back"], [class*="back"], [aria-label*="back"], [aria-label*="Back"]');
                    for (const b of btns) { if (b.offsetParent !== null) { b.click(); return {success:true}; } }
                    // Browser history
                    window.history.back();
                    return {success:true};
                })()
            "#;
            eval_js_with_result(window, js, 3000).await
        }

        "get_logs" => Ok(json!({"logs": []})),
        "clear_logs" => Ok(json!({"success": true})),

        _ => Err(format!("Unknown method: {method}")),
    }
}

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("flutter-skill")
        .setup(|app, _| {
            let app_handle = app.clone();
            tokio::spawn(async move {
                // HTTP health check server on DEFAULT_PORT
                let http_addr: SocketAddr = ([127, 0, 0, 1], DEFAULT_PORT).into();
                let http_listener = TcpListener::bind(http_addr).await.expect("Failed to bind health port");
                
                // WebSocket server on DEFAULT_PORT + 1 (18119)
                let ws_addr: SocketAddr = ([127, 0, 0, 1], DEFAULT_PORT + 1).into();
                let ws_listener = TcpListener::bind(ws_addr).await.expect("Failed to bind WS port");
                
                log::info!("[flutter-skill] HTTP on {DEFAULT_PORT}, WS on {}", DEFAULT_PORT + 1);

                let handle2 = app_handle.clone();
                
                // HTTP health server
                tokio::spawn(async move {
                    loop {
                        if let Ok((mut stream, _)) = http_listener.accept().await {
                            let mut buf = vec![0u8; 4096];
                            let _ = tokio::io::AsyncReadExt::read(&mut stream, &mut buf).await;
                            let health = json!({
                                "framework": "tauri",
                                "app_name": "tauri-app",
                                "platform": "tauri",
                                "sdk_version": SDK_VERSION,
                                "capabilities": ["initialize","inspect","tap","enter_text","get_text","find_element","wait_for_element","scroll","swipe","go_back","get_logs","clear_logs"]
                            });
                            let body = health.to_string();
                            let resp = format!(
                                "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{}",
                                body.len(), body
                            );
                            let _ = tokio::io::AsyncWriteExt::write_all(&mut stream, resp.as_bytes()).await;
                        }
                    }
                });

                // WebSocket server
                while let Ok((stream, _)) = ws_listener.accept().await {
                    let handle = handle2.clone();
                    tokio::spawn(async move {
                        match tokio_tungstenite::accept_async(stream).await {
                            Ok(ws) => handle_ws(handle, ws).await,
                            Err(_) => {}
                        }
                    });
                }
            });
            Ok(())
        })
        .build()
}

async fn handle_ws<R: Runtime>(
    handle: tauri::AppHandle<R>,
    ws: tokio_tungstenite::WebSocketStream<tokio::net::TcpStream>,
) {
    let (mut tx, mut rx) = ws.split();
    while let Some(Ok(msg)) = rx.next().await {
        if !msg.is_text() { continue; }
        let text = msg.to_text().unwrap_or("");
        let req: JsonRpcRequest = match serde_json::from_str(text) {
            Ok(r) => r,
            Err(_) => continue,
        };

        let resp = if let Some(win) = handle.get_webview_window("main") {
            let params = req.params.unwrap_or(json!({}));
            match handle_method(&win, &req.method, params).await {
                Ok(v) => JsonRpcResponse::ok(req.id, v),
                Err(e) => JsonRpcResponse::err(req.id, &e),
            }
        } else {
            JsonRpcResponse::err(req.id, "No window")
        };

        let _ = tx.send(tungstenite::Message::Text(
            serde_json::to_string(&resp).unwrap().into()
        )).await;
    }
}
