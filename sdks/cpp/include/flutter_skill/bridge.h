/**
 * flutter-skill C++ Bridge SDK
 *
 * Implements the flutter-skill bridge protocol (JSON-RPC 2.0 over WebSocket)
 * so that AI agents can automate native C++ desktop applications.
 *
 * Supports: Windows (UI Automation), macOS (AXUIElement), Linux (XTest/AT-SPI)
 *
 * Usage:
 *   #include <flutter_skill/bridge.h>
 *
 *   int main() {
 *     flutter_skill::FlutterSkillBridge bridge;
 *     bridge.start();   // non-blocking
 *     bridge.wait();    // block until stopped
 *   }
 *
 * The bridge listens on ws://127.0.0.1:18118 by default.
 */

#pragma once

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace flutter_skill {

// ── Options ────────────────────────────────────────────────────────────────

struct BridgeOptions {
    int         port     = 18118;
    std::string app_name = "cpp-app";
    std::string host     = "127.0.0.1";
};

// ── Automation backend (platform-specific) ─────────────────────────────────

struct ToolResult {
    bool        success;
    std::string json; ///< Full JSON object string (without outer braces)
};

class AutomationBackend {
public:
    virtual ~AutomationBackend() = default;

    virtual ToolResult screenshot()                                                   = 0;
    virtual ToolResult tap(double x, double y)                                        = 0;
    virtual ToolResult enter_text(const std::string& text)                            = 0;
    virtual ToolResult press_key(const std::string& key,
                                 const std::vector<std::string>& modifiers)           = 0;
    virtual ToolResult scroll(const std::string& direction, double amount)            = 0;
    virtual ToolResult inspect()                                                      = 0;
    virtual ToolResult get_focused_window_title()                                     = 0;
};

/// Create the platform-specific backend (macOS / Windows / Linux).
std::unique_ptr<AutomationBackend> create_automation_backend();

// ── Bridge ─────────────────────────────────────────────────────────────────

class FlutterSkillBridge {
public:
    explicit FlutterSkillBridge(BridgeOptions opts = {});
    ~FlutterSkillBridge();

    /// Start listening (non-blocking — spawns a background thread).
    void start();

    /// Stop the bridge and close the listening socket.
    void stop();

    /// Block until the bridge stops.
    void wait();

    bool is_running() const noexcept { return running_.load(); }

    // Allow injecting a custom backend (useful for testing).
    void set_backend(std::unique_ptr<AutomationBackend> backend);

private:
    BridgeOptions                    opts_;
    std::unique_ptr<AutomationBackend> backend_;
    std::thread                      server_thread_;
    std::atomic<bool>                running_{false};
    int                              server_fd_{-1};

    void        run_server();
    void        handle_client(int fd);
    void        handle_http(int fd, const std::string& request);
    std::string dispatch(const std::string& method, const std::string& params_json);
    std::string make_success(const std::string& extra = "");
    std::string make_error_result(const std::string& msg);
};

// ── SDK version ────────────────────────────────────────────────────────────

inline const char* sdk_version() { return "0.1.0"; }

} // namespace flutter_skill
