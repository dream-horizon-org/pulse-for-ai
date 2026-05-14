---
name: pulse-start-config
description: Canonical option list for Pulse.start() — autoDetectExceptions, autoDetectNetwork, autoDetectNavigation, networkHeaders, logLevel. Edits only the existing start() call.
category: sdk-reference
invoke-when: Pulse.start options, autoDetectExceptions, autoDetectNetwork, autoDetectNavigation, networkHeaders, disable JS instrumentation, capture HTTP headers
allowed-tools: Read, Edit, Bash
---

## Scope

Canonical option list for the JS-layer `Pulse.start()` call wired by `/integrating-pulse-expo` Step 6. Use when the user wants to turn off an automatic instrumentation, capture custom HTTP headers, or enable verbose JS logging in development.

## Guardrails

Modify only the existing `start()` call in the entry point — do not add new call sites. Defaults are correct for almost every app; only change a flag when the user explicitly asks.

---

## Defaults

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  autoDetectExceptions: true,    // default: true — JS crashes + unhandled rejections
  autoDetectNetwork:    true,    // default: true — fetch / XHR / axios interception
  autoDetectNavigation: true,    // default: true — kill switch only, does NOT add tracking
  // logLevel:        PulseLogLevel.NONE,  // default: NONE — never set non-NONE in production
  // networkHeaders:  { ... },              // optional
});
```

All flags are `boolean`. To disable an instrumentation, set it to `false`.

> **Note:** `Pulse.start()` does **not** accept a `globalAttributes` option. Set global attributes in the Expo plugin config (see `global-attributes.md` and `plugin-reference.md`) or via the runtime `Pulse.setGlobalAttribute(...)` API.

## `autoDetectExceptions`

When `true`, Pulse installs a global JS error handler — unhandled exceptions and unhandled promise rejections are reported automatically. Manual reporting (`Pulse.reportException` / `PulseService.trackNonFatal`) still works when this is `false`.

## `autoDetectNetwork`

When `true`, Pulse intercepts `XMLHttpRequest`, `fetch`, and `axios` calls — no app changes required. To stop intercepting JS-layer HTTP entirely, set to `false`. (Native HTTP — Android OkHttp via `Image` / `FastImage` — is controlled separately by the plugin's `okHttpInstrumentation` toggle.)

## `autoDetectNavigation`

Kill switch only. Setting `true` does **not** by itself enable screen tracking — that requires `Pulse.useNavigationTracking(...)` (already wired by `/integrating-pulse-expo`). Set to `false` to disable navigation instrumentation completely, regardless of the hook.

## `networkHeaders`

Capture specific request / response headers alongside each network span. Only headers you list are captured.

```typescript
Pulse.start({
  networkHeaders: {
    requestHeaders:  ['x-request-id', 'x-trace-id'],
    responseHeaders: ['x-response-time', 'cache-control'],
  },
});
```

## `logLevel`

For development troubleshooting only. The SDK is silent by default. Always gate behind `__DEV__`:

```typescript
Pulse.start({
  logLevel: __DEV__ ? PulseLogLevel.DEBUG : PulseLogLevel.NONE,
});
```

| Level | What it shows |
|---|---|
| `PulseLogLevel.VERBOSE` | All internal event matching — very noisy |
| `PulseLogLevel.DEBUG` | Export results, config fetches |
| `PulseLogLevel.INFO` | Session boundaries |
| `PulseLogLevel.WARN` | Recoverable errors |
| `PulseLogLevel.ERROR` | Unrecoverable errors |
| `PulseLogLevel.NONE` | Silent (production default) |

This option controls only the **JS layer**. To also enable native logs, set `android.logLevel` / `ios.logLevel` in the Expo plugin config (see `log-level.md`) and re-run `npx expo prebuild --clean`.
