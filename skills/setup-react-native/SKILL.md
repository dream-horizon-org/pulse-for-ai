---
name: setup-react-native
description: Full Pulse SDK setup for bare React Native apps (not Expo). Detects Android Application class, iOS AppDelegate, navigation library, and root component. Configures native init, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to React Native without Expo.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

## Invoke When

- User asks to "add Pulse", "set up Pulse", or "integrate Pulse" in a React Native or Expo app
- User wants error monitoring, crash reporting, tracing, profiling, session tracking, or logging in a React Native app
- User wants to monitor native crashes, ANRs, or app hangs on iOS/Android
- User mentions `@dreamhorizonorg/pulse-react-native`, mobile observability, or Pulse SDK
- `react-native` is in `package.json` and `expo` is NOT

---

## Step 0 — Already Installed?

```bash
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
```

If found → **stop**. Tell the user Pulse is already installed. Setup is complete — upgrade is a separate flow.

---

## Step 1 — Detect Everything Upfront

Run all checks now. Record results — don't re-run these later.

```bash
# Android: find Application class from manifest
grep -A5 '<application' android/app/src/main/AndroidManifest.xml 2>/dev/null | grep 'android:name'

# iOS: find AppDelegate (all variants)
find ios -maxdepth 3 \( -name "AppDelegate.swift" -o -name "AppDelegate.m" -o -name "AppDelegate.mm" \) 2>/dev/null

# Find root component registered with AppRegistry
grep -r "AppRegistry.registerComponent" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" . 2>/dev/null | head -5

# Navigation: find where NavigationContainer is rendered
grep -rl "NavigationContainer" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" . 2>/dev/null | grep -v node_modules | head -5

# Navigation library
cat package.json | grep -E '"@react-navigation/native"|"react-native-navigation"|"expo-router"'

# Android minSdk
grep "minSdkVersion\|minSdk " android/app/build.gradle 2>/dev/null

# Wrapper placement
ls -d src/services src/utils src/lib src 2>/dev/null | head -1
```

| What to determine | Impact |
|---|---|
| `android:name` in `<application>` | Identifies Application class file to edit. Default: `MainApplication` |
| AppDelegate extension (`.swift` / `.m` / `.mm`) | Determines Swift vs Objective-C init code |
| `AppRegistry.registerComponent(appName, () => X)` | X is the root component file — this is where `PulseService.start()` goes |
| File containing `<NavigationContainer>` | This is where `useNavigationTracking` hook goes |
| `@react-navigation/native` present | Add `useNavigationTracking` in wrapper |
| `react-native-navigation` (Wix) present | Not supported — skip nav tracking, tell user |
| `minSdkVersion < 26` | Add coreLibraryDesugaring |
| User said Android-only / iOS-only? | Skip unused platform steps |

---

## Step 2 — Install

```bash
yarn add @dreamhorizonorg/pulse-react-native
```

iOS — link native code:
```bash
cd ios && pod install && cd ..
```

---

## Step 3 — Android Native Init

> Skip if user confirmed iOS only.

### 3a — Find the Application class file

From the manifest `android:name` value, resolve the file:
- `.MainApplication` or `com.example.MainApplication` → find `MainApplication.kt` or `MainApplication.java`
- Custom class (e.g. `com.example.App`) → find that file

```bash
find android/app/src/main/java -name "MainApplication.kt" -o -name "MainApplication.java" 2>/dev/null
```

Read the file. Confirm it has `onCreate()`.

### 3b — Inject Pulse init

Create a private `initPulse()` function and call it from `onCreate()` before `super.onCreate()`. `Application.onCreate()` runs on the main thread — never dispatch Pulse init to a background thread.

**Kotlin (`.kt`):**

```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulse.android.api.otel.PulseDataCollectionConsent

override fun onCreate() {
    initPulse()
    super.onCreate()
}

private fun initPulse() {
    Pulse.initialize(
        application = this,
        apiKey = "YOUR_API_KEY",
        dataCollectionState = PulseDataCollectionConsent.ALLOWED,
        instrumentations = {
            fragment { enabled(false) }   // disable for RN — JS navigation handles screens
        }
    )
}
```

**Java (`.java`):**

> Java requires all parameters to be passed explicitly — `Pulse.initialize` has no `@JvmOverloads`.

```java
import com.pulsereactnativeotel.Pulse;
import com.pulse.android.api.otel.PulseDataCollectionConsent;
import com.pulse.utils.PulseLogLevel;

@Override
public void onCreate() {
    initPulse();
    super.onCreate();
}

private void initPulse() {
    // All params must be passed — no @JvmOverloads on Pulse.initialize
    Pulse.initialize(
        this,                                // application
        "YOUR_API_KEY",                      // apiKey
        PulseDataCollectionConsent.ALLOWED,  // dataCollectionState
        null,                                // resource
        null,                                // globalAttributes
        null,                                // beforeSendData
        PulseLogLevel.NONE,                  // logLevel
        null                                 // instrumentations (fragment tracking on by default — acceptable for Java)
    );
}
```

> For Java projects, fragment tracking stays enabled. This is fine for brownfield apps. For greenfield RN Java apps, consider creating a Kotlin init file to use the `instrumentations` DSL.

