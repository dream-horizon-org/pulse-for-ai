---
name: pulse-consent
description: Add GDPR/CCPA data collection consent control to an existing Pulse bare React Native setup. Change native init to PENDING and handle ALLOWED/DENIED from JS.
category: sdk-feature
invoke-when: GDPR, CCPA, data consent, consent screen, data collection, privacy, pending allowed denied, buffer data, gate collection
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "add GDPR consent to Pulse" or "gate data collection behind consent"
- User has a consent/privacy screen and needs Pulse to buffer until user accepts
- User needs to handle consent denial (shut down collection)
- Pulse is already set up

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-react-native` first. Do not proceed.

```bash
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

Use `PulseService` from the wrapper if found; otherwise use `Pulse` directly from `@dreamhorizonorg/pulse-react-native`.

---

## Three States

| State | Effect |
|---|---|
| `ALLOWED` | All telemetry collected and exported immediately |
| `PENDING` | Data buffered locally — nothing exported until state changes |
| `DENIED` | Buffer cleared, SDK shuts down — terminal for the process lifetime |

---

## Step 1 — Change Native Init to PENDING

Find the Application class and AppDelegate and change `dataCollectionState`:

**Android (Kotlin) — `MainApplication.kt`:**
```kotlin
Pulse.initialize(
  application = this,
  apiKey = "YOUR_API_KEY",
  dataCollectionState = PulseDataCollectionConsent.PENDING
)
```

**iOS (Swift) — `AppDelegate.swift`:**
```swift
PulseSDK.initialize(
  apiKey: "YOUR_API_KEY",
  dataCollectionState: .pending
)
```

---

## Step 2 — Call setDataCollectionState After User Responds

Find the consent screen or consent handler:

```bash
grep -rl "consent\|gdpr\|privacy\|onAccept\|onDecline" \
  --include="*.ts" --include="*.tsx" src/ . 2>/dev/null | grep -v node_modules | head -10
```

Add the state change after the user's response:

```typescript
import { PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
import { PulseService } from './src/config/pulse';
// No wrapper? Use: import { Pulse } from '@dreamhorizonorg/pulse-react-native' and Pulse.setDataCollectionState(...)

async function handleConsentResponse(accepted: boolean) {
  if (accepted) {
    await saveConsentPreference(true);
    PulseService.setDataCollectionState(PulseDataCollectionConsent.ALLOWED);
  } else {
    await saveConsentPreference(false);
    PulseService.setDataCollectionState(PulseDataCollectionConsent.DENIED);
  }
}
```

---

## Step 3 — Restore on Re-launch

On app start, if the user previously accepted, initialize with `ALLOWED` in native init — or call `setDataCollectionState(ALLOWED)` early in JS before user interaction.

---

## Native Runtime APIs

If consent needs to change from native code before the JS layer loads:

**Android (Kotlin):**
```kotlin
import com.pulsereactnativeotel.Pulse
import com.pulse.android.api.otel.PulseDataCollectionConsent

Pulse.setDataCollectionState(PulseDataCollectionConsent.ALLOWED)
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED)
```

**iOS (Swift):**
```swift
Pulse.shared.setDataCollectionState(.allowed)
Pulse.shared.setDataCollectionState(.denied)
```

**iOS (Objective-C):**
```objc
[PulseSDK setDataCollectionStateWithState:@"ALLOWED"];
[PulseSDK setDataCollectionStateWithState:@"DENIED"];
```

---

## Important Notes

- `DENIED` is terminal for the process lifecycle — SDK shuts down and won't collect until app restarts
- `PENDING` data is buffered in memory only — not persisted across app restarts
- Call `setDataCollectionState` after `Pulse.start()` has run in JS
- All three states propagate to both the JS layer and native layer automatically
