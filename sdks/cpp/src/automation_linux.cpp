/**
 * flutter-skill Linux automation backend.
 *
 * Uses:
 *  - XTest extension for mouse/keyboard synthesis
 *  - XGetImage + libpng for screenshots
 *  - Xlib for window/display information
 *
 * Requires: libx11-dev, libxtst-dev, libpng-dev
 *   apt install libx11-dev libxtst-dev libpng-dev
 */

#if defined(__linux__)

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/XTest.h>
#include <X11/keysym.h>
#include <png.h>

#include "flutter_skill/bridge.h"
#include "json_rpc.h"
#include "sha1.h"  // for base64_encode

#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <vector>

namespace flutter_skill {

using namespace detail;

// ── Screenshot via XGetImage + libpng ─────────────────────────────────────

struct PngBuffer {
    std::vector<uint8_t> data;
};

static void png_write_to_buffer(png_structp png, png_bytep data, png_size_t len) {
    auto* buf = reinterpret_cast<PngBuffer*>(png_get_io_ptr(png));
    buf->data.insert(buf->data.end(), data, data + len);
}

static void png_flush_noop(png_structp) {}

static std::string capture_screen_base64(Display* dpy) {
    Window root = DefaultRootWindow(dpy);
    XWindowAttributes attrs{};
    XGetWindowAttributes(dpy, root, &attrs);

    int w = attrs.width;
    int h = attrs.height;

    XImage* img = XGetImage(dpy, root, 0, 0, w, h, AllPlanes, ZPixmap);
    if (!img) return "";

    // Encode as PNG
    PngBuffer buf;
    png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING,
                                               nullptr, nullptr, nullptr);
    png_infop info  = png_create_info_struct(png);
    png_set_write_fn(png, &buf, png_write_to_buffer, png_flush_noop);
    png_set_IHDR(png, info, w, h, 8, PNG_COLOR_TYPE_RGB,
                 PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
                 PNG_FILTER_TYPE_DEFAULT);
    png_write_info(png, info);

    std::vector<uint8_t> row(w * 3);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            unsigned long pixel = XGetPixel(img, x, y);
            row[x * 3 + 0] = (pixel >> 16) & 0xFF; // R
            row[x * 3 + 1] = (pixel >>  8) & 0xFF; // G
            row[x * 3 + 2] = (pixel >>  0) & 0xFF; // B
        }
        png_write_row(png, row.data());
    }
    png_write_end(png, nullptr);
    png_destroy_write_struct(&png, &info);
    XDestroyImage(img);

    std::string raw(reinterpret_cast<char*>(buf.data.data()), buf.data.size());
    return base64_encode(raw);
}

// ── Key mapping ────────────────────────────────────────────────────────────

static KeySym key_name_to_keysym(const std::string& key) {
    static const std::map<std::string, KeySym> table = {
        {"enter",     XK_Return},  {"return",    XK_Return},
        {"tab",       XK_Tab},     {"escape",    XK_Escape},
        {"backspace", XK_BackSpace},{"delete",   XK_Delete},
        {"space",     XK_space},
        {"up",        XK_Up},      {"down",      XK_Down},
        {"left",      XK_Left},    {"right",     XK_Right},
        {"home",      XK_Home},    {"end",       XK_End},
        {"pageup",    XK_Page_Up}, {"pagedown",  XK_Page_Down},
        {"f1",  XK_F1},  {"f2",  XK_F2},  {"f3",  XK_F3},  {"f4",  XK_F4},
        {"f5",  XK_F5},  {"f6",  XK_F6},  {"f7",  XK_F7},  {"f8",  XK_F8},
        {"f9",  XK_F9},  {"f10", XK_F10}, {"f11", XK_F11}, {"f12", XK_F12},
        {"ctrl",    XK_Control_L}, {"control", XK_Control_L},
        {"shift",   XK_Shift_L},
        {"alt",     XK_Alt_L},
        {"super",   XK_Super_L},   {"meta", XK_Super_L},
    };
    auto it = table.find(key);
    if (it != table.end()) return it->second;
    if (key.size() == 1) return (KeySym)key[0];
    return NoSymbol;
}

// ── Linux backend ──────────────────────────────────────────────────────────

class LinuxAutomationBackend : public AutomationBackend {
public:
    LinuxAutomationBackend() : dpy_(XOpenDisplay(nullptr)) {}
    ~LinuxAutomationBackend() override {
        if (dpy_) XCloseDisplay(dpy_);
    }

    ToolResult screenshot() override {
        if (!dpy_) return {false, "No X display"};
        std::string b64 = capture_screen_base64(dpy_);
        if (b64.empty()) return {false, "Screenshot failed"};

        Window root = DefaultRootWindow(dpy_);
        XWindowAttributes attrs{};
        XGetWindowAttributes(dpy_, root, &attrs);

        std::string extra =
            "\"screenshot\":" + json_str(b64) + ","
            "\"format\":\"png\","
            "\"width\":" + std::to_string(attrs.width) + ","
            "\"height\":" + std::to_string(attrs.height);
        return {true, extra};
    }

