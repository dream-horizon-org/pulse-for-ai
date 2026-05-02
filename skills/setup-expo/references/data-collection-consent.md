# Data Collection Consent

Control when Pulse starts exporting data — for GDPR, CCPA, or any consent-gated setup.

## Three States

| State | Effect |
|---|---|
| `ALLOWED` | All telemetry collected and exported immediately |
| `PENDING` | Data buffered locally — nothing exported until state changes |
| `DENIED` | Buffer cleared, SDK shuts down — terminal for the process lifetime |

## Setup

**Initialize with `PENDING` in `app.json`:**

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "PENDING"
  }
]
```

Run `npx expo prebuild --clean` after changing this value.

**After user grants consent — call from JS:**

```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';

// User accepts
Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);

// User declines (terminal — requires app restart to re-enable)
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

## Common Pattern

```typescript
async function handleConsentScreen(accepted: boolean) {
  if (accepted) {
    await saveConsentPreference(true);
    Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
  } else {
    await saveConsentPreference(false);
    Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
  }
}
```

## Native Runtime APIs

Expo plugin handles native init — but if consent needs to be changed from native code (e.g. native consent SDK fires before JS layer loads), use these directly:

**Android (Kotlin):**
```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulse.android.api.otel.PulseDataCollectionConsent

Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED)
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED)
```

**iOS (Swift):**
```swift
import PulseReactNativeOtel

Pulse.shared.setDataCollectionState(.allowed)
Pulse.shared.setDataCollectionState(.denied)
```

Transitions follow the same rules — `DENIED` is terminal until next app launch.

## Important Notes

- `DENIED` is terminal for the process lifecycle — SDK shuts down and won't collect until app restarts with `PENDING` or `ALLOWED` in the plugin config
- `PENDING` data is buffered in memory only — not persisted across app restarts
- Call `setDataCollectionState` after `PulseService.start()` has run
- On re-launch: if user previously accepted, start with `ALLOWED` in app.json (or call `setDataCollectionState(ALLOWED)` on startup from stored preference)
