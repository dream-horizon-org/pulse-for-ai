---
name: pulse-errors
description: Add manual error reporting and React error boundaries to an existing Pulse setup in a bare React Native app. Handles try/catch errors, API failures, and component render errors.
category: sdk-feature
invoke-when: report handled errors, non-fatal errors, error boundary, catch exceptions, error monitoring, manual exception reporting, errors not crashing app
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "add error reporting/monitoring to Pulse" in a React Native app
- User wants to report caught errors from try/catch or API failures
- User wants React error boundaries with Pulse
- User already has Pulse set up

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

## Manual Exception Reporting

**With wrapper (`src/config/pulse.ts`):**

```typescript
import { PulseService } from './src/config/pulse';

try {
  await riskyOperation();
} catch (error) {
  PulseService.trackNonFatal(error, {
    screen: 'Checkout',
    action: 'submitOrder',
  });
}
```

**Direct SDK (no wrapper):**

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

try {
  await riskyOperation();
} catch (error) {
  Pulse.reportException(error, false, { screen: 'Checkout', action: 'submitOrder' });
  // Pulse.reportException(error, true, ...)  — treat as fatal
}
```

---

## React Error Boundaries

`ErrorBoundary` and `withErrorBoundary` are always used directly from the SDK — they are not in the wrapper.

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// No fallback — error.fatal = true
<Pulse.ErrorBoundary>
  <YourComponent />
</Pulse.ErrorBoundary>

// With fallback UI — error.fatal = false
<Pulse.ErrorBoundary fallback={<Text>Something went wrong</Text>}>
  <YourComponent />
</Pulse.ErrorBoundary>

// Full control
<Pulse.ErrorBoundary
  fallback={({ error, componentStack }) => (
    <View>
      <Text>{error instanceof Error ? error.message : String(error)}</Text>
    </View>
  )}
  onError={(error, componentStack) => console.log('Render error:', error)}
>
  <YourComponent />
</Pulse.ErrorBoundary>

// HOC pattern
const SafeComponent = Pulse.withErrorBoundary(UserProfile, {
  fallback: <Text>Profile failed to load</Text>,
});
```

**Fatal vs non-fatal:** No fallback → `error.fatal = true`. Fallback provided → `error.fatal = false`.

---

## Error Attributes

| Attribute | Description |
|---|---|
| `error.fatal` | `true` for unhandled crashes, `false` for handled errors |
| `error.source` | Always `"js"` |
| `exception.type` | Error class name (e.g. `"TypeError"`) |
| `exception.message` | Error message string |
| `exception.stacktrace` | Full JS stack trace |
| `screen.name` | Current screen (requires navigation tracking) |

---

## Disable Auto-Detection

Auto-detection of JS crashes is on by default. To turn it off:

```typescript
// With wrapper:
PulseService.start({ autoDetectExceptions: false });

// Direct SDK:
Pulse.start({ autoDetectExceptions: false });
```
