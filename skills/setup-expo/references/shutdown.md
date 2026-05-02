# Shutdown

Stop all Pulse data collection — for feature flag kill switches or process-level cleanup.

```typescript
import { PulseService } from './services/PulseService';

PulseService.shutdown();
// or directly: Pulse.shutdown()
```

**Shutdown is final for the process lifetime.** Requires an app restart to re-enable.

## Feature Flag Kill Switch

Check the flag before calling `PulseService.start()` to avoid initializing at all:

```typescript
if (featureFlags.pulseEnabled) {
  PulseService.start();
} else {
  // or shutdown after start if flag changes at runtime:
  PulseService.shutdown();
}
```

## Consent Revocation

For GDPR consent flows, prefer `setDataCollectionState(DENIED)`:

```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

See `data-collection-consent.md` for the full consent flow.

## Native Shutdown

If shutdown needs to be triggered from native code (e.g. a feature flag resolved before the JS layer):

**Android (Kotlin):**
```kotlin
PulseSDK.INSTANCE.shutdown()
```

**iOS (Swift):**
```swift
Pulse.shared.shutdown()
```

**iOS (Objective-C):**
```objc
[PulseSDK shutdown];
```
