//! High-level browser operations built on CDP.
//! Each operation minimizes CDP round-trips by pushing logic into the browser.

use crate::cdp::CdpConnection;
use base64::Engine;
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;

/// Navigate to a URL. Returns the final URL.
pub async fn navigate(conn: &Arc<CdpConnection>, url: &str) -> Result<Value, String> {
    // Check current URL first — skip if already there
    let current = conn
        .call(
            "Runtime.evaluate",
            json!({"expression": "location.href", "returnByValue": true}),
        )
        .await?;
    let current_url = current["value"].as_str().unwrap_or("");
    if current_url == url {
        return Ok(json!({"navigated": false, "url": url, "reason": "already_there"}));
    }

    conn.call("Page.navigate", json!({"url": url})).await?;

    // Wait for load
    let mut rx = conn.on_event("Page.loadEventFired");
    tokio::select! {
        _ = rx.recv() => {},
        _ = tokio::time::sleep(std::time::Duration::from_secs(10)) => {},
    }
    conn.remove_listeners("Page.loadEventFired");

    Ok(json!({"navigated": true, "url": url}))
}

/// Evaluate JS expression. Returns the result value.
pub async fn evaluate(conn: &Arc<CdpConnection>, expression: &str) -> Result<Value, String> {
    let result = conn
        .call(
            "Runtime.evaluate",
            json!({
                "expression": expression,
                "returnByValue": true,
                "awaitPromise": true,
            }),
        )
        .await?;

    if let Some(exc) = result.get("exceptionDetails") {
        return Err(format!("JS exception: {exc}"));
    }

    Ok(result
        .get("result")
        .and_then(|r| r.get("value"))
        .cloned()
        .unwrap_or(Value::Null))
}

/// Take a screenshot. Returns base64 JPEG data.
pub async fn screenshot(conn: &Arc<CdpConnection>, quality: u8) -> Result<String, String> {
    let result = conn
        .call(
            "Page.captureScreenshot",
            json!({
                "format": "jpeg",
                "quality": quality,
                "optimizeForSpeed": true,
            }),
        )
        .await?;

    result["data"]
        .as_str()
        .map(|s| s.to_string())
        .ok_or_else(|| "No screenshot data".into())
}

/// Get page text snapshot (accessibility-like).
pub async fn snapshot(conn: &Arc<CdpConnection>) -> Result<String, String> {
    let js = r#"
        (() => {
            const lines = [];
            const walk = (node, depth) => {
                if (node.nodeType === 3) {
                    const t = node.textContent.trim();
                    if (t) lines.push(t);
                    return;
                }
                if (node.nodeType !== 1) return;
                const el = node;
                const tag = el.tagName.toLowerCase();
                const style = getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden') return;
                
                if (tag === 'input' || tag === 'select' || tag === 'textarea') {
                    const type = el.type || tag;
                    const val = el.value || el.placeholder || '';
                    lines.push(`[${type}] ${val}`);
                    return;
                }
                if (tag === 'a') lines.push('[link] ');
                if (tag === 'button') lines.push('[button] ');
                if (tag === 'img') { lines.push(`[img] ${el.alt || ''}`); return; }
                
                for (const child of el.childNodes) walk(child, depth + 1);
            };
            walk(document.body, 0);
            return lines.join('\n');
        })()
    "#;
    evaluate(conn, js).await.map(|v| v.as_str().unwrap_or("").to_string())
}

/// Tap/click at coordinates.
pub async fn tap(conn: &Arc<CdpConnection>, x: f64, y: f64) -> Result<Value, String> {
    // Pipeline: mouseMoved + mousePressed + mouseReleased
    let results = conn
        .pipeline(vec![
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mouseMoved", "x": x, "y": y}),
            ),
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1}),
            ),
            (
                "Input.dispatchMouseEvent",
                json!({"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1}),
            ),
        ])
        .await;

    for r in &results {
        if let Err(e) = r {
            return Err(e.clone());
        }
    }

    Ok(json!({"success": true, "x": x, "y": y}))
}

