# User Identification

Attach user identity to all telemetry for the current session.

## JS API

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// After login
Pulse.setUserId('user-abc123');
Pulse.setUserProperties({
    subscription: 'premium',
    region: 'us-west',
    verified: true,
});

// After logout — always clear to prevent cross-user data leakage
Pulse.setUserId(null);
```

## Common Pattern

```typescript
async function handleLogin(credentials) {
    const user = await loginUser(credentials);
    Pulse.setUserId(user.id);
    Pulse.setUserProperties({ plan: user.plan, region: user.region });
}

function handleLogout() {
    Pulse.setUserId(null);
}
```

User ID and properties persist until explicitly cleared or the app process ends.
