# Session Replay Masking

Pulse session replay records screen interactions. Use `PulseMask` to hide sensitive content (PII, passwords, payment details) and `PulseUnmask` to reveal nested content inside a masked region.

## Import

```typescript
import { PulseMask, PulseUnmask } from '@dreamhorizonorg/pulse-react-native';
```

## Mask Sensitive Content

```tsx
import { PulseMask } from '@dreamhorizonorg/pulse-react-native';

function PaymentScreen() {
    return (
        <View>
            <Text>Order Summary</Text>
            <PulseMask>
                <TextInput placeholder="Card number" />
                <TextInput placeholder="CVV" secureTextEntry />
            </PulseMask>
        </View>
    );
}
```

Everything inside `<PulseMask>` is redacted in replay recordings.

## Unmask Inside a Masked Region

```tsx
import { PulseMask, PulseUnmask } from '@dreamhorizonorg/pulse-react-native';

function ProfileScreen() {
    return (
        <PulseMask>
            <Text>Hidden content</Text>
            <PulseUnmask>
                <Text>Visible in replay</Text>
            </PulseUnmask>
        </PulseMask>
    );
}
```

## Props

Both components accept all standard `View` props (`style`, `testID`, etc.) in addition to `children`.

## When to Use

- Form fields with card numbers, passwords, SSNs
- User-generated content that may contain PII
- Medical or financial data displays
- Any content subject to GDPR/CCPA redaction requirements
