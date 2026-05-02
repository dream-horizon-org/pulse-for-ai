# pulse-for-ai

AI skills for [Pulse SDK](https://pulse-ux.com) — set up mobile observability in your app with a single command, across Claude Code, Cursor, and GitHub Copilot.

## What's included

| Skill | What it does |
|---|---|
| `/pulse:setup` | Detects your project type and routes to the right skill |
| `/pulse:setup-react-native` | Full setup for bare React Native apps |
| `/pulse:setup-expo` | Full setup for Expo projects |
| `/pulse:setup-android` | Native Android setup *(coming soon)* |
| `/pulse:setup-ios` | Native iOS setup *(coming soon)* |

---

## Installation

### Claude Code

```
/plugin marketplace add dream-horizon-org/pulse-for-ai
/plugin install pulse@pulse-for-ai
```

Then use:
```
/pulse:setup
```

### Cursor

Settings → Plugins → search **"Pulse"** → Install

Then use `/pulse:setup` in the chat.

### GitHub Copilot

Copilot auto-discovers skills from `.github/skills/`. Add this repo as a context source in your Copilot settings, then ask:

> "Set up Pulse SDK in this project"

---

## How it works

Each skill reads your project first, then writes real code — package installs, native init files, app.json config, JS initialization, navigation hooks. No copy-paste required.

Skills are complete and inline — no external URLs fetched at runtime. Reference files for advanced topics (error handling, custom events, source maps) are loaded on demand.

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

PRs welcome. Skills are plain Markdown — edit a `SKILL.md` file, bump the version in both `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`, open a PR.

Source of truth for all skill content: [pulse-ux.com/docs](https://pulse-ux.com/docs/developer-guide/sdk/)
