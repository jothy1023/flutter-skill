/**
 * flutter-skill macOS automation backend.
 *
 * Uses:
 *  - CoreGraphics CGEvent for mouse/keyboard synthesis
 *  - CoreGraphics CGDisplayCreateImageForRect for screenshots
 *  - Accessibility API (AXUIElement) for UI inspection
 */

#if defined(__APPLE__)

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#include "flutter_skill/bridge.h"
#include "json_rpc.h"
#include "sha1.h"

#include <map>
#include <string>
#include <vector>

namespace flutter_skill {

using namespace detail;

// ── Screenshot ─────────────────────────────────────────────────────────────

static std::string capture_screen_base64() {
    // CGWindowListCreateImage was removed in macOS 15; delegate to screencapture(1).
    // Requires Screen Recording permission on macOS 10.15+.
    NSString* tmpPath = [NSTemporaryDirectory()
                         stringByAppendingPathComponent:@"flutter_skill_cap.png"];

    NSTask* task = [NSTask new];
    task.launchPath = @"/usr/sbin/screencapture";
    task.arguments  = @[@"-x", @"-t", @"png", tmpPath];
    [task launch];
    [task waitUntilExit];

    NSData* data = [NSData dataWithContentsOfFile:tmpPath];
    if (!data) return "";

    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];

    std::string raw((const char*)data.bytes, data.length);
    return base64_encode(raw);
}

// ── Key mapping ────────────────────────────────────────────────────────────

static CGKeyCode key_name_to_code(const std::string& key) {
    static const std::map<std::string, CGKeyCode> table = {
        {"return",    36}, {"enter",     36},
        {"tab",       48}, {"escape",    53},
        {"backspace", 51}, {"delete",    117},
        {"space",     49},
        {"up",       126}, {"down",     125},
        {"left",     123}, {"right",    124},
        {"home",     115}, {"end",      119},
        {"pageup",   116}, {"pagedown", 121},
        // Modifier keys
        {"shift",     56}, {"lshift",    56}, {"rshift",    60},
        {"ctrl",      59}, {"control",   59}, {"lctrl",     59}, {"rctrl",     62},
        {"alt",       58}, {"option",    58}, {"lalt",      58}, {"ralt",      61},
        {"cmd",       55}, {"command",   55}, {"meta",      55},
        // Function keys
        {"f1", 122}, {"f2", 120}, {"f3",  99}, {"f4",  118},
        {"f5", 96},  {"f6",  97}, {"f7",  98}, {"f8",  100},
        {"f9", 101}, {"f10",109}, {"f11", 103}, {"f12", 111},
    };
    auto it = table.find(key);
    if (it != table.end()) return it->second;

    // Single-character keys: use the character code (ASCII)
    // Note: This is a simplification; for a full solution use TIS/TSM APIs.
    if (key.size() == 1) {
        // Map common ASCII chars to virtual key codes via UCKeyboard
        // For brevity, return 0 and let the caller use CGEventKeyboardSetUnicodeString
        return 0xFF; // sentinel
    }
    return 0xFF;
}

static CGEventFlags modifiers_to_flags(const std::vector<std::string>& mods) {
    CGEventFlags flags = 0;
    for (const auto& m : mods) {
        if (m == "ctrl"  || m == "control") flags |= kCGEventFlagMaskControl;
        if (m == "shift")                   flags |= kCGEventFlagMaskShift;
        if (m == "alt"   || m == "option")  flags |= kCGEventFlagMaskAlternate;
        if (m == "cmd"   || m == "command" || m == "meta") flags |= kCGEventFlagMaskCommand;
    }
    return flags;
}

// ── macOS backend ──────────────────────────────────────────────────────────

class MacOSAutomationBackend : public AutomationBackend {
public:
    ToolResult screenshot() override {
        std::string b64 = capture_screen_base64();
        if (b64.empty()) return {false, "Screenshot capture failed"};

        NSScreen* screen = [NSScreen mainScreen];
        NSRect frame = screen ? screen.frame : NSMakeRect(0, 0, 0, 0);
        size_t w = (size_t)frame.size.width;
        size_t h = (size_t)frame.size.height;
        (void)w; (void)h; // used below

        std::string extra =
            "\"screenshot\":" + json_str(b64) + ","
            "\"format\":\"png\","
            "\"width\":" + std::to_string(w) + ","
            "\"height\":" + std::to_string(h);
        return {true, extra};
    }

    ToolResult tap(double x, double y) override {
        CGPoint pt = CGPointMake(x, y);

        // Mouse down
        CGEventRef down = CGEventCreateMouseEvent(
            nullptr, kCGEventLeftMouseDown, pt, kCGMouseButtonLeft);
        CGEventPost(kCGSessionEventTap, down);
        CFRelease(down);

        // Mouse up
        CGEventRef up = CGEventCreateMouseEvent(
            nullptr, kCGEventLeftMouseUp, pt, kCGMouseButtonLeft);
        CGEventPost(kCGSessionEventTap, up);
        CFRelease(up);

        return {true, "\"message\":\"Tapped at (" +
                std::to_string((int)x) + "," + std::to_string((int)y) + ")\""};
    }