/// Tap an element by text content. Finds element, gets coordinates, clicks.
/// Prioritizes: buttons/links > shortest match > visible elements.
/// Done in 2 CDP calls: 1 evaluate (find + coords) + 1 pipeline (mouse events).
pub async fn tap_text(conn: &Arc<CdpConnection>, text: &str) -> Result<Value, String> {
    let escaped = text.replace('\\', "\\\\").replace('\'', "\\'");
    let js = format!(
        r#"
        (() => {{
            const text = '{escaped}';
            // Strategy 1: Find button/link/submit with matching text (most reliable)
            const clickables = document.querySelectorAll('button, a, [role=button], input[type=submit]');
            for (const el of clickables) {{
                const t = el.textContent.trim();
                if (t === text || t.includes(text)) {{
                    const r = el.getBoundingClientRect();
                    if (r.width > 0 && r.height > 0 && r.y >= 0 && r.y < window.innerHeight) {{
                        return {{x: r.x + r.width/2, y: r.y + r.height/2, tag: el.tagName, matched: 'clickable'}};
                    }}
                }}
            }}
            // Strategy 2: TreeWalker — find shortest text match
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let best = null;
            let bestLen = Infinity;
            while (walker.nextNode()) {{
                const n = walker.currentNode;
                const t = n.textContent.trim();
                if (t.includes(text) && t.length < bestLen) {{
                    const el = n.parentElement;
                    const r = el.getBoundingClientRect();
                    if (r.width > 0 && r.height > 0) {{
                        best = el;
                        bestLen = t.length;
                    }}
                }}
            }}
            if (!best) return null;
            const r = best.getBoundingClientRect();
            return {{x: r.x + r.width/2, y: r.y + r.height/2, tag: best.tagName, matched: 'text'}};
        }})()
    "#
    );

    let coords = evaluate(conn, &js).await?;
    if coords.is_null() {
        return Err(format!("Element with text '{text}' not found or not visible"));
    }

    let x = coords["x"].as_f64().ok_or("No x coordinate")?;
    let y = coords["y"].as_f64().ok_or("No y coordinate")?;
    tap(conn, x, y).await
}

/// Upload a file to an input element — universal approach.
///
/// Strategy 1 (most reliable, ~200ms): File chooser interception via CDP mouse click.
///   Produces fully native File objects that work with ALL frameworks and APIs.
///   Enables Page.setInterceptFileChooserDialog, clicks input/label, handles chooser.
///
/// Strategy 2 (fallback, ~200ms): File chooser via JS el.click().
///   For sites where CDP mouse events don't trigger the file dialog.
///
/// Strategy 3 (fast fallback, ~5ms): CDP setFileInputFiles + framework event dispatch.
///   Fast but produces File objects that may not work with all framework internals
///   (e.g., some async validators, FormData uploads via fetch, or custom FileReader chains).
pub async fn upload_file(
    conn: &Arc<CdpConnection>,
    selector: &str,
    file_path: &Path,
) -> Result<Value, String> {
    let path_str = file_path.to_str().ok_or("Invalid file path")?;
    let escaped_sel = selector.replace('\\', "\\\\").replace('\'', "\\'");

    // ── Strategy 1: File chooser interception (JS .click() on unhidden input) ──
    // Most reliable: unhide hidden inputs, JS click triggers file chooser, Chrome intercepts it.
    match upload_file_chooser(conn, selector, file_path, true).await {
        Ok(v) => return Ok(v),
        Err(_) => {}
    }

    // ── Strategy 2: File chooser interception (CDP mouse click on label/parent) ──
    match upload_file_chooser(conn, selector, file_path, false).await {
        Ok(v) => return Ok(v),
        Err(_) => {}
    }

    // ── Strategy 3: setFileInputFiles + framework event dispatch ──
    if set_files_cdp(conn, selector, file_path).await.is_ok() {
        let verify_js = format!(
            r#"(() => {{
                function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
                const el = dq('{escaped_sel}', document);
                if (!el || !el.files || el.files.length === 0) return {{ok:false}};
                return {{ok:true, count:el.files.length, name:el.files[0].name}};
            }})()"#
        );
        let verify = evaluate(conn, &verify_js).await.unwrap_or(json!({"ok":false}));

        if verify["ok"].as_bool() == Some(true) {
            // Dispatch full framework-aware event chain
            let dispatch_js = format!(
                r#"(() => {{
                    function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
                    const el = dq('{escaped_sel}', document);
                    if (!el) return 'not_found';

                    // Native events
                    el.dispatchEvent(new Event('input', {{bubbles:true, cancelable:true}}));
                    el.dispatchEvent(new Event('change', {{bubbles:true, cancelable:true}}));

                    // React 17+ (__reactProps)
                    const rp = Object.keys(el).find(k => k.startsWith('__reactProps'));
                    if (rp && el[rp] && typeof el[rp].onChange === 'function') {{
                        try {{ el[rp].onChange({{target:el, currentTarget:el, type:'change'}}); }} catch(e) {{}}
                        return 'react';
                    }}
                    // React 16 (__reactEvents)
                    const re = Object.keys(el).find(k => k.startsWith('__reactEvents'));
                    if (re && el[re] && typeof el[re].onChange === 'function') {{
                        try {{ el[re].onChange({{target:el, currentTarget:el, type:'change'}}); }} catch(e) {{}}
                        return 'react16';
                    }}
                    // Vue 2
                    if (el.__vue_) {{
                        try {{ el.__vue__.$emit('change', el.files); el.__vue__.$emit('input', el.files); }} catch(e) {{}}
                        return 'vue2';
                    }}
                    // Vue 3
                    if (el.__vueParentComponent) {{
                        try {{ el.dispatchEvent(new Event('update:modelValue', {{bubbles:true}})); }} catch(e) {{}}
                        return 'vue3';
                    }}
                    return 'native';
                }})()"#
            );
            let method = evaluate(conn, &dispatch_js).await.unwrap_or(json!("unknown"));

            return Ok(json!({
                "success": true,
                "files": verify["count"],
                "method": method,
                "path": path_str,
                "strategy": 3,
            }));
        }
    }

    Err("All upload strategies failed".into())
}

