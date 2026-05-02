# Data Collection Consent

Control when Pulse starts exporting data — for GDPR, CCPA, or any consent-gated setup.

## Three States

| State | Effect |
|---|---|
| `ALLOWED` | All telemetry collected and exported immediately |
| `PENDING` | Data buffered locally — nothing exported until state changes |
| `DENIED` | Buffer cleared, SDK shuts down — terminal for the process lifetime |

## Setup

Initialize with `PENDING` so nothing is exported until consent is granted.

**Android (Kotlin) — in Application class:**
```kotlin
Pulse.initialize(
    application = this,
    apiKey = "YOUR_API_KEY",
    dataCollectionState = PulseDataCollectionConsent.PENDING
) {
    fragment { enabled(false) }
}
```

**iOS (Swift) — in AppDelegate:**
```swift
PulseSDK.initialize(
    apiKey: "YOUR_API_KEY",
    dataCollectionState: .pending,
    instrumentations: { config in
        config.screenLifecycle { $0.enabled(false) }
    }
)
```

**After user grants consent — call from JS:**
```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';

// User accepts
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);

// User declines (terminal — requires app restart to re-enable)
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

## Native Runtime APIs

If consent is managed in native code (e.g. a native consent SDK or before the JS layer loads), change state directly from Android/iOS:

**Android (Kotlin):**
```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulse.android.api.otel.PulseDataCollectionConsent

// Call from any Activity, Service, or Application class after init
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED)
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED)
```

**iOS (Swift):**
```swift
import PulseReactNativeOtel

// Call after PulseSDK.initialize(...)
Pulse.shared.setDataCollectionState(.allowed)
Pulse.shared.setDataCollectionState(.denied)
```

**iOS (Objective-C):**
```objc
#import <PulseReactNativeOtel-Swift.h>

[PulseSDK setDataCollectionStateWithState:@"ALLOWED"];
[PulseSDK setDataCollectionStateWithState:@"DENIED"];
```

Transitions follow the same rules — `DENIED` is terminal until next app launch.

## Important Notes

- `DENIED` is terminal for the process lifecycle — SDK shuts down and will not collect data until the app is restarted with `ALLOWED` or `PENDING` in native init
- `PENDING` data is buffered in memory only — not persisted across app restarts
- Call `setDataCollectionState` after `PulseService.start()` has been called
- All three states propagate to both the JS layer and native layer automatically
