---
name: integrating-pulse-expo
description: >-
  Integrates Pulse (@dreamhorizonorg/pulse-react-native) into Expo using the config plugin — install, merge plugin JSON, prebuild,
  PulseService wrapper, entry wiring for Expo Router or React Navigation, and verify builds. Use when adding or integrating Pulse in
  Expo; for crashes, sessions, traces, profiling, logging, ANRs in Expo apps; when package.json lists expo or the user mentions
  Pulse together with Expo, app.config, Expo Router, or eas.json.
category: sdk-setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

## Invoke When

- User asks to "add Pulse", "set up Pulse", or "integrate Pulse" in an Expo app
- User wants error monitoring, crash reporting, tracing, profiling, session tracking, or logging in an Expo app
- User wants to monitor native crashes, ANRs, or app hangs on iOS/Android in an Expo project
- User mentions `@dreamhorizonorg/pulse-react-native`, mobile observability, or Pulse SDK with Expo
- `expo` is in `package.json`

---

## ⚠️ Safety Rules — Read Before Touching Anything

This skill runs against a real client codebase. **Every change must be minimal, additive, and reversible.** When in doubt, stop and ask the user.

### Hard rules (never break)

1. **Read every file before editing it.** No blind writes. No assumed file shapes.
2. **Additive only.** Never overwrite or replace an existing file. Never reformat, reorder, or "clean up" surrounding code.
3. **Stay inside the listed touch points.** Files this skill is allowed to modify:
   - The active Expo config (`app.json`, `app.config.js`, or `app.config.ts`) — **only** the `plugins` array
   - The entry point (`app/_layout.tsx` or `App.tsx`) — **only** to add the import + `PulseService.start()` (and `useNavigationTracking` if applicable)
   - **New** file `src/config/pulse.ts` (or `pulse.ts` at root if no `src/`)
   - `.env.example` — additive only
4. **Never modify business logic.** No refactors, no renames, no architectural moves, no upgrades to RN/Expo/React/TypeScript versions, no Babel/Metro/EAS config changes.
5. **Never install anything except `@dreamhorizonorg/pulse-react-native`.** Do not add `expo-router`, `@react-navigation/native`, or any other dependency.
6. **Never write `.env`** — write `.env.example` only. Never commit, stage, or print real API keys.
7. **Never convert config formats.** If the project uses `app.json`, keep it as `app.json`. If `app.config.ts`, stay there.
8. **Never run destructive commands.** No `git reset`, `git clean`, `rm -rf`, `prebuild` without `--clean` not implied by the user. The only commands this skill runs are listed in Steps 2, 4, and 7.
9. **Show the diff before writing.** For any edit, summarize "I'm about to add N lines to file X — here they are." Then write.
10. **One step at a time.** Run each numbered step, report the result, then proceed. If a step fails, stop and report — do not retry the same broken command.

### Allowed file matrix

| File | Action |
|---|---|
| `app.json` / `app.config.js` / `app.config.ts` | Read → append one entry to `plugins` array. Never replace, never reorder existing entries. |
| `app/_layout.tsx` or `App.tsx` | Read → add import + `PulseService.start()` at module level + (optional) `useNavigationTracking`. Never touch render tree beyond what is documented in Step 6. |
| `src/config/pulse.ts` | Create new file (or `pulse.ts` at root). Never overwrite if it already exists — stop and ask. |
| `.env.example` | Append `EXPO_PUBLIC_PULSE_API_KEY=...` if missing. Never overwrite an existing line. |
| `.env` | **Never touch.** |
| Anything else | **Forbidden.** |

### When to stop and ask

- The active config file already contains a `@dreamhorizonorg/pulse-react-native` plugin entry → ask before editing.
- `src/config/pulse.ts` (or `pulse.ts`) already exists → ask before overwriting.
- `app/_layout.tsx` already calls `Pulse.start()` or `PulseService.start()` → ask before adding.
- The project uses an unfamiliar config setup (custom Metro, monorepo, EAS-only, no `package.json`) → ask before proceeding.
- Any read returns content the skill does not recognize → ask, do not guess.

---

## Step 0 — Guard: Right Project? Already Done?

> Confirm this is an Expo project and Pulse isn't already set up before touching anything.