/// Set files via CDP DOM.setFileInputFiles (supplements DataTransfer).
async fn set_files_cdp(
    conn: &Arc<CdpConnection>,
    selector: &str,
    file_path: &Path,
) -> Result<(), String> {
    let path_str = file_path.to_str().ok_or("Invalid path")?;
    let doc = conn.call("DOM.getDocument", json!({})).await?;
    let root_id = doc["root"]["nodeId"].as_u64().unwrap_or(0);

    // Try direct querySelector first
    let qr = conn
        .call(
            "DOM.querySelector",
            json!({"nodeId": root_id, "selector": selector}),
        )
        .await;
    if let Ok(ref result) = qr {
        if let Some(node_id) = result["nodeId"].as_u64() {
            if node_id != 0 {
                let _ = conn
                    .call(
                        "DOM.setFileInputFiles",
                        json!({"nodeId": node_id, "files": [path_str]}),
                    )
                    .await;
                return Ok(());
            }
        }
    }

    // Shadow DOM fallback: find via JS and get backendNodeId
    let escaped = selector.replace('\\', "\\\\").replace('\'', "\\'");
    let js_result = evaluate(
        conn,
        &format!(
            r#"(() => {{
                function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
                const el = dq('{escaped}', document);
                return el ? true : false;
            }})()"#
        ),
    )
    .await;

    if js_result == Ok(serde_json::Value::Bool(true)) {
        // Use Runtime to get the element as a remote object, then resolve to node
        let obj = conn
            .call(
                "Runtime.evaluate",
                json!({
                    "expression": format!(
                        "(() => {{ function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }} return dq('{escaped}', document); }})()"
                    ),
                    "returnByValue": false,
                }),
            )
            .await?;

        if let Some(object_id) = obj["result"]["objectId"].as_str() {
            let node = conn
                .call(
                    "DOM.describeNode",
                    json!({"objectId": object_id}),
                )
                .await?;
            if let Some(backend_id) = node["node"]["backendNodeId"].as_u64() {
                let _ = conn
                    .call(
                        "DOM.setFileInputFiles",
                        json!({"backendNodeId": backend_id, "files": [path_str]}),
                    )
                    .await;
            }
        }
    }

    Ok(())
}

