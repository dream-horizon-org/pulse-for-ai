# Pulse SDK — Skill Tree

AI skills for integrating [Pulse](https://pulse-ux.com), an Experience Intelligence Platform built on OpenTelemetry. Supports Android, iOS, React Native, and Expo.

## Install

```bash
npx skills add dream-horizon-org/pulse-for-ai
```

Works with Claude Code, Cursor, GitHub Copilot, and 50+ AI agents via [skills.sh](https://skills.sh).

---

## Available Skills

### Setup (Start Here)

| Skill | Trigger | Description |
|---|---|---|
| [setup](skills/setup/SKILL.md) | `/pulse:setup` | Auto-detects project type and routes to the correct platform skill |
| [setup-react-native](skills/setup-react-native/SKILL.md) | `/pulse:setup-react-native` | Full SDK setup for bare React Native apps — Android + iOS native init, JS layer, navigation |
| [setup-expo](skills/setup-expo/SKILL.md) | `/pulse:setup-expo` | Full SDK setup for Expo projects — config plugin, prebuild, Expo Router support |

### Coming Soon

| Skill | Description |
|---|---|
| `setup-android` | Native Android SDK setup |
| `setup-ios` | Native iOS SDK setup |

---

## When to Use Each Skill

| Project type | Use |
|---|---|
| Has `expo` in package.json | `setup-expo` |
| Has `react-native` but not `expo` | `setup-react-native` |
| Native Android app | `setup-android` *(coming soon)* |
| Native iOS app | `setup-ios` *(coming soon)* |
| Not sure | `setup` — it detects and routes automatically |

---

## What Pulse Collects Automatically

Once set up, the following requires no additional code:

- JS crashes + unhandled promise rejections
- HTTP requests (fetch, XHR, axios)
- App startup timing
- Screen lifecycle (activity/view controller transitions)
- Session tracking
- ANR detection (Android)
- Slow/jank frame detection (Android)

Optional with one line: navigation tracking, error boundaries, custom events, custom spans, user identification.
