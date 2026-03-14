cmake_minimum_required(VERSION 3.16)

# ── Test executable ────────────────────────────────────────────────────────

add_executable(flutter_skill_tests
    test_bridge.cpp
    test_json_rpc.cpp
    test_websocket.cpp
)

target_link_libraries(flutter_skill_tests PRIVATE flutter_skill)
target_include_directories(flutter_skill_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

# Register individual test cases with CTest
add_test(NAME JsonRpcParsing      COMMAND flutter_skill_tests json_rpc)
add_test(NAME WebSocketHandshake  COMMAND flutter_skill_tests websocket)
add_test(NAME BridgeProtocol      COMMAND flutter_skill_tests bridge)
add_test(NAME PlatformBackend     COMMAND flutter_skill_tests platform)

# Default: run all tests
add_test(NAME AllTests            COMMAND flutter_skill_tests all)