/// File chooser interception: enable intercept, click to trigger dialog, handle with file path.
/// `use_js_click`: true = use el.click() (JS), false = use CDP Input.dispatchMouseEvent.
async fn upload_file_chooser(
    conn: &Arc<CdpConnection>,
    selector: &str,
    file_path: &Path,
    use_js_click: bool,
) -> Result<Value, String> {
    let path_str = file_path.to_str().ok_or("Invalid path")?;
    let escaped_sel = selector.replace('\\', "\\\\").replace('\'', "\\'");

    // Enable file chooser interception
    conn.call(
        "Page.setInterceptFileChooserDialog",
        json!({"enabled": true}),
    )
    .await?;

    // Subscribe to event BEFORE triggering click
    let mut rx = conn.on_event("Page.fileChooserOpened");

    if use_js_click {
        // Strategy: JS click — temporarily make hidden inputs visible for click
        let _ = evaluate(
            conn,
            &format!(
                r#"(() => {{
                    function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
                    const el = dq('{escaped_sel}', document);
                    if (!el) return 'not_found';
                    const cs = getComputedStyle(el);
                    const wasHidden = cs.display === 'none' || cs.visibility === 'hidden' || el.offsetWidth === 0;
                    if (wasHidden) {{
                        el.style.cssText = 'display:block !important; visibility:visible !important; position:fixed !important; top:-9999px !important; left:-9999px !important; width:1px !important; height:1px !important; opacity:0.01 !important;';
                    }}
                    el.click();
                    if (wasHidden) {{
                        setTimeout(() => {{ el.style.cssText = ''; }}, 100);
                    }}
                    return wasHidden ? 'clicked_unhidden' : 'clicked';
                }})()"#
            ),
        )
        .await;
    } else {
        // Strategy: CDP mouse events
        // Make the file input itself clickable: unhide, position on screen, highest z-index
        let _ = evaluate(
            conn,
            &format!(
                r#"(() => {{
                    function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
                    const el = dq('{escaped_sel}', document);
                    if (!el) return;
                    el.dataset.fsOrig = el.getAttribute('style') || '';
                    el.style.cssText = 'display:block !important; visibility:visible !important; position:fixed !important; top:10px !important; left:10px !important; width:50px !important; height:50px !important; opacity:0.01 !important; z-index:2147483647 !important; pointer-events:all !important;';
                }})()"#
            ),
        ).await;
        let coords = evaluate(
            conn,
            &format!(
                r#"
            (() => {{
                function dq(sel, root) {{
                    let el = root.querySelector(sel);
                    if (el) return el;
                    for (const n of root.querySelectorAll('*')) {{
                        if (n.shadowRoot) {{ el = dq(sel, n.shadowRoot); if (el) return el; }}
                    }}
                    return null;
                }}
                const input = dq('{escaped_sel}', document);
                if (!input) return null;

                // Priority 0: the input itself (we may have unhidden it above)
                const ir = input.getBoundingClientRect();
                if (ir.width > 0 && ir.height > 0)
                    return {{x: ir.x + ir.width/2, y: ir.y + ir.height/2}};

                // Priority 1: wrapping <label> with visible children (masks, overlays)
                let label = input.closest('label');
                if (!label) {{
                    let p = input.parentElement;
                    while (p) {{ if (p.tagName === 'LABEL') {{ label = p; break; }} p = p.parentElement; }}
                }}
                if (label) {{
                    const children = label.querySelectorAll('*');
                    let best = null, bestArea = 0;
                    for (const child of children) {{
                        const r = child.getBoundingClientRect();
                        const area = r.width * r.height;
                        if (area > bestArea && r.width > 10 && r.height > 10 && r.y >= 0) {{
                            best = {{x: r.x + r.width/2, y: r.y + r.height/2}}; bestArea = area;
                        }}
                    }}
                    if (best) return best;
                    const lr = label.getBoundingClientRect();
                    if (lr.width > 0 && lr.height > 0)
                        return {{x: lr.x + lr.width/2, y: lr.y + lr.height/2}};
                }}

                // Priority 2: visible parent
                let target = input.parentElement;
                while (target && (target.offsetWidth === 0 || target.offsetHeight === 0))
                    target = target.parentElement;
                if (!target) return null;
                const r = target.getBoundingClientRect();
                return {{x: r.x + r.width/2, y: r.y + r.height/2}};
            }})()
            "#
            ),
        )
        .await?;

        if coords.is_null() {
            conn.remove_listeners("Page.fileChooserOpened");
            let _ = conn.call("Page.setInterceptFileChooserDialog", json!({"enabled": false})).await;
            return Err("No visible click target for file input".into());
        }

        let x = coords["x"].as_f64().unwrap();
        let y = coords["y"].as_f64().unwrap();

        // Hover first (reveals hidden overlays on some sites like Zhihu)
        let _ = conn.call("Input.dispatchMouseEvent", json!({"type": "mouseMoved", "x": x, "y": y})).await;
        tokio::time::sleep(std::time::Duration::from_millis(200)).await;

        // Click the (possibly unhidden) input directly
        let _ = conn.pipeline(vec![
            ("Input.dispatchMouseEvent", json!({"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1})),
            ("Input.dispatchMouseEvent", json!({"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1})),
        ]).await;
    }

    // Wait for file chooser event (2s timeout)
    let event = tokio::select! {
        Some(e) = rx.recv() => {
            eprintln!("[upload] fileChooserOpened received (js_click={})", use_js_click);
            Some(e)
        },
        _ = tokio::time::sleep(std::time::Duration::from_secs(2)) => {
            eprintln!("[upload] fileChooser timeout (js_click={})", use_js_click);
            None
        },
    };

    // Restore original style if we modified the input
    let _ = evaluate(conn, &format!(
        r#"(() => {{
            function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
            const el = dq('{escaped_sel}', document);
            if (el && el.dataset.fsOrig !== undefined) {{
                el.setAttribute('style', el.dataset.fsOrig);
                delete el.dataset.fsOrig;
            }}
        }})()"#
    )).await;

    conn.remove_listeners("Page.fileChooserOpened");

    if event.is_none() {
        let _ = conn.call("Page.setInterceptFileChooserDialog", json!({"enabled": false})).await;
        return Err(format!("File chooser not triggered (js_click={})", use_js_click));
    }

    let evt = event.unwrap();

    // Handle file chooser: set files. Try multiple methods for reliability.
    let mut files_set = false;

    // Method 1: Use backendNodeId from event
    if let Some(backend_id) = evt.get("backendNodeId").and_then(|v| v.as_u64()) {
        if conn.call("DOM.setFileInputFiles", json!({"backendNodeId": backend_id, "files": [path_str]})).await.is_ok() {
            files_set = true;
        }
    }

    // Method 2: Resolve element via Runtime.evaluate + DOM.describeNode (most reliable)
    if !files_set {
        let obj = conn.call("Runtime.evaluate", json!({
            "expression": format!(
                "(() => {{ function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }} return dq('{}', document); }})()",
                escaped_sel
            ),
            "returnByValue": false,
        })).await;
        if let Ok(ref result) = obj {
            if let Some(object_id) = result["result"]["objectId"].as_str() {
                if let Ok(node) = conn.call("DOM.describeNode", json!({"objectId": object_id})).await {
                    if let Some(bid) = node["node"]["backendNodeId"].as_u64() {
                        let _ = conn.call("DOM.setFileInputFiles", json!({"backendNodeId": bid, "files": [path_str]})).await;
                        files_set = true;
                    }
                }
            }
        }
    }

    // Method 3: DOM.getDocument + querySelector
    if !files_set {
        let _ = set_files_cdp(conn, selector, file_path).await;
    }

    let _ = conn.call("Page.setInterceptFileChooserDialog", json!({"enabled": false})).await;

    // After file chooser, dispatch events for framework compatibility
    let _ = evaluate(conn, &format!(
        r#"(() => {{
            function dq(s,r) {{ let e=r.querySelector(s); if(e) return e; for(const n of r.querySelectorAll('*')) {{ if(n.shadowRoot) {{ e=dq(s,n.shadowRoot); if(e) return e; }} }} return null; }}
            const el = dq('{escaped_sel}', document);
            if (!el) return;
            el.dispatchEvent(new Event('input', {{bubbles:true}}));
            el.dispatchEvent(new Event('change', {{bubbles:true}}));
            const rp = Object.keys(el).find(k => k.startsWith('__reactProps'));
            if (rp && el[rp] && typeof el[rp].onChange === 'function')
                try {{ el[rp].onChange({{target:el, currentTarget:el, type:'change'}}); }} catch(e) {{}}
        }})()"#
    )).await;

    let strategy = if use_js_click { 1 } else { 2 };
    Ok(json!({"success": true, "method": "fileChooser", "path": path_str, "strategy": strategy}))
}

