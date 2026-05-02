# Custom Events

Track business events — conversions, feature usage, user actions.

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

If a centralized analytics function exists, add `PulseService.trackEvent()` alongside existing calls in that function:

```typescript
// Existing wrapper — add Pulse once here, not at every call site
function trackAnalyticsEvent(name: string, props?: Record<string, unknown>) {
  Amplitude.track(name, props);         // existing
  PulseService.trackEvent(name, props); // add Pulse here
}
```

---

```typescript
import { PulseService } from './services/PulseService';

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

**Supported attribute types:** `string`, `number`, `boolean`, and arrays of these types.

## Direct Pulse API

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.trackEvent('checkout_started', { cart_total: 99.99 });
```

## Correlate with Spans

Events tracked inside an active span are automatically associated with it:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

const span = Pulse.startSpan('checkout_flow');

Pulse.trackEvent('payment_method_selected', { method: 'card' });
Pulse.trackEvent('address_confirmed', { country: 'US' });

span.end();
```
