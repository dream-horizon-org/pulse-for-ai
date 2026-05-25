---
name: setup-expo
description: Full Pulse SDK setup for Expo projects using the config plugin. Detects Expo Router vs standard navigation, configures app.json plugin, runs prebuild, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to an Expo project.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

> **Editing rule:** Make minimal, surgical edits only. Do not reformat existing code, reorder imports, fix style issues, or touch any lines outside the specific insertion points. Every change must be Pulse-only. Preserve all surrounding code exactly as-is.

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
4. **Never modify business logic.** No refactors, no renames, no architectural moves.
5. **Never install anything except `@dreamhorizonorg/pulse-react-native`.**
6. **Never write `.env`** — write `.env.example` only. Never commit, stage, or print real API keys.
7. **Never convert config formats.** If the project uses `app.json`, keep it as `app.json`.
8. **Never run destructive commands.** No `git reset`, `git clean`, `rm -rf`.
9. **Show the diff before writing.** For any edit, summarize "I'm about to add N lines to file X." Then write.
10. **One step at a time.** Run each numbered step, report the result, then proceed.

### Allowed file matrix

| File | Action |
|---|---|
| `app.json` / `app.config.js` / `app.config.ts` | Read → append one entry to `plugins` array only |
| `app/_layout.tsx` or `App.tsx` | Read → add import + `PulseService.start()` + optional `useNavigationTracking` |
| `src/config/pulse.ts` | Create new file only. Never overwrite if exists — stop and ask. |
| `.env.example` | Append `EXPO_PUBLIC_PULSE_API_KEY=...` if missing |
| `.env` | **Never touch.** |
| Anything else | **Forbidden.** |

### When to stop and ask

- Config already contains `@dreamhorizonorg/pulse-react-native` plugin entry → ask before editing.
- `src/config/pulse.ts` or `pulse.ts` already exists → ask before overwriting.
- Entry point already calls `Pulse.start()` or `PulseService.start()` → ask before adding.
- Unfamiliar config setup → ask before proceeding.

---

## Step 0 — Load Project Memory

Check if this project has been seen before:

```bash
cat .pulse/learnings.md 2>/dev/null
```

If file exists, read it and apply all recorded facts (config file path, package manager, Expo SDK version, quirks) — skip re-detecting anything already known. If file doesn't exist, proceed normally.

---

## Step 0b — Already Installed?

```bash
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
cat app.json 2>/dev/null | grep "pulse-react-native"
cat app.config.js 2>/dev/null | grep "pulse-react-native"
cat app.config.ts 2>/dev/null | grep "pulse-react-native"
```

If package installed AND plugin already in config, also check whether JS init is already wired:

```bash
grep -r "Pulse\.start\|PulseService\.start" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | grep -v node_modules | head -3
```

- Package installed AND plugin in config AND `Pulse.start` already called → **do not re-run setup**. Instead tell the user:
  > "Pulse is already set up in this project. What would you like to add next?
  > (1) GDPR / data consent, (2) Global attributes, (3) Handled error reporting, (4) Custom events, (5) User identification, (6) CodePush / OTA tracking, (7) Source maps"
  
  When the user responds, read the relevant reference file from `./references/` and implement the feature in their codebase. Don't re-run setup steps.

  If they want to upgrade instead:
  1. Check current vs latest: `npm show @dreamhorizonorg/pulse-react-native version` vs version in `package.json`
  2. Already on latest → tell user "You're already on the latest version. No action needed."
  3. Upgrade available → bump version, re-run `npx expo prebuild --clean`, rebuild. Check changelog for any plugin config changes.
- Package installed and plugin in config but no `Pulse.start` found → skip Steps 2–4, continue from Step 5.

---

## Step 1 — Detect

```bash
# Expo Router?
ls app/_layout.tsx app/_layout.jsx app/_layout.js 2>/dev/null

# Navigation lib
cat package.json | grep -E '"@react-navigation/native"|"expo-router"'

# Android minSdk + ProGuard (if android/ exists from a prior prebuild)
grep "minSdkVersion\|minSdk \|minifyEnabled\|productFlavors" android/app/build.gradle 2>/dev/null

# Wrapper placement
ls -d src/services src/utils src/lib src 2>/dev/null | head -1

# app.config.js vs app.json
ls app.config.js app.config.ts app.json 2>/dev/null | head -1

# TypeScript or JavaScript project?
ls tsconfig.json 2>/dev/null

# Monorepo?
ls packages/ apps/ turbo.json nx.json pnpm-workspace.yaml 2>/dev/null | head -3
```