### 3c — coreLibraryDesugaring (if minSdkVersion < 26)

Add to `android/app/build.gradle`:

```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

---

## Step 4 — iOS Native Init

> Skip if user confirmed Android only.

Read the AppDelegate file found in Step 1.

**Swift (`AppDelegate.swift`):**

```swift
import PulseReactNativeOtel

// Inside application(_:didFinishLaunchingWithOptions:), before the super call:
PulseSDK.initialize(
    apiKey: "YOUR_API_KEY",
    dataCollectionState: .allowed,
    instrumentations: { config in
        config.screenLifecycle { $0.enabled(false) }  // disable for RN — JS navigation handles screens
    }
)
// return super.application(application, didFinishLaunchingWithOptions: launchOptions)
```

**Objective-C (`AppDelegate.m` or `.mm`):**

```objc
#import <PulseReactNativeOtel-Swift.h>

// Inside application:didFinishLaunchingWithOptions:, before [super application:...]:
PulseObjcInstrumentations *inst = [PulseObjcInstrumentations new];
inst.screenLifecycle = [PulseObjcEnabledConfig disabled];

[PulseSDK pulseInitialize:@"YOUR_API_KEY"
    dataCollectionState:@"ALLOWED"
       globalAttributes:nil
          configuration:nil
        instrumentations:inst];
```

**Critical:** Pulse must init on the main thread before React Native starts. Never dispatch to a background thread or defer.

---

## Step 5 — Create PulseService Wrapper

Detect placement from Step 1 results:
- `src/services/` exists → `src/services/PulseService.ts`
- `src/utils/` exists → `src/utils/PulseService.ts`
- `src/lib/` exists → `src/lib/PulseService.ts`
- `src/` exists → `src/PulseService.ts`
- Otherwise → `PulseService.ts` (root)

**With `@react-navigation/native`:**

```typescript
import {
  Pulse,
  type PulseConfig,
  type PulseAttributes,
} from '@dreamhorizonorg/pulse-react-native';
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';
import type React from 'react';

export const PulseService = {
  /** Call at module level in your root component file, before any render */
  start: (config?: PulseConfig) => Pulse.start(config),

  /**
   * Call inside the component that renders <NavigationContainer>.
   * Tracks screen_load and screen_session events automatically.
   * Returns onReady — pass it to <NavigationContainer onReady={onReady}>.
   */
  useNavigationTracking: (
    navigationRef: React.RefObject<NavigationContainerRef<ParamListBase>>,
  ) =>
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

**Without navigation (no nav lib or Wix):**

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

> **Wix Navigation (`react-native-navigation`):** screen tracking is not supported. All other Pulse features work. Use the wrapper above without `useNavigationTracking`.

---

## Step 6 — Wire Root Component

From Step 1, find the component registered with `AppRegistry.registerComponent(appName, () => RootComponent)`.

Open that component file (`App.tsx` or equivalent). Add `PulseService.start()` at module level — **before** the component function, so it runs before any render.

```typescript
import { PulseService } from '<wrapper-path>/PulseService';  // adjust path

PulseService.start();  // module level — runs once before any component renders

export default function App() {
  // your existing app code
}
```

Do NOT put this in `index.js` / `index.ts` (the AppRegistry entry file) — place it in the root component file.

---

## Step 7 — Wire Navigation Tracking

> Skip if no `@react-navigation/native` was found in Step 1.

From Step 1, open the file where `<NavigationContainer>` is rendered. Add the `useNavigationTracking` hook inside that component.

```typescript
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { PulseService } from '<wrapper-path>/PulseService';

function RootNavigator() {
  const navigationRef = React.useRef(null);
  const onReady = PulseService.useNavigationTracking(navigationRef);

  return (
    <NavigationContainer ref={navigationRef} onReady={onReady}>
      {/* existing navigator */}
    </NavigationContainer>
  );
}
```

This enables automatic `screen_load` and `screen_session` tracking for every screen transition.

---

## Step 8 — API Key

Replace `YOUR_API_KEY` in:
- Android: the Application class file (inside `initPulse()`)
- iOS: AppDelegate

If not yet available, ask:
> "What is your Pulse API key? Find it in the Pulse dashboard under Project Settings."

---

## Step 9 — Verify

Build and run on device or simulator. Add temporarily to the root component:

```typescript
if (__DEV__) {
  console.log('Pulse native initialized:', Pulse.isInitialized());
}
```

`isInitialized()` reflects native SDK status — `true` confirms Android/iOS native init succeeded. Remove after confirming.

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
> - Add global metadata (A/B tests, environment) → `${SKILL_ROOT}/references/global-attributes.md`
> - Tune `Pulse.start()` options → `${SKILL_ROOT}/references/rn-start-config.md`
> - Android native instrumentation config → `${SKILL_ROOT}/references/android-native-apis.md`
> - iOS native instrumentation config → `${SKILL_ROOT}/references/ios-native-apis.md`
> - Upload source maps for readable crash stacks → `${SKILL_ROOT}/references/source-maps.md`
> - Shutdown / feature flag kill switch → `${SKILL_ROOT}/references/shutdown.md`
