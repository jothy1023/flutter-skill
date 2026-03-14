/**
 * flutter-skill Windows automation backend.
 *
 * Uses:
 *  - SendInput for mouse and keyboard synthesis
 *  - BitBlt + GetDC for screen capture (PNG via GDI+)
 *  - IUIAutomation for accessibility inspection
 */

#if defined(_WIN32)

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wingdi.h>
#include <objbase.h>
#include <uiautomation.h>
#include <gdiplus.h>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "uiautomationcore.lib")

#include "flutter_skill/bridge.h"
#include "json_rpc.h"

#include <map>
#include <sstream>
#include <string>
#include <vector>

namespace flutter_skill {

using namespace detail;

// ── Base64 helper (reuse from sha1.h) ─────────────────────────────────────
// base64_encode is defined in sha1.h which is included via bridge.cpp.
// Forward-declare for use here.
namespace detail { std::string base64_encode(const std::string&); }

// ── GDI+ screenshot ────────────────────────────────────────────────────────

static CLSID get_png_clsid() {
    CLSID clsid{};
    // Well-known CLSID for image/png encoder
    // {557CF406-1A04-11D3-9A73-0000F81EF32E}
    clsid.Data1 = 0x557CF406;
    clsid.Data2 = 0x1A04;
    clsid.Data3 = 0x11D3;
    clsid.Data4[0] = 0x9A; clsid.Data4[1] = 0x73;
    clsid.Data4[2] = 0x00; clsid.Data4[3] = 0x00;
    clsid.Data4[4] = 0xF8; clsid.Data4[5] = 0x1E;
    clsid.Data4[6] = 0xF3; clsid.Data4[7] = 0x2E;
    return clsid;
}

static std::string capture_screen_base64() {
    ULONG_PTR gdiplusToken = 0;
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&gdiplusToken, &input, nullptr);

    int w = GetSystemMetrics(SM_CXSCREEN);
    int h = GetSystemMetrics(SM_CYSCREEN);

    HDC screenDC = GetDC(nullptr);
    HDC memDC    = CreateCompatibleDC(screenDC);
    HBITMAP bmp  = CreateCompatibleBitmap(screenDC, w, h);
    HBITMAP old  = (HBITMAP)SelectObject(memDC, bmp);
    BitBlt(memDC, 0, 0, w, h, screenDC, 0, 0, SRCCOPY);
    SelectObject(memDC, old);

    // Encode to PNG in memory
    IStream* stream = nullptr;
    CreateStreamOnHGlobal(nullptr, TRUE, &stream);
    {
        Gdiplus::Bitmap gdiBmp(bmp, nullptr);
        CLSID pngClsid = get_png_clsid();
        gdiBmp.Save(stream, &pngClsid, nullptr);
    }

    HGLOBAL hMem = nullptr;
    GetHGlobalFromStream(stream, &hMem);
    SIZE_T size = GlobalSize(hMem);
    void* ptr   = GlobalLock(hMem);
    std::string raw(reinterpret_cast<char*>(ptr), size);
    GlobalUnlock(hMem);
    stream->Release();

    DeleteObject(bmp);
    DeleteDC(memDC);
    ReleaseDC(nullptr, screenDC);
    Gdiplus::GdiplusShutdown(gdiplusToken);

    return base64_encode(raw);
}

// ── Key mapping ────────────────────────────────────────────────────────────

