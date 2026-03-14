/**
 * Integration tests for the FlutterSkillBridge.
 *
 * These tests:
 *  1. Inject a mock automation backend.
 *  2. Start the bridge on a random high port.
 *  3. Connect via a raw TCP socket + WebSocket handshake.
 *  4. Send JSON-RPC messages and verify responses.
 */
#include "test_runner.h"
#include "json_rpc.h"
#include "sha1.h"
#include "websocket.h"
#include "flutter_skill/bridge.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <random>
#include <thread>

#ifdef _WIN32
#  include <winsock2.h>
#  include <ws2tcpip.h>
#else
#  include <arpa/inet.h>
#  include <netinet/in.h>
#  include <sys/socket.h>
#  include <unistd.h>
#endif

using namespace flutter_skill;
using namespace flutter_skill::detail;

// ── Mock backend ────────────────────────────────────────────────────────────

class MockBackend : public AutomationBackend {
public:
    int tap_count    = 0;
    int text_count   = 0;
    int key_count    = 0;
    int scroll_count = 0;

    ToolResult screenshot() override {
        return {true, "\"screenshot\":\"data\",\"format\":\"png\",\"width\":1920,\"height\":1080"};
    }
    ToolResult tap(double x, double y) override {
        tap_count++;
        return {true, "\"message\":\"tapped\",\"x\":" + std::to_string(x) +
                ",\"y\":" + std::to_string(y)};
    }
    ToolResult enter_text(const std::string& text) override {
        text_count++;
        return {true, "\"message\":\"entered\",\"text\":" + json_str(text)};
    }
    ToolResult press_key(const std::string& key,
                         const std::vector<std::string>&) override {
        key_count++;
        return {true, "\"message\":\"key pressed\",\"key\":" + json_str(key)};
    }
    ToolResult scroll(const std::string& dir, double amount) override {
        scroll_count++;
        return {true, "\"message\":\"scrolled\",\"direction\":" + json_str(dir) +
                ",\"amount\":" + std::to_string(amount)};
    }
    ToolResult inspect() override {
        return {true, "\"title\":\"Mock Window\""};
    }
    ToolResult get_focused_window_title() override {
        return {true, "\"title\":\"Mock Window\""};
    }
};

// ── Client helpers ──────────────────────────────────────────────────────────

static int make_client(int port) {
#ifdef _WIN32
    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);
#endif
    int fd = (int)::socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons((uint16_t)port);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");

    if (::connect(fd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        sock_close(fd);
        return -1;
    }
    return fd;
}

static bool do_upgrade(int fd) {
    // Generate a random 16-byte nonce, base64-encode it
    uint8_t nonce[16];
    std::mt19937 rng(std::random_device{}());
    for (auto& b : nonce) b = (uint8_t)(rng() & 0xFF);
    std::string raw_nonce(reinterpret_cast<char*>(nonce), 16);
    std::string key = base64_encode(raw_nonce);

    std::string req =
        "GET / HTTP/1.1\r\n"
        "Host: 127.0.0.1\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: " + key + "\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        "\r\n";

    sock_send(fd, req.data(), req.size());

    // Read HTTP response
    std::string resp;
    char c;
    while (resp.size() < 4 || resp.substr(resp.size() - 4) != "\r\n\r\n") {
        ssize_t r = sock_recv(fd, &c, 1);
        if (r <= 0) return false;
        resp += c;
    }
    return resp.find("101") != std::string::npos;
}

static std::string send_rpc(int fd, int id, const std::string& method,
                             const std::string& params = "{}") {
    std::string msg = "{\"id\":" + std::to_string(id) +
                      ",\"method\":\"" + method + "\"" +
                      ",\"params\":" + params + "}";

    // Client frames are masked (RFC 6455 §5.3)
    uint8_t mask[4] = {0x12, 0x34, 0x56, 0x78};
    std::vector<uint8_t> frame;
    frame.push_back(0x81);  // FIN + text
    if (msg.size() < 126) {
        frame.push_back(0x80 | (uint8_t)msg.size());
    } else {
        frame.push_back(0x80 | 126);
        frame.push_back((uint8_t)(msg.size() >> 8));
        frame.push_back((uint8_t)(msg.size() & 0xFF));
    }
    frame.insert(frame.end(), mask, mask + 4);
    for (size_t i = 0; i < msg.size(); i++)
        frame.push_back(msg[i] ^ mask[i % 4]);

    sock_send(fd, frame.data(), frame.size());

    // Read response frame
    WsFrame resp;
    if (!ws_read_frame(fd, resp)) return "";
    return resp.payload;
}

