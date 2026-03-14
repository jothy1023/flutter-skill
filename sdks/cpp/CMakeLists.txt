cmake_minimum_required(VERSION 3.16)
project(flutter_skill_cpp VERSION 0.1.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Library ────────────────────────────────────────────────────────────────

add_library(flutter_skill STATIC
    src/bridge.cpp
)

target_include_directories(flutter_skill PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src   # internal headers (sha1.h, websocket.h, etc.)
)

# ── Platform-specific sources and link libraries ────────────────────────────

if(APPLE)
    target_sources(flutter_skill PRIVATE src/automation_macos.mm)
    target_link_libraries(flutter_skill PUBLIC
        "-framework ApplicationServices"
        "-framework Foundation"
        "-framework AppKit"
        "-framework CoreGraphics"
    )
elseif(WIN32)
    target_sources(flutter_skill PRIVATE src/automation_windows.cpp)
    target_link_libraries(flutter_skill PUBLIC
        gdiplus
        ole32
        oleaut32
        uiautomationcore
        ws2_32
    )
elseif(UNIX)
    find_package(X11 REQUIRED)
    find_package(PNG REQUIRED)

    target_sources(flutter_skill PRIVATE src/automation_linux.cpp)
    target_include_directories(flutter_skill PUBLIC
        ${X11_INCLUDE_DIR}
        ${PNG_INCLUDE_DIRS}
    )
    target_link_libraries(flutter_skill PUBLIC
        ${X11_LIBRARIES}
        ${X11_Xtst_LIB}
        ${PNG_LIBRARIES}
    )
endif()

# ── Example executable ─────────────────────────────────────────────────────

option(BUILD_EXAMPLE "Build the example bridge server" ON)

if(BUILD_EXAMPLE)
    add_executable(flutter_skill_bridge examples/main.cpp)
    target_link_libraries(flutter_skill_bridge PRIVATE flutter_skill)
endif()

# ── Tests ──────────────────────────────────────────────────────────────────

option(BUILD_TESTS "Build the test suite" ON)

if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
