#!/usr/bin/env python3
"""
Real integration test for the flutter-skill C++ bridge.

Starts the actual bridge server (real macOS backend), connects over WebSocket,
and validates every tool against the live system.
"""

import base64
import json
import os
import signal
import struct
import subprocess
import sys
import time

import websocket  # websocket-client

BRIDGE_BIN = "/tmp/flutter_skill_bridge"
PORT = 19118  # Use a non-default port so it doesn't clash with a running SDK
WS_URL = f"ws://127.0.0.1:{PORT}"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

PASS = "\033[32m  [  OK ]\033[0m"
FAIL = "\033[31m  [FAIL ]\033[0m"
RUN  = "  [ RUN ]"

passed = 0
failed = 0
results = []


def rpc(ws, method, params=None, req_id=1):
    payload = {"id": req_id, "method": method, "params": params or {}}
    ws.send(json.dumps(payload))
    raw = ws.recv()
    return json.loads(raw)


def check(name, cond, detail=""):
    global passed, failed
    if cond:
        print(f"{PASS} {name}")
        passed += 1
        return True
    else:
        print(f"{FAIL} {name}" + (f" — {detail}" if detail else ""))
        failed += 1
        return False


def run_test(name, fn):
    print(f"{RUN} {name}")
    try:
        fn()
    except Exception as e:
        global failed
        print(f"{FAIL} {name} — exception: {e}")
        failed += 1


# ── Start bridge ─────────────────────────────────────────────────────────────

print("=" * 60)
print("flutter-skill C++ SDK — Real Integration Tests")
print("=" * 60)
print(f"\nStarting bridge on port {PORT}…")

bridge = subprocess.Popen(
    [BRIDGE_BIN, str(PORT)],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)

# Wait until the bridge is accepting connections (up to 3 seconds)
deadline = time.time() + 3.0
ready = False
while time.time() < deadline:
    if bridge.poll() is not None:
        out, err = bridge.communicate()
        print(f"Bridge failed to start: {err.decode()}")
        sys.exit(1)
    try:
        import socket
        s = socket.create_connection(("127.0.0.1", PORT), timeout=0.1)
        s.close()
        ready = True
        break
    except OSError:
        time.sleep(0.05)

if not ready:
    print(f"Bridge did not start in time on port {PORT}")
    bridge.terminate()
    sys.exit(1)

print(f"Bridge PID: {bridge.pid}\n")

# ── Connect ───────────────────────────────────────────────────────────────────

try:
    ws = websocket.create_connection(WS_URL, timeout=5)
except Exception as e:
    print(f"Failed to connect: {e}")
    bridge.terminate()
    sys.exit(1)

print("Connected via WebSocket.\n")

# ── Tests ─────────────────────────────────────────────────────────────────────

def test_ping():
    r = rpc(ws, "ping")
    result = r.get("result", {})
    check("ping returns pong", result.get("pong") is True, str(result))

def test_initialize():
    r = rpc(ws, "initialize")
    result = r.get("result", {})
    caps = result.get("capabilities", [])
    check("initialize — success", result.get("success") is True, str(result))
    check("initialize — framework=cpp", result.get("framework") == "cpp")
    check("initialize — has tap", "tap" in caps)
    check("initialize — has screenshot", "screenshot" in caps)
    check("initialize — has enter_text", "enter_text" in caps)
    check("initialize — has press_key", "press_key" in caps)
    print(f"         SDK version: {result.get('sdk_version', '?')}")
    print(f"         Capabilities: {', '.join(caps)}")

def test_get_focused_window():
    r = rpc(ws, "get_focused_window_title")
    result = r.get("result", {})
    check("get_focused_window_title — success", result.get("success") is True)
    title = result.get("title", "")
    # Title may be empty in a headless environment, but the call must succeed
    check("get_focused_window_title — no error", "error" not in result)
    print(f"         Focused window: {title!r}")

def test_inspect():
    r = rpc(ws, "inspect")
    result = r.get("result", {})
    check("inspect — success", result.get("success") is True, str(result))
    print(f"         Inspect result: {result}")

