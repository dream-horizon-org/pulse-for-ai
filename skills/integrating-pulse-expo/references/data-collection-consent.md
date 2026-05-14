---
name: pulse-consent
description: Switch the initial Pulse data-collection state in the plugin config and surface the runtime API for ALLOWED / PENDING / DENIED transitions. Never builds or modifies a consent UI on its own.
category: sdk-feature
invoke-when: GDPR, CCPA, data consent, consent screen, privacy, pending allowed denied, gate collection
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User wants Pulse to defer collection until a user accepts (GDPR / CCPA / App Store privacy).
- User has an existing consent screen / hook and needs Pulse to react to its decision.
- User wants to terminate collection on consent denial.

---

## Guardrails

This skill makes **at most two** kinds of changes, and only when explicitly requested:

1. **Plugin config**: change `dataCollectionState` from `"ALLOWED"` to `"PENDING"` (or back) in the active Expo config (`app.json` / `app.config.*`). Then prompt the user to re-run `npx expo prebuild --clean` (do not run it yourself).
2. **A user-named file**: insert the `setDataCollectionState(...)` call exactly where the user points, after their accept / decline handler.

Never:

- Build, design, or place a consent popup / modal / banner. Pulse does not ship UI.
- Search the codebase for consent-related screens and pick a file yourself.
- Persist the user's consent choice to disk on their behalf — that is the user's app concern.
- Change the Expo config beyond the single `dataCollectionState` field.
- Re-run `npx expo prebuild --clean` automatically — surface the command and let the user run it.

If the user asks to "add GDPR" without naming a file → respond with the plugin-config change and the runtime API, then ask which screen / handler should call `setDataCollectionState`.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

- Package missing → tell user to run `/integrating-pulse-expo` first. Stop.
- `pulse.ts` wrapper found → use `PulseService.setDataCollectionState(...)`.
- Wrapper missing → use `Pulse.setDataCollectionState(...)` direct from the SDK.

---

## The three states

| State | Behavior |
|---|---|
| `ALLOWED` | All telemetry collected and exported immediately |
| `PENDING` | SDK initialized — data buffered **in memory only**, nothing exported, **not persisted across restarts** |
| `DENIED` | Buffer cleared, SDK shuts down — **terminal** for the process; requires app restart to re-initialize |

Valid runtime transitions:

| From | To `ALLOWED` | To `DENIED` |
|---|---|---|
| `PENDING` | flushes buffer, starts exporting | clears buffer, shuts down |
| `ALLOWED` | no-op | clears buffer, shuts down |
| `DENIED` | invalid — restart required | — |

---

## Step 1 — Change the initial state in the plugin config

Read the active config file (`app.json`, `app.config.js`, or `app.config.ts`). Update only the `dataCollectionState` field — do not touch other keys:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "PENDING"
  }
]
```

Tell the user this requires a native rebuild:

```bash
npx expo prebuild --clean
```

(Surface the command — do not run it yourself.)

Per-platform overrides are also valid (use only if the user requests them):

```json
"android": { "dataCollectionState": "PENDING" },
"ios":     { "dataCollectionState": "PENDING" }
```

---

## Step 2 — Runtime API (suggest, then user-directed insertion)

```typescript
import { PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
import { PulseService } from '@/config/pulse';
// no wrapper: import { Pulse } from '@dreamhorizonorg/pulse-react-native';

PulseService.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
PulseService.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

Suggested call site (do not auto-insert): after the user's existing accept / decline handler resolves. Example shape only:

```typescript
async function onConsentAnswered(accepted: boolean) {
  await persistConsent(accepted);                 // user's existing code — unchanged
  PulseService.setDataCollectionState(
    accepted ? PulseDataCollectionConsent.ALLOWED : PulseDataCollectionConsent.DENIED,
  );
}
```

When the user names the file and handler, add the two lines (`import` + the call). Show the diff first.

---

## Step 3 — Persisting consent across sessions

Pulse does **not** persist the runtime consent choice across app restarts. On every launch, the SDK initializes in whatever `dataCollectionState` the **plugin config** carries — that is the only place the initial state lives.

If the client needs persistence across sessions, it must be configured in the **same `app.config.js` / `app.config.ts` where the Pulse plugin was added**. Those files are JavaScript evaluated at build time, so they can read a stored / environment-driven value and pass it as `dataCollectionState`. **Do not add JS code in the entry point that reads from `AsyncStorage` / `MMKV` / secure storage and replays the choice — that is not the supported pattern.**

```js
// app.config.js — read your persisted/build-time value here, not at runtime in the JS entry point
const persistedConsent = process.env.EXPO_PUBLIC_PULSE_INITIAL_CONSENT ?? 'PENDING';

module.exports = {
  expo: {
    plugins: [
      ['@dreamhorizonorg/pulse-react-native', {
        apiKey: process.env.EXPO_PUBLIC_PULSE_API_KEY,
        dataCollectionState: persistedConsent,   // 'ALLOWED' | 'PENDING' | 'DENIED'
      }],
    ],
  },
};
```

Re-run `npx expo prebuild --clean` after the resolved value changes.

What the skill is allowed to do here:

- Surface the snippet above and confirm with the user **which** stored / env value should drive `dataCollectionState`.
- If the user names the env var (or build-time source), edit `app.config.js` / `app.config.ts` to read it and set `dataCollectionState`. Show the diff first.

What the skill must **not** do:

- Add `AsyncStorage` / `MMKV` / secure-store reads to the JS entry point to "restore" consent on launch.
- Pick a storage layer or write persistence code on the user's behalf.
- Convert `app.json` to `app.config.js` for this purpose unless the user explicitly asks (this is one of the few cases where the conversion may be required — confirm before doing it).

For per-session runtime updates after the user answers a prompt this session, use `setDataCollectionState(...)` from Step 2 — that is unchanged.

---

## Native side (informational only — do not add unless user asks)

If consent is set from native code before the JS bundle loads:

- Android (Kotlin): `Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED)` — `Pulse` from `com.pulsereactnativeotel.Pulse`, `PulseDataCollectionConsent` from `com.pulsereactnativeotel.PulseDataCollectionConsent`.
- iOS (Swift): `PulseSDK.setDataCollectionState(.allowed)` — from `PulseReactNativeOtel`.
- iOS (Obj-C): `[PulseSDK pulseSetDataCollectionState:@"ALLOWED"]`.

Surface only if asked. Do not modify native files as part of this skill.

---

## Important reminders

- `setDataCollectionState` only runs after `Pulse.start()` has executed.
- `DENIED` is **terminal** for the process — no way to re-enable without an app restart.
- `PENDING` data is in memory only; killing the app loses anything buffered.
