---
name: pulse-errors
description: Surface the Pulse handled-error API and React error-boundary component. Wires them into source files only when the user explicitly names them.
category: sdk-feature
invoke-when: report handled errors, non-fatal errors, error boundary, catch exceptions, manual exception reporting
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User wants to report caught errors (try/catch, API failures) to Pulse, and Pulse is already set up.
- User wants a React error boundary that reports to Pulse.

---

## Guardrails

This skill is **suggestion-first**:

1. Surface the API and the recommended call patterns.
2. **Only** modify a source file if the user names it (and ideally the function or component).

Never:

- Sweep the codebase for `try` / `catch` blocks and inject `trackNonFatal` calls.
- Wrap arbitrary screens or root components in `<Pulse.ErrorBoundary>` based on heuristics.
- Refactor existing error handling, logging layers, or API client retry logic.
- Replace an existing error-boundary library (e.g. `react-error-boundary`) — surface that Pulse can coexist or replace it, but defer to the user's choice.

If the user says "add error reporting to Pulse" without naming files → respond with the API and ask which call sites or component subtrees they want to wrap.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

- Package missing → tell user to run `/integrating-pulse-expo` first. Stop.
- `pulse.ts` wrapper found → use `PulseService.trackNonFatal(...)`.
- Wrapper missing → use `Pulse.reportException(...)` direct from the SDK.

---

## What is and is not auto-captured

Already on by default after `/integrating-pulse-expo`:

- Unhandled JS exceptions
- Unhandled promise rejections
- Native crashes (iOS + Android)
- ANRs (Android)

**Not** auto-captured (this is what `trackNonFatal` is for):

- Errors caught with `try` / `catch`
- Error responses returned from API calls (e.g. `response.ok === false`)
- Errors swallowed by promise `.catch()` handlers
- React render errors — those need an error boundary

Auto-detection of JS crashes can be turned off with:

```typescript
Pulse.start({ autoDetectExceptions: false });
```

Manual reporting still works when `autoDetectExceptions: false`.

---

## API reference — manual exception reporting

```typescript
Pulse.reportException(
  error: unknown,
  isFatal?: boolean,                       // default: false
  attributes?: Record<string, AttributeValue>,
): void
```

Wrapper equivalent (created by `/integrating-pulse-expo`):

```typescript
PulseService.trackNonFatal(error: unknown, context?: Record<string, AttributeValue>): void
```

`trackNonFatal` calls `Pulse.reportException(error, false, context)`. To report something as fatal, call the SDK directly:

```typescript
Pulse.reportException(error, true);
```

Suggested usage (do not auto-insert):

```typescript
import { PulseService } from '@/config/pulse';
// no wrapper: import { Pulse } from '@dreamhorizonorg/pulse-react-native';

try {
  await submitOrder(payload);
} catch (error) {
  PulseService.trackNonFatal(error, {
    screen: 'Checkout',
    action: 'submitOrder',
  });
}
```

---

## API reference — React error boundary

Pick the option that matches the user's codebase. **Never** replace an existing boundary with `<Pulse.ErrorBoundary>` unless the user explicitly asks — Option B below is the right path when a boundary already exists.

### Option A — No existing error boundary (use `<Pulse.ErrorBoundary>` / `withErrorBoundary`)

`<Pulse.ErrorBoundary>` and `Pulse.withErrorBoundary` are imported **directly from the SDK** (the wrapper does not re-export them):

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// No fallback → reports as fatal (`error.fatal = true`)
<Pulse.ErrorBoundary>
  <YourComponent />
</Pulse.ErrorBoundary>

// With fallback UI → reports as non-fatal (`error.fatal = false`)
<Pulse.ErrorBoundary fallback={<Text>Something went wrong</Text>}>
  <YourComponent />
</Pulse.ErrorBoundary>

// Render-prop fallback + onError callback
<Pulse.ErrorBoundary
  fallback={({ error }) => (
    <Text>{error instanceof Error ? error.message : String(error)}</Text>
  )}
  onError={(error, componentStack) => console.log('Render error:', error)}
>
  <YourComponent />
</Pulse.ErrorBoundary>

// HOC variant
const SafeProfile = Pulse.withErrorBoundary(UserProfile, {
  fallback: <Text>Profile failed to load</Text>,
});
```

### Option B — You already have an error boundary

Keep the existing component. Inside `componentDidCatch` (or the equivalent hook in libraries like `react-error-boundary`), call **`Pulse.reportException`** and choose **fatal vs non-fatal yourself**.

```tsx
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

class AppErrorBoundary extends React.Component {
  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Example: this boundary renders a fallback UI → treat as non-fatal for Pulse
    Pulse.reportException(error, false, {
      componentStack: errorInfo.componentStack ?? '',
    });

    // Or, if this boundary does NOT recover the UI and you want crash-style classification:
    // Pulse.reportException(error, true, { componentStack: errorInfo.componentStack ?? '' });
  }

  // ...existing render / state — leave untouched
}
```

`react-error-boundary` equivalent:

```tsx
import { ErrorBoundary } from 'react-error-boundary';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

<ErrorBoundary
  FallbackComponent={ExistingFallback}
  onError={(error, info) => {
    Pulse.reportException(error, false, {
      componentStack: info.componentStack ?? '',
    });
  }}
>
  <App />
</ErrorBoundary>
```

`Pulse.reportException` arguments:

- **First** — an `Error` (or any value the SDK can stringify).
- **Second** — `isFatal: boolean`. Pick `true` only when the boundary does not recover the UI; otherwise `false`.
- **Third** *(optional)* — extra attributes; merged with the global attributes already attached to all telemetry.

What the skill is allowed to do here:

- When the user names their boundary file, add the `import` + the `Pulse.reportException(...)` call inside `componentDidCatch` / `onError`. Show the diff first.
- Surface that `isFatal` is the user's call — do not pick it on heuristics.

What the skill must **not** do:

- Replace the user's boundary with `<Pulse.ErrorBoundary>`.
- Change the fallback UI, the boundary's lifecycle, or its placement in the tree.
- Install `react-error-boundary` or any other boundary library.

---

Error boundaries do **not** catch errors in event handlers, async code, or effects — use `try` / `catch` + `Pulse.reportException` (or `PulseService.trackNonFatal`) for those.

---

## User-directed insertion

When the user names a file or component (e.g. "wrap `<Checkout />` in an error boundary in `app/(tabs)/checkout.tsx`"), make only the requested change. Show the diff first.

---

## Reported attributes

| Attribute | Description |
|---|---|
| `error.fatal` | `true` for unhandled crashes / no-fallback boundaries; `false` otherwise |
| `error.source` | Always `"js"` |
| `exception.type` | Error class name (e.g. `"TypeError"`) |
| `exception.message` | Error message string |
| `exception.stacktrace` | JS stack trace |
| `screen.name` | Current screen (when navigation tracking is wired) |
| `span_id` / `trace_id` | When the error occurs inside an active span |