| What to determine | Impact |
|---|---|
| `app/_layout.tsx` exists | Expo Router — use Expo Router wrapper + `useNavigationContainerRef` |
| `@react-navigation/native` present | Standard Expo — use React Navigation wrapper |
| Neither present | Simple app — `PulseService.start()` only, no nav tracking |
| `minSdkVersion < 26` in android/ | Add `coreLibraryDesugaring` to plugin config |
| App uses `Image`, `FastImage`, or native Android HTTP | Add `okHttpInstrumentation` to plugin config (Android only — iOS URLSession is auto) |
| GDPR / consent required? | Use `"PENDING"` instead of `"ALLOWED"` |
| `app.config.js` vs `app.json` | Edit the correct config file |
| `tsconfig.json` present | Use `.ts`/`.tsx` for wrapper. Absent → use `.js`/`.jsx` |
| Expo SDK ≤ 52 (`"expo": "~52.x.x"` or lower in package.json) | Add `android.kotlin19Compat: true` to plugin config |
| New Architecture (Expo SDK 51+) | SDK is Turbo Module compatible — no extra config needed |
| Monorepo detected (`turbo.json`, `nx.json`, `packages/`, `apps/`) | Run `npx expo install` and all Expo commands from the app package directory, not the repo root |
| `react-native-web` present or user targeting web | `isSupportedPlatform()` returns `false` on web — SDK silently no-ops. No data in Pulse dashboard for the web target. Web apps should use `@dreamhorizon/pulse-web` instead. |

---

## Step 2 — Install

```bash
npx expo install @dreamhorizonorg/pulse-react-native
```

---

## Step 3 — Configure Plugin

Read the config file detected in Step 1. Check if `@dreamhorizonorg/pulse-react-native` is already in `plugins` — if so, skip to Step 4.

**Fallback chain — if no config file found in Step 1:**
```bash
find . -maxdepth 2 -name "app.json" -o -name "app.config.js" -o -name "app.config.ts" 2>/dev/null | grep -v node_modules
```
- Multiple found → ask user: "Which is your main Expo config file?"
- None found → ask user: "Where is your Expo config file (app.json or app.config.js)?"

**Critical:** `apiKey` and `dataCollectionState` must be at the plugin root level. Do NOT nest inside `android` or `ios` sub-keys — plugin will fail silently.

---

### If config is `app.json`

Add to the `plugins` array inside the `expo` key:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED"
  }
]
```

---

### If config is `app.config.js` or `app.config.ts`

The config is a JS/TS module — **do not paste JSON**. Add to the `plugins` array in the exported object:

```js
// app.config.js
module.exports = {
  expo: {
    // ...existing config...
    plugins: [
      // ...existing plugins...
      [
        '@dreamhorizonorg/pulse-react-native',
        {
          apiKey: 'YOUR_API_KEY',
          dataCollectionState: 'ALLOWED',
        },
      ],
    ],
  },
};
```

If it uses `export default` (TypeScript):

```ts
// app.config.ts
import { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  // ...existing config...
  plugins: [
    // ...existing plugins...
    [
      '@dreamhorizonorg/pulse-react-native',
      {
        apiKey: 'YOUR_API_KEY',
        dataCollectionState: 'ALLOWED',
      },
    ],
  ],
};

export default config;
```

Preserve all existing config — only add the Pulse plugin entry to the existing `plugins` array. If no `plugins` array exists, create one.

**Do not hardcode the API key in source control.** For `app.config.js`/`app.config.ts`, use an env var:

```js
// .env
EXPO_PUBLIC_PULSE_API_KEY=your-key-here
```
```js
// app.config.js
apiKey: process.env.EXPO_PUBLIC_PULSE_API_KEY,
```

`EXPO_PUBLIC_*` vars are automatically available in Expo config files. For `app.json` (static), the key must be a literal — move to `app.config.js` if you need env-based keys.

---

**If `minSdkVersion < 26`**, add inside the plugin config:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": {
    "coreLibraryDesugaring": { "enabled": true }
  }
}
```

**If using Expo SDK ≤ 52** (Kotlin 1.9.x), add `kotlin19Compat` to avoid build errors:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": {
    "kotlin19Compat": true
  }
}
```

Check Expo SDK version: `cat package.json | grep '"expo"'`. If version is `~52.x.x` or lower, add this.

**If app uses `Image`, `FastImage`, or any native Android HTTP client**, add `okHttpInstrumentation` to capture OkHttp traffic that bypasses the JS layer:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": {
    "okHttpInstrumentation": { "enabled": true }
  }
}
```

