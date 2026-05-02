---
name: setup-expo
description: Full Pulse SDK setup for Expo projects using the config plugin. Detects Expo Router vs standard navigation, configures app.json plugin, runs prebuild, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to an Expo project.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

## Invoke When

- User asks to "add Pulse", "set up Pulse", or "integrate Pulse" in an Expo app
- User wants error monitoring, crash reporting, tracing, profiling, session tracking, or logging in an Expo app
- User wants to monitor native crashes, ANRs, or app hangs on iOS/Android in an Expo project
- User mentions `@dreamhorizonorg/pulse-react-native`, mobile observability, or Pulse SDK with Expo
- `expo` is in `package.json`

---

## Step 0 — Already Installed?

```bash
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
cat app.json 2>/dev/null | grep "pulse-react-native"
cat app.config.js 2>/dev/null | grep "pulse-react-native"
```

If package is installed AND plugin is already in app.json/app.config.js → **stop**. Tell user Pulse is already set up. Upgrade is a separate flow.

---

## Step 1 — Detect

```bash
# Expo Router?
ls app/_layout.tsx app/_layout.jsx app/_layout.js 2>/dev/null

# Navigation lib
cat package.json | grep -E '"@react-navigation/native"|"expo-router"'

# Android minSdk (if android/ exists from a prior prebuild)
grep "minSdkVersion\|minSdk " android/app/build.gradle 2>/dev/null

# Wrapper placement
ls -d src/services src/utils src/lib src 2>/dev/null | head -1

# app.config.js vs app.json
ls app.config.js app.config.ts app.json 2>/dev/null | head -1
```

| What to determine | Impact |
|---|---|
| `app/_layout.tsx` exists | Expo Router — use Expo Router wrapper + `useNavigationContainerRef` |
| `@react-navigation/native` present | Standard Expo — use React Navigation wrapper |
| Neither present | Simple app — `PulseService.start()` only, no nav tracking |
| `minSdkVersion < 26` in android/ | Add `coreLibraryDesugaring` to plugin config |
| GDPR / consent required? | Use `"PENDING"` instead of `"ALLOWED"` |
| `app.config.js` vs `app.json` | Edit the correct config file |

---

## Step 2 — Install

```bash
npx expo install @dreamhorizonorg/pulse-react-native
```

---

## Step 3 — Configure Plugin

Read the existing `app.json` (or `app.config.js`). Add to the `plugins` array:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED"
  }
]
```

**Critical:** `apiKey` and `dataCollectionState` must be at the plugin root level. Do NOT nest inside `android` or `ios` sub-keys — plugin will fail silently.

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

**If GDPR / consent required**, use `"PENDING"` and tell the user to call this after consent is granted:
```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
// DENIED is terminal — SDK shuts down until app restart
```

Ask for API key if not in codebase:
> "What is your Pulse API key? Find it in the Pulse dashboard under Project Settings."

---

## Step 4 — Prebuild

```bash
npx expo prebuild --clean
```

Generates native Android and iOS projects with Pulse init baked in. Re-run every time the plugin config changes.

---

## Step 5 — Create PulseService Wrapper

Detect placement from Step 1:
- `src/services/` → `src/services/PulseService.ts`
- `src/utils/` → `src/utils/PulseService.ts`
- `src/lib/` → `src/lib/PulseService.ts`
- `src/` → `src/PulseService.ts`
- Otherwise → `PulseService.ts` (root)

**Expo Router:**

```typescript
import {
  Pulse,
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

  shutdown: () => Pulse.shutdown(),
};
```

**Standard Expo with React Navigation:**

```typescript
import {
  Pulse,
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

  shutdown: () => Pulse.shutdown(),
};
```

**No navigation:**

```typescript
import {
  Pulse,
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

```tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { PulseService } from '<wrapper-path>/PulseService';

PulseService.start();

function App() {
  const navigationRef = React.useRef(null);
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
- **iOS:** ViewController transitions, URLSession
- **Sessions** — session start/end, session duration
- **Screen events** (if navigation was wired): `screen_load` on every navigation, `screen_session` — time spent on each screen

`PulseService` at `<wrapper-path>` is the single entry point — use it instead of importing `Pulse` directly.

---

## What's Next?

Confirm the API key is saved, then ask the user:

> "Pulse is set up and tracking. What would you like to configure next?"
> - Track business events (`trackEvent`) → `${SKILL_ROOT}/references/custom-events.md`
> - Report handled errors and add error boundaries → `${SKILL_ROOT}/references/errors.md`
> - Measure operation durations with spans → `${SKILL_ROOT}/references/custom-spans.md`
> - Attach user identity (login/logout) → `${SKILL_ROOT}/references/user-identification.md`
> - Screen interactive tracking (time-to-interactive) → `${SKILL_ROOT}/references/screen-tracking.md`
> - Gate data collection behind consent (GDPR) → `${SKILL_ROOT}/references/data-collection-consent.md`
> - Add global metadata (A/B tests, OTA update ID) → `${SKILL_ROOT}/references/global-attributes.md`
> - Full plugin options (all Android/iOS instrumentations) → `${SKILL_ROOT}/references/plugin-reference.md`
> - Tune `Pulse.start()` options → `${SKILL_ROOT}/references/rn-start-config.md`
> - Upload source maps for readable crash stacks → `${SKILL_ROOT}/references/source-maps.md`
> - Shutdown / feature flag kill switch → `${SKILL_ROOT}/references/shutdown.md`

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Plugin error on prebuild | `apiKey`/`dataCollectionState` at plugin root — not inside `android`/`ios` |
| `isInitialized()` returns false | Re-run `npx expo prebuild --clean`, rebuild |
| iOS: module not found | Run `cd ios && pod install` |
| Android: unresolved `Pulse` | Confirm prebuild completed, clean rebuild |
| Expo Router: no screen events | Confirm `registerWhenContainerReady: true` in wrapper |

---

## Need More?

| Topic | Reference |
|---|---|
| `Pulse.start()` all options | `${SKILL_ROOT}/references/rn-start-config.md` |
| Screen session / interactive / load tracking | `${SKILL_ROOT}/references/screen-tracking.md` |
| Full plugin options (all Android/iOS instrumentations) | `${SKILL_ROOT}/references/plugin-reference.md` |
| Expo Router navigation deep-dive | `${SKILL_ROOT}/references/expo-router.md` |
| Custom events | `${SKILL_ROOT}/references/custom-events.md` |
| Handled errors + error boundaries | `${SKILL_ROOT}/references/errors.md` |
| Custom spans (measure durations) | `${SKILL_ROOT}/references/custom-spans.md` |
| User identification | `${SKILL_ROOT}/references/user-identification.md` |
| Global metadata | `${SKILL_ROOT}/references/global-attributes.md` |
| Data collection consent (GDPR) | `${SKILL_ROOT}/references/data-collection-consent.md` |
| Shutdown / feature flag kill switch | `${SKILL_ROOT}/references/shutdown.md` |
| Debug logging | `${SKILL_ROOT}/references/log-level.md` |
| Source maps for crash symbolication | `${SKILL_ROOT}/references/source-maps.md` |
