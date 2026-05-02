# Global Attributes

Attach metadata to every span and event for the lifetime of the session.

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setGlobalAttribute('environment', 'production');
Pulse.setGlobalAttribute('app_version', '2.1.0');
Pulse.setGlobalAttribute('feature_flag_x', true);
Pulse.setGlobalAttribute('experiment_group', 'variant_b');
```

**Supported types:** `string`, `number`, `boolean`, and arrays of these types.

Call after `PulseService.start()`. Attributes persist until the app process ends — they are not cleared between sessions.

## Common Use Cases

```typescript
// Environment tagging
Pulse.setGlobalAttribute('environment', __DEV__ ? 'development' : 'production');

// Release tracking
Pulse.setGlobalAttribute('release_channel', 'beta');
Pulse.setGlobalAttribute('app_version', DeviceInfo.getVersion());

// A/B test attribution
Pulse.setGlobalAttribute('experiment_checkout_v2', 'control');

// Feature flag state
Pulse.setGlobalAttribute('dark_mode_enabled', userPrefs.darkMode);
```

## Difference from User Properties

| | Global Attributes | User Properties |
|---|---|---|
| Scope | All telemetry | Tied to user identity |
| API | `setGlobalAttribute` | `setUserProperties` / `setUserId` |
| Cleared on logout? | No | Yes (when you call `setUserId(null)`) |
| Typical use | App config, experiments | User plan, region, cohort |