    ToolResult tap(double x, double y) override {
        if (!dpy_) return {false, "No X display"};

        // Move pointer
        XTestFakeMotionEvent(dpy_, -1, (int)x, (int)y, CurrentTime);
        // Left button down
        XTestFakeButtonEvent(dpy_, 1, True,  CurrentTime);
        // Left button up
        XTestFakeButtonEvent(dpy_, 1, False, CurrentTime);
        XFlush(dpy_);

        return {true, "\"message\":\"Tapped at (" +
                std::to_string((int)x) + "," + std::to_string((int)y) + ")\""};
    }

    ToolResult enter_text(const std::string& text) override {
        if (!dpy_) return {false, "No X display"};

        for (unsigned char c : text) {
            KeySym sym = (KeySym)c;
            KeyCode kc = XKeysymToKeycode(dpy_, sym);
            if (!kc) continue;
            XTestFakeKeyEvent(dpy_, kc, True,  CurrentTime);
            XTestFakeKeyEvent(dpy_, kc, False, CurrentTime);
        }
        XFlush(dpy_);

        return {true, "\"message\":\"Entered text\""};
    }

    ToolResult press_key(const std::string& key,
                         const std::vector<std::string>& mods) override {
        if (!dpy_) return {false, "No X display"};

        KeySym sym = key_name_to_keysym(key);
        if (sym == NoSymbol) return {false, "Unknown key: " + key};

        KeyCode kc = XKeysymToKeycode(dpy_, sym);
        if (!kc) return {false, "No keycode for: " + key};

        // Press modifiers
        std::vector<KeyCode> modcodes;
        for (const auto& m : mods) {
            KeySym msym = key_name_to_keysym(m);
            if (msym == NoSymbol) continue;
            KeyCode mkc = XKeysymToKeycode(dpy_, msym);
            if (mkc) {
                XTestFakeKeyEvent(dpy_, mkc, True, CurrentTime);
                modcodes.push_back(mkc);
            }
        }

        XTestFakeKeyEvent(dpy_, kc, True,  CurrentTime);
        XTestFakeKeyEvent(dpy_, kc, False, CurrentTime);

        // Release modifiers in reverse
        for (auto it = modcodes.rbegin(); it != modcodes.rend(); ++it)
            XTestFakeKeyEvent(dpy_, *it, False, CurrentTime);

        XFlush(dpy_);
        return {true, "\"message\":\"Pressed key: " + key + "\""};
    }

    ToolResult scroll(const std::string& direction, double amount) override {
        if (!dpy_) return {false, "No X display"};

        // XTest button 4 = scroll up, 5 = down, 6 = left, 7 = right
        unsigned int btn = 5; // down
        if (direction == "up")    btn = 4;
        if (direction == "right") btn = 7;
        if (direction == "left")  btn = 6;

        int clicks = std::max(1, (int)(amount / 120));
        for (int i = 0; i < clicks; i++) {
            XTestFakeButtonEvent(dpy_, btn, True,  CurrentTime);
            XTestFakeButtonEvent(dpy_, btn, False, CurrentTime);
        }
        XFlush(dpy_);

        return {true, "\"message\":\"Scrolled " + direction + "\""};
    }

    ToolResult inspect() override {
        if (!dpy_) return {true, "\"title\":null"};

        // Get focused window title via EWMH _NET_ACTIVE_WINDOW
        Atom net_active = XInternAtom(dpy_, "_NET_ACTIVE_WINDOW", True);
        Atom net_name   = XInternAtom(dpy_, "_NET_WM_NAME", True);
        Window root     = DefaultRootWindow(dpy_);

        Atom type_ret;
        int  fmt_ret;
        unsigned long items_ret, bytes_after;
        unsigned char* data = nullptr;

        XGetWindowProperty(dpy_, root, net_active, 0, 1, False,
                           XA_WINDOW, &type_ret, &fmt_ret,
                           &items_ret, &bytes_after, &data);
        Window active = 0;
        if (data) {
            active = *(Window*)data;
            XFree(data);
        }

        std::string title;
        if (active) {
            XTextProperty text_prop{};
            if (XGetWMName(dpy_, active, &text_prop) && text_prop.value) {
                title = reinterpret_cast<char*>(text_prop.value);
                XFree(text_prop.value);
            }
        }

        return {true, "\"title\":" + json_str(title)};
    }

    ToolResult get_focused_window_title() override {
        return inspect();
    }

private:
    Display* dpy_;
};

// ── Factory ────────────────────────────────────────────────────────────────

std::unique_ptr<AutomationBackend> create_automation_backend() {
    return std::make_unique<LinuxAutomationBackend>();
}

} // namespace flutter_skill

#endif // __linux__
