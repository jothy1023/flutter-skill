# IDE Setup Guides

## Claude Code / Claude Desktop

Add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

Then ask Claude: *"Connect to my Flutter app and test the login flow"*

## Cursor

Add to `.cursor/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

Restart Cursor. The MCP tools appear in Cursor's tool panel.

## Windsurf

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

## Cline (VSCode Extension)

Open VSCode Settings → Extensions → Cline → MCP Servers:

```json
{
  "flutter-skill": {
    "command": "flutter-skill",
    "args": ["server"]
  }
}
```

## GitHub Copilot (VSCode)

Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "flutter-skill": {
      "type": "stdio",
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

## OpenClaw

### MCP Mode

Already works out of the box via the `e2e-testing` skill. Or add manually:

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

### Serve Mode (HTTP + CLI)

For standalone browser automation from OpenClaw, use the HTTP serve mode:

1. Start the serve instance:

```bash
flutter-skill serve https://your-app.com
```

2. Use CLI client commands directly:

```bash
flutter-skill nav https://your-app.com/login
flutter-skill snap
flutter-skill tap "Login"
flutter-skill type "user@example.com"
flutter-skill screenshot /tmp/login.jpg
```

3. Or configure your `SKILL.md` to use the serve API:

```markdown
## Tools

- flutter-skill serve: HTTP API at http://127.0.0.1:3000
- CLI commands: nav, snap, screenshot, tap, type, key, eval, title, text, hover, upload, tools, call
```

See [CLI_CLIENT.md](CLI_CLIENT.md) for the full command reference.

## Continue.dev

Add to `.continue/config.json`:

```json
{
  "mcpServers": {
    "flutter-skill": {
      "command": "flutter-skill",
      "args": ["server"]
    }
  }
}
```

Restart Continue.dev. The 253 MCP tools will appear in the tool panel.

## Verify Installation

After configuring, ask your AI:

> "List all flutter-skill tools"

You should see 253 tools. Then try:

> "Connect to https://example.com via CDP and take a screenshot"

If it works, you're all set! Try `page_summary` for the AI-native experience:

> "Get a page summary of the current page using flutter-skill"
