---
name: pulse-shutdown
description: Surface the Pulse shutdown API and the feature-flag kill-switch pattern. Suggestion-only — never wires shutdown into source files on its own.
category: sdk-feature
invoke-when: shutdown, kill switch, feature flag disable Pulse, stop Pulse, terminate collection, disable telemetry runtime
allowed-tools: Read, Edit, Bash
---

## Scope

Surface the Pulse `shutdown` API and the recommended kill-switch pattern. Insert calls only into files the user names.

Stops all Pulse data collection for the rest of the process. Used for feature-flag kill switches and for `setDataCollectionState(DENIED)` flows (consent revocation routes through `setDataCollectionState`, not `shutdown` — see below).

---

## Guardrails

- **Suggestion-first.** Only insert `PulseService.shutdown()` / `Pulse.shutdown()` into files the user names.
- **Do not** wire shutdown into a feature-flag system on heuristics — the user's flag layer is theirs to integrate.
- **Do not** restructure the entry point. If the user wants to gate `start()` behind a flag, suggest the snippet and add it only at a user-named call site.
- Surface that shutdown is **terminal for the process**: re-enabling requires an app restart.

## API

```typescript
PulseService.shutdown();                                           // wrapper
// or direct from SDK:
import { Pulse } from '@dreamhorizonorg/pulse-react-native';
Pulse.shutdown();
```

The wrapper created by `/integrating-pulse-expo` exposes `shutdown()` as `PulseService.shutdown()`.

## Feature-flag kill switch (suggested pattern)

The cleaner pattern is to skip `start()` entirely when the flag is off — that avoids initializing the SDK at all:

```typescript
import { PulseService } from '@/config/pulse';

if (featureFlags.pulseEnabled) {
  PulseService.start();
}
```

If the flag flips to off mid-session and the user wants the SDK off immediately, call `shutdown()` at that point (user-named call site only):

```typescript
if (!featureFlags.pulseEnabled) {
  PulseService.shutdown();
}
```

Re-enabling without a restart is not possible — surface this constraint to the user.

## Consent revocation — prefer `setDataCollectionState`

For GDPR / CCPA flows, do **not** use `shutdown()` directly. Use:

```typescript
import { Pulse, PulseDataCollectionConsent } from '@dreamhorizonorg/pulse-react-native';
Pulse.setDataCollectionState(PulseDataCollectionConsent.DENIED);
```

`DENIED` clears the buffer and shuts the SDK down through the consent path. See `data-collection-consent.md`.

## Native side (informational only — do not add unless user asks)

If shutdown must be triggered from native code (e.g. a feature flag resolved before the JS bundle loads):

- Android (Kotlin): `Pulse.shutdown()` — from `com.pulsereactnativeotel.Pulse`.
- iOS (Swift): `PulseSDK.shutdown()` — from `PulseReactNativeOtel`.
- iOS (Obj-C): `BOOL stopped = [PulseSDK shutdown];`

Surface only if asked. Do not modify native files as part of this skill.
