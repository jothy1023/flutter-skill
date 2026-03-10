/**
 * flutter-skill HarmonyOS SDK
 *
 * Implements the flutter-skill bridge protocol over WebSocket so that AI agents
 * can automate HarmonyOS (ArkUI / ArkTS) applications.
 *
 * Usage (in your Ability's onCreate):
 *
 *   import { FlutterSkillBridge } from './FlutterSkillAbility';
 *
 *   const bridge = new FlutterSkillBridge({ appName: 'my-harmony-app' });
 *   bridge.start();
 *
 * The bridge listens on ws://127.0.0.1:18118 by default.
 * flutter-skill will auto-discover it via port scanning.
 */

import webSocket from '@ohos.net.webSocket';
import http from '@ohos.net.http';
import router from '@ohos.router';
import image from '@ohos.multimedia.image';
import display from '@ohos.display';
import inputSimulator from '@ohos.multimodalInput.inputSimulator';
import componentSnapshot from '@ohos.arkui.componentSnapshot';
import { BusinessError } from '@ohos.base';

const DEFAULT_PORT = 18118;
const SDK_VERSION = '0.1.0';

interface BridgeOptions {
  port?: number;
  appName?: string;
}

interface ToolResult {
  success: boolean;
  error?: string;
  [key: string]: unknown;
}

interface RpcRequest {
  id: string | number;
  method: string;
  params?: Record<string, unknown>;
}

interface RpcResponse {
  id: string | number;
  result?: unknown;
  error?: { code: number; message: string };
}

export class FlutterSkillBridge {
  private port: number;
  private appName: string;
  private logs: string[] = [];
  private maxLogs = 500;
  private server: webSocket.WebSocketServer | null = null;
  private clients: Set<webSocket.WebSocket> = new Set();

  constructor(options: BridgeOptions = {}) {
    this.port = options.port ?? DEFAULT_PORT;
    this.appName = options.appName ?? 'harmony-app';
  }

  // --------------- Lifecycle ---------------

  start(): void {
    this.server = webSocket.createWebSocketServer();
    this.server.on('connect', (ws: webSocket.WebSocket) => {
      this.clients.add(ws);
      this.log(`[flutter-skill] Client connected`);

      ws.on('message', async (event: webSocket.MessageEvent) => {
        const text = typeof event.data === 'string'
          ? event.data
          : new TextDecoder().decode(event.data as ArrayBuffer);
        await this.handleMessage(ws, text);
      });

      ws.on('close', () => {
        this.clients.delete(ws);
        this.log(`[flutter-skill] Client disconnected`);
      });

      ws.on('error', (err: BusinessError) => {
        this.log(`[flutter-skill] WS error: ${err.message}`);
      });
    });

    this.server.listen({ address: '127.0.0.1', port: this.port }, () => {
      this.log(`[flutter-skill] Bridge listening on ws://127.0.0.1:${this.port}`);
    });
  }

  stop(): void {
    this.clients.forEach(ws => ws.close());
    this.clients.clear();
    this.server?.close();
    this.server = null;
  }

  // --------------- Message handling ---------------

  private async handleMessage(ws: webSocket.WebSocket, raw: string): Promise<void> {
    let req: RpcRequest;
    try {
      req = JSON.parse(raw) as RpcRequest;
    } catch {
      return;
    }

    const { id, method, params = {} } = req;

    // Health-check ping
    if (method === 'ping') {
      this.sendResponse(ws, id, { pong: true });
      return;
    }

    // Capability advertisement
    if (method === 'initialize' || method === 'getInfo') {
      this.sendResponse(ws, id, {
        framework: 'harmonyos',
        app_name: this.appName,
        platform: 'ohos',
        sdk_version: SDK_VERSION,
        capabilities: [
          'initialize', 'inspect', 'tap', 'enter_text', 'get_text',
          'screenshot', 'go_back', 'get_logs', 'clear_logs', 'press_key',
          'scroll', 'get_current_route',
        ],
      });
      return;
    }

    let result: ToolResult;
    try {
      result = await this.dispatch(method, params);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.sendError(ws, id, -32000, msg);
      return;
    }
    this.sendResponse(ws, id, result);
  }

  private sendResponse(ws: webSocket.WebSocket, id: string | number, result: unknown): void {
    const resp: RpcResponse = { id, result };
    ws.send(JSON.stringify(resp));
  }

