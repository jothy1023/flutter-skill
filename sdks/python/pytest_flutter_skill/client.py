"""JSON-RPC client that talks to the flutter-skill MCP server (stdio)."""

from __future__ import annotations

import json
import subprocess
import threading
import time
from typing import Any


class FlutterSkillClient:
    """Wraps the flutter-skill MCP server process and exposes tool calls as
    Python methods.

    Usage::

        client = FlutterSkillClient()
        client.start()
        client.connect_app()
        client.tap(text="Login")
        client.assert_visible(text="Dashboard")
        client.stop()
    """

    def __init__(self, executable: str = "flutter_skill", timeout: int = 30):
        self._executable = executable
        self._timeout = timeout
        self._proc: subprocess.Popen | None = None
        self._lock = threading.Lock()
        self._id = 0
        self._pending: dict[int, Any] = {}
        self._reader_thread: threading.Thread | None = None
        self._running = False

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def start(self) -> None:
        """Start the flutter-skill MCP server subprocess."""
        self._proc = subprocess.Popen(
            [self._executable],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self._running = True
        self._reader_thread = threading.Thread(
            target=self._read_loop, daemon=True
        )
        self._reader_thread.start()
        # Give the server a moment to initialise
        time.sleep(0.3)

    def stop(self) -> None:
        """Shut down the MCP server subprocess."""
        self._running = False
        if self._proc:
            try:
                self._proc.stdin.close()
                self._proc.wait(timeout=5)
            except Exception:
                self._proc.kill()
        self._proc = None

    # ------------------------------------------------------------------
    # JSON-RPC transport
    # ------------------------------------------------------------------

    def _next_id(self) -> int:
        with self._lock:
            self._id += 1
            return self._id

    def _send(self, method: str, params: dict | None = None) -> Any:
        """Send a JSON-RPC request and block until the response arrives."""
        req_id = self._next_id()
        event = threading.Event()
        self._pending[req_id] = {"event": event, "result": None, "error": None}

        payload = json.dumps(
            {"jsonrpc": "2.0", "id": req_id, "method": method, "params": params or {}}
        )
        assert self._proc is not None, "Client not started — call start() first"
        self._proc.stdin.write(payload + "\n")
        self._proc.stdin.flush()

        if not event.wait(timeout=self._timeout):
            del self._pending[req_id]
            raise TimeoutError(
                f"flutter-skill did not respond to '{method}' within {self._timeout}s"
            )

        entry = self._pending.pop(req_id)
        if entry["error"] is not None:
            raise RuntimeError(f"flutter-skill error: {entry['error']}")
        return entry["result"]

    def _read_loop(self) -> None:
        assert self._proc is not None
        for line in self._proc.stdout:
            if not self._running:
                break
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg_id = msg.get("id")
            if msg_id is not None and msg_id in self._pending:
                entry = self._pending[msg_id]
                if "error" in msg:
                    entry["error"] = msg["error"].get("message", str(msg["error"]))
                else:
                    entry["result"] = msg.get("result")
                entry["event"].set()

    # ------------------------------------------------------------------
    # Tool call helper
    # ------------------------------------------------------------------

    def call_tool(self, name: str, **kwargs: Any) -> dict:
        """Call any flutter-skill MCP tool by name."""
        result = self._send(
            "tools/call", {"name": name, "arguments": kwargs}
        )
        # MCP returns {"content": [{"type": "text", "text": "..."}]}
        if isinstance(result, dict) and "content" in result:
            texts = [c["text"] for c in result["content"] if c.get("type") == "text"]
            raw = "\n".join(texts)
            try:
                return json.loads(raw)
            except (json.JSONDecodeError, ValueError):
                return {"raw": raw}
        return result or {}

    # ------------------------------------------------------------------
    # Convenience wrappers
    # ------------------------------------------------------------------

    def connect_app(self, uri: str | None = None) -> dict:
        kwargs = {}
        if uri:
            kwargs["uri"] = uri
        return self.call_tool("connect_app", **kwargs)

    def connect_cdp(self, port: int = 9222, url: str | None = None) -> dict:
        kwargs: dict = {"port": port}
        if url:
            kwargs["url"] = url
        return self.call_tool("connect_cdp", **kwargs)

    def tap(self, *, key: str | None = None, text: str | None = None) -> dict:
        kwargs: dict = {}
        if key:
            kwargs["key"] = key
        if text:
            kwargs["text"] = text
        return self.call_tool("tap", **kwargs)

    def enter_text(self, text: str, *, key: str | None = None) -> dict:
        kwargs: dict = {"text": text}
        if key:
            kwargs["key"] = key
        return self.call_tool("enter_text", **kwargs)

    def press_key(self, key: str) -> dict:
        return self.call_tool("press_key", key=key)

    def screenshot(self, path: str | None = None) -> dict:
        kwargs = {}
        if path:
            kwargs["path"] = path
        return self.call_tool("screenshot", **kwargs)

    def snapshot(self) -> dict:
        return self.call_tool("snapshot")

    def scroll(
        self,
        direction: str = "down",
        amount: int = 300,
        *,
        key: str | None = None,
        text: str | None = None,
    ) -> dict:
        kwargs: dict = {"direction": direction, "amount": amount}
        if key:
            kwargs["key"] = key
        if text:
            kwargs["text"] = text
        return self.call_tool("scroll", **kwargs)

    def navigate(self, url: str) -> dict:
        return self.call_tool("navigate", url=url)

    def go_back(self) -> dict:
        return self.call_tool("go_back")

    def get_logs(self) -> dict:
        return self.call_tool("get_logs")

    def hot_reload(self) -> dict:
        return self.call_tool("hot_reload")

    # ------------------------------------------------------------------
    # Assertions — raise AssertionError on failure so pytest reports them
    # ------------------------------------------------------------------

    def assert_visible(self, *, key: str | None = None, text: str | None = None) -> None:
        """Assert that an element is visible in the current screen."""
        kwargs: dict = {}
        if key:
            kwargs["key"] = key
        if text:
            kwargs["text"] = text
        result = self.call_tool("assert_visible", **kwargs)
        if not result.get("success", True) or result.get("visible") is False:
            desc = key or text or "(unknown)"
            raise AssertionError(
                f"Element not visible: {desc}\n{result.get('error', '')}"
            )

    def assert_not_visible(self, *, key: str | None = None, text: str | None = None) -> None:
        """Assert that an element is NOT visible in the current screen."""
        kwargs: dict = {}
        if key:
            kwargs["key"] = key
        if text:
            kwargs["text"] = text
        result = self.call_tool("assert_not_visible", **kwargs)
        if not result.get("success", True):
            desc = key or text or "(unknown)"
            raise AssertionError(
                f"Element unexpectedly visible: {desc}\n{result.get('error', '')}"
            )

    def assert_text(self, expected: str, *, key: str | None = None) -> None:
        """Assert that an element contains the expected text."""
        kwargs: dict = {"expected": expected}
        if key:
            kwargs["key"] = key
        result = self.call_tool("assert_text", **kwargs)
        if not result.get("success", True) or result.get("match") is False:
            raise AssertionError(
                f"Text assertion failed. Expected: {expected!r}\n{result.get('error', '')}"
            )

    def find_element(self, text: str | None = None, *, key: str | None = None) -> bool:
        """Return True if an element with the given text/key exists."""
        snap = self.snapshot()
        elements = snap.get("elements", [])
        for el in elements:
            if key and el.get("key") == key:
                return True
            if text and text.lower() in str(el.get("text", "")).lower():
                return True
        # Fallback: check raw snapshot text
        raw = json.dumps(snap)
        if text and text.lower() in raw.lower():
            return True
        return False

    def wait_for_element(
        self,
        *,
        key: str | None = None,
        text: str | None = None,
        timeout: int = 5000,
    ) -> dict:
        kwargs: dict = {"timeout": timeout}
        if key:
            kwargs["key"] = key
        if text:
            kwargs["text"] = text
        return self.call_tool("wait_for_element", **kwargs)