```bash
node -e "const p=require('./package.json'); const d={...p.dependencies,...p.devDependencies}; console.log(d['expo'] ? 'expo' : 'not-expo')" 2>/dev/null
ls app.json app.config.js app.config.ts eas.json 2>/dev/null
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
cat app.json 2>/dev/null | grep "pulse-react-native"
cat app.config.js 2>/dev/null | grep "pulse-react-native"
cat app.config.ts 2>/dev/null | grep "pulse-react-native"
```

- `expo` not in deps and no Expo config files → **stop**. Tell user: "This looks like bare React Native. Use `/integrating-pulse-react-native` instead."
- Package installed AND plugin already in config → **do not re-run setup**. Instead, tell the user:
  > "Pulse is already set up in this project. What would you like to add next? You can say a number or describe what you need:
  > (1) GDPR / data consent, (2) Global attributes, (3) Handled error reporting, (4) Custom events, (5) User identification, (6) CodePush / OTA tracking, (7) Source maps"

  When the user responds, read the relevant reference file from `${SKILL_ROOT}/references/` and implement the feature in their codebase. Don't re-run any setup steps.

---

## Step 1 — Detect: Collect All Signals Upfront

> Determine navigation type, Android SDK level, and config format. Every decision in Steps 3–6 flows from these results — don't re-run checks later.

```bash
# Is this Expo Router or standard React Navigation?
ls app/_layout.tsx app/_layout.jsx app/_layout.js 2>/dev/null
cat package.json | grep -E '"@react-navigation/native"|"expo-router"'

# Android minSdk — needed to decide if coreLibraryDesugaring is required
grep "minSdkVersion\|minSdk " android/app/build.gradle 2>/dev/null

# OkHttp check — expo-image / FastImage use Android's OkHttp, which bypasses the JS layer
# If found, okHttpInstrumentation must be enabled in the plugin config
grep -r "expo-image\|FastImage\|react-native-fast-image" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" . 2>/dev/null | grep -v node_modules | head -3

# Which config file is active? app.config.ts/js takes precedence over app.json
ls app.config.ts app.config.js app.json 2>/dev/null | head -1

# Does a src/ directory exist? (determines pulse.ts placement)
ls -d src 2>/dev/null
```

| Finding | Decision |
|---|---|
| `app/_layout.tsx` exists | Expo Router → use Expo Router wrapper, disable fragment + screenLifecycle in plugin |
| `@react-navigation/native` present | Standard Expo → use React Navigation wrapper |
| Neither | No nav tracking — `PulseService.start()` only |
| `minSdkVersion < 26` | Add `coreLibraryDesugaring` to plugin config |
| `expo-image` / `FastImage` found | Add `okHttpInstrumentation` to plugin config |
| `app.config.ts` or `app.config.js` found | Edit that file — it takes precedence over `app.json` |

---

## Step 2 — Install the Package

> Add the SDK. Use `npx expo install` (not `yarn add`) so Expo pins the correct compatible version.

```bash
npx expo install @dreamhorizonorg/pulse-react-native
```

---

## Step 3 — Configure the Plugin

> The plugin handles all native init — no Kotlin/Swift edits needed. It injects Pulse into the Android Application class and iOS AppDelegate during prebuild.

**Read the active config file found in Step 1 first.** Then add the following entry to the existing `plugins` array — do not replace the file or restructure it:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED"
  }
]
```

**Critical:** `apiKey` and `dataCollectionState` must be at the plugin root. Do NOT nest inside `android` or `ios` — plugin will fail silently.

**If Expo Router** — disable native screen lifecycle to avoid double-counting what Expo Router already tracks. Keep `activity` on; it powers the AppStart span:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": { "instrumentation": { "fragment": { "enabled": false } } },
  "ios": { "instrumentation": { "screenLifecycle": { "enabled": false } } }
}
```

**If `minSdkVersion < 26`** — add desugaring so Java 8+ APIs work on older Android:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": { "coreLibraryDesugaring": { "enabled": true } }
}
```

**If `expo-image` / `FastImage` found** — enable OkHttp instrumentation to capture image and native HTTP traffic on Android (iOS URLSession is automatic):
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": { "okHttpInstrumentation": { "enabled": true } }
}
```

