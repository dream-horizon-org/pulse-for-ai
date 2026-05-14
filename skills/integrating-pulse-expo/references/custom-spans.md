---
name: pulse-custom-spans
description: Wrap user-named JS functions or code blocks in a Pulse span to measure duration, capture exceptions, and correlate events. Suggestion-first — never sweeps the codebase for "slow-looking" code.
category: sdk-feature
invoke-when: custom span, profile function, measure duration, instrument code, trackSpan, startSpan, time function, JS profiling, span around function
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User wants to profile a specific JS function, hook, or code block in their Expo app, and Pulse is already set up.
- User points at a file or function and asks to "measure" / "trace" / "time" / "instrument" it.

---

## Guardrails

This skill is **suggestion-first**: only wrap files / functions / blocks the user explicitly names. Do not sweep the codebase for "slow-looking" code (API clients, parsers, image processors, etc.) and instrument on heuristics.

Never:

- Add `Pulse.trackSpan` / `Pulse.startSpan` calls into files the user did not name.
- Refactor the target function (e.g. extract sub-helpers, change error handling) to fit a span shape.
- Replace existing `console.time` / `performance.now()` / external profilers — surface that Pulse can replace them, but defer to the user.
- Leak spans. Every `startSpan(...)` must be paired with `span.end(...)` in every code path (including error paths).

If the user asks to "profile my app" without naming a function → ask which call site they want measured and may be ask user explicitly if them want to grep slow functions. Do not do on your own.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-expo` first. Stop.

The wrapper created by `/integrating-pulse-expo` does **not** export `trackSpan` / `startSpan` — import directly from the SDK:

```typescript
import { Pulse, SpanStatusCode } from '@dreamhorizonorg/pulse-react-native';
```

---

## Closure-based — `Pulse.trackSpan` (preferred)

Auto-ends the span when the callback returns or throws. Use this whenever the operation fits inside a single function:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Sync
const parsed = Pulse.trackSpan(
  'parse_response',
  { attributes: { format: 'json' } },
  () => JSON.parse(payload),
);

// Async
const users = await Pulse.trackSpan(
  'fetch_users',
  {},
  () => api.fetchUsers(),
);
```

Signature:

```typescript
Pulse.trackSpan<T>(
  name: string,
  options: { attributes?: Record<string, AttributeValue>; inheritContext?: boolean },
  action: () => T | Promise<T>,
): T | Promise<T>
```

If the callback throws, the span records the exception, sets status to `ERROR`, and re-throws — the user's existing error handling still runs.

---

## Manual — `Pulse.startSpan` + `span.end()`

Use only when the operation crosses multiple call sites or cannot be expressed as a single callback:

```typescript
import { Pulse, SpanStatusCode } from '@dreamhorizonorg/pulse-react-native';

const span = Pulse.startSpan('image_upload', {
  attributes: { size_bytes: file.size },
});

try {
  await performUpload(file);
  span.setAttributes({ items_uploaded: 1 });
  span.end(SpanStatusCode.OK);
} catch (error) {
  span.recordException(error);
  span.end(SpanStatusCode.ERROR);
  throw error;                 // preserve the user's existing error flow
}
```

**Always pair `startSpan` with `end()` in every path** (try, catch, early returns). Leaked spans are flushed eventually but with incorrect duration.

---

## Span methods

```typescript
span.setAttributes({ key: 'value' });             // add or update attributes
span.addEvent('checkpoint', { step: 'parse' });   // mark a moment in time
span.recordException(error);                      // attach an error
span.end(SpanStatusCode.OK);                      // OK | ERROR | UNSET (default)
```

---

## Context control

By default each new span becomes the active parent for any subsequent spans (so events emitted inside also get `trace_id` / `span_id`). Pass `inheritContext: false` to start an isolated span that will not affect the hierarchy:

```typescript
const bg = Pulse.startSpan('background_sync', { inheritContext: false });
// ... work that must not parent unrelated spans ...
bg.end(SpanStatusCode.OK);
```

---

## User-directed insertion

When the user names a target ("wrap `loadFeed` in `src/feed/api.ts`"), insert the minimal change:

- Closure form: replace the function body's outer `return` / `await` with `Pulse.trackSpan('loadFeed', {}, () => …)`.
- Manual form: add `startSpan` at the top, `end()` in every exit path. Show the diff first.

Do not rename the function, change its signature, move it to another file, or modify callers.

---

## Native side (informational only — do not add unless user asks)

Native span APIs exist but are out of scope for this reference:

- Android (Kotlin): `Pulse.trackSpan(...)` from `com.pulsereactnativeotel.Pulse`.
- iOS (Swift): `PulseSDK.trackSpan(...)` from `PulseReactNativeOtel`. Manual spans are Swift-only on iOS — not exposed via the Obj-C bridge.

Surface only if the user explicitly asks about instrumenting native code; do not modify native files as part of this skill.
