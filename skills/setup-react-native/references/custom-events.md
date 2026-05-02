# Custom Events

Track business events that are meaningful to your product — conversions, feature usage, user actions.

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
