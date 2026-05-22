---
name: setup-react-native
description: Full Pulse SDK setup for bare React Native apps (not Expo). Detects Android Application class, iOS AppDelegate, navigation library, and root component. Configures native init, creates a PulseService wrapper, and wires the JS layer. Use when asked to add Pulse to React Native without Expo.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

> **Editing rule:** Make minimal, surgical edits only. Do not reformat existing code, reorder imports, fix style issues, or touch any lines outside the specific insertion points. Every change must be Pulse-only. Preserve all surrounding code exactly as-is.

## Invoke When

- User asks to "add Pulse", "set up Pulse", or "integrate Pulse" in a React Native or Expo app
- User wants error monitoring, crash reporting, tracing, profiling, session tracking, or logging in a React Native app
- User wants to monitor native crashes, ANRs, or app hangs on iOS/Android
- User mentions `@dreamhorizonorg/pulse-react-native`, mobile observability, or Pulse SDK
- `react-native` is in `package.json` and `expo` is NOT

---

## Step 0 — Load Project Memory

Check if this project has been seen before:

```bash
cat .pulse/learnings.md 2>/dev/null
```

If file exists, read it and apply all recorded facts (file paths, package manager, quirks) — skip re-detecting anything already known. If file doesn't exist, proceed normally.

---

## Step 0b — Already Installed?

```bash
cat package.json | grep '"@dreamhorizonorg/pulse-react-native"'
```

If package found, also check whether init is already wired:

```bash
grep -r "Pulse\.start\|PulseService\.start" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" . 2>/dev/null | grep -v node_modules | head -3
```

- Package installed **and** `Pulse.start` already called → **stop**. Tell the user Pulse is already set up. If they want to upgrade:
  1. Check current vs latest: `npm show @dreamhorizonorg/pulse-react-native version` vs version in `package.json`
  2. Already on latest → tell user "You're already on the latest version. No action needed."
  3. Upgrade available → bump version, then:
     - iOS: `cd ios && pod install && cd ..`, clean build in Xcode
     - Android: `cd android && ./gradlew clean && cd ..`, rebuild
     - Check changelog for any native init changes needed
- Package installed but no `Pulse.start` found → skip Steps 2–4 (native already configured), continue from Step 5.

---

## Step 1 — Detect Everything Upfront

Run all checks now. Record results — don't re-run these later.

> **First:** confirm native folders exist:
> ```bash
> ls android/ ios/ 2>/dev/null
> ```
> If `android/` or `ios/` missing → ask user: "Have you run `npx react-native init` to generate native folders? They are required for SDK integration."

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

# Android minSdk + ProGuard + product flavors
grep "minSdkVersion\|minSdk \|minifyEnabled\|productFlavors" android/app/build.gradle 2>/dev/null

# Wrapper placement
ls -d src/services src/utils src/lib src 2>/dev/null | head -1

# TypeScript or JavaScript project?
ls tsconfig.json 2>/dev/null

