# Android Native Instrumentation

Configure or disable Android instrumentations in `Pulse.initialize()`.

```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulsereactnativeotel.PulseDataCollectionConsent

Pulse.initialize(
    application = this,
    apiKey = "YOUR_API_KEY",
    dataCollectionState = PulseDataCollectionConsent.ALLOWED
) {
    activity          { enabled(true) }   // Activity lifecycle — powers AppStart span
    fragment          { enabled(false) }  // Fragment tracking — disable for RN apps
    crashReporter     { enabled(true) }   // Native crash detection (JVM + NDK)
    anrReporter       { enabled(true) }   // ANR detection (main thread blocked > 5s)
    slowRenderingReporter { enabled(true) }  // Jank (>16ms) and frozen frames (>700ms)
    interaction       { enabled(true) }   // User tap/touch events
}
```

## Per-Instrumentation Notes

| Instrumentation | Default | Notes |
|---|---|---|
| `activity` | on | Keep enabled — required for AppStart span |
| `fragment` | on | **Disable for RN** — JS navigation handles screen tracking |
| `crashReporter` | on | JVM and NDK native crashes |
| `anrReporter` | on | App Not Responding — fires when main thread blocked > 5s |
| `slowRenderingReporter` | on | Slow frames > 16ms, frozen frames > 700ms |
| `interaction` | on | Touch and tap interaction events |

## coreLibraryDesugaring

Required when `minSdkVersion < 26`. Without it, the SDK will fail to initialize on older Android versions.

`android/app/build.gradle`:
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

## Runtime State Changes

```kotlin
// Change consent after init
PulseSDK.INSTANCE.setDataCollectionState(PulseDataCollectionConsent.ALLOWED)

// Set user identity from native code
PulseSDK.INSTANCE.setUserId("usr_12345")
PulseSDK.INSTANCE.setUserProperties {
    put("plan", "premium")
    put("region", "us-west")
}

// Shutdown
PulseSDK.INSTANCE.shutdown()
```
