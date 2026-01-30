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
