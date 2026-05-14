---
name: pulse-user-id
description: Attach user identity to all Pulse telemetry in an existing bare React Native setup — filter crashes, sessions, and events by user in the dashboard.
category: sdk-feature
invoke-when: identify users, attach user id, set user properties, filter by user, user identification, who was affected, user tracking
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "add user identification to Pulse" in a React Native app
- User wants to filter crashes or sessions by user ID in the dashboard
- User wants to attach metadata (plan, region) to telemetry
- Pulse is already set up

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-react-native` first. Do not proceed.

```bash
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

Use `PulseService` from the wrapper if found; otherwise use `Pulse` directly from `@dreamhorizonorg/pulse-react-native`.

---

## Where to Add This

Find the login and logout handlers:

```bash
grep -rl "login\|signIn\|authenticate\|logout\|signOut" \
  --include="*.ts" --include="*.tsx" src/ . 2>/dev/null | grep -v node_modules | head -10
```

Add user identification after a successful login and clear on logout.

---

## Implementation

**With wrapper (`src/config/pulse.ts`):**

```typescript
import { PulseService } from './src/config/pulse';

// After successful login
async function handleLogin(credentials) {
  const user = await loginUser(credentials);
  PulseService.setUser(user.id, {
    plan:     user.plan,
    region:   user.region,
    verified: user.emailVerified,
  });
}

// After logout — always clear to prevent cross-user data leakage
function handleLogout() {
  PulseService.clearUser();
}
```

**Direct SDK (no wrapper):**

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setUserId(user.id);
Pulse.setUserProperties({ plan: user.plan, region: user.region, verified: user.emailVerified });

// On logout:
Pulse.setUserId(null);
```

---

## Fine-Grained Control

Update a single property without overwriting others:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setUserProperty('plan', 'enterprise');
Pulse.setUserProperty('plan', null);  // remove a specific property
```

---

## Native APIs

If user identity is set from native code before the JS layer loads (e.g. after a native auth flow):

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

---

User ID and properties persist until explicitly cleared or the app process ends.
