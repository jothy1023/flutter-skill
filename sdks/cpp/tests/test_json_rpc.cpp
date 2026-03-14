/**
 * Tests for json_rpc.h parsing and construction helpers.
 */
#include "test_runner.h"
#include "json_rpc.h"

using namespace flutter_skill::detail;

REGISTER_TEST(json_rpc, get_string_value) {
    std::string json = R"({"id":1,"method":"ping","params":{}})";
    EXPECT_EQ(json_get(json, "method"), "ping");

}

REGISTER_TEST(json_rpc, get_numeric_value) {
    std::string json = R"({"id":42,"method":"tap"})";
    EXPECT_EQ(json_get(json, "id"), "42");

}

REGISTER_TEST(json_rpc, get_nested_object) {
    std::string json = R"({"params":{"x":100,"y":200}})";
    std::string params = json_get(json, "params");
    EXPECT_CONTAINS(params, "100");
    EXPECT_CONTAINS(params, "200");

}

REGISTER_TEST(json_rpc, get_missing_key) {
    std::string json = R"({"id":1})";
    EXPECT_EQ(json_get(json, "method"), "");

}

REGISTER_TEST(json_rpc, rpc_ok_response) {
    std::string resp = rpc_ok("1", "{\"success\":true}");
    EXPECT_CONTAINS(resp, "\"id\":1");
    EXPECT_CONTAINS(resp, "\"result\"");
    EXPECT_CONTAINS(resp, "\"success\":true");

}

REGISTER_TEST(json_rpc, rpc_error_response) {
    std::string resp = rpc_error("2", -32000, "Something went wrong");
    EXPECT_CONTAINS(resp, "\"id\":2");
    EXPECT_CONTAINS(resp, "\"error\"");
    EXPECT_CONTAINS(resp, "-32000");
    EXPECT_CONTAINS(resp, "Something went wrong");

}

REGISTER_TEST(json_rpc, result_ok_empty) {
    std::string r = result_ok();
    EXPECT_CONTAINS(r, "\"success\":true");

}

REGISTER_TEST(json_rpc, result_ok_with_extra) {
    std::string r = result_ok("\"message\":\"hello\"");
    EXPECT_CONTAINS(r, "\"success\":true");
    EXPECT_CONTAINS(r, "\"message\":\"hello\"");

}

REGISTER_TEST(json_rpc, result_err) {
    std::string r = result_err("Bad input");
    EXPECT_CONTAINS(r, "\"success\":false");
    EXPECT_CONTAINS(r, "Bad input");

}

REGISTER_TEST(json_rpc, json_str_escaping) {
    std::string r = json_str("hello \"world\"");
    EXPECT_CONTAINS(r, "\\\"world\\\"");

}

REGISTER_TEST(json_rpc, get_string_with_escape) {
    std::string json = R"({"key":"hello \"world\""})";
    EXPECT_EQ(json_get(json, "key"), "hello \"world\"");

}