  private sendError(
    ws: webSocket.WebSocket,
    id: string | number,
    code: number,
    message: string,
  ): void {
    const resp: RpcResponse = { id, error: { code, message } };
    ws.send(JSON.stringify(resp));
  }

  // --------------- Tool dispatcher ---------------

  private async dispatch(
    method: string,
    params: Record<string, unknown>,
  ): Promise<ToolResult> {
    switch (method) {
      case 'screenshot':
        return await this.takeScreenshot(params);
      case 'tap':
        return await this.tap(params);
      case 'enter_text':
        return await this.enterText(params);
      case 'press_key':
        return await this.pressKey(params);
      case 'scroll':
        return await this.scroll(params);
      case 'go_back':
        return await this.goBack();
      case 'get_logs':
        return { success: true, logs: this.logs };
      case 'clear_logs':
        this.logs = [];
        return { success: true };
      case 'get_current_route':
        return await this.getCurrentRoute();
      case 'inspect':
        return await this.inspect();
      case 'get_text':
        return await this.getText(params);
      default:
        return { success: false, error: `Unknown method: ${method}` };
    }
  }

  // --------------- Tool implementations ---------------

  private async takeScreenshot(_params: Record<string, unknown>): Promise<ToolResult> {
    try {
      const displayObj = display.getDefaultDisplaySync();
      const pixelMap = await displayObj.capture();
      const imageSource = image.createImageSource(pixelMap as unknown as ArrayBuffer);
      const packOpts: image.PackingOption = { format: 'image/png', quality: 90 };
      const packer = image.createImagePacker();
      const buffer = await packer.packing(imageSource, packOpts);
      const base64 = this.arrayBufferToBase64(buffer);
      return {
        success: true,
        screenshot: base64,
        format: 'png',
        width: displayObj.width,
        height: displayObj.height,
      };
    } catch (e) {
      return { success: false, error: `Screenshot failed: ${e}` };
    }
  }

  private async tap(params: Record<string, unknown>): Promise<ToolResult> {
    const x = params['x'] as number | undefined;
    const y = params['y'] as number | undefined;
    if (x === undefined || y === undefined) {
      return { success: false, error: 'tap requires x and y coordinates' };
    }
    try {
      await inputSimulator.injectMouseEvent({
        action: inputSimulator.Action.MOUSE_ACTION_BUTTON_DOWN,
        screenX: x,
        screenY: y,
        button: inputSimulator.MouseButton.MOUSE_BUTTON_LEFT,
      });
      await inputSimulator.injectMouseEvent({
        action: inputSimulator.Action.MOUSE_ACTION_BUTTON_UP,
        screenX: x,
        screenY: y,
        button: inputSimulator.MouseButton.MOUSE_BUTTON_LEFT,
      });
      return { success: true, message: `Tapped at (${x}, ${y})` };
    } catch (e) {
      return { success: false, error: `Tap failed: ${e}` };
    }
  }

  private async enterText(params: Record<string, unknown>): Promise<ToolResult> {
    const text = params['text'] as string | undefined;
    if (!text) {
      return { success: false, error: 'enter_text requires a text parameter' };
    }
    try {
      for (const char of text) {
        await inputSimulator.injectKeyEvent({
          action: inputSimulator.KeyAction.KEY_ACTION_DOWN,
          key: inputSimulator.KeyCode.KEYCODE_UNKNOWN,
          unicodeChar: char.codePointAt(0) ?? 0,
        });
        await inputSimulator.injectKeyEvent({
          action: inputSimulator.KeyAction.KEY_ACTION_UP,
          key: inputSimulator.KeyCode.KEYCODE_UNKNOWN,
          unicodeChar: char.codePointAt(0) ?? 0,
        });
      }
      return { success: true, message: `Entered text: ${text}` };
    } catch (e) {
      return { success: false, error: `enter_text failed: ${e}` };
    }
  }

