# Error Handling

Pulse captures JS crashes and unhandled promise rejections automatically when `autoDetectExceptions: true` (default). Use the APIs below for manual reporting and React error boundaries.

## Manual Exception Reporting

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

try {
    await riskyOperation();
} catch (error) {
    // Non-fatal (handled error)
    Pulse.reportException(error);

    // Fatal (app-level crash equivalent)
    Pulse.reportException(error, true);

    // With additional context
    Pulse.reportException(error, false, {
        operation: 'checkout',
        userId: 'user-123',
        amount: 49.99,
    });
}
```

## Error Boundaries

Wrap subtrees to catch render errors without crashing the whole app:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Basic — crash treated as fatal
<Pulse.ErrorBoundary>
    <YourComponent />
</Pulse.ErrorBoundary>

// With fallback UI — crash treated as non-fatal
<Pulse.ErrorBoundary fallback={<Text>Something went wrong</Text>}>
    <YourComponent />
</Pulse.ErrorBoundary>

// Full control
<Pulse.ErrorBoundary
    fallback={({ error, componentStack }) => (
        <View>
            <Text>Something went wrong</Text>
            <Text>{error instanceof Error ? error.message : String(error)}</Text>
        </View>
    )}
    onError={(error, componentStack) => {
        console.log('Render error:', error);
    }}
>
    <YourComponent />
</Pulse.ErrorBoundary>

// HOC pattern
const SafeComponent = Pulse.withErrorBoundary(UserProfile, {
    fallback: <Text>Profile failed to load</Text>,
});
```

**Fatal vs non-fatal:** No fallback → `error.fatal = true`. Fallback provided → `error.fatal = false`.

## Error Attributes

| Attribute | Description |
|---|---|
| `error.fatal` | `true` for unhandled crashes, `false` for handled errors |
| `error.source` | Always `"js"` |
| `exception.type` | Error class name (e.g. `"TypeError"`) |
| `exception.message` | Error message string |
| `exception.stacktrace` | Full JS stack trace |
| `screen.name` | Current screen (requires navigation tracking to be set up) |

## Disable Auto-Detection

```typescript
Pulse.start({ autoDetectExceptions: false });
```
