/**
 * flutter-skill C++ bridge — standalone example server.
 *
 * Build:
 *   cmake -B build && cmake --build build
 *   ./build/flutter_skill_bridge [port]
 */

#include <flutter_skill/bridge.h>

#include <atomic>
#include <csignal>
#include <cstdio>
#include <thread>

static std::atomic<bool> g_stop{false};

static void handle_signal(int) {
    // Signal-safe: only set a flag.
    g_stop = true;
}

int main(int argc, char* argv[]) {
    flutter_skill::BridgeOptions opts;
    opts.app_name = "my-cpp-app";
    if (argc > 1) opts.port = std::atoi(argv[1]);

    flutter_skill::FlutterSkillBridge bridge(opts);

    std::signal(SIGINT,  handle_signal);
    std::signal(SIGTERM, handle_signal);

    try {
        bridge.start();
        fprintf(stdout, "[main] flutter-skill bridge running on port %d\n", opts.port);

        // Poll the stop flag; stop() closes the listening socket which
        // unblocks the accept() loop so the server thread exits cleanly.
        while (!g_stop.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
        bridge.stop();

    } catch (const std::exception& e) {
        fprintf(stderr, "[main] Error: %s\n", e.what());
        return 1;
    }

    return 0;
}
