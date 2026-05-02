# Pulse.start() Configuration

All options are optional — defaults work for most apps.

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  autoDetectExceptions: true,    // default: true — JS crashes + unhandled rejections
  autoDetectNetwork:    true,    // default: true — fetch, XHR, axios interception
  autoDetectNavigation: true,    // default: true — kill switch only, does NOT add tracking
  logLevel: PulseLogLevel.DEBUG, // dev only — remove before release
  networkHeaders: {
    requestHeaders:  ['x-request-id', 'x-trace-id'],
    responseHeaders: ['x-response-time', 'cache-control'],
  },
});
```

## autoDetectNavigation

Kill switch only — `true` does not enable screen tracking. You still need `useNavigationTracking`. Set to `false` to fully disable navigation instrumentation.

## networkHeaders

Capture custom HTTP headers alongside each network span. Only listed header names are captured.

## logLevel

| Level | Output |
|---|---|
| `PulseLogLevel.VERBOSE` | All internal event matching — very noisy |
| `PulseLogLevel.DEBUG` | Export results, config fetches |
| `PulseLogLevel.INFO` | Session boundaries |
| `PulseLogLevel.WARN` | Recoverable errors |
| `PulseLogLevel.ERROR` | Unrecoverable errors |
| `PulseLogLevel.NONE` | Silent (production default) |

```typescript
Pulse.start({
  logLevel: __DEV__ ? PulseLogLevel.DEBUG : PulseLogLevel.NONE,
});
```
