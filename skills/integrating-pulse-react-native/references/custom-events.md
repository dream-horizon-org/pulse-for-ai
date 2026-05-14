---
name: pulse-custom-events
description: Track business events in an existing Pulse bare React Native setup — purchases, funnel steps, feature usage. Correlates with sessions and traces.
category: sdk-feature
invoke-when: track events, custom events, business events, log events, track user actions, purchases, funnel, analytics events
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "add event tracking to Pulse" in a React Native app
- User wants to log purchases, funnel steps, or feature usage
- User wants to correlate user actions with crashes or traces
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

## Find Existing Analytics Hook First

Before scattering `trackEvent` calls everywhere, check if the app already centralizes analytics — wire Pulse there instead:

```bash
# JS/TS layer
grep -rl "trackEvent\|logEvent\|sendEvent\|Analytics\." \
  --include="*.ts" --include="*.tsx" src/ . 2>/dev/null | grep -v node_modules | head -10

grep -E '"@segment/analytics-react-native"|"@amplitude/analytics-react-native"|"@react-native-firebase/analytics"|"mixpanel-react-native"' package.json 2>/dev/null

# Android native layer
grep -r "trackEvent\|logEvent\|Analytics\." \
  --include="*.kt" --include="*.java" \
  android/app/src/main/java/ 2>/dev/null | grep -v "//\|Pulse" | head -10

# iOS native layer
grep -r "trackEvent\|logEvent\|Analytics\." \
  --include="*.swift" --include="*.m" \
  ios/ 2>/dev/null | grep -v "//\|Pulse" | head -10
```

**If a central hook is found** — add Pulse there. One change, all events covered:

```typescript
// With wrapper:
import { PulseService } from './src/config/pulse';
// Direct SDK: import { Pulse } from '@dreamhorizonorg/pulse-react-native'

function trackAnalyticsEvent(name: string, props?: Record<string, unknown>) {
  existingAnalytics.track(name, props);        // existing
  PulseService.trackEvent(name, props);         // add Pulse here
  // Direct SDK: Pulse.trackEvent(name, props)
}
```

**If no central hook is found** — do NOT scatter `trackEvent` calls throughout the codebase. Instead, propose a catalogue first:

1. Scan for meaningful user actions:
```bash
grep -rn "onPress\|onSubmit\|handleLogin\|handleCheckout\|handlePurchase\|handleSignup\|navigate(" \
  --include="*.tsx" --include="*.ts" src/ . 2>/dev/null | grep -v node_modules | head -30
```

2. Present a catalogue to the user — **do not write any code yet**:

> Here are the events I'd add. Review and confirm before I make any changes:
>
> | Event name | File | Line | Key properties |
> |---|---|---|---|
> | `user_signed_up` | `src/screens/SignUp.tsx` | 45 | `method` |
> | `purchase_completed` | `src/checkout/Payment.tsx` | 89 | `product_id`, `amount` |
> | `feature_opened` | `src/home/Dashboard.tsx` | 23 | `feature_name` |
>
> Should I add all of these, remove any, or add more?

3. After user confirms, add `PulseService.trackEvent(name, props)` at each location — one call per event, no new wrapper layers.

---

## Implementation

**With wrapper (`src/config/pulse.ts`):**

```typescript
import { PulseService } from './src/config/pulse';

// Simple event
PulseService.trackEvent('user_logout');

// Event with attributes
PulseService.trackEvent('purchase_completed', {
  product_id: 'SKU-123',
  price:      49.99,
  quantity:   2,
  in_stock:   true,
});
```

**Direct SDK (no wrapper):**

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.trackEvent('user_logout');
Pulse.trackEvent('purchase_completed', { product_id: 'SKU-123', price: 49.99 });
```

**Supported attribute types:** `string`, `number`, `boolean`, and arrays of these types.

---

## Correlate with Spans

Events tracked inside an active span are automatically associated with it:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';
import { PulseService } from './src/config/pulse';
// No wrapper? use Pulse.trackEvent(...) directly

const span = Pulse.startSpan('checkout_flow');

PulseService.trackEvent('payment_method_selected', { method: 'card' });
PulseService.trackEvent('address_confirmed', { country: 'US' });

span.end();
```

---

## Native APIs

**Kotlin (Android):**
```kotlin
import com.pulsereactnativeotel.Pulse

Pulse.trackEvent(
  name = "purchase_completed",
  observedTimeStampInMs = System.currentTimeMillis(),
  params = mapOf("product_id" to "SKU-123"),
)
```

**Swift (iOS):**
```swift
import PulseReactNativeOtel

Pulse.trackEvent(
  name: "purchase_completed",
  observedTimeStampInMs: Int64(Date().timeIntervalSince1970 * 1000),
  params: ["product_id": "SKU-123"]
)
```
