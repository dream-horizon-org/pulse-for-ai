# User Identification

Attach user identity to all telemetry for the current session.

```typescript
import { PulseService } from './services/PulseService';

// After login
PulseService.setUser('usr-abc123', {
  plan:     'premium',
  region:   'us-west',
  verified: true,
});

// After logout — always clear to prevent cross-user data leakage
PulseService.clearUser();
```

## Direct Pulse API

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setUserId('usr-abc123');
Pulse.setUserProperties({ plan: 'premium', region: 'us-west' });

// Set a single property
Pulse.setUserProperty('plan', 'enterprise');
Pulse.setUserProperty('plan', null);  // remove a specific property

// Clear on logout
Pulse.setUserId(null);
```

## Common Pattern

```typescript
async function handleLogin(credentials) {
  const user = await loginUser(credentials);
  PulseService.setUser(user.id, { plan: user.plan, region: user.region });
}

function handleLogout() {
  PulseService.clearUser();
}
```

User ID and properties persist until explicitly cleared or the app process ends.

## Native APIs

If user identity is set from native code (e.g. after a native auth flow before JS layer loads):

**Kotlin (Android):**
```kotlin
PulseSDK.INSTANCE.setUserId("usr_12345")
PulseSDK.INSTANCE.setUserProperty("plan", "premium")
PulseSDK.INSTANCE.setUserId(null)  // clear on logout
```

**Swift (iOS):**
```swift
Pulse.shared.setUserId("usr_12345")
Pulse.shared.setUserProperty(name: "plan", value: AttributeValue.string("premium"))
Pulse.shared.setUserId(nil)  // clear on logout
```