static WORD key_name_to_vk(const std::string& key) {
    static const std::map<std::string, WORD> table = {
        {"enter",     VK_RETURN}, {"return",    VK_RETURN},
        {"tab",       VK_TAB},    {"escape",    VK_ESCAPE},
        {"backspace", VK_BACK},   {"delete",    VK_DELETE},
        {"space",     VK_SPACE},
        {"up",        VK_UP},     {"down",      VK_DOWN},
        {"left",      VK_LEFT},   {"right",     VK_RIGHT},
        {"home",      VK_HOME},   {"end",       VK_END},
        {"pageup",    VK_PRIOR},  {"pagedown",  VK_NEXT},
        {"f1",  VK_F1},  {"f2",  VK_F2},  {"f3",  VK_F3},  {"f4",  VK_F4},
        {"f5",  VK_F5},  {"f6",  VK_F6},  {"f7",  VK_F7},  {"f8",  VK_F8},
        {"f9",  VK_F9},  {"f10", VK_F10}, {"f11", VK_F11}, {"f12", VK_F12},
        {"ctrl",    VK_CONTROL}, {"control", VK_CONTROL},
        {"shift",   VK_SHIFT},
        {"alt",     VK_MENU},
        {"win",     VK_LWIN},
    };
    auto it = table.find(key);
    if (it != table.end()) return it->second;
    if (key.size() == 1) return VkKeyScanA(key[0]) & 0xFF;
    return 0;
}

static void push_key_input(std::vector<INPUT>& inputs, WORD vk, bool down,
                            bool use_unicode = false, WCHAR uc = 0) {
    INPUT in{};
    in.type = INPUT_KEYBOARD;
    if (use_unicode) {
        in.ki.wScan   = uc;
        in.ki.dwFlags = KEYEVENTF_UNICODE | (down ? 0 : KEYEVENTF_KEYUP);
    } else {
        in.ki.wVk     = vk;
        in.ki.dwFlags = down ? 0 : KEYEVENTF_KEYUP;
    }
    inputs.push_back(in);
}

static void send_modifier_down(std::vector<INPUT>& inputs,
                                const std::vector<std::string>& mods) {
    for (const auto& m : mods) {
        WORD vk = key_name_to_vk(m);
        if (vk) push_key_input(inputs, vk, true);
    }
}

static void send_modifier_up(std::vector<INPUT>& inputs,
                               const std::vector<std::string>& mods) {
    for (auto it = mods.rbegin(); it != mods.rend(); ++it) {
        WORD vk = key_name_to_vk(*it);
        if (vk) push_key_input(inputs, vk, false);
    }
}

// ── Windows backend ────────────────────────────────────────────────────────

class WindowsAutomationBackend : public AutomationBackend {
public:
    ToolResult screenshot() override {
        std::string b64 = capture_screen_base64();
        if (b64.empty()) return {false, "Screenshot capture failed"};

        int w = GetSystemMetrics(SM_CXSCREEN);
        int h = GetSystemMetrics(SM_CYSCREEN);

        std::string extra =
            "\"screenshot\":" + json_str(b64) + ","
            "\"format\":\"png\","
            "\"width\":" + std::to_string(w) + ","
            "\"height\":" + std::to_string(h);
        return {true, extra};
    }

    ToolResult tap(double x, double y) override {
        // Normalize to [0, 65535]
        int sw = GetSystemMetrics(SM_CXSCREEN);
        int sh = GetSystemMetrics(SM_CYSCREEN);
        LONG nx = (LONG)(x / sw * 65535.0);
        LONG ny = (LONG)(y / sh * 65535.0);

        INPUT inputs[3]{};

        inputs[0].type           = INPUT_MOUSE;
        inputs[0].mi.dx          = nx;
        inputs[0].mi.dy          = ny;
        inputs[0].mi.dwFlags     = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;

        inputs[1].type           = INPUT_MOUSE;
        inputs[1].mi.dwFlags     = MOUSEEVENTF_LEFTDOWN;

        inputs[2].type           = INPUT_MOUSE;
        inputs[2].mi.dwFlags     = MOUSEEVENTF_LEFTUP;

        SendInput(3, inputs, sizeof(INPUT));

        return {true, "\"message\":\"Tapped at (" +
                std::to_string((int)x) + "," + std::to_string((int)y) + ")\""};
    }

