/**
 * Minimal SHA-1 implementation for WebSocket handshake key computation.
 * Public domain — based on RFC 3174 reference implementation.
 */
#pragma once

#include <cstdint>
#include <cstring>
#include <string>

namespace flutter_skill::detail {

struct SHA1Context {
    uint32_t intermediate_hash[5];
    uint32_t length_low;
    uint32_t length_high;
    int16_t  message_block_index;
    uint8_t  message_block[64];
    int      computed;
    int      corrupted;
};

inline uint32_t sha1_circular_shift(int bits, uint32_t word) {
    return (word << bits) | (word >> (32 - bits));
}

inline void sha1_process_message_block(SHA1Context* ctx) {
    const uint32_t K[] = {0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xCA62C1D6};
    uint32_t W[80];
    uint32_t A, B, C, D, E, temp;

    for (int t = 0; t < 16; t++) {
        W[t]  = (uint32_t)(ctx->message_block[t * 4]) << 24;
        W[t] |= (uint32_t)(ctx->message_block[t * 4 + 1]) << 16;
        W[t] |= (uint32_t)(ctx->message_block[t * 4 + 2]) << 8;
        W[t] |= (uint32_t)(ctx->message_block[t * 4 + 3]);
    }
    for (int t = 16; t < 80; t++)
        W[t] = sha1_circular_shift(1, W[t-3] ^ W[t-8] ^ W[t-14] ^ W[t-16]);

    A = ctx->intermediate_hash[0];
    B = ctx->intermediate_hash[1];
    C = ctx->intermediate_hash[2];
    D = ctx->intermediate_hash[3];
    E = ctx->intermediate_hash[4];

    for (int t = 0; t < 20; t++) {
        temp = sha1_circular_shift(5, A) + ((B & C) | ((~B) & D)) + E + W[t] + K[0];
        E = D; D = C; C = sha1_circular_shift(30, B); B = A; A = temp;
    }
    for (int t = 20; t < 40; t++) {
        temp = sha1_circular_shift(5, A) + (B ^ C ^ D) + E + W[t] + K[1];
        E = D; D = C; C = sha1_circular_shift(30, B); B = A; A = temp;
    }
    for (int t = 40; t < 60; t++) {
        temp = sha1_circular_shift(5, A) + ((B & C) | (B & D) | (C & D)) + E + W[t] + K[2];
        E = D; D = C; C = sha1_circular_shift(30, B); B = A; A = temp;
    }
    for (int t = 60; t < 80; t++) {
        temp = sha1_circular_shift(5, A) + (B ^ C ^ D) + E + W[t] + K[3];
        E = D; D = C; C = sha1_circular_shift(30, B); B = A; A = temp;
    }

    ctx->intermediate_hash[0] += A;
    ctx->intermediate_hash[1] += B;
    ctx->intermediate_hash[2] += C;
    ctx->intermediate_hash[3] += D;
    ctx->intermediate_hash[4] += E;
    ctx->message_block_index = 0;
}

inline void sha1_pad_message(SHA1Context* ctx) {
    if (ctx->message_block_index > 55) {
        ctx->message_block[ctx->message_block_index++] = 0x80;
        while (ctx->message_block_index < 64)
            ctx->message_block[ctx->message_block_index++] = 0;
        sha1_process_message_block(ctx);
        while (ctx->message_block_index < 56)
            ctx->message_block[ctx->message_block_index++] = 0;
    } else {
        ctx->message_block[ctx->message_block_index++] = 0x80;
        while (ctx->message_block_index < 56)
            ctx->message_block[ctx->message_block_index++] = 0;
    }
    ctx->message_block[56] = (uint8_t)(ctx->length_high >> 24);
    ctx->message_block[57] = (uint8_t)(ctx->length_high >> 16);
    ctx->message_block[58] = (uint8_t)(ctx->length_high >> 8);
    ctx->message_block[59] = (uint8_t)(ctx->length_high);
    ctx->message_block[60] = (uint8_t)(ctx->length_low >> 24);
    ctx->message_block[61] = (uint8_t)(ctx->length_low >> 16);
    ctx->message_block[62] = (uint8_t)(ctx->length_low >> 8);
    ctx->message_block[63] = (uint8_t)(ctx->length_low);
    sha1_process_message_block(ctx);
}

inline void sha1_init(SHA1Context* ctx) {
    ctx->length_low = ctx->length_high = 0;
    ctx->message_block_index = 0;
    ctx->intermediate_hash[0] = 0x67452301;
    ctx->intermediate_hash[1] = 0xEFCDAB89;
    ctx->intermediate_hash[2] = 0x98BADCFE;
    ctx->intermediate_hash[3] = 0x10325476;
    ctx->intermediate_hash[4] = 0xC3D2E1F0;
    ctx->computed = ctx->corrupted = 0;
}

inline void sha1_input(SHA1Context* ctx, const uint8_t* data, unsigned len) {
    while (len-- && !ctx->corrupted) {
        ctx->message_block[ctx->message_block_index++] = (*data & 0xFF);
        ctx->length_low += 8;
        if (ctx->length_low == 0 && ++ctx->length_high == 0)
            ctx->corrupted = 1;
        if (ctx->message_block_index == 64)
            sha1_process_message_block(ctx);
        data++;
    }
}

inline void sha1_result(SHA1Context* ctx, uint8_t digest[20]) {
    if (!ctx->computed) {
        sha1_pad_message(ctx);
        for (int i = 0; i < 64; i++) ctx->message_block[i] = 0;
        ctx->length_low = ctx->length_high = 0;
        ctx->computed = 1;
    }
    for (int i = 0; i < 20; i++)
        digest[i] = (uint8_t)(ctx->intermediate_hash[i >> 2] >> (8 * (3 - (i & 3))));
}

/// Compute SHA-1 of input and return raw 20-byte digest.
inline std::string sha1(const std::string& input) {
    SHA1Context ctx;
    sha1_init(&ctx);
    sha1_input(&ctx, reinterpret_cast<const uint8_t*>(input.data()),
               static_cast<unsigned>(input.size()));
    uint8_t digest[20];
    sha1_result(&ctx, digest);
    return std::string(reinterpret_cast<char*>(digest), 20);
}

/// Base64-encode a raw binary string.
inline std::string base64_encode(const std::string& input) {
    static const char* table =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve(((input.size() + 2) / 3) * 4);
    for (size_t i = 0; i < input.size(); i += 3) {
        uint32_t n = (uint8_t)input[i] << 16;
        if (i + 1 < input.size()) n |= (uint8_t)input[i + 1] << 8;
        if (i + 2 < input.size()) n |= (uint8_t)input[i + 2];
        out += table[(n >> 18) & 63];
        out += table[(n >> 12) & 63];
        out += (i + 1 < input.size()) ? table[(n >> 6) & 63] : '=';
        out += (i + 2 < input.size()) ? table[n & 63] : '=';
    }
    return out;
}

/// Compute the Sec-WebSocket-Accept value for a given Sec-WebSocket-Key.
inline std::string ws_accept_key(const std::string& client_key) {
    const std::string magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    return base64_encode(sha1(client_key + magic));
}

} // namespace flutter_skill::detail
