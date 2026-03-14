/**
 * flutter-skill C++ bridge — WebSocket server + JSON-RPC dispatcher.
 */

#include "flutter_skill/bridge.h"

#include "json_rpc.h"
#include "sha1.h"    // must come before websocket.h (defines ws_accept_key)
#include "websocket.h"

#ifdef _WIN32
#  include <winsock2.h>
#  include <ws2tcpip.h>
#else
#  include <arpa/inet.h>
#  include <netinet/in.h>
#  include <sys/socket.h>
#  include <unistd.h>
#endif

#include <cstdio>
#include <cstring>
#include <stdexcept>

namespace flutter_skill {

using namespace detail;

// ── Construction / destruction ─────────────────────────────────────────────

FlutterSkillBridge::FlutterSkillBridge(BridgeOptions opts)
    : opts_(std::move(opts)), backend_(create_automation_backend()) {}

FlutterSkillBridge::~FlutterSkillBridge() { stop(); }

void FlutterSkillBridge::set_backend(std::unique_ptr<AutomationBackend> backend) {
    backend_ = std::move(backend);
}

// ── Lifecycle ──────────────────────────────────────────────────────────────

void FlutterSkillBridge::start() {
    if (running_.load()) return;

#ifdef _WIN32
    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);
#endif

    // Create listening socket
    server_fd_ = (int)::socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd_ < 0) throw std::runtime_error("socket() failed");

    int yes = 1;
#ifdef _WIN32
    ::setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, (char*)&yes, sizeof(yes));
