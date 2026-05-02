# Custom Events

Track business events that are meaningful to your product — conversions, feature usage, user actions.

## Find Existing Analytics Hook First

Before adding new `trackEvent` calls, check if the app already centralizes analytics — wire Pulse there instead of scattering calls.

**JS/TS layer:**
```bash
# Existing analytics wrappers
grep -rl "trackEvent\|logEvent\|sendEvent\|Analytics\." \
  --include="*.ts" --include="*.tsx" --include="*.js" \
  src/ . 2>/dev/null | grep -v node_modules | head -10

# Known analytics libs
grep -E '"@segment/analytics-react-native"|"@amplitude/analytics-react-native"|"@react-native-firebase/analytics"|"mixpanel-react-native"' package.json 2>/dev/null
```

**Android native layer:**
```bash
grep -r "trackEvent\|logEvent\|Analytics\." \
  --include="*.kt" --include="*.java" \
  android/app/src/main/java/ 2>/dev/null | grep -v "//\|Pulse" | head -10
```

**iOS native layer:**
```bash
grep -r "trackEvent\|logEvent\|Analytics\." \
  --include="*.swift" --include="*.m" --include="*.mm" \
  ios/ 2>/dev/null | grep -v "//\|Pulse" | head -10
```

If a centralized analytics function exists (e.g. `Analytics.track()`, `AnalyticsService.logEvent()`), add `PulseService.trackEvent()` alongside existing calls in that function — not at every call site.

**Example — wrapping existing analytics:**
```typescript
// Existing analytics wrapper — add Pulse here, not at every call site
function trackAnalyticsEvent(name: string, props?: Record<string, unknown>) {
  Amplitude.track(name, props);        // existing
  PulseService.trackEvent(name, props); // add Pulse here
}
```

---

## Basic Usage

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Simple event
Pulse.trackEvent('user_logout');

// Event with attributes
Pulse.trackEvent('purchase_completed', {
    product_id: 'SKU-123',
    price: 49.99,
    quantity: 2,
    in_stock: true,
});
```

**Supported attribute types:** `string`, `number`, `boolean`, and arrays of these types.

## Correlate Events with Spans

Events tracked inside an active span are automatically associated with it:

```typescript
const span = Pulse.startSpan('checkout');

Pulse.trackEvent('payment_method_selected', { method: 'card' });
Pulse.trackEvent('shipping_address_entered', { country: 'US' });

span.end();
```

## Native APIs (for events fired from native code)

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

PulseSDK.trackEvent(
    name: "purchase_completed",
    observedTimeStampInMs: Int64(Date().timeIntervalSince1970 * 1000),
    params: ["product_id": "SKU-123"]
)
```
