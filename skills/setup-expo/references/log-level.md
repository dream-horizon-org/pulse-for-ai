# Debug Logging

Enable verbose logging to debug Pulse SDK during development.

```typescript
import { Pulse, PulseLogLevel } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  logLevel: __DEV__ ? PulseLogLevel.DEBUG : PulseLogLevel.NONE,
});
```

## Log Levels

| Level | What it shows |
|---|---|
| `VERBOSE` | Internal event matching — very noisy |
| `DEBUG` | Export results, config fetches — most useful for troubleshooting |
| `INFO` | Session start/end boundaries |
| `WARN` | Recoverable errors |
| `ERROR` | Unrecoverable errors |
| `NONE` | Silent — production default |

## Common Debug Scenarios

**`isInitialized()` returns false after prebuild:**
→ Re-run `npx expo prebuild --clean`, check plugin config — `apiKey` must be at root level

**Not seeing events in the dashboard:**
→ Use `DEBUG` — check for export errors or API key issues

**Expo Router: no screen events:**
→ Confirm `registerWhenContainerReady: true` is set, use `VERBOSE` to check navigation matching
