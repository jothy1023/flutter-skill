/**
 * Minimal RFC 6455 WebSocket frame parser / writer.
 * Text-frame only (no binary, no extensions).
 */
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#ifdef _WIN32
#  include <winsock2.h>
#  pragma comment(lib, "ws2_32.lib")
   using ssize_t = SSIZE_T;
#else
#  include <sys/socket.h>
#  include <unistd.h>
#endif

namespace flutter_skill::detail {

// ── Low-level I/O helpers ──────────────────────────────────────────────────

inline ssize_t sock_send(int fd, const void* buf, size_t len) {
#ifdef _WIN32
    return ::send(fd, (const char*)buf, (int)len, 0);
#else
    return ::send(fd, buf, len, MSG_NOSIGNAL);
#endif
}

inline ssize_t sock_recv(int fd, void* buf, size_t len) {
#ifdef _WIN32
    return ::recv(fd, (char*)buf, (int)len, 0);
#else
    return ::recv(fd, buf, len, 0);
#endif
}

inline void sock_close(int fd) {
#ifdef _WIN32
    ::closesocket(fd);
#else
    ::close(fd);
#endif
}

/// Read exactly `n` bytes or return false on error/EOF.
inline bool recv_all(int fd, uint8_t* buf, size_t n) {
    size_t got = 0;
    while (got < n) {
        ssize_t r = sock_recv(fd, buf + got, n - got);
        if (r <= 0) return false;
        got += (size_t)r;
    }
    return true;
}

// ── HTTP upgrade handshake ─────────────────────────────────────────────────

/// Read headers until double CRLF.
inline std::string read_http_request(int fd) {
    std::string req;
    char c;
    while (true) {
        ssize_t r = sock_recv(fd, &c, 1);
        if (r <= 0) break;
        req += c;
        if (req.size() >= 4 && req.substr(req.size() - 4) == "\r\n\r\n") break;
    }
    return req;
}

/// Extract header value (case-insensitive name match).
inline std::string get_header(const std::string& request, const std::string& name) {
    // Search line by line
    size_t pos = 0;
    while (pos < request.size()) {
        size_t eol = request.find("\r\n", pos);
        if (eol == std::string::npos) break;
        std::string line = request.substr(pos, eol - pos);
        pos = eol + 2;
        size_t colon = line.find(':');
        if (colon == std::string::npos) continue;
        std::string hname = line.substr(0, colon);
        // Case-insensitive comparison
        if (hname.size() != name.size()) continue;
        bool match = true;
        for (size_t i = 0; i < hname.size(); i++) {
            if (tolower((unsigned char)hname[i]) != tolower((unsigned char)name[i])) {
                match = false; break;
            }
        }
        if (!match) continue;
        size_t vstart = line.find_first_not_of(" \t", colon + 1);
        if (vstart == std::string::npos) return "";
        return line.substr(vstart);
    }
    return "";
}

/// Perform the WebSocket upgrade handshake. Returns true on success.
inline bool ws_handshake(int fd, const std::string& request) {
    std::string key = get_header(request, "Sec-WebSocket-Key");
    if (key.empty()) return false;

    std::string accept = ws_accept_key(key);
    std::string response =
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Accept: " + accept + "\r\n"
        "\r\n";

    return sock_send(fd, response.data(), response.size()) > 0;
}

// ── Frame opcodes ─────────────────────────────────────────────────────────

enum class WsOpcode : uint8_t {
    Continuation = 0x0,
    Text         = 0x1,
    Binary       = 0x2,
    Close        = 0x8,
    Ping         = 0x9,
    Pong         = 0xA,
};

// ── Frame reading ─────────────────────────────────────────────────────────

struct WsFrame {
    bool      fin;
    WsOpcode  opcode;
    bool      masked;
    uint64_t  payload_len;
    uint8_t   mask_key[4];
    std::string payload;
};

/// Read one WebSocket frame from the socket.
/// Returns false on socket error / connection close.
inline bool ws_read_frame(int fd, WsFrame& frame) {
    uint8_t header[2];
    if (!recv_all(fd, header, 2)) return false;

    frame.fin    = (header[0] & 0x80) != 0;
    frame.opcode = static_cast<WsOpcode>(header[0] & 0x0F);
    frame.masked = (header[1] & 0x80) != 0;
    uint64_t len = header[1] & 0x7F;

    if (len == 126) {
        uint8_t ext[2];
        if (!recv_all(fd, ext, 2)) return false;
        len = ((uint64_t)ext[0] << 8) | ext[1];
    } else if (len == 127) {
        uint8_t ext[8];
        if (!recv_all(fd, ext, 8)) return false;
        len = 0;
        for (int i = 0; i < 8; i++) len = (len << 8) | ext[i];
    }
    frame.payload_len = len;

    if (frame.masked) {
        if (!recv_all(fd, frame.mask_key, 4)) return false;
    }

    if (len > 0) {
        std::vector<uint8_t> buf(len);
        if (!recv_all(fd, buf.data(), len)) return false;
        if (frame.masked) {
            for (uint64_t i = 0; i < len; i++)
                buf[i] ^= frame.mask_key[i % 4];
        }
        frame.payload.assign(reinterpret_cast<char*>(buf.data()), len);
    }

    return true;
}

// ── Frame writing ─────────────────────────────────────────────────────────

/// Send a WebSocket text frame (server-to-client, unmasked).
inline bool ws_send_text(int fd, const std::string& text) {
    std::vector<uint8_t> frame;
    frame.push_back(0x81); // FIN + Text opcode

    size_t len = text.size();
    if (len < 126) {
        frame.push_back((uint8_t)len);
    } else if (len < 65536) {
        frame.push_back(126);
        frame.push_back((uint8_t)(len >> 8));
        frame.push_back((uint8_t)(len & 0xFF));
    } else {
        frame.push_back(127);
        for (int s = 56; s >= 0; s -= 8)
            frame.push_back((uint8_t)(len >> s));
    }

    frame.insert(frame.end(), text.begin(), text.end());
    return sock_send(fd, frame.data(), frame.size()) > 0;
}

/// Send a WebSocket close frame.
inline void ws_send_close(int fd) {
    uint8_t close_frame[] = {0x88, 0x00}; // FIN + Close, no payload
    sock_send(fd, close_frame, sizeof(close_frame));
}

/// Send a WebSocket pong frame.
inline bool ws_send_pong(int fd, const std::string& payload) {
    std::vector<uint8_t> frame;
    frame.push_back(0x8A); // FIN + Pong
    frame.push_back((uint8_t)payload.size());
    frame.insert(frame.end(), payload.begin(), payload.end());
    return sock_send(fd, frame.data(), frame.size()) > 0;
}

} // namespace flutter_skill::detail
