# Shutdown

Stop all Pulse data collection — for feature flag kill switches or process-level cleanup.

```typescript
import { PulseService } from './services/PulseService';

PulseService.shutdown();
// or directly: Pulse.shutdown()
```

**Shutdown is final for the process lifetime.** The SDK cannot be restarted — requires an app restart.

## Feature Flag Kill Switch

```typescript
if (!featureFlags.pulseEnabled) {
  PulseService.shutdown();
}
```

Check the flag before calling `PulseService.start()` to avoid initializing at all:

```typescript
if (featureFlags.pulseEnabled) {
  PulseService.start();
}
```

## Consent Revocation

For GDPR consent flows, prefer `setDataCollectionState(DENIED)` — it's designed for that case and has the same terminal effect:

```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

See `data-collection-consent.md` for the full consent flow.

## Native Shutdown

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
