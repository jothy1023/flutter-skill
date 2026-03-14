/**
 * Minimal JSON-RPC 2.0 helpers.
 *
 * We avoid pulling in a full JSON library for the bridge's core to keep
 * the SDK self-contained. The bridge only needs to:
 *   1. Parse the "id", "method", "params" fields from incoming messages.
 *   2. Produce simple JSON response objects.
 *
 * All values are treated as raw JSON strings (so objects/arrays pass through).
 */
#pragma once

#include <string>

namespace flutter_skill::detail {

/// Extract the string value of a top-level JSON key (best-effort, handles
/// both quoted strings and raw JSON values/objects/arrays).
inline std::string json_get(const std::string& json, const std::string& key) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return "";

    pos += needle.size();
    // Skip whitespace and colon
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == ':' || json[pos] == '\t'))
        pos++;

    if (pos >= json.size()) return "";

    char first = json[pos];

    if (first == '"') {
        // Quoted string — extract content with basic escape handling
        std::string value;
        pos++;
        while (pos < json.size()) {
            char c = json[pos++];
            if (c == '\\' && pos < json.size()) {
                char e = json[pos++];
                switch (e) {
                    case '"':  value += '"';  break;
                    case '\\': value += '\\'; break;
                    case 'n':  value += '\n'; break;
                    case 'r':  value += '\r'; break;
                    case 't':  value += '\t'; break;
                    default:   value += e;    break;
                }
            } else if (c == '"') {
                break;
            } else {
                value += c;
            }
        }
        return value;
    }

    if (first == '{' || first == '[') {
        // Object or array — balance braces/brackets
        char open  = first;
        char close = (first == '{') ? '}' : ']';
        int  depth = 0;
        size_t start = pos;
        bool in_string = false;
        while (pos < json.size()) {
            char c = json[pos++];
            if (c == '"' && !in_string) in_string = true;
            else if (c == '"' && in_string && json[pos - 2] != '\\') in_string = false;
            if (!in_string) {
                if (c == open)  depth++;
                if (c == close) { depth--; if (depth == 0) break; }
            }
        }
        return json.substr(start, pos - start);
    }

    // Number, boolean, null — read until delimiter
    size_t start = pos;
    while (pos < json.size() && json[pos] != ',' && json[pos] != '}' &&
           json[pos] != ']' && json[pos] != ' ' && json[pos] != '\n')
        pos++;
    return json.substr(start, pos - start);
}

/// Build a JSON-RPC 2.0 success response.
inline std::string rpc_ok(const std::string& id, const std::string& result_json) {
    // id can be a number or a quoted string — pass through as-is
    return "{\"id\":" + id + ",\"result\":" + result_json + "}";
}

/// Build a JSON-RPC 2.0 error response.
inline std::string rpc_error(const std::string& id, int code, const std::string& message) {
    // Escape the message for JSON
    std::string escaped;
    for (char c : message) {
        if (c == '"')       escaped += "\\\"";
        else if (c == '\\') escaped += "\\\\";
        else if (c == '\n') escaped += "\\n";
        else if (c == '\r') escaped += "\\r";
        else                escaped += c;
    }
    return "{\"id\":" + id + ",\"error\":{\"code\":" + std::to_string(code) +
           ",\"message\":\"" + escaped + "\"}}";
}

/// Build a simple success result JSON object.
inline std::string result_ok(const std::string& extra = "") {
    if (extra.empty()) return "{\"success\":true}";
    return "{\"success\":true," + extra + "}";
}

/// Build a simple error result JSON object.
inline std::string result_err(const std::string& msg) {
    std::string escaped;
    for (char c : msg) {
        if (c == '"')       escaped += "\\\"";
        else if (c == '\\') escaped += "\\\\";
        else                escaped += c;
    }
    return "{\"success\":false,\"error\":\"" + escaped + "\"}";
}

/// Wrap a string value for embedding in JSON.
inline std::string json_str(const std::string& s) {
    std::string out = "\"";
    for (char c : s) {
        if (c == '"')       out += "\\\"";
        else if (c == '\\') out += "\\\\";
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else                out += c;
    }
    out += "\"";
    return out;
}

} // namespace flutter_skill::detail
