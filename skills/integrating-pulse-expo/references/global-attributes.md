---
name: pulse-global-attributes
description: Add global attributes to Pulse via the Expo plugin config (`app.json` / `app.config.*`). Suggestion-first — only adds attributes the user explicitly names.
category: sdk-feature
invoke-when: global attributes, tag telemetry, env version release channel, build metadata, filter dashboard, OTA tracking, CodePush metadata
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User wants to tag every Pulse signal (crashes, events, traces, sessions) with build / environment metadata so the dashboard can filter by it.
- User wants to label telemetry by OTA / CodePush release.

---

## Guardrails

- **Only configure global attributes in the plugin block of `app.json` / `app.config.js` / `app.config.ts`.** Do **not** add them anywhere in JS source files.
- **Never auto-pick attributes.** Only add the keys the user explicitly names. If they say "add env and version", add exactly those — do not also add `release_channel`, `commit_sha`, build IDs, etc. on your own.
- **Never modify the JS entry point** for global attributes. `Pulse.start()` does **not** accept a `globalAttributes` option — do not write that code.
- After editing the plugin block, surface (do not run) `npx expo prebuild --clean`. Native rebuild is required for plugin-config changes to take effect.
- Per-platform overrides (`android` / `ios`) are valid — use them only if the user asks for platform-specific values.

If the user asks to "add global attributes" without naming the keys → ask which keys/values they want before editing.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-expo` first. Stop.

---

## Where to add — plugin config

Read the active config file (the one chosen in `/integrating-pulse-expo` Step 1). Locate the `@dreamhorizonorg/pulse-react-native` plugin entry and add `globalAttributes` under the `android` and/or `ios` blocks. Do not add `globalAttributes` at the plugin root — the schema only supports it per-platform.

Same value on both platforms:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED",
    "android": {
      "globalAttributes": {
        "env":             "production",
        "release_channel": "stable"
      }
    },
    "ios": {
      "globalAttributes": {
        "env":             "production",
        "release_channel": "stable"
      }
    }
  }
]
```

Per-platform variation (only if requested):

```json
"android": { "globalAttributes": { "platform_label": "android-native" } },
"ios":     { "globalAttributes": { "platform_label": "ios-native"      } }
```

Supported value types in the plugin config: `string`, `number`, `boolean`, and arrays of these.

---

## After editing

Surface this command to the user — **do not run it yourself**:

```bash
npx expo prebuild --clean
```

Then rebuild iOS and/or Android (`npx expo run:ios`, `npx expo run:android`). Without `--clean`, the new attributes will not be picked up on next launch.

---

## Runtime API (informational — do not write into the user's app unless they explicitly ask)

For values that are not known at compile time (A/B test assignment, feature flags, OTA bundle ID), the SDK exposes a runtime API:

```typescript
Pulse.setGlobalAttribute(name: string, value: string | number | boolean | Array<string | number | boolean>): void
```

The wrapper created by `/integrating-pulse-expo` does **not** include this method — call it directly on `Pulse` from `@dreamhorizonorg/pulse-react-native`. Surface this only if the user explicitly asks for runtime tagging; do not insert it on your own.

Example (suggestion only):

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setGlobalAttribute('experiment_new_checkout', 'variant_b');
```

For OTA / CodePush tagging, see `source-maps.md` — the same `--bundle-id` value should also be set as a `codeBundleId` global attribute at runtime.

---

## What gets tagged automatically

The SDK already attaches device, OS, app, and session attributes to all telemetry. Examples include `device.manufacturer`, `device.model.name`, `os.name`, `os.version`, `service.name`, `service.version`, `app.build_id`, `session.id`, `screen.name`. Do not duplicate these as custom attributes.

---

## Scope notes

- Custom global attributes set via the plugin config flow into both JS-layer and native-layer telemetry.
- Custom attributes set via the runtime `Pulse.setGlobalAttribute(...)` apply to JS-layer telemetry (custom events, spans, JS errors). Native crashes / ANR / activity events include device + OS + app attributes automatically, but not custom JS-layer attributes.