**API key — use env var, not a hardcoded string:**

```bash
ls .env.example 2>/dev/null
ls app.config.js app.config.ts 2>/dev/null
```

1. Create or update `.env.example`:
   ```
   EXPO_PUBLIC_PULSE_API_KEY=your_pulse_api_key_here
   ```
2. If config is `app.config.js` / `app.config.ts` → use the env var:
   ```js
   apiKey: process.env.EXPO_PUBLIC_PULSE_API_KEY,
   ```
3. If config is `app.json` only → use `"YOUR_API_KEY"` literal placeholder. `app.json` does not support env vars — that is fine, leave it as a placeholder for the user to fill in.

After setup, tell the user:
> Copy `.env.example` to `.env` and set your real key: `EXPO_PUBLIC_PULSE_API_KEY=pk_live_...`
> Find it in the Pulse dashboard under **Project Settings**. Never commit `.env` — add it to `.gitignore`. Commit only `.env.example`.

---

## Step 4 — Prebuild

> Generates the native `ios/` and `android/` folders with Pulse baked in. Must be re-run after any plugin config change.

```bash
npx expo prebuild --clean
```

> **Locale fix:** If this fails with `Encoding::CompatibilityError`:
> ```bash
> LANG=en_US.UTF-8 npx expo prebuild --clean
> ```
> Fix permanently: add `export LANG=en_US.UTF-8` to `~/.zshrc` or `~/.bashrc`.

---

## Step 5 — Create `src/config/pulse.ts`

> A thin wrapper over the Pulse SDK. All app code imports from here — never from `@dreamhorizonorg/pulse-react-native` directly. This keeps the SDK call surface in one place and makes future changes easy.

**Placement:**
- `src/` exists → create `src/config/pulse.ts`
- No `src/` → create `pulse.ts` at root

**Expo Router:**

```typescript
import {
  Pulse,
  PulseDataCollectionConsent,
  type PulseConfig,
  type PulseAttributes,
} from '@dreamhorizonorg/pulse-react-native';
import type { RefObject } from 'react';

export const PulseService = {
  start: (config?: PulseConfig) => Pulse.start(config),

  useNavigationTracking: (navigationRef: RefObject<any>) =>
    Pulse.useNavigationTracking(navigationRef, {
      registerWhenContainerReady: true,
    }),

  setUser: (id: string, properties?: PulseAttributes) => {
    Pulse.setUserId(id);
    if (properties) Pulse.setUserProperties(properties);
  },

  clearUser: () => Pulse.setUserId(null),

  trackEvent: (name: string, properties?: PulseAttributes) =>
    Pulse.trackEvent(name, properties),

  trackNonFatal: (error: unknown, context?: PulseAttributes) =>
    Pulse.reportException(error, false, context),

  setDataCollectionState: (state: PulseDataCollectionConsent) =>
    Pulse.setDataCollectionState(state),

  shutdown: () => Pulse.shutdown(),
};
```

**Standard Expo with React Navigation:**

```typescript
import {
  Pulse,
  PulseDataCollectionConsent,
  type PulseConfig,
  type PulseAttributes,
} from '@dreamhorizonorg/pulse-react-native';
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';
import type React from 'react';

export const PulseService = {
  start: (config?: PulseConfig) => Pulse.start(config),

  useNavigationTracking: (navigationRef: React.RefObject<NavigationContainerRef<ParamListBase>>) =>
    Pulse.useNavigationTracking(navigationRef),

  setUser: (id: string, properties?: PulseAttributes) => {
    Pulse.setUserId(id);
    if (properties) Pulse.setUserProperties(properties);
  },

  clearUser: () => Pulse.setUserId(null),

  trackEvent: (name: string, properties?: PulseAttributes) =>
    Pulse.trackEvent(name, properties),

  trackNonFatal: (error: unknown, context?: PulseAttributes) =>
    Pulse.reportException(error, false, context),

  setDataCollectionState: (state: PulseDataCollectionConsent) =>
    Pulse.setDataCollectionState(state),

  shutdown: () => Pulse.shutdown(),
};
```

**No navigation:**

