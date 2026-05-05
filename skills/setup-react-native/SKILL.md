---
name: setup-react-native
description: Full Pulse SDK setup for bare React Native apps (not Expo). Detects Android Application class, iOS AppDelegate, navigation library, and root component. Configures native init, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to React Native without Expo.
category: sdk-setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

## Invoke When

- User asks to "add Pulse", "set up Pulse", or "integrate Pulse" in a React Native or Expo app
- User wants error monitoring, crash reporting, tracing, profiling, session tracking, or logging in a React Native app
- User wants to monitor native crashes, ANRs, or app hangs on iOS/Android
- User mentions `@dreamhorizonorg/pulse-react-native`, mobile observability, or Pulse SDK
- `react-native` is in `package.json` and `expo` is NOT

---

## Step 0 — Verify Platform + Already Installed?

```bash
# Confirm this is bare React Native (not Expo)
node -e "const p=require('./package.json'); const d={...p.dependencies,...p.devDependencies}; console.log(d['expo'] ? 'expo' : d['react-native'] ? 'react-native' : 'unknown')" 2>/dev/null
ls app.json app.config.js app.config.ts eas.json 2>/dev/null

# Check if Pulse is already installed
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
```

- If `expo` found in deps, or Expo config files (`app.json`, `eas.json`, `app.config.js`) exist → **stop**. Tell the user: "This looks like an Expo project. Use `/pulse:setup-expo` instead."
- If Pulse is already installed → **stop**. Tell the user Pulse is already installed. Setup is complete — upgrade is a separate flow.

---

## Step 1 — Detect Everything Upfront

Run all checks now. Record results — don't re-run these later.

```bash
# Android: find Application class from manifest
grep -A5 '<application' android/app/src/main/AndroidManifest.xml 2>/dev/null | grep 'android:name'

# iOS: find AppDelegate — covers Swift, ObjC (.m), and ObjC++ (.mm, default in RN 0.71+)
find ios -maxdepth 3 \( -name "AppDelegate.swift" -o -name "AppDelegate.m" -o -name "AppDelegate.mm" \) 2>/dev/null

# Find root component registered with AppRegistry
grep -r "AppRegistry.registerComponent" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" . 2>/dev/null | grep -v node_modules | head -5

# Navigation: find where NavigationContainer is rendered
grep -rl "NavigationContainer" --include="*.tsx" --include="*.ts" --include="*.jsx" --include="*.js" . 2>/dev/null | grep -v node_modules | head -5

# Navigation library
cat package.json | grep -E '"@react-navigation/native"|"react-native-navigation"|"expo-router"'

# Android minSdk
grep "minSdkVersion\|minSdk " android/app/build.gradle 2>/dev/null

# TypeScript present? (affects wrapper file extension)
ls tsconfig.json 2>/dev/null

# New Architecture? (RN 0.73+ — affects native module bridging, not Pulse init)
grep -E '"newArchEnabled"|newArchEnabled' android/gradle.properties 2>/dev/null
grep "RCT_NEW_ARCH_ENABLED" ios/Podfile 2>/dev/null

# Does a src/ directory exist? (determines pulse.ts placement)
ls -d src 2>/dev/null

# Monorepo check — is this a subpackage?
ls ../../package.json ../package.json 2>/dev/null | head -1
```

| What to determine | Impact |
|---|---|
| `android:name` in `<application>` | Application class to edit. Default: `MainApplication`. Custom = find that file |
| No `android/` folder | Android-only setup not needed — iOS only, or Android not yet added |
| AppDelegate is `.mm` or `.m` | Use Objective-C snippet. `.swift` → Swift snippet |
| `AppRegistry.registerComponent(appName, () => X)` | X = root component file — add `PulseService.start()` there |
| File containing `<NavigationContainer>` | Add `useNavigationTracking` hook in that file |
| `@react-navigation/native` present | Add `useNavigationTracking` in wrapper |
| `react-native-navigation` (Wix) present | Nav tracking not supported — skip, tell user |
| `minSdkVersion < 26` | Add coreLibraryDesugaring |
| `tsconfig.json` present | Create wrapper as `PulseService.ts` — else `.js` |
| New Architecture enabled | Note only — Pulse supports both. No init change needed |
| `../../package.json` found | Likely monorepo — confirm which subpackage to instrument |
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