    ToolResult enter_text(const std::string& text) override {
        // Convert UTF-8 to UTF-16
        int wlen = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
        if (wlen <= 0) return {false, "Invalid UTF-8"};
        std::wstring wide(wlen, 0);
        MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, &wide[0], wlen);

        std::vector<INPUT> inputs;
        for (wchar_t wc : wide) {
            if (wc == 0) continue;
            push_key_input(inputs, 0, true,  true, wc);
            push_key_input(inputs, 0, false, true, wc);
        }
        if (!inputs.empty())
            SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));

        return {true, "\"message\":\"Entered text\""};
    }

    ToolResult press_key(const std::string& key,
                         const std::vector<std::string>& mods) override {
        WORD vk = key_name_to_vk(key);
        if (!vk) return {false, "Unknown key: " + key};

        std::vector<INPUT> inputs;
        send_modifier_down(inputs, mods);
        push_key_input(inputs, vk, true);
        push_key_input(inputs, vk, false);
        send_modifier_up(inputs, mods);

        SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));

        return {true, "\"message\":\"Pressed key: " + key + "\""};
    }

    ToolResult scroll(const std::string& direction, double amount) override {
        INPUT in{};
        in.type = INPUT_MOUSE;

        if (direction == "up" || direction == "down") {
            in.mi.dwFlags = MOUSEEVENTF_WHEEL;
            in.mi.mouseData = (direction == "up")
                ? (DWORD)(int)amount
                : (DWORD)(-(int)amount);
        } else {
            in.mi.dwFlags = MOUSEEVENTF_HWHEEL;
            in.mi.mouseData = (direction == "right")
                ? (DWORD)(int)amount
                : (DWORD)(-(int)amount);
        }

        SendInput(1, &in, sizeof(INPUT));
        return {true, "\"message\":\"Scrolled " + direction + "\""};
    }

    ToolResult inspect() override {
        HWND hwnd = GetForegroundWindow();
        if (!hwnd) return {true, "\"title\":null"};

        wchar_t title[512]{};
        GetWindowTextW(hwnd, title, 512);
        wchar_t cls[256]{};
        GetClassNameW(hwnd, cls, 256);

        auto wto = [](const wchar_t* ws) -> std::string {
            int n = WideCharToMultiByte(CP_UTF8, 0, ws, -1, nullptr, 0, nullptr, nullptr);
            if (n <= 0) return "";
            std::string s(n - 1, 0);
            WideCharToMultiByte(CP_UTF8, 0, ws, -1, &s[0], n, nullptr, nullptr);
            return s;
        };

        RECT r{};
        GetWindowRect(hwnd, &r);

        return {true,
            "\"title\":" + json_str(wto(title)) + ","
            "\"class_name\":" + json_str(wto(cls)) + ","
            "\"bounds\":{\"x\":" + std::to_string(r.left) +
                ",\"y\":" + std::to_string(r.top) +
                ",\"width\":" + std::to_string(r.right - r.left) +
                ",\"height\":" + std::to_string(r.bottom - r.top) + "}"};
    }

    ToolResult get_focused_window_title() override {
        HWND hwnd = GetForegroundWindow();
        if (!hwnd) return {true, "\"title\":null"};

        wchar_t title[512]{};
        GetWindowTextW(hwnd, title, 512);

        int n = WideCharToMultiByte(CP_UTF8, 0, title, -1, nullptr, 0, nullptr, nullptr);
        std::string utf8;
        if (n > 1) {
            utf8.resize(n - 1);
            WideCharToMultiByte(CP_UTF8, 0, title, -1, &utf8[0], n, nullptr, nullptr);
        }

        return {true, "\"title\":" + json_str(utf8)};
    }
};

// ── Factory ────────────────────────────────────────────────────────────────

std::unique_ptr<AutomationBackend> create_automation_backend() {
    return std::make_unique<WindowsAutomationBackend>();
}

} // namespace flutter_skill

#endif // _WIN32
