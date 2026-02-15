# Contributing to flutter-skill

Thanks for your interest! Here's how to get started.

## Quick Start

```bash
git clone https://github.com/ai-dashboad/flutter-skill
cd flutter-skill
dart pub get
dart run bin/flutter_skill.dart server
```

## Ways to Contribute

- 🐛 **Bug reports** — [open an issue](https://github.com/ai-dashboad/flutter-skill/issues/new)
- 💡 **Feature requests** — suggest new MCP tools or platform support
- 📖 **Documentation** — fix typos, improve guides, add examples
- 🧪 **Testing** — try flutter-skill on your app and report results
- 🔌 **SDK contributions** — help improve platform SDKs

## Project Structure

```
├── lib/src/cli/        # MCP server + CLI
├── sdks/               # Platform SDKs (electron, android, tauri, kmp, etc.)
├── test/e2e/           # E2E test suite + test apps
├── docs/               # Documentation
├── vscode-extension/   # VSCode extension
├── intellij-plugin/    # JetBrains plugin
└── skills/             # Agent skills (skills.sh / OpenClaw)
```

## Development

```bash
dart analyze                           # Lint
dart test                              # Unit tests
node test/e2e/bridge_e2e_test.mjs      # E2E tests (need a running test app)
```

## Pull Requests

1. Fork → branch → implement → test → PR
2. Keep PRs focused (one feature/fix per PR)
3. Update tests if behavior changes
4. Follow existing code style

## Code of Conduct

Be kind. Be constructive. We're all here to build cool stuff.
