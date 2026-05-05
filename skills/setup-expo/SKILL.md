---
name: setup-expo
description: Full Pulse SDK setup for Expo projects using the config plugin. Detects Expo Router vs standard navigation, configures app.json plugin, runs prebuild, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to an Expo project.
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

- `expo` not in deps and no Expo config files → **stop**. Tell user: "This looks like bare React Native. Use `/pulse:setup-react-native` instead."
- Package installed AND plugin already in config → **stop**. Tell user Pulse is already set up.

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

Read the active config file found in Step 1. Add to the `plugins` array:

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
ls .env .env.example 2>/dev/null
ls app.config.js app.config.ts 2>/dev/null
```

1. Create or update `.env.example`:
   ```
   EXPO_PUBLIC_PULSE_API_KEY=your_pulse_api_key_here
   ```
2. If `.env` doesn't exist, create it with the same line.
3. If config is `app.config.js` / `app.config.ts` → use the env var:
   ```js
   apiKey: process.env.EXPO_PUBLIC_PULSE_API_KEY,
   ```
4. If config is `app.json` only → use `"YOUR_API_KEY"` literal. Note: `app.json` doesn't support env vars. The user can rename it to `app.config.js` later.

After setup, tell the user:
> Set your real key in `.env`: `EXPO_PUBLIC_PULSE_API_KEY=pk_live_...`
> Find it in the Pulse dashboard under **Project Settings**. Add `.env` to `.gitignore` — commit only `.env.example`.

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
2. Edit the relevant step in `skills/setup-expo/SKILL.md`
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

Present these to the user and ask which they want to implement. When they pick one, read the reference file and make the changes in their codebase.

**1. Control data collection consent**
Right now `dataCollectionState` is `ALLOWED`. If you need GDPR compliance, set it to `PENDING` and call this after the user grants consent:
```typescript
PulseService.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
// DENIED is terminal — SDK shuts down until next app start
```
Reference: `${SKILL_ROOT}/references/data-collection-consent.md`

**2. Set global attributes**
Attach metadata (app version, environment, release channel) to every signal Pulse captures — crashes, events, traces, sessions.
```typescript
PulseService.start({
  globalAttributes: { env: 'production', version: '2.1.0', channel: 'stable' }
});
```
Reference: `${SKILL_ROOT}/references/global-attributes.md`

**3. Report handled errors**
Catch errors from try/catch, API failures, and rejected promises — they show up in Pulse alongside crashes.
```typescript
PulseService.trackNonFatal(error, { screen: 'Checkout', action: 'submitOrder' });
```
Reference: `${SKILL_ROOT}/references/errors.md`

**4. Track business events**
Purchases, funnel steps, button taps — correlate user behavior with performance data.
```typescript
PulseService.trackEvent('purchase_completed', { product_id: 'abc', value: 9.99 });
```
Reference: `${SKILL_ROOT}/references/custom-events.md`

**5. Identify users**
Attach a user ID to all telemetry — filter crashes, sessions, and traces by user.
```typescript
PulseService.setUser(userId, { plan: 'pro' });  // on login
PulseService.clearUser();                        // on logout
```
Reference: `${SKILL_ROOT}/references/user-identification.md`

**6. CodePush / OTA tracking**
Add OTA update metadata (update ID, bundle version) as global attributes so you can correlate issues with specific releases.
Reference: `${SKILL_ROOT}/references/global-attributes.md`

**7. Upload source maps and symbol files**
Make crash stack traces readable — JS source maps, Android ProGuard mappings, iOS dSYMs.
Reference: `${SKILL_ROOT}/references/source-maps.md`

---

Ask: **"Which of these would you like to add? (1–7, or describe what you need)"**

---

## More Options

| Feature | Reference |
|---|---|
| Measure operation duration (API calls, rendering) | `${SKILL_ROOT}/references/custom-spans.md` |
| Screen time-to-interactive per screen | `${SKILL_ROOT}/references/screen-tracking.md` |
| React error boundary | `${SKILL_ROOT}/references/errors.md` |
| Full plugin config options | `${SKILL_ROOT}/references/plugin-reference.md` |
| Expo Router navigation deep-dive | `${SKILL_ROOT}/references/expo-router.md` |
| Android native instrumentation APIs | `${SKILL_ROOT}/references/android-native-apis.md` |
| iOS native instrumentation APIs | `${SKILL_ROOT}/references/ios-native-apis.md` |
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
