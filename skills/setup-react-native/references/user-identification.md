# User Identification

Attach a user identity to all telemetry for the current session.

## JS API

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Set user ID after login
Pulse.setUserId('user-abc123');

// Set user properties
Pulse.setUserProperty('subscription', 'premium');
Pulse.setUserProperties({
    subscription: 'premium',
    region: 'us-west',
    verified: true,
});

// Clear on logout — important to avoid cross-user data leakage
Pulse.setUserId(null);
Pulse.setUserProperty('subscription', null);
```

## Common Login/Logout Pattern

```typescript
async function handleLogin(credentials) {
    const user = await loginUser(credentials);
    Pulse.setUserId(user.id);
    Pulse.setUserProperties({
        subscription: user.plan,
        region: user.region,
    });
}

function handleLogout() {
    Pulse.setUserId(null);
}
```

**Note:** User ID and properties are scoped to the current app process. They persist until explicitly cleared or the process ends. Always clear on logout to prevent data leakage.

## Native APIs

**Kotlin (Android):**
```kotlin
import com.pulsereactnativeotel.Pulse

Pulse.setUserId("usr_12345")
Pulse.setUserProperty("plan", "premium")
Pulse.setUserId(null) // logout
```

**Swift (iOS):**
```swift
import PulseReactNativeOtel

PulseSDK.setUserId("usr_12345")
PulseSDK.setUserId(nil) // logout
```