# Monorepo?
ls packages/ apps/ turbo.json nx.json pnpm-workspace.yaml 2>/dev/null | head -3
```

| What to determine | Impact |
|---|---|
| `android:name` in `<application>` | Identifies Application class file to edit. Default: `MainApplication` |
| AppDelegate extension (`.swift` / `.m` / `.mm`) | Determines Swift vs Objective-C init code |
| `AppRegistry.registerComponent(appName, () => X)` | X is the root component file — this is where `PulseService.start()` goes. If multiple entries found, ask: "Which is your main app component?" |
| File(s) containing `<NavigationContainer>` | This is where `useNavigationTracking` hook goes. If multiple files returned, ask: "Which file renders your root NavigationContainer?" |
| `@react-navigation/native` present | Add `useNavigationTracking` in wrapper |
| `react-native-navigation` (Wix) present | Not supported — skip nav tracking, tell user |
| `minSdkVersion < 26` | Add coreLibraryDesugaring |
| `tsconfig.json` present | Use `.ts`/`.tsx` for wrapper. Absent → use `.js`/`.jsx` |
| New Architecture (RN 0.73+ — check `newArchEnabled=true` in `android/gradle.properties`) | SDK is Turbo Module compatible — no extra config needed |
| Monorepo detected (`turbo.json`, `nx.json`, `packages/`, `apps/`) | Run install and all native commands from the app package directory, not the repo root |
| `minifyEnabled true` in build.gradle | ProGuard/R8 enabled — SDK ships consumer rules that auto-apply. If release build crashes, see troubleshooting. |
| `productFlavors` in build.gradle | Multiple build flavors — API key should be flavor-specific. See Step 8. |
| User said Android-only / iOS-only? | Skip unused platform steps |
| `react-native-web` present or user targeting web | `isSupportedPlatform()` returns `false` on web — SDK silently no-ops. No data in Pulse dashboard for the web target. Web apps should use `@dreamhorizon/pulse-web` instead. |

---

## Step 2 — Install

Detect package manager from lock files:

```bash
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock 2>/dev/null | head -1
```

| Lock file | Install command |
|---|---|
| `yarn.lock` | `yarn add @dreamhorizonorg/pulse-react-native` |
| `package-lock.json` | `npm install @dreamhorizonorg/pulse-react-native` |
| `pnpm-lock.yaml` | `pnpm add @dreamhorizonorg/pulse-react-native` |
| `bun.lockb` or `bun.lock` | `bun add @dreamhorizonorg/pulse-react-native` |
| None found | `npm install @dreamhorizonorg/pulse-react-native` |

Run the matching command.

iOS — link native code:
```bash
cd ios && pod install && cd ..
```

> If `pod install` fails on Apple Silicon (M1/M2/M3), try:
> ```bash
> cd ios && arch -x86_64 pod install && cd ..
> ```

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

**Fallback chain:**
- File not found at default path → search recursively: `find android -name "*.kt" -o -name "*.java" | xargs grep -l "extends Application\|: Application()" 2>/dev/null`
- Still not found → ask user: "What is the path to your Android Application class file?"
- No `onCreate()` in file → ask user: "Does your Application class extend another custom class? If so, which file has `onCreate()`?"

Read the file. Confirm it has `onCreate()`.

### 3b — Inject Pulse init

Create a private `initPulse()` function and call it from `onCreate()` **after** `super.onCreate()`. `Application.onCreate()` runs on the main thread — never dispatch Pulse init to a background thread.

**Kotlin (`.kt`):**

```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulsereactnativeotel.PulseDataCollectionConsent