```typescript
import {
  Pulse,
  PulseDataCollectionConsent,
  type PulseConfig,
  type PulseAttributes,
} from '@dreamhorizonorg/pulse-react-native';

export const PulseService = {
  start: (config?: PulseConfig) => Pulse.start(config),

  setUser: (id: string, properties?: PulseAttributes) => {
    Pulse.setUserId(id);
    if (properties) Pulse.setUserProperties(properties);
  },

  clearUser: () => Pulse.setUserId(null),

  trackEvent: (name: string, properties?: PulseAttributes) =>
    Pulse.trackEvent(name, properties),

  trackNonFatal: (error: unknown, context?: PulseAttributes) =>
    Pulse.reportException(error, false, context),

  setDataCollectionState: (state: PulseDataCollectionConsent) =>
    Pulse.setDataCollectionState(state),

  shutdown: () => Pulse.shutdown(),
};
```

---

## Step 6 — Wire the Entry Point

> Start Pulse at module level so it runs before any component renders. Wire the navigation ref so screen transitions are tracked automatically.

**Expo Router (`app/_layout.tsx`):**

```tsx
import { Stack, useNavigationContainerRef } from 'expo-router';
import { PulseService } from '../src/config/pulse';  // adjust path

PulseService.start();  // module level — runs once before any render

export default function RootLayout() {
  const navigationRef = useNavigationContainerRef();
  PulseService.useNavigationTracking(navigationRef);

  return <Stack />;
}
```

**Standard Expo (`App.tsx`) with React Navigation:**

```tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { PulseService } from './src/config/pulse';  // adjust path

PulseService.start();

export default function App() {
  const navigationRef = React.useRef(null);
  const onReady = PulseService.useNavigationTracking(navigationRef);

  return (
    <NavigationContainer ref={navigationRef} onReady={onReady}>
      {/* existing navigator */}
    </NavigationContainer>
  );
}
```

**No navigation:**

```typescript
import { PulseService } from './src/config/pulse';  // adjust path
PulseService.start();
```

---

## Step 7 — Run & Verify

> Confirm the native build works and Pulse is reporting to the dashboard.

```bash
npx expo run:ios
# or
npx expo run:android
```

Build succeeds + app opens = Pulse is active. Open the Pulse dashboard — session events should appear within a few minutes.

If sessions don't appear → re-run `npx expo prebuild --clean` and rebuild.

---

## Self-Healing

If any step fails during a real setup run, **edit this skill file before retrying** — don't retry the same broken step.

1. Identify which step failed and what the error was
2. Edit the relevant step in `skills/integrating-pulse-expo/SKILL.md`
3. Continue from the corrected step

| Failure | What to fix |
|---|---|
| Plugin config key wrong (prebuild error) | Update Step 3 config snippet |
| `npx expo install` installs wrong version | Add version pin to Step 2 |
| `useNavigationContainerRef` import changed | Update Step 6 Expo Router snippet |
| Detection command wrong result | Update Step 1 commands |
| New plugin option not covered | Add to Step 3 |

---

## ✅ Setup Complete