> **Locale fix:** If `pod install` fails with `Encoding::CompatibilityError`, run:
> ```bash
> cd ios && LANG=en_US.UTF-8 pod install && cd ..
> ```
> Fix permanently: add `export LANG=en_US.UTF-8` to `~/.zshrc` or `~/.bashrc`.

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

## Step 5 — Create `src/config/pulse.ts`

> A thin wrapper over the Pulse SDK. All app code imports from here — never from `@dreamhorizonorg/pulse-react-native` directly.

**Placement:**
- `src/` exists → create `src/config/pulse.ts`
- No `src/` → create `pulse.ts` at root

**With `@react-navigation/native`:**

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

**Without navigation (no nav lib or Wix):**

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

> **Wix Navigation (`react-native-navigation`):** screen tracking not supported. All other features work. Use the wrapper above without `useNavigationTracking`.

---

## Step 6 — Wire Root Component

From Step 1, find the component registered with `AppRegistry.registerComponent(appName, () => RootComponent)`.

Open that component file (`App.tsx` or equivalent). Add `PulseService.start()` at module level — **before** the component function, so it runs before any render.

```typescript
import { PulseService } from './src/config/pulse';  // adjust path

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
import { PulseService } from './src/config/pulse';  // adjust path

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

---

## Self-Healing

If any step fails or produces an unexpected result during a real setup run, **edit this skill file before retrying**. Don't just retry the same broken step.

**How:**
1. Identify which step failed and what the actual output/error was
2. Edit the relevant step in this file (`skills/setup-react-native/SKILL.md`) to fix the instruction, command, or code snippet
3. Continue from the corrected step

**Common cases to fix here:**
| Failure | What to edit |
|---|---|
| Application class has different name or path | Update Step 3a detect command and note |
| `Pulse.initialize` signature changed (new param, param removed) | Update Step 3b Kotlin/Java snippets |
| iOS import name changed | Update Step 4 Swift/ObjC import |
| `pod install` fails due to podspec issue | Add troubleshooting note to Step 2 |
| `AppRegistry.registerComponent` not at project root | Update Step 1 detect scope |
| Navigation wrapper file is in unexpected location | Update Step 7 note |
| `isInitialized()` returns false for a known reason | Add to Step 9 troubleshooting |

Edit this file at: `skills/setup-react-native/SKILL.md`

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
| URLSession traffic | iOS — includes image downloads |
| Screen lifecycle | UIViewControllers (iOS) / Activities (Android) |
| Screen events (JS) | `screen_load` + `screen_session` per screen (if navigation wired) |
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
Attach metadata (app version, environment, build number) to every signal Pulse captures — crashes, events, traces, sessions.
```typescript
PulseService.start({
  globalAttributes: { env: 'production', version: '2.1.0' }
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

When the user picks one, read the reference file and implement it in their codebase.

---

## More Options

If the user asks about something not in the list above:

| Feature | Reference |
|---|---|
| Measure operation duration (API calls, rendering) | `${SKILL_ROOT}/references/custom-spans.md` |
| Screen time-to-interactive per screen | `${SKILL_ROOT}/references/screen-tracking.md` |
| Add build/env metadata to all telemetry | `${SKILL_ROOT}/references/global-attributes.md` |
| Gate collection behind consent (GDPR) | `${SKILL_ROOT}/references/data-collection-consent.md` |
| Readable crash stacks (source maps) | `${SKILL_ROOT}/references/source-maps.md` |
| React Error Boundary | `${SKILL_ROOT}/references/errors.md`|
| Android native instrumentation config | `${SKILL_ROOT}/references/android-native-apis.md` |
| iOS native instrumentation config | `${SKILL_ROOT}/references/ios-native-apis.md` |