/// Get the page title.
pub async fn get_title(conn: &Arc<CdpConnection>) -> Result<String, String> {
    evaluate(conn, "document.title")
        .await
        .map(|v| v.as_str().unwrap_or("").to_string())
}

/// Press a key.
pub async fn press_key(conn: &Arc<CdpConnection>, key: &str) -> Result<Value, String> {
    let results = conn
        .pipeline(vec![
            (
                "Input.dispatchKeyEvent",
                json!({"type": "keyDown", "key": key}),
            ),
            (
                "Input.dispatchKeyEvent",
                json!({"type": "keyUp", "key": key}),
            ),
        ])
        .await;

    for r in &results {
        if let Err(e) = r {
            return Err(e.clone());
        }
    }
    Ok(json!({"success": true, "key": key}))
}

/// Scroll to an element by text.
pub async fn scroll_to(conn: &Arc<CdpConnection>, text: &str) -> Result<Value, String> {
    let escaped = text.replace('\\', "\\\\").replace('\'', "\\'");
    evaluate(
        conn,
        &format!(
            r#"
        (() => {{
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            while (walker.nextNode()) {{
                if (walker.currentNode.textContent.includes('{escaped}')) {{
                    walker.currentNode.parentElement.scrollIntoView({{behavior:'smooth',block:'center'}});
                    return true;
                }}
            }}
            return false;
        }})()
    "#
        ),
    )
    .await
    .map(|v| json!({"scrolled": v}))
}
