# Error Handling

Pulse captures JS crashes and unhandled promise rejections automatically. Use these APIs for manual reporting and React error boundaries.

## Manual Exception Reporting

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

try {
    await riskyOperation();
} catch (error) {
    Pulse.reportException(error);                     // non-fatal
    Pulse.reportException(error, true);               // fatal
    Pulse.reportException(error, false, {             // with context
        operation: 'checkout',
        screen: 'CartScreen',
    });
}
```

## Error Boundaries

```tsx
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// No fallback — error.fatal = true
<Pulse.ErrorBoundary>
    <YourComponent />
</Pulse.ErrorBoundary>

// With fallback — error.fatal = false
<Pulse.ErrorBoundary fallback={<Text>Something went wrong</Text>}>
    <YourComponent />
</Pulse.ErrorBoundary>

// Full control
<Pulse.ErrorBoundary
    fallback={({ error }) => <Text>{error.message}</Text>}
    onError={(error, componentStack) => console.log(error)}
>
    <YourComponent />
</Pulse.ErrorBoundary>

// HOC
const SafeComponent = Pulse.withErrorBoundary(UserProfile, {
    fallback: <Text>Failed to load</Text>,
});
```

## Error Attributes

| Attribute | Description |
|---|---|
| `error.fatal` | `true` = unhandled crash / no fallback. `false` = handled |
| `error.source` | Always `"js"` |
| `exception.type` | Error class name (e.g. `"TypeError"`) |
| `exception.message` | Error message |
| `exception.stacktrace` | Full JS stack trace |
| `screen.name` | Current screen (requires navigation tracking) |