#else
    ::setsockopt(server_fd_, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
#endif

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons((uint16_t)opts_.port);
    addr.sin_addr.s_addr = inet_addr(opts_.host.c_str());

    if (::bind(server_fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        sock_close(server_fd_);
        throw std::runtime_error("bind() failed on port " + std::to_string(opts_.port));
    }
    ::listen(server_fd_, 8);

    running_ = true;
    server_thread_ = std::thread([this] { run_server(); });
}

void FlutterSkillBridge::stop() {
    if (!running_.exchange(false)) return;
    if (server_fd_ >= 0) {
        sock_close(server_fd_);
        server_fd_ = -1;
    }
    if (server_thread_.joinable()) server_thread_.join();
#ifdef _WIN32
    WSACleanup();
#endif
}

void FlutterSkillBridge::wait() {
    if (server_thread_.joinable()) server_thread_.join();
}

// ── Server loop ────────────────────────────────────────────────────────────

void FlutterSkillBridge::run_server() {
    fprintf(stderr, "[flutter-skill] Bridge listening on ws://%s:%d\n",
            opts_.host.c_str(), opts_.port);

    while (running_.load()) {
        sockaddr_in client_addr{};
#ifdef _WIN32
        int addr_len = sizeof(client_addr);
#else
        socklen_t addr_len = sizeof(client_addr);
#endif
        int client_fd = (int)::accept(server_fd_,
                                      reinterpret_cast<sockaddr*>(&client_addr),
                                      &addr_len);
        if (client_fd < 0) {
            if (!running_.load()) break; // stopped
            continue;
        }
        // Handle each client synchronously (simple, low-contention).
        // For production use, spawn a thread or use async I/O.
        handle_client(client_fd);
        sock_close(client_fd);
    }

    fprintf(stderr, "[flutter-skill] Bridge stopped.\n");
}

// ── Client handling ────────────────────────────────────────────────────────

void FlutterSkillBridge::handle_client(int fd) {
    // 1. Read HTTP upgrade request
    std::string http_req = read_http_request(fd);
    if (http_req.empty()) return;

    // 2. Perform WebSocket handshake
    if (!ws_handshake(fd, http_req)) return;

    fprintf(stderr, "[flutter-skill] Client connected\n");

    // 3. Process WebSocket frames
    while (running_.load()) {
        WsFrame frame;
        if (!ws_read_frame(fd, frame)) break;

        switch (frame.opcode) {
            case WsOpcode::Ping:
                ws_send_pong(fd, frame.payload);
                break;

            case WsOpcode::Close:
                ws_send_close(fd);
                goto done;

            case WsOpcode::Text: {
                // Parse JSON-RPC
                const std::string& msg = frame.payload;
                std::string id     = json_get(msg, "id");
                std::string method = json_get(msg, "method");
                std::string params = json_get(msg, "params");
                if (id.empty()) id = "null";
                if (params.empty()) params = "{}";

                // Wrap id as JSON (preserve number vs. string)
                // json_get returns the raw value for numbers, so leave as-is.
                // For string ids json_get strips quotes — re-quote them.
                // Simple heuristic: if original id token starts with '"', re-quote.
                {
                    size_t id_pos = msg.find("\"id\"");
                    if (id_pos != std::string::npos) {
                        size_t v = msg.find_first_not_of(" \t:", id_pos + 4);
                        if (v != std::string::npos && msg[v] == '"') {
                            id = json_str(id); // was a string id
                        }
                    }
                }

                std::string result = dispatch(method, params);
                std::string response = rpc_ok(id, result);
                ws_send_text(fd, response);
                break;
            }

            default:
                break;
        }
    }
done:
    fprintf(stderr, "[flutter-skill] Client disconnected\n");
}

// ── JSON-RPC dispatcher ────────────────────────────────────────────────────

std::string FlutterSkillBridge::dispatch(const std::string& method,
                                          const std::string& params) {
    // Health check
    if (method == "ping") {
        return result_ok("\"pong\":true");
    }

    // Capability advertisement
    if (method == "initialize" || method == "getInfo") {
        return "{"
               "\"success\":true,"
               "\"framework\":\"cpp\","
               "\"app_name\":" + json_str(opts_.app_name) + ","
               "\"sdk_version\":" + json_str(sdk_version()) + ","
               "\"capabilities\":["
               "\"initialize\",\"ping\",\"inspect\",\"tap\",\"enter_text\","
               "\"press_key\",\"scroll\",\"screenshot\",\"get_focused_window_title\","
               "\"get_logs\",\"clear_logs\""
               "]}";
    }

    if (method == "get_logs") {
        return result_ok("\"logs\":[]");
    }
    if (method == "clear_logs") {
        return result_ok();
    }

    // Delegate to platform backend
    if (!backend_) return result_err("No automation backend available");

    try {
        ToolResult r;

        if (method == "screenshot") {
            r = backend_->screenshot();
        } else if (method == "tap") {
            double x = 0, y = 0;
            std::string sx = json_get(params, "x");
            std::string sy = json_get(params, "y");
            if (!sx.empty()) x = std::stod(sx);
            if (!sy.empty()) y = std::stod(sy);
            r = backend_->tap(x, y);
        } else if (method == "enter_text") {
            std::string text = json_get(params, "text");
            r = backend_->enter_text(text);
        } else if (method == "press_key") {
            std::string key = json_get(params, "key");
            std::vector<std::string> mods;
            // Basic modifier extraction: "modifiers": ["ctrl","shift"]
            std::string mods_raw = json_get(params, "modifiers");
            if (!mods_raw.empty() && mods_raw.front() == '[') {
                size_t p = 0;
                while ((p = mods_raw.find('"', p)) != std::string::npos) {
                    size_t q = mods_raw.find('"', p + 1);
                    if (q == std::string::npos) break;
                    mods.push_back(mods_raw.substr(p + 1, q - p - 1));
                    p = q + 1;
                }
            }
            r = backend_->press_key(key, mods);
        } else if (method == "scroll") {
            std::string dir = json_get(params, "direction");
            if (dir.empty()) dir = "down";
            double amount = 300;
            std::string sa = json_get(params, "amount");
            if (!sa.empty()) amount = std::stod(sa);
            r = backend_->scroll(dir, amount);
        } else if (method == "inspect") {
            r = backend_->inspect();
        } else if (method == "get_focused_window_title") {
            r = backend_->get_focused_window_title();
        } else {
            return result_err("Unknown method: " + method);
        }

        if (r.success) {
            return r.json.empty() ? result_ok() : result_ok(r.json);
        } else {
            return result_err(r.json);
        }
    } catch (const std::exception& e) {
        return result_err(std::string("Exception: ") + e.what());
    }
}

std::string FlutterSkillBridge::make_success(const std::string& extra) {
    return result_ok(extra);
}

std::string FlutterSkillBridge::make_error_result(const std::string& msg) {
    return result_err(msg);
}

} // namespace flutter_skill
