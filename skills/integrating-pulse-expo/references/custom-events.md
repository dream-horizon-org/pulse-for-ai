---
name: pulse-custom-events
description: Wire Pulse `trackEvent` into an existing analytics pipeline, or guide the user through adding it where they choose. Never invents a business-event catalogue and never scatters tracking calls.
category: sdk-feature
invoke-when: track events, custom events, business events, log events, track user actions, analytics events
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks to track business critical or analytics events in their Expo app and Pulse is already set up.
- User wants to bridge an existing analytics service (Segment, Amplitude, Mixpanel, Firebase Analytics, Google Analytics etc.) into Pulse.

---

## Guardrails

This skill is **suggestion-first** — do not write code unless one of these is true:

1. The project has a single, central analytics hook/wrapper that already routes all events through one function. Add Pulse there only.
2. The user explicitly names files / functions / call sites where they want `Pulse.trackEvent` added.

If neither applies — **do not modify any source file**. Print the available API and stop. Never:

- Invent a list of business events ("I'll add `checkout_started`, `signup_completed`, …") and add them.
- Scatter `trackEvent` calls across screens or handlers based on heuristics like `onPress`, `handleLogin`, etc.
- Refactor an existing analytics layer or move providers around.
- Install or recommend a different analytics library.

If unsure → ask the user where they want events tracked.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

- Package missing → tell user to run `/integrating-pulse-expo` first. Stop.
- `pulse.ts` wrapper found → use `PulseService.trackEvent(...)`.
- Wrapper missing → use `Pulse.trackEvent(...)` direct from `@dreamhorizonorg/pulse-react-native`.

---

## Path A — Bridge into an existing analytics hook

Find the centralized analytics function (one read-only sweep):

```bash
rg -l "trackEvent\(|logEvent\(|sendEvent\(|Analytics\." --type ts --type tsx -g '!node_modules' | head -10
grep -E '"@segment/analytics-react-native"|"@amplitude/analytics-react-native"|"@react-native-firebase/analytics"|"mixpanel-react-native"' package.json
```

If a single hub function is found (e.g. `src/analytics/track.ts` exposing one `track(name, props)` call), and the user confirms it is the right place, add Pulse alongside the existing call — **only that one line**:

```typescript
import { PulseService } from '@/config/pulse';
// no wrapper: import { Pulse } from '@dreamhorizonorg/pulse-react-native';

export function track(name: string, props?: Record<string, unknown>) {
  existingAnalytics.track(name, props);          // existing — unchanged
  PulseService.trackEvent(name, props);          // ← single additive line
  // direct SDK alternative: Pulse.trackEvent(name, props);
}
```

If multiple analytics call sites exist with no central hub → **stop**. Ask user that there is no central place we need to add Pulse.trackEvent at multiple places.

---

## Path B — User-directed insertion

When the user names specific files or functions ("add `purchase_completed` in `src/checkout/Payment.tsx` after `submitOrder()` resolves"), add **only** what they specified:

```typescript
import { PulseService } from '@/config/pulse';
// no wrapper: import { Pulse } from '@dreamhorizonorg/pulse-react-native';

await submitOrder(payload);
PulseService.trackEvent('purchase_completed', {
  product_id: payload.productId,
  amount:     payload.amount,
});
```

Show the diff first. Add nothing else.

---

## API reference

```typescript
Pulse.trackEvent(name: string, attributes?: Record<string, AttributeValue>): void
```

Supported `attributes` value types: `string`, `number`, `boolean`, and arrays of these.

Examples:

```typescript
Pulse.trackEvent('user_logout');

Pulse.trackEvent('purchase_completed', {
  product_id: 'SKU-123',
  price:      49.99,
  quantity:   2,
  in_stock:   true,
});
```

## Native side (informational only — do not add unless user asks)

Native event emission lives in Kotlin / Swift APIs. Surface this only if the user explicitly asks about emitting events from native code that is from Android or iOS ; do not modify native files as part of this skill.

- Android (Kotlin) entry point: `Pulse.trackEvent(...)` from `com.pulsereactnativeotel.Pulse`
- iOS (Swift) entry point: `PulseSDK.trackEvent(...)` from `PulseReactNativeOtel`

See the React Native [Custom Events](https://pulse-ux.com/docs/developer-guide/sdk/react-native/instrumentation/custom-events) doc for native signatures.