  private async pressKey(params: Record<string, unknown>): Promise<ToolResult> {
    const key = (params['key'] as string | undefined)?.toLowerCase() ?? '';
    const keyCodeMap: Record<string, number> = {
      'enter': inputSimulator.KeyCode.KEYCODE_ENTER,
      'return': inputSimulator.KeyCode.KEYCODE_ENTER,
      'tab': inputSimulator.KeyCode.KEYCODE_TAB,
      'escape': inputSimulator.KeyCode.KEYCODE_ESCAPE,
      'backspace': inputSimulator.KeyCode.KEYCODE_DEL,
      'delete': inputSimulator.KeyCode.KEYCODE_FORWARD_DEL,
      'space': inputSimulator.KeyCode.KEYCODE_SPACE,
      'up': inputSimulator.KeyCode.KEYCODE_DPAD_UP,
      'down': inputSimulator.KeyCode.KEYCODE_DPAD_DOWN,
      'left': inputSimulator.KeyCode.KEYCODE_DPAD_LEFT,
      'right': inputSimulator.KeyCode.KEYCODE_DPAD_RIGHT,
      'home': inputSimulator.KeyCode.KEYCODE_MOVE_HOME,
      'end': inputSimulator.KeyCode.KEYCODE_MOVE_END,
    };
    const keyCode = keyCodeMap[key];
    if (!keyCode) {
      return { success: false, error: `Unknown key: ${key}` };
    }
    try {
      await inputSimulator.injectKeyEvent({ action: inputSimulator.KeyAction.KEY_ACTION_DOWN, key: keyCode });
      await inputSimulator.injectKeyEvent({ action: inputSimulator.KeyAction.KEY_ACTION_UP, key: keyCode });
      return { success: true, message: `Pressed key: ${key}` };
    } catch (e) {
      return { success: false, error: `pressKey failed: ${e}` };
    }
  }

  private async scroll(params: Record<string, unknown>): Promise<ToolResult> {
    const direction = (params['direction'] as string | undefined) ?? 'down';
    const amount = (params['amount'] as number | undefined) ?? 300;
    const displayObj = display.getDefaultDisplaySync();
    const cx = displayObj.width / 2;
    const cy = displayObj.height / 2;
    const dy = direction === 'up' ? -amount : direction === 'down' ? amount : 0;
    const dx = direction === 'left' ? -amount : direction === 'right' ? amount : 0;
    try {
      await inputSimulator.injectMouseEvent({
        action: inputSimulator.Action.MOUSE_ACTION_BUTTON_DOWN,
        screenX: cx,
        screenY: cy,
        button: inputSimulator.MouseButton.MOUSE_BUTTON_LEFT,
      });
      await inputSimulator.injectMouseEvent({
        action: inputSimulator.Action.MOUSE_ACTION_MOVE,
        screenX: cx + dx,
        screenY: cy + dy,
      });
      await inputSimulator.injectMouseEvent({
        action: inputSimulator.Action.MOUSE_ACTION_BUTTON_UP,
        screenX: cx + dx,
        screenY: cy + dy,
        button: inputSimulator.MouseButton.MOUSE_BUTTON_LEFT,
      });
      return { success: true, message: `Scrolled ${direction} by ${amount}px` };
    } catch (e) {
      return { success: false, error: `scroll failed: ${e}` };
    }
  }

  private async goBack(): Promise<ToolResult> {
    try {
      router.back();
      return { success: true, message: 'Navigated back' };
    } catch (e) {
      return { success: false, error: `go_back failed: ${e}` };
    }
  }

  private async getCurrentRoute(): Promise<ToolResult> {
    try {
      const state = router.getState();
      return { success: true, route: state.path ?? state.name ?? '(unknown)' };
    } catch (e) {
      return { success: false, error: `getCurrentRoute failed: ${e}` };
    }
  }

  private async inspect(): Promise<ToolResult> {
    // Return current router state and page info as a lightweight snapshot
    try {
      const state = router.getState();
      return {
        success: true,
        page: state.path ?? state.name ?? '(unknown)',
        params: state.params ?? {},
      };
    } catch (e) {
      return { success: false, error: `inspect failed: ${e}` };
    }
  }

  private async getText(params: Record<string, unknown>): Promise<ToolResult> {
    const id = params['key'] as string | undefined;
    if (!id) {
      return { success: false, error: 'get_text requires a key (component id)' };
    }
    try {
      const snapshot = await componentSnapshot.get(id);
      // The snapshot is a PixelMap; we return the id and note that direct text
      // extraction requires the app to expose text via a registered data source.
      return {
        success: true,
        note: 'Text extraction via componentSnapshot returns a PixelMap. For text values, expose them via a custom bridge tool.',
        key: id,
        snapshot_available: snapshot !== null,
      };
    } catch (e) {
      return { success: false, error: `get_text failed: ${e}` };
    }
  }

  // --------------- Helpers ---------------

  private log(msg: string): void {
    const entry = `[${new Date().toISOString()}] ${msg}`;
    this.logs.push(entry);
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
    console.log(entry);
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
  }
}