**If Expo Router detected (Step 1)**, disable native screen lifecycle events to avoid duplicating what Expo Router already tracks. Keep `activity` enabled — it powers the AppStart span:
```json
{
  "apiKey": "YOUR_API_KEY",
  "dataCollectionState": "ALLOWED",
  "android": {
    "instrumentation": {
      "fragment": { "enabled": false }
    }
  },
  "ios": {
    "instrumentation": {
      "screenLifecycle": { "enabled": false }
    }
  }
}
```

**If GDPR / consent required**, use `"PENDING"` and tell the user to call this after consent is granted:
```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
// DENIED is terminal — SDK shuts down until app restart
```

**API key — use env var, not a hardcoded string:**

1. Append to `.env.example` (create if missing):
   ```
   EXPO_PUBLIC_PULSE_API_KEY=your_pulse_api_key_here
   ```
2. If config is `app.config.js` / `app.config.ts` → use `process.env.EXPO_PUBLIC_PULSE_API_KEY` as the `apiKey` value.
3. If config is `app.json` → use `"YOUR_API_KEY"` placeholder (app.json doesn't support env vars).

> Never write `.env` — only `.env.example`. Tell the user: copy `.env.example` to `.env` and set the real key. Find it in Pulse dashboard → Project Settings.

Ask for API key if not in codebase:
> "What is your Pulse API key? Find it in the Pulse dashboard under Project Settings."

---

## Step 4 — Prebuild

> **Warning — destructive:** `--clean` deletes and regenerates `android/` and `ios/` directories. Any uncommitted changes in those folders will be lost.
>
> Before running, check:
> ```bash
> git status android/ ios/ 2>/dev/null
> ```
> If there are uncommitted changes, tell the user: "Prebuild will overwrite `android/` and `ios/`. Commit or stash those changes first, or they will be lost."
> Only proceed after the user confirms.

> **EAS Build users:** Skip this step. Prebuild runs automatically in the EAS pipeline — do not run it locally.

```bash
npx expo prebuild --clean
```

Generates native Android and iOS projects with Pulse init baked in. Re-run every time the plugin config changes.

> **Expo Go users:** Pulse SDK requires a dev build or `expo run:ios` / `expo run:android` — it does not work in Expo Go. If the user is using Expo Go, tell them they need a dev build.

---

## Step 5 — Create PulseService Wrapper

Check if a wrapper already exists:

```bash
find . \( -name "PulseService.ts" -o -name "PulseService.js" \) 2>/dev/null | grep -v node_modules
```

If found → read it first. Extend it with any missing methods rather than overwriting it.

If not found, detect placement from Step 1 and use `.ts` or `.js` based on TypeScript detection:
- `src/services/` → `src/services/PulseService.ts` (or `.js`)
- `src/utils/` → `src/utils/PulseService.ts` (or `.js`)
- `src/lib/` → `src/lib/PulseService.ts` (or `.js`)
- `src/` → `src/PulseService.ts` (or `.js`)
- Otherwise → `PulseService.ts` (or `.js`) at root

**Expo Router:**

```typescript
import {
  Pulse,
  PulseDataCollectionConsent,
  type PulseConfig,
  type PulseAttributes,
} from '@dreamhorizonorg/pulse-react-native';
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';

export const PulseService = {
  /** Call at module level in root _layout.tsx, before any component renders */
  start: (config?: PulseConfig) => Pulse.start(config),

  /**
   * Call inside root layout with useNavigationContainerRef() from expo-router.
   * Tracks screen_load and screen_session events automatically.
   */
  useNavigationTracking: (navigationRef: NavigationContainerRef<ParamListBase>) =>
    Pulse.useNavigationTracking(navigationRef, {
      registerWhenContainerReady: true,   // required for Expo Router
      screenSessionTracking: true,
      screenNavigationTracking: true,
      screenInteractiveTracking: false,
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
    Pulse.useNavigationTracking(navigationRef, {
      screenSessionTracking: true,
      screenNavigationTracking: true,
      screenInteractiveTracking: false,
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

## Step 6 — Wire Entry Point

**Expo Router (`app/_layout.tsx`):**

```tsx
import { Stack, useNavigationContainerRef } from 'expo-router';
import { PulseService } from '<wrapper-path>/PulseService';

PulseService.start();  // module level — before any render

function RootLayout() {
  const navigationRef = useNavigationContainerRef();
  PulseService.useNavigationTracking(navigationRef);

  return <Stack />;
}

export default RootLayout;
```

**Standard Expo (`App.tsx`) with React Navigation:**

If `App.tsx` already has a `<NavigationContainer>`, add `ref` and `onReady` to it. If there is no `NavigationContainer` yet, wrap the root view with one. Either way the result must be:

```tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';
import { PulseService } from '<wrapper-path>/PulseService';

PulseService.start();

function App() {
  const navigationRef = React.useRef<NavigationContainerRef<ParamListBase>>(null);
  const onReady = PulseService.useNavigationTracking(navigationRef);

  return (
    <NavigationContainer ref={navigationRef} onReady={onReady}>
      {/* existing navigator */}
    </NavigationContainer>
  );
}

export default App;
```

**No navigation — add to `App.tsx`:**

```typescript
import { PulseService } from '<wrapper-path>/PulseService';
PulseService.start();
```

---

## Step 7 — Run & Verify

```bash
npx expo run:ios
# or
npx expo run:android
```

Add temporarily to confirm native init succeeded:
```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';
if (__DEV__) {
  console.log('Pulse native initialized:', Pulse.isInitialized());
}
```

`Pulse.isInitialized()` reflects native SDK status — `true` confirms native init from prebuild succeeded. If false → re-run `npx expo prebuild --clean` and rebuild. Remove after confirming.

---

## ✅ Pulse is Now Active

Tell the user what Pulse is now tracking automatically:

- **JS crashes** and unhandled promise rejections
- **HTTP requests** — fetch, XHR, axios (url, method, status, duration)
- **App startup timing** — cold start duration
- **Android:** activity lifecycle, ANR detection, slow/jank frames
- **iOS:** URLSession (includes `Image` and `FastImage` traffic automatically)
- **Sessions** — session start/end, session duration
- **Screen events** (if navigation was wired): `screen_load` on every navigation, `screen_session` — time spent on each screen
- **Android `Image`/`FastImage`** — only if `okHttpInstrumentation` was enabled in plugin config

`PulseService` at the path created in Step 5 is the single entry point — use it instead of importing `Pulse` directly. Replace all `<wrapper-path>` placeholders in the generated code with the actual resolved path (e.g. `../services/PulseService`).

---

## What's Next?

Confirm the API key is saved, then ask the user:

> "Pulse is set up and tracking. What would you like to configure next?"
> - Track business events (`trackEvent`) → `./references/custom-events.md`
> - Report handled errors and add error boundaries → `./references/errors.md`
> - Measure operation durations with spans → `./references/custom-spans.md`
> - Attach user identity (login/logout) → `./references/user-identification.md`
> - Screen interactive tracking (time-to-interactive) → `./references/screen-tracking.md`
> - Gate data collection behind consent (GDPR) → `./references/data-collection-consent.md`
> - Add global metadata (A/B tests, OTA update ID) → `./references/global-attributes.md`
> - Full plugin options (all Android/iOS instrumentations) → `./references/plugin-reference.md`
> - Tune `Pulse.start()` options → `./references/rn-start-config.md`
> - Network monitoring config (OkHttp, custom headers) → `./references/network.md`
> - Upload source maps for readable crash stacks → `./references/source-maps.md`
> - Shutdown / feature flag kill switch → `./references/shutdown.md`
> - Mask PII / sensitive content in session replay → `./references/session-replay.md`
> - Navigation tracking options deep-dive → `./references/navigation.md`

**Remind the user:** Source maps must be re-uploaded on every release build. Without this, crash stack traces will be unreadable in production.

---

## Save Project Memory

Write `.pulse/learnings.md` with everything discovered about this project. Create or overwrite:

Add `.pulse/` to `.gitignore` if not already present:
```bash
grep -q "\.pulse/" .gitignore 2>/dev/null || echo ".pulse/" >> .gitignore
```

```markdown
# Pulse Project Learnings
<!-- Auto-generated by pulse:setup-expo. Do not commit — .pulse/ is gitignored. -->

- **Integrated:** yes (date: <today>)
- **Package manager:** <yarn|npm|pnpm|bun>
- **Language:** <TypeScript|JavaScript>
- **Expo SDK version:** <e.g. 53.0.0>
- **Config file:** <app.json|app.config.js|app.config.ts>
- **Navigation:** <Expo Router|React Navigation|none> — root in <file>
- **PulseService location:** <path/to/PulseService.ts>
- **Monorepo:** <yes — app root at X|no>
- **Quirks:** <any non-standard findings, e.g. kotlin19Compat needed, coreLibraryDesugaring added, EAS Build in use>
```

Fill in only what was discovered. Omit unknown fields. This file lets the next agent run skip re-detection and avoid repeating mistakes.

---

## What Would You Like to Add Next?

Pulse is running. The setup above gives you crashes, sessions, and HTTP tracing with no extra code. Common follow-ups:

**1. GDPR / data consent** — initialize with `PENDING`, export nothing until user accepts. Required for EU apps.
Reference: `./references/data-collection-consent.md`

**2. Global attributes** — tag every crash and session with `env`, `version`, build metadata.
Reference: `./references/global-attributes.md`

**3. Report handled errors** — send caught exceptions to Pulse alongside crashes.
```typescript
PulseService.trackNonFatal(error, { screen: 'Checkout' });
```
Reference: `./references/errors.md`

**4. Track business events** — log purchases, funnel steps, feature usage.
```typescript
PulseService.trackEvent('purchase_completed', { value: 9.99 });
```
Reference: `./references/custom-events.md`

**5. Identify users** — attach user ID to every crash and session.
```typescript
PulseService.setUser(userId, { plan: 'pro' });
PulseService.clearUser(); // on logout
```
Reference: `./references/user-identification.md`

**6. CodePush / OTA tracking** — tag bundle version so crashes map to the right source map.
Reference: `./references/global-attributes.md`

**7. Source maps** — resolve minified stack traces to original TypeScript lines.
Reference: `./references/source-maps.md`

When the user picks one, read the reference file and implement it in their codebase.

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Plugin error on prebuild | `apiKey`/`dataCollectionState` at plugin root — not inside `android`/`ios` sub-keys |
| `isInitialized()` returns false | Re-run `npx expo prebuild --clean`, rebuild. Confirm not running in Expo Go (dev build required). |
| Expo Go: nothing works | Pulse requires a dev build — `npx expo run:ios` or `npx expo run:android`. Not compatible with Expo Go. |
| iOS: module not found | Run `cd ios && pod install` after prebuild |
| Android: unresolved `Pulse` | Prebuild did not complete. Re-run `npx expo prebuild --clean`, then rebuild. |
| Android build fails with Kotlin error | Expo SDK ≤ 52 — add `android.kotlin19Compat: true` to plugin config, re-run prebuild |
| Android build fails with desugaring error | `minSdkVersion < 26` — add `android.coreLibraryDesugaring.enabled: true` to plugin config |
| Expo Router: no screen events | Confirm `registerWhenContainerReady: true` in `useNavigationTracking` call |
| Standard nav: no screen events | Confirm `onReady` return value is passed to `<NavigationContainer onReady={onReady}>` |
| No network events | `autoDetectNetwork: true` by default. For Android `Image`/`FastImage`, enable `okHttpInstrumentation` in plugin config — see `./references/network.md` |
| Release build crashes (Android) | R8/ProGuard issue. SDK ships consumer rules — should auto-apply. If still failing, add `-keep class com.pulsereactnativeotel.** { *; }` to `android/app/proguard-rules.pro` |
| EAS Build: prebuild errors | Do not run `npx expo prebuild` locally — EAS handles it. Check EAS build logs for plugin config errors. |
| Plugin config change not taking effect | Re-run `npx expo prebuild --clean` after every plugin config change |

---

## Need More?

| Topic | Reference |
|---|---|
| `Pulse.start()` all options | `./references/rn-start-config.md` |
| Screen session / interactive / load tracking | `./references/screen-tracking.md` |
| Full plugin options (all Android/iOS instrumentations) | `./references/plugin-reference.md` |
| Expo Router navigation deep-dive | `./references/expo-router.md` |
| Custom events | `./references/custom-events.md` |
| Handled errors + error boundaries | `./references/errors.md` |
| Custom spans (measure durations) | `./references/custom-spans.md` |
| User identification | `./references/user-identification.md` |
| Global metadata | `./references/global-attributes.md` |
| Data collection consent (GDPR) | `./references/data-collection-consent.md` |
| Shutdown / feature flag kill switch | `./references/shutdown.md` |
| Debug logging | `./references/log-level.md` |
| Source maps for crash symbolication | `./references/source-maps.md` |
| Network monitoring (OkHttp, headers) | `./references/network.md` |
