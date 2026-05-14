# Debug Logging

Enable verbose logging to debug Pulse SDK during development.

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  logLevel: PulseLogLevel.DEBUG,
});
```

Always guard with `__DEV__` — never ship debug logs to production:

```typescript
Pulse.start({
  logLevel: __DEV__ ? PulseLogLevel.DEBUG : PulseLogLevel.NONE,
});
```

## Log Levels

| Level | What it shows |
|---|---|
| `VERBOSE` | Internal event matching — very noisy, use only if DEBUG isn't enough |
| `DEBUG` | Export results, config fetches — most useful for troubleshooting |
| `INFO` | Session start/end boundaries |
| `WARN` | Recoverable errors |
| `ERROR` | Unrecoverable errors |
| `NONE` | Silent — production default |

## Common Debug Scenarios

**Not seeing events in the dashboard:**
→ Use `DEBUG` — check for export errors or missing API key

**Navigation not tracking:**
→ Use `VERBOSE` — check if navigation events are being matched

**Network requests missing:**
→ Use `DEBUG` — check which requests are being intercepted
