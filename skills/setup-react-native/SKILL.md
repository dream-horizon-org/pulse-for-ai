---
name: setup-react-native
description: Full Pulse SDK setup for bare React Native apps (not Expo). Covers Android and iOS native initialization, JS layer, navigation tracking, error handling, and network monitoring. Use when asked to add Pulse to a React Native project without Expo.
category: sdk-setup
parent: setup
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

← [setup](../setup/SKILL.md)

## Invoke When

- "Add Pulse to my React Native app"
- "Set up Pulse SDK in React Native"
- `react-native` is in package.json but `expo` is NOT

---

## Phase 1: Detect

```bash
# Check install state
cat package.json | grep -E '"@dreamhorizonorg/pulse-react-native"'

# Determine app type
grep -r "extends Application" android/app/src/main/java --include="*.kt" -l 2>/dev/null
grep -r "extends Application" android/app/src/main/java --include="*.java" -l 2>/dev/null
ls ios/*/AppDelegate.swift ios/*/AppDelegate.m 2>/dev/null

# Check navigation
cat package.json | grep "@react-navigation"

# Check Android minSdk
grep "minSdk" android/app/build.gradle 2>/dev/null
```

| Question | Impact |
|---|---|
| Is `@dreamhorizonorg/pulse-react-native` already in package.json? | Skip install — go to Step 2 |
| Is this a brownfield app (RN embedded in native)? | Application class and AppDelegate may be non-default — find the real files |
| Is AppDelegate Swift or Objective-C? | Determines iOS init code |
| Does `@react-navigation` exist in package.json? | Add `useNavigationTracking` in Step 5 |
| Is Android minSdk < 26? | Add core library desugaring in Step 2 |

---

## Phase 2: Guide

### Step 1 — Install

```bash
yarn add @dreamhorizonorg/pulse-react-native
```

Then link iOS native code:
```bash
cd ios && pod install && cd ..
```

### Step 2 — Android Native Init

Find the Application class. For standard apps it's `MainApplication.kt`. For brownfield apps:
```bash
grep -r "extends Application" android/app/src/main/java --include="*.kt" -l
grep -r "extends Application" android/app/src/main/java --include="*.java" -l
```

Add to `onCreate()` **before** `super.onCreate()`:

```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulsereactnativeotel.PulseDataCollectionConsent

override fun onCreate() {
    super.onCreate()
    Pulse.initialize(
        application = this,
        apiKey = "YOUR_API_KEY",
        dataCollectionState = PulseDataCollectionConsent.ALLOWED
    )
    // ... rest of existing onCreate
}
```

**For greenfield RN apps** (new apps not embedding into existing native), disable fragment tracking to avoid duplicate screen events — activities already handle this:

```kotlin
Pulse.initialize(
    application = this,
    apiKey = "YOUR_API_KEY",
    dataCollectionState = PulseDataCollectionConsent.ALLOWED
) {
    fragment { enabled(false) }
    // activity{} stays enabled — it powers the AppStart span
}
```

**If Android minSdk < 26**, add to `android/app/build.gradle`:

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

### Step 3 — iOS Native Init

**Swift AppDelegate** (`ios/*/AppDelegate.swift`):

```swift
import PulseReactNativeOtel

@main
class AppDelegate: RCTAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        PulseSDK.initialize(
            apiKey: "YOUR_API_KEY",
            dataCollectionState: .allowed
        )
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

**Objective-C AppDelegate** (`ios/*/AppDelegate.m`):

```objc
#import <PulseReactNativeOtel-Swift.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [PulseSDK pulseInitialize:@"YOUR_API_KEY"
        dataCollectionState:@"ALLOWED"
           globalAttributes:nil
              configuration:nil
            instrumentations:nil];
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}
```

**For greenfield RN apps**, disable iOS screenLifecycle to avoid double-counting with JS navigation:

```swift
PulseSDK.initialize(
    apiKey: "YOUR_API_KEY",
    dataCollectionState: .allowed,
    instrumentations: { config in
        config.screenLifecycle { $0.enabled(false) }
    }
)
```

**Critical:** Pulse init must run on the main thread before React Native starts. Never defer, dispatch, or move it to a background thread.

### Step 4 — JS Initialization

Find the JS entry point. For standard apps it's `App.tsx`. For brownfield, locate `AppRegistry.registerComponent`:
```bash
grep -r "AppRegistry.registerComponent" --include="*.tsx" --include="*.ts" --include="*.js" -l .
```

Add before any components render:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.start();
```

Optional — only set `logLevel` in development, remove before release:

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
    autoDetectExceptions: true,   // default: true
    autoDetectNetwork: true,      // default: true
    autoDetectNavigation: true,   // default: true — kill switch only, does not add tracking
    // logLevel: PulseLogLevel.DEBUG,  // dev debugging only — remove before release
});
```

### Step 5 — Navigation Tracking (if React Navigation is present)

`autoDetectNavigation: true` is a kill switch — it does NOT automatically track screens. To get screen tracking, add `useNavigationTracking`:

```typescript
import { NavigationContainer, type NavigationContainerRef } from '@react-navigation/native';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

function App() {
    const navigationRef = React.useRef<NavigationContainerRef>(null);
    const onReady = Pulse.useNavigationTracking(navigationRef, {
        screenSessionTracking: true,      // default: on
        screenNavigationTracking: true,   // default: on
        screenInteractiveTracking: false, // default: off — enable if you call Pulse.markContentReady()
    });

    return (
        <NavigationContainer ref={navigationRef} onReady={onReady}>
            {/* your navigator */}
        </NavigationContainer>
    );
}
```

### Step 6 — API Key

Ask the user if the API key is not already in the codebase or environment:
> "What is your Pulse API key? You can find it in the Pulse dashboard under Project Settings."

Replace `YOUR_API_KEY` in both the Android Application class and iOS AppDelegate.

---

## Phase 3: Verify

Add temporarily to the JS entry file to confirm initialization:

```typescript
console.log('Pulse initialized:', Pulse.isInitialized());
```

Build and run on a device or simulator. Check the Pulse dashboard — session events should appear within a few minutes. Remove the log line after confirming.

---

## Troubleshooting

| Issue | Solution |
|---|---|
| iOS: `PulseReactNativeOtel` not found after install | Run `cd ios && pod install` |
| `Pulse.isInitialized()` returns false | Native init must run before `super.application(...)` on iOS / before `super.onCreate()` on Android |
| Duplicate screen events in the dashboard | Disable `fragment{}` (Android) / `screenLifecycle` (iOS) in greenfield apps |
| `Image` / `FastImage` network requests not tracked | These use OkHttp on Android — enable Android network instrumentation via the native SDK config |
| Navigation not tracked despite `autoDetectNavigation: true` | That option is only a kill switch — add `useNavigationTracking` hook (Step 5) |

---

## Next Steps

Ask the user if they want to set up any of the following:

- Error boundaries and manual error reporting → `${SKILL_ROOT}/references/errors.md`
- Custom events and spans → `${SKILL_ROOT}/references/custom-events.md`, `${SKILL_ROOT}/references/custom-spans.md`
- Network monitoring details → `${SKILL_ROOT}/references/network.md`
- Source maps for crash symbolication → `${SKILL_ROOT}/references/source-maps.md`
- User identification → `${SKILL_ROOT}/references/user-identification.md`
