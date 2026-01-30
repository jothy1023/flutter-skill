## 0.2.0

**Major Feature Release - 25+ MCP Tools**

### New Features
- **UI Inspection**: `get_widget_tree`, `get_widget_properties`, `get_text_content`, `find_by_type`
- **Interactions**: `double_tap`, `long_press`, `swipe`, `drag`
- **State Validation**: `get_text_value`, `get_checkbox_state`, `get_slider_value`, `wait_for_element`, `wait_for_gone`
- **Screenshots**: `screenshot` (full app), `screenshot_element` (specific element)
- **Navigation**: `get_current_route`, `go_back`, `get_navigation_stack`
- **Debug & Logs**: `get_logs`, `get_errors`, `get_performance`, `clear_logs`
- **Development**: `hot_reload`, `pub_search`

### Bug Fixes
- Fixed global swipe using `platformDispatcher.views` for screen center calculation
- Fixed `screenshot_element` to capture any widget by finding nearest `RenderRepaintBoundary` ancestor

### Documentation
- Complete rewrite of README.md with all tool categories
- Updated SKILL.md with full tool reference and parameters
- Updated USAGE_GUIDE.md with CLI and MCP examples

## 0.1.6

- Docs: Updated README to reflect unified `flutter_skill` global commands.

## 0.1.5

- Fix: Added missing implementation for `scroll` extension found during comprehensive verification.
- Verified: All CLI features (inspect, tap, enterText, scroll) verified against real macOS app.

## 0.1.4

- Housekeeping: Removed `demo_counter` test app from package distribution.

## 0.1.3

- Fix: Critical fix for `launch` command to correctly capture VM Service URI with auth tokens.
- Fix: Critical fix for `inspect` command to correctly traverse widget tree (was stubbed in 0.1.2).
- Feature: `launch` command now forwards arguments to `flutter run` (e.g. `-d macos`).

## 0.1.2

- Docs: Updated README architecture diagram to reflect `flutter_skill` executable.
- No functional changes.

## 0.1.1

- Featured: Simplified CLI with `flutter_skill` global executable.
- Refactor: Moved CLI logic to `lib/src/cli` for better reusability.
- Usage: `flutter_skill launch`, `flutter_skill inspect`, etc.

## 0.1.0

- Initial release of Flutter Skill.
- Includes `launch`, `inspect`, `act` CLI tools.
- Includes `flutter_skill` app-side binding.
- Includes MCP server implementation.
