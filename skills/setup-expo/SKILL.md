---
name: setup-expo
description: Full Pulse SDK setup for Expo projects using the config plugin. Covers Expo Router and standard Expo navigation, app.json plugin configuration, prebuild, and JS initialization. Use when asked to add Pulse to an Expo project.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

## Invoke When

- "Add Pulse to my Expo app"
- "Set up Pulse SDK with Expo"
- `expo` is in package.json

---

## Phase 1: Detect

```bash
# Check install state
cat package.json | grep -E '"@dreamhorizonorg/pulse-react-native"|"expo"'

# Check if plugin already configured
cat app.json 2>/dev/null | grep "pulse-react-native"
cat app.config.js 2>/dev/null | grep "pulse-react-native"

# Check for Expo Router
ls app/_layout.tsx app/_layout.jsx app/_layout.js 2>/dev/null
cat package.json | grep "expo-router"

# Check Android minSdk
grep "minSdkVersion" android/app/build.gradle 2>/dev/null
```

| Question | Impact |
|---|---|
| Is `@dreamhorizonorg/pulse-react-native` already installed? | Skip Step 1 |
| Is Pulse plugin already in app.json/app.config.js? | Skip Step 2 |
| Does the project use Expo Router (`app/_layout.tsx` exists)? | Use Expo Router JS init pattern in Step 4 |
| Does the user need GDPR/consent gating? | Use `"PENDING"` instead of `"ALLOWED"` in Step 2 |
| Is Android minSdk < 26? | Add `coreLibraryDesugaring` to plugin config in Step 2 |

---

## Phase 2: Guide

### Step 1 — Install

```bash
npx expo install @dreamhorizonorg/pulse-react-native
```

### Step 2 — Configure app.json

Read the existing `app.json` to find the plugins array. Add the Pulse config plugin:

```json
{
  "expo": {
    "plugins": [
      [
        "@dreamhorizonorg/pulse-react-native",
        {
          "apiKey": "YOUR_API_KEY",
          "dataCollectionState": "ALLOWED"
        }
      ]
    ]
  }
}
```

**Critical:** `apiKey` and `dataCollectionState` must be at the plugin root level. Do NOT nest them inside `android` or `ios` keys — the plugin will fail to initialize.

**GDPR / consent flow:** Use `"PENDING"` if data collection requires user consent. After user grants consent, call:
```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
```
Note: `DENIED` is terminal — once set, the SDK shuts down for the lifetime of the process.

**Android minSdk < 26**, add to the plugin config:
```json
{
  "android": {
    "coreLibraryDesugaring": { "enabled": true }
  }
}
```

Ask the user for their API key if not found in the codebase or environment:
> "What is your Pulse API key? You can find it in the Pulse dashboard under Project Settings."

### Step 3 — Prebuild

```bash
npx expo prebuild --clean
```

This generates the iOS and Android native projects with Pulse initialization baked in. Re-run this every time the plugin config changes.

### Step 4 — JS Initialization

**Standard Expo (App.tsx):**

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.start();

export default function App() {
    return (
        // your app
    );
}
```

**Expo Router (app/_layout.tsx):**

```tsx
import { Stack, useNavigationContainerRef } from 'expo-router';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.start();

function RootLayout() {
    const navigationRef = useNavigationContainerRef();

    Pulse.useNavigationTracking(navigationRef, {
        registerWhenContainerReady: true, // required for Expo Router
        screenSessionTracking: true,
        screenNavigationTracking: true,
        screenInteractiveTracking: false, // enable only if you call Pulse.markContentReady()
    });

    return <Stack />;
}

export default RootLayout;
```

`registerWhenContainerReady: true` is required for Expo Router — the navigation container is not immediately available on mount.

---

## Phase 3: Run & Verify

Build and run the app:

```bash
npx expo run:ios
# or
npx expo run:android
```

Check initialization:
```typescript
console.log('Pulse initialized:', Pulse.isInitialized()); // should be true
```

Open the Pulse dashboard — session events should appear within a few minutes. Remove the console.log after confirming.

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Plugin error on prebuild | `apiKey` / `dataCollectionState` must be at plugin root — not inside `android`/`ios` |
| `Pulse.isInitialized()` returns false | Re-run `npx expo prebuild --clean` then rebuild |
| iOS: module not found after prebuild | Run `cd ios && pod install` |
| Android: unresolved reference `Pulse` | Confirm prebuild completed; clean and rebuild |
| Navigation events not tracked | Confirm `registerWhenContainerReady: true` is set for Expo Router |

---

## Next Steps

Ask if the user wants to configure any of the following:

- Full plugin options (Android/iOS instrumentation toggles) → `${SKILL_ROOT}/references/plugin-reference.md`
- Expo Router navigation details → `${SKILL_ROOT}/references/expo-router.md`
- Error boundaries and manual error reporting → `${SKILL_ROOT}/references/errors.md`
- Source maps for crash symbolication → `${SKILL_ROOT}/references/source-maps.md`
- User identification → `${SKILL_ROOT}/references/user-identification.md`
