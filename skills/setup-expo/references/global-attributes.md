# Global Attributes

Attach metadata to every span and event for the lifetime of the session.

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setGlobalAttribute('environment', 'production');
Pulse.setGlobalAttribute('app_version', '2.1.0');
Pulse.setGlobalAttribute('experiment_group', 'variant_b');
Pulse.setGlobalAttribute('dark_mode_enabled', true);
```

**Supported types:** `string`, `number`, `boolean`, and arrays of these types.

Call after `PulseService.start()`. Attributes persist for the app session.

## Common Use Cases

```typescript
// Environment tagging
Pulse.setGlobalAttribute('environment', __DEV__ ? 'development' : 'production');

// Release tracking
Pulse.setGlobalAttribute('release_channel', Updates.channel ?? 'production');
Pulse.setGlobalAttribute('update_id', Updates.updateId ?? 'embedded');

// A/B test attribution
Pulse.setGlobalAttribute('experiment_new_checkout', 'control');
```

## Expo OTA Updates

Useful for tagging which OTA update is running:

```typescript
import * as Updates from 'expo-updates';

Pulse.setGlobalAttribute('ota_update_id', Updates.updateId ?? 'embedded');
Pulse.setGlobalAttribute('release_channel', Updates.channel ?? 'production');
```