// ── Helper: find a free port ────────────────────────────────────────────────

static int find_free_port() {
    int fd = (int)::socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_port        = 0;
    addr.sin_addr.s_addr = INADDR_ANY;
    ::bind(fd, (sockaddr*)&addr, sizeof(addr));
    socklen_t len = sizeof(addr);
    ::getsockname(fd, (sockaddr*)&addr, &len);
    int port = ntohs(addr.sin_port);
    sock_close(fd);
    return port;
}

// ── Test fixture ────────────────────────────────────────────────────────────

struct BridgeFixture {
    int                              port;
    MockBackend*                     mock;
    std::unique_ptr<FlutterSkillBridge> bridge;
    int                              client_fd = -1;

    BridgeFixture() : port(find_free_port()), mock(new MockBackend()) {
        BridgeOptions opts;
        opts.port = port;
        bridge    = std::make_unique<FlutterSkillBridge>(opts);
        bridge->set_backend(std::unique_ptr<MockBackend>(mock));
        bridge->start();
        std::this_thread::sleep_for(std::chrono::milliseconds(50));

        client_fd = make_client(port);
        if (client_fd >= 0) do_upgrade(client_fd);
    }

    ~BridgeFixture() {
        if (client_fd >= 0) sock_close(client_fd);
        bridge->stop();
    }
};

// ── Tests ───────────────────────────────────────────────────────────────────

REGISTER_TEST(bridge, ping_pong) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 1, "ping");
    EXPECT_CONTAINS(resp, "\"pong\":true");

}

REGISTER_TEST(bridge, initialize_returns_capabilities) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 2, "initialize");
    EXPECT_CONTAINS(resp, "\"framework\":\"cpp\"");
    EXPECT_CONTAINS(resp, "\"capabilities\"");
    EXPECT_CONTAINS(resp, "\"tap\"");
    EXPECT_CONTAINS(resp, "\"screenshot\"");

}

REGISTER_TEST(bridge, screenshot) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 3, "screenshot");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_CONTAINS(resp, "\"screenshot\"");

}

REGISTER_TEST(bridge, tap) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 4, "tap", "{\"x\":100,\"y\":200}");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_EQ(f.mock->tap_count, 1);

}

REGISTER_TEST(bridge, enter_text) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 5, "enter_text", "{\"text\":\"hello\"}");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_EQ(f.mock->text_count, 1);

}

REGISTER_TEST(bridge, press_key) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 6, "press_key",
                                "{\"key\":\"enter\",\"modifiers\":[]}");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_EQ(f.mock->key_count, 1);

}

REGISTER_TEST(bridge, scroll) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 7, "scroll",
                                "{\"direction\":\"down\",\"amount\":300}");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_EQ(f.mock->scroll_count, 1);

}

REGISTER_TEST(bridge, inspect) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 8, "inspect");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_CONTAINS(resp, "Mock Window");

}

REGISTER_TEST(bridge, unknown_method_returns_error) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 9, "nonexistent_method");
    EXPECT_CONTAINS(resp, "\"success\":false");
    EXPECT_CONTAINS(resp, "Unknown method");

}

REGISTER_TEST(bridge, get_logs) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    std::string resp = send_rpc(f.client_fd, 10, "get_logs");
    EXPECT_CONTAINS(resp, "\"success\":true");
    EXPECT_CONTAINS(resp, "\"logs\"");

}

REGISTER_TEST(bridge, multiple_sequential_requests) {
    BridgeFixture f;
    EXPECT_TRUE(f.client_fd >= 0);

    for (int i = 0; i < 5; i++) {
        std::string resp = send_rpc(f.client_fd, 100 + i, "ping");
        EXPECT_CONTAINS(resp, "pong");
    }

}

// ── Platform backend smoke test ──────────────────────────────────────────────

REGISTER_TEST(platform, backend_creation) {
    auto backend = create_automation_backend();
    EXPECT_TRUE(backend != nullptr);

}

REGISTER_TEST(platform, backend_get_focused_window) {
    auto backend = create_automation_backend();
    EXPECT_TRUE(backend != nullptr);
    // This may return an empty title in a CI environment; just check it doesn't crash.
    auto result = backend->get_focused_window_title();
    // success is true even if title is empty/null
    EXPECT_TRUE(result.success);

}

// ── Main ────────────────────────────────────────────────────────────────────

int main(int argc, char* argv[]) {
    std::string filter = "all";
    if (argc > 1) filter = argv[1];

    fprintf(stdout, "flutter-skill C++ SDK tests [suite: %s]\n\n", filter.c_str());
    return run_tests(filter);
}
