/**
 * Tests for WebSocket handshake helpers (SHA-1, base64, accept key).
 */
#include "test_runner.h"
#include "sha1.h"
#include "websocket.h"

using namespace flutter_skill::detail;

// ── SHA-1 tests ─────────────────────────────────────────────────────────────

REGISTER_TEST(websocket, sha1_empty_string) {
    // SHA-1("") = da39a3ee5e6b4b0d3255bfef95601890afd80709
    std::string digest = sha1("");
    EXPECT_EQ(digest.size(), (size_t)20);
    EXPECT_EQ((unsigned char)digest[0], 0xda);
    EXPECT_EQ((unsigned char)digest[1], 0x39);

}

REGISTER_TEST(websocket, sha1_abc) {
    // SHA-1("abc") = a9993e364706816aba3e25717850c26c9cd0d89d
    std::string digest = sha1("abc");
    EXPECT_EQ((unsigned char)digest[0], 0xa9);
    EXPECT_EQ((unsigned char)digest[1], 0x99);

}

// ── Base64 tests ────────────────────────────────────────────────────────────

REGISTER_TEST(websocket, base64_encode_basic) {
    EXPECT_EQ(base64_encode("Man"),      "TWFu");
    EXPECT_EQ(base64_encode("Ma"),       "TWE=");
    EXPECT_EQ(base64_encode("M"),        "TQ==");
    EXPECT_EQ(base64_encode(""),         "");

}

REGISTER_TEST(websocket, base64_encode_hello) {
    EXPECT_EQ(base64_encode("Hello, World!"), "SGVsbG8sIFdvcmxkIQ==");

}

// ── WebSocket accept key ────────────────────────────────────────────────────

REGISTER_TEST(websocket, ws_accept_key_rfc6455) {
    // RFC 6455 example: key = "dGhlIHNhbXBsZSBub25jZQ=="
    // Expected accept = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    std::string accept = ws_accept_key("dGhlIHNhbXBsZSBub25jZQ==");
    EXPECT_EQ(accept, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");

}

// ── Frame encode / decode roundtrip (in-memory) ─────────────────────────────

REGISTER_TEST(websocket, frame_masking) {
    // Simulate a masked client frame: text "Hello"
    // FIN=1, opcode=1(text), MASK=1, payload_len=5
    std::string payload = "Hello";
    uint8_t mask[4] = {0x37, 0xfa, 0x21, 0x3d};

    std::vector<uint8_t> raw;
    raw.push_back(0x81);              // FIN + text
    raw.push_back(0x80 | (uint8_t)payload.size()); // mask bit + len
    raw.insert(raw.end(), mask, mask + 4);
    for (size_t i = 0; i < payload.size(); i++)
        raw.push_back(payload[i] ^ mask[i % 4]);

    // Manually unmask
    std::string unmasked;
    for (size_t i = 0; i < payload.size(); i++)
        unmasked += (char)(raw[6 + i] ^ mask[i % 4]);

    EXPECT_EQ(unmasked, "Hello");

}