> **Pulse is active. Open the [Pulse dashboard](https://pulse-ux.com) — sessions should appear within a few minutes.**

With the setup above, the following works with **no additional code**:

| What's tracked | Notes |
|---|---|
| Native crashes | iOS and Android — with full stack traces |
| JS exceptions | Unhandled errors and promise rejections |
| ANR detection | Android only |
| App startup timing | Cold start duration |
| HTTP traffic | `fetch` / `XMLHttpRequest` / `axios` (JS layer) |
| HTTP traffic — images | `expo-image`, `FastImage`, native Android HTTP (if `okHttpInstrumentation` enabled) |
| Screen lifecycle | UIViewControllers (iOS) / Activities + Fragments (Android) — unless disabled for Expo Router |
| Screen events (JS) | `screen_load` + `screen_session` per screen — time to load and time spent |
| Session tracking | Start, end, duration |
| Slow / jank frames | Android only |

`PulseService` in `src/config/pulse.ts` is the single entry point — always use it instead of importing from `@dreamhorizonorg/pulse-react-native` directly.

---

## What Would You Like to Add Next?

Pulse is running — the setup above gives you crashes, sessions, and HTTP tracing with no extra code. Below are the most common follow-ups. When the user picks one, read the reference file and implement it in their codebase.

**1. GDPR / data consent**
Your current setup collects immediately. If you show a consent screen before tracking, initialize with `PENDING` — Pulse buffers all data locally and exports nothing until the user accepts. Declining shuts the SDK down for that session. Required for EU apps and App Store compliance in many regions.
```typescript
// After user accepts (import PulseDataCollectionConsent from the SDK):
PulseService.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
// DENIED is terminal — SDK stops until next app start
```
Reference: `${SKILL_ROOT}/references/data-collection-consent.md`

**2. Global attributes**
Tag every crash, event, trace, and session with build metadata — so the Pulse dashboard lets you filter by `env`, `version`, or `release_channel`. Configured in the **plugin block of `app.json` / `app.config.*`** (compile-time) — not in JS code. Requires `npx expo prebuild --clean` after the change.
```json
"android": { "globalAttributes": { "env": "production", "release_channel": "stable" } },
"ios":     { "globalAttributes": { "env": "production", "release_channel": "stable" } }
```
Reference: `${SKILL_ROOT}/references/global-attributes.md`

**3. Report handled errors**
Errors you catch (API failures, bad responses, try/catch) don't crash the app — but they matter. `trackNonFatal` sends them to Pulse alongside actual crashes so you see the full picture in one place.
```typescript
PulseService.trackNonFatal(error, { screen: 'Checkout', action: 'submitOrder' });
```
Reference: `${SKILL_ROOT}/references/errors.md`

**4. Track business events**
Log what users did before a crash — purchases, funnel steps, feature usage. Pulse correlates events with the active session and span so you can reconstruct the exact user journey leading to an issue.
```typescript
PulseService.trackEvent('purchase_completed', { product_id: 'abc', value: 9.99 });
```
Reference: `${SKILL_ROOT}/references/custom-events.md`

**5. Identify users**
Attach a user ID to every crash, event, and session — so you can answer "who was affected?" and pull up a specific user's full session history in the dashboard.
```typescript
PulseService.setUser(userId, { plan: 'pro' });  // after login
PulseService.clearUser();                         // after logout
```
Reference: `${SKILL_ROOT}/references/user-identification.md`

**6. CodePush / OTA update tracking**
Without this, a crash from OTA update #42 looks identical to the embedded build in the dashboard. Tag the running bundle version as a global attribute so crashes map to the right source map and you can track regressions per OTA release.
Reference: `${SKILL_ROOT}/references/global-attributes.md`

**7. Source maps and symbol files**
Minified stack traces show `index.bundle:1:12345` — useless for triage. Upload source maps once per release and Pulse resolves every frame to the original TypeScript line. Highest-impact improvement for crash debugging.
Reference: `${SKILL_ROOT}/references/source-maps.md`

---

**Which would you like to add? Say a number (1–7), describe what you need, or "skip".**

---

## More Options

| Feature | Reference |
|---|---|
| Measure operation duration (API calls, rendering) | `${SKILL_ROOT}/references/custom-spans.md` |
| Screen time-to-interactive per screen | `${SKILL_ROOT}/references/screen-tracking.md` |
| React error boundary | `${SKILL_ROOT}/references/errors.md` |
| `Pulse.start()` options (autoDetect flags, networkHeaders, logLevel) | `${SKILL_ROOT}/references/rn-start-config.md` |
| Full plugin config options | `${SKILL_ROOT}/references/plugin-reference.md` |
| Expo Router navigation deep-dive | `${SKILL_ROOT}/references/expo-router.md` |
| Shutdown / kill switch | `${SKILL_ROOT}/references/shutdown.md` |
| Debug logging | `${SKILL_ROOT}/references/log-level.md` |

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Plugin error on prebuild | `apiKey`/`dataCollectionState` at plugin root — not inside `android`/`ios` |
| Sessions don't appear in dashboard | Re-run `npx expo prebuild --clean`, rebuild |
| iOS: module not found | Run `cd ios && pod install` |
| Android: unresolved `Pulse` | Confirm prebuild completed, clean rebuild |
| Expo Router: no screen events | Confirm `registerWhenContainerReady: true` in `pulse.ts` wrapper |
