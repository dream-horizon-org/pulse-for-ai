---
name: pulse-log-level
description: Surface the Pulse JS-layer and native log-level options for development diagnostics. Always gated behind __DEV__ — never sets non-NONE log levels in production code paths.
category: sdk-reference
invoke-when: debug logging, log level, verbose, PulseLogLevel, troubleshooting Pulse, no events appearing, Pulse silent in dev
allowed-tools: Read, Edit, Bash
---

## Scope

Surface the Pulse `logLevel` API for development-only diagnostics. Do **not** enable `DEBUG` / `VERBOSE` in source files on the user's behalf — surface the gated snippet and let them apply it.

---

## Guardrails

- **Never** ship logging at anything other than `PulseLogLevel.NONE` in production. Always gate behind `__DEV__`.
- Do not modify the JS entry point to add `logLevel` unless the user asks. Surface the snippet first.
- Native log levels live in plugin config (`android.logLevel` / `ios.logLevel`). Do not change them on the user's behalf — they require `npx expo prebuild --clean` and a rebuild.

## JS-layer log level

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  logLevel: __DEV__ ? PulseLogLevel.DEBUG : PulseLogLevel.NONE,
});
```

All Pulse log lines are prefixed with `PulseSDK`.

## Levels

| Level | Value | What you see |
|---|---|---|
| `VERBOSE` | 0 | Internal event matching, fine-grained flow details |
| `DEBUG` | 1 | Export results, config fetch, feature toggles |
| `INFO` | 2 | Session boundaries, init completion |
| `WARN` | 3 | Recoverable errors, export failures |
| `ERROR` | 4 | Unrecoverable errors |
| `NONE` | 5 | Silent — production default |

## Native log level (plugin config)

To enable native-side logs as well, set under the relevant platform block in the active Expo config — re-run `npx expo prebuild --clean` after the change:

```json
"android": { "logLevel": "DEBUG" },
"ios":     { "logLevel": "DEBUG" }
```

Accepted values (case-insensitive): `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"`.

## Common debug scenarios

- **`Pulse.isInitialized()` returns false after prebuild** → re-run `npx expo prebuild --clean`. Confirm `apiKey` and `dataCollectionState` are at the plugin root (not nested under `android` / `ios`).
- **Events not appearing in the dashboard** → set JS `logLevel: DEBUG` in dev. Look for export errors or auth failures.
- **Expo Router: no screen events** → confirm `registerWhenContainerReady: true` is set in `useNavigationTracking`. Set `logLevel: VERBOSE` to see navigation matching attempts.