    ToolResult enter_text(const std::string& text) override {
        // Convert UTF-8 to UTF-16 for CGEvent
        NSString* nsStr = [NSString stringWithUTF8String:text.c_str()];
        if (!nsStr) return {false, "Invalid UTF-8 text"};

        for (NSUInteger i = 0; i < nsStr.length; i++) {
            UniChar ch = [nsStr characterAtIndex:i];
            CGEventRef down = CGEventCreateKeyboardEvent(nullptr, 0, true);
            CGEventKeyboardSetUnicodeString(down, 1, &ch);
            CGEventPost(kCGSessionEventTap, down);
            CFRelease(down);

            CGEventRef up = CGEventCreateKeyboardEvent(nullptr, 0, false);
            CGEventKeyboardSetUnicodeString(up, 1, &ch);
            CGEventPost(kCGSessionEventTap, up);
            CFRelease(up);
        }

        return {true, "\"message\":\"Entered text\""};
    }

    ToolResult press_key(const std::string& key,
                         const std::vector<std::string>& modifiers) override {
        CGKeyCode code = key_name_to_code(key);
        CGEventFlags flags = modifiers_to_flags(modifiers);

        if (code == 0xFF && key.size() == 1) {
            // Single character — use unicode injection
            UniChar ch = (UniChar)key[0];
            CGEventRef down = CGEventCreateKeyboardEvent(nullptr, 0, true);
            CGEventSetFlags(down, flags);
            CGEventKeyboardSetUnicodeString(down, 1, &ch);
            CGEventPost(kCGSessionEventTap, down);
            CFRelease(down);

            CGEventRef up = CGEventCreateKeyboardEvent(nullptr, 0, false);
            CGEventSetFlags(up, flags);
            CGEventKeyboardSetUnicodeString(up, 1, &ch);
            CGEventPost(kCGSessionEventTap, up);
            CFRelease(up);

            return {true, "\"message\":\"Pressed key: " + key + "\""};
        }

        if (code == 0xFF) return {false, "Unknown key: " + key};

        CGEventRef down = CGEventCreateKeyboardEvent(nullptr, code, true);
        CGEventSetFlags(down, flags);
        CGEventPost(kCGSessionEventTap, down);
        CFRelease(down);

        CGEventRef up = CGEventCreateKeyboardEvent(nullptr, code, false);
        CGEventSetFlags(up, flags);
        CGEventPost(kCGSessionEventTap, up);
        CFRelease(up);

        return {true, "\"message\":\"Pressed key: " + key + "\""};
    }

    ToolResult scroll(const std::string& direction, double amount) override {
        // Positive = scroll down/right; negative = scroll up/left
        int32_t dy = 0, dx = 0;
        if (direction == "down")  dy = -(int32_t)amount;
        if (direction == "up")    dy =  (int32_t)amount;
        if (direction == "right") dx = -(int32_t)amount;
        if (direction == "left")  dx =  (int32_t)amount;

        CGEventRef scroll = CGEventCreateScrollWheelEvent(
            nullptr, kCGScrollEventUnitPixel, 2, dy, dx);
        CGEventPost(kCGSessionEventTap, scroll);
        CFRelease(scroll);

        return {true, "\"message\":\"Scrolled " + direction + "\""};
    }

    ToolResult inspect() override {
        // Return the frontmost application's accessibility root info
        pid_t pid = 0;
        NSRunningApplication* frontApp =
            [[NSWorkspace sharedWorkspace] frontmostApplication];
        if (frontApp) pid = frontApp.processIdentifier;

        AXUIElementRef appRef = AXUIElementCreateApplication(pid);
        CFTypeRef titleRef = nullptr;
        AXUIElementCopyAttributeValue(appRef, kAXTitleAttribute, &titleRef);

        std::string title = "(unknown)";
        if (titleRef && CFGetTypeID(titleRef) == CFStringGetTypeID()) {
            const char* t = CFStringGetCStringPtr(
                (CFStringRef)titleRef, kCFStringEncodingUTF8);
            if (t) title = t;
        }

        if (titleRef)  CFRelease(titleRef);
        if (appRef)    CFRelease(appRef);

        std::string bundle = frontApp ? frontApp.bundleIdentifier.UTF8String : "";
        std::string name   = frontApp ? frontApp.localizedName.UTF8String : "";

        return {true,
            "\"title\":" + json_str(title) + ","
            "\"bundle_id\":" + json_str(bundle) + ","
            "\"app_name\":" + json_str(name)};
    }

    ToolResult get_focused_window_title() override {
        NSRunningApplication* frontApp =
            [[NSWorkspace sharedWorkspace] frontmostApplication];
        if (!frontApp) return {true, "\"title\":null"};

        pid_t pid = frontApp.processIdentifier;
        AXUIElementRef app = AXUIElementCreateApplication(pid);

        CFTypeRef focusedWindow = nullptr;
        AXUIElementCopyAttributeValue(
            app, kAXFocusedWindowAttribute, &focusedWindow);

        std::string title;
        if (focusedWindow) {
            CFTypeRef t = nullptr;
            AXUIElementCopyAttributeValue(
                (AXUIElementRef)focusedWindow, kAXTitleAttribute, &t);
            if (t && CFGetTypeID(t) == CFStringGetTypeID()) {
                const char* cstr = CFStringGetCStringPtr(
                    (CFStringRef)t, kCFStringEncodingUTF8);
                if (cstr) title = cstr;
            }
            if (t) CFRelease(t);
            CFRelease(focusedWindow);
        }
        CFRelease(app);

        return {true, "\"title\":" + json_str(title)};
    }
};

// ── Factory ────────────────────────────────────────────────────────────────

std::unique_ptr<AutomationBackend> create_automation_backend() {
    return std::make_unique<MacOSAutomationBackend>();
}

} // namespace flutter_skill

#endif // __APPLE__