def test_get_logs():
    r = rpc(ws, "get_logs")
    result = r.get("result", {})
    check("get_logs — success", result.get("success") is True)
    check("get_logs — has logs array", "logs" in result)

def test_clear_logs():
    r = rpc(ws, "clear_logs")
    result = r.get("result", {})
    check("clear_logs — success", result.get("success") is True)

def test_screenshot():
    r = rpc(ws, "screenshot")
    result = r.get("result", {})
    check("screenshot — success", result.get("success") is True, str(result))

    b64 = result.get("screenshot", "")
    if b64:
        try:
            raw = base64.b64decode(b64)
            is_png = raw[:8] == PNG_MAGIC
            check("screenshot — valid PNG magic bytes", is_png,
                  f"got {raw[:8].hex()}")
            size_kb = len(raw) // 1024
            print(f"         Screenshot size: {size_kb} KB "
                  f"({result.get('width')}×{result.get('height')})")
        except Exception as e:
            check("screenshot — base64 decode", False, str(e))
    else:
        # In a headless CI environment screencapture may fail — not a fatal error
        print("         [note] No screenshot data (may need Screen Recording permission)")
        # Still mark as pass since the bridge responded correctly
        check("screenshot — bridge responded", result.get("success") is not None)

def test_scroll():
    # Scroll should always succeed (no position required)
    r = rpc(ws, "scroll", {"direction": "down", "amount": 100})
    result = r.get("result", {})
    check("scroll down — success", result.get("success") is True, str(result))

    r = rpc(ws, "scroll", {"direction": "up", "amount": 100})
    result = r.get("result", {})
    check("scroll up — success", result.get("success") is True, str(result))

def test_press_key():
    # Press Shift — safe to press without visible side-effects
    r = rpc(ws, "press_key", {"key": "shift", "modifiers": []})
    result = r.get("result", {})
    check("press_key shift — success", result.get("success") is True, str(result))

def test_tap():
    # Tap at top-left corner (1,1) — safe, no visible effect
    r = rpc(ws, "tap", {"x": 1, "y": 1})
    result = r.get("result", {})
    check("tap (1,1) — success", result.get("success") is True, str(result))

def test_enter_text():
    # Open TextEdit and type something, or just test the call succeeds
    r = rpc(ws, "enter_text", {"text": "flutter-skill"})
    result = r.get("result", {})
    check("enter_text — success", result.get("success") is True, str(result))

def test_unknown_method():
    r = rpc(ws, "this_method_does_not_exist")
    result = r.get("result", {})
    check("unknown method — returns failure", result.get("success") is False)
    check("unknown method — has error field", "error" in result)

def test_sequential_requests():
    """Send 10 requests sequentially and verify all succeed."""
    all_ok = True
    for i in range(10):
        r = rpc(ws, "ping", req_id=100 + i)
        if not r.get("result", {}).get("pong"):
            all_ok = False
            break
    check("10 sequential ping requests", all_ok)

def test_rpc_id_echo():
    """Verify the response id matches the request id."""
    for req_id in [1, 42, 999]:
        r = rpc(ws, "ping", req_id=req_id)
        check(f"rpc id echo — id={req_id}", r.get("id") == req_id,
              f"got id={r.get('id')}")

# ── Run all tests ─────────────────────────────────────────────────────────────

print("Running tests…\n")

run_test("ping",                test_ping)
run_test("initialize",          test_initialize)
run_test("get_focused_window",  test_get_focused_window)
run_test("inspect",             test_inspect)
run_test("get_logs",            test_get_logs)
run_test("clear_logs",          test_clear_logs)
run_test("screenshot",          test_screenshot)
run_test("scroll",              test_scroll)
run_test("press_key",           test_press_key)
run_test("tap",                 test_tap)
run_test("enter_text",          test_enter_text)
run_test("unknown_method",      test_unknown_method)
run_test("sequential_requests", test_sequential_requests)
run_test("rpc_id_echo",         test_rpc_id_echo)

# ── Results ───────────────────────────────────────────────────────────────────

ws.close()
bridge.terminate()
bridge.wait()

print(f"\n{'=' * 60}")
print(f"Results: {passed} passed, {failed} failed")
print("=" * 60)

sys.exit(0 if failed == 0 else 1)
