# pulse-for-ai

AI skills for [Pulse SDK](https://pulse-ux.com) — set up mobile observability in your app with a single command, across Claude Code, Cursor, GitHub Copilot, and 50+ other AI agents.

## What's included

| Skill | Trigger | What it does |
|---|---|---|
| `setup` | `/setup` | Detects your project type and routes to the right skill |
| `integrating-pulse-react-native` | `/integrating-pulse-react-native` | Full setup for bare React Native apps |
| `integrating-pulse-expo` | `/integrating-pulse-expo` | Full setup for Expo projects |
| `setup-android` | `/setup-android` | Native Android setup *(coming soon)* |
| `setup-ios` | `/setup-ios` | Native iOS setup *(coming soon)* |

Slash commands use the **skill name** directly: type `/` plus the name (for example `/integrating-pulse-expo`). The `pulse:` prefix is not part of the skill — it was only a redundant namespace in older docs; hosts may still group commands under the Pulse plugin UI, but the invocation string is just `/<skill-name>`.

---

## Installation

### Any agent (recommended)

Uses the [skills.sh](https://skills.sh) CLI — installs to Claude Code, Cursor, Copilot, and 50+ other agents in one command:

```bash
npx skills add dream-horizon-org/pulse-for-ai
```

Then use `/setup` in your agent chat.

---

### Claude Code

```
/plugin install dream-horizon-org/pulse-for-ai
```

Then:
```
/setup
```

---

### Cursor

Settings → Plugins → search **"Pulse"** → Install

Then use `/setup` in chat.

---

### GitHub Copilot

Add `dream-horizon-org/pulse-for-ai` as a context source in Copilot settings. Skills are auto-discovered from `.github/skills/`.

Then ask: *"Set up Pulse SDK in this project"*

---

## How it works

Each skill reads your project first, then writes real code — package installs, native init files, app.json config, JS initialization, navigation hooks. No copy-paste required.

Skills are fully inline — no external URLs fetched at runtime. Reference files for advanced topics (error handling, custom events, source maps) are loaded on demand only when relevant.

---

## Platforms

| Platform | Status |
|---|---|
| Expo | ✅ v1 |
| Bare React Native | ✅ v1 |
| Android (native) | Coming soon |
| iOS (native) | Coming soon |

---

## Contributing

PRs welcome. Skills are plain Markdown — edit under `skills/`. When you publish a plugin release, bump semver in `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json` together.

Source of truth for all skill content: [pulse-ux.com/docs](https://pulse-ux.com/docs/developer-guide/sdk/)