override fun onCreate() {
    super.onCreate()
    initPulse()
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
    super.onCreate();
    initPulse();
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

Read `android/app/build.gradle` first. Then make surgical edits:

- If a `compileOptions` block **already exists** inside `android {}` → add `coreLibraryDesugaringEnabled true` inside it. Do not create a second `compileOptions` block.
- If no `compileOptions` block exists → add one inside the existing `android {}` block.
- If `coreLibraryDesugaringEnabled` is already present → skip.
- If a `dependencies` block **already exists** → add the `coreLibraryDesugaring` line inside it. Do not create a second `dependencies` block.
- If no `dependencies` block exists → add one.

Result should look like this (merged into existing structure, not appended as new blocks):

```gradle
android {
    // ...existing android config...
    compileOptions {
        // ...existing compile options...
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    // ...existing dependencies...
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

---

## Step 4 — iOS Native Init

> Skip if user confirmed Android only.

**Fallback chain — if AppDelegate not found in Step 1:**
```bash
find ios -name "AppDelegate*" 2>/dev/null
```
- Still not found → ask user: "What is the path to your iOS AppDelegate file?"
- `.mm` file found → treat as Objective-C

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

Check if a wrapper already exists:

```bash
find . \( -name "PulseService.ts" -o -name "PulseService.js" \) 2>/dev/null | grep -v node_modules
```

If found → read it first. Extend it with any missing methods rather than overwriting it.

If not found, detect placement from Step 1 results and use `.ts` or `.js` based on TypeScript detection:
- `src/services/` exists → `src/services/PulseService.ts` (or `.js`)
- `src/utils/` exists → `src/utils/PulseService.ts` (or `.js`)
- `src/lib/` exists → `src/lib/PulseService.ts` (or `.js`)
- `src/` exists → `src/PulseService.ts` (or `.js`)
- Otherwise → `PulseService.ts` (or `.js`) at root

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
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';
import { PulseService } from '<wrapper-path>/PulseService';

function RootNavigator() {
  const navigationRef = React.useRef<NavigationContainerRef<ParamListBase>>(null);
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

**Do not hardcode the key in source control.** Use environment injection:

Option A — `react-native-config` (recommended):
```bash
# .env
PULSE_API_KEY=your-key-here
```
```kotlin
// MainApplication.kt
import com.lugg.reactnativeconfig.BuildConfig
apiKey = BuildConfig.PULSE_API_KEY
```
```swift
// AppDelegate.swift
apiKey: Bundle.main.object(forInfoDictionaryKey: "PULSE_API_KEY") as? String ?? ""
```

Option B — Android build flavors (if `productFlavors` detected in build.gradle):
```kotlin
// Per-flavor key in build.gradle
productFlavors {
    staging { buildConfigField "String", "PULSE_API_KEY", '"staging-key"' }
    production { buildConfigField "String", "PULSE_API_KEY", '"prod-key"' }
}
// MainApplication.kt
apiKey = BuildConfig.PULSE_API_KEY
```

---

## Step 9 — Verify

Build and run on device or simulator. Add temporarily to the root component:

```typescript
if (__DEV__) {
  console.log('Pulse native initialized:', Pulse.isInitialized());
}
```

`isInitialized()` reflects native SDK status — `true` confirms Android/iOS native init succeeded. Remove after confirming.

**If `false`:**
1. Check `Pulse.initialize()` is called after `super.onCreate()` (Android) / before `return super.application(...)` (iOS)
2. Check logcat/Xcode console for init errors
3. Confirm `pod install` was run after npm/yarn install (iOS)
4. Clean and rebuild — do not just reload Metro

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
> - Add global metadata (A/B tests, environment) → `./references/global-attributes.md`
> - Tune `Pulse.start()` options → `./references/rn-start-config.md`
> - Android native instrumentation config → `./references/android-native-apis.md`
> - iOS native instrumentation config → `./references/ios-native-apis.md`
> - Upload source maps for readable crash stacks → `./references/source-maps.md`
> - Shutdown / feature flag kill switch → `./references/shutdown.md`
> - Network monitoring config (custom headers, OkHttp) → `./references/network.md`
> - Mask PII / sensitive content in session replay → `./references/session-replay.md`
> - Navigation tracking options deep-dive → `./references/navigation.md`
> - Debug logging verbosity → `./references/log-level.md`

**Remind the user:** Source maps must be re-uploaded on every release build. Without this, crash stack traces will be unreadable in production.

---

## Save Project Memory

Write `.pulse/learnings.md` with everything discovered about this project. Create or overwrite:

Add `.pulse/` to the project root `.gitignore` if not already present. Run this from the project root:
```bash
grep -q "\.pulse/" "$(pwd)/.gitignore" 2>/dev/null || echo ".pulse/" >> "$(pwd)/.gitignore"
```

```markdown
# Pulse Project Learnings
<!-- Auto-generated by pulse:setup-react-native. Do not commit — .pulse/ is gitignored. -->

- **Integrated:** yes (date: <today>)
- **Package manager:** <yarn|npm|pnpm|bun>
- **Language:** <TypeScript|JavaScript>
- **Android Application class:** <path/to/MainApplication.kt>
- **iOS AppDelegate:** <path/to/AppDelegate.swift|.m|.mm>
- **Navigation:** <@react-navigation/native|none> — container in <file>
- **PulseService location:** <path/to/PulseService.ts>
- **Monorepo:** <yes — app root at X|no>
- **Quirks:** <any non-standard findings, e.g. custom Application class path, unusual project structure>
```

Fill in only what was discovered. Omit unknown fields. This file lets the next agent run skip re-detection and avoid repeating mistakes.

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `isInitialized()` returns `false` | Confirm `Pulse.initialize()` is called after `super.onCreate()` on the main thread. Check logcat for init errors. |
| Release build crashes immediately (Android) | R8/ProGuard stripping SDK classes. SDK ships consumer rules that should auto-apply. If still failing, add `-keep class com.pulsereactnativeotel.** { *; }` to `proguard-rules.pro`. |
| iOS: module not found after install | Run `cd ios && pod install && cd ..`, then clean build. |
| No screen events in dashboard | Confirm `useNavigationTracking` is called inside the component that renders `<NavigationContainer>` and `onReady` is passed to it. |
| No network events | Confirm `autoDetectNetwork: true` (default). If using OkHttp/Image on Android, see `./references/network.md`. |
| `react-native-navigation` (Wix) detected | Screen tracking not supported — all other features work. |
