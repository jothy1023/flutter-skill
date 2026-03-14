/**
 * Minimal test runner — no external dependencies required.
 * Uses C++17 inline variables to ensure globals are shared across TUs.
 */
#pragma once

#include <cstdio>
#include <functional>
#include <string>
#include <vector>

struct TestCase {
    std::string name;
    std::string suite;
    std::function<void()> fn;
};

// Inline ensures exactly one definition across all TUs (C++17)
inline std::vector<TestCase>& test_registry() {
    static std::vector<TestCase> reg;
    return reg;
}

inline int& g_failed() { static int v = 0; return v; }

#define REGISTER_TEST(suite, name) \
    static void test_##suite##_##name(); \
    namespace { \
        struct _Reg_##suite##_##name { \
            _Reg_##suite##_##name() { \
                test_registry().push_back({#name, #suite, test_##suite##_##name}); \
            } \
        } _reg_##suite##_##name; \
    } \
    static void test_##suite##_##name()

#define EXPECT_TRUE(expr) \
    do { \
        if (!(expr)) { \
            fprintf(stderr, "  FAIL: %s:%d: expected true: %s\n", \
                    __FILE__, __LINE__, #expr); \
            g_failed()++; \
            return; \
        } \
    } while (0)

#define EXPECT_FALSE(expr) EXPECT_TRUE(!(expr))

#define EXPECT_EQ(a, b) \
    do { \
        auto _a = (a); auto _b = (b); \
        if (!(_a == _b)) { \
            fprintf(stderr, "  FAIL: %s:%d: %s != %s\n", \
                    __FILE__, __LINE__, #a, #b); \
            g_failed()++; \
            return; \
        } \
    } while (0)

#define EXPECT_CONTAINS(haystack, needle) \
    do { \
        std::string _h = (haystack); std::string _n = (needle); \
        if (_h.find(_n) == std::string::npos) { \
            fprintf(stderr, "  FAIL: %s:%d: '%s' not found in '%s'\n", \
                    __FILE__, __LINE__, _n.c_str(), _h.c_str()); \
            g_failed()++; \
            return; \
        } \
    } while (0)

inline int run_tests(const std::string& suite_filter) {
    bool run_all = (suite_filter == "all" || suite_filter.empty());
    int passed = 0;

    for (auto& tc : test_registry()) {
        if (!run_all && tc.suite != suite_filter) continue;

        fprintf(stdout, "  [ RUN ] %s::%s\n", tc.suite.c_str(), tc.name.c_str());
        int prev_failed = g_failed();
        tc.fn();
        if (g_failed() == prev_failed) {
            passed++;
            fprintf(stdout, "  [  OK ] %s::%s\n", tc.suite.c_str(), tc.name.c_str());
        } else {
            fprintf(stdout, "  [FAIL ] %s::%s\n", tc.suite.c_str(), tc.name.c_str());
        }
    }

    fprintf(stdout, "\n%d passed, %d failed\n", passed, g_failed());
    return g_failed() > 0 ? 1 : 0;
}
