---
name: pulse-user-id
description: Suggest the Pulse user-identification API and wire it only into files the user explicitly names. Never searches for or modifies auth flows on its own.
category: sdk-feature
invoke-when: identify users, attach user id, set user properties, filter telemetry by user
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks to attach a user ID / properties to Pulse telemetry in their Expo app, and Pulse is already set up.

---

## Guardrails

This skill is **suggestion-first**:

1. Surface the available API and the recommended call points (login → set, logout → clear).
2. **Only** modify a source file if the user names the file (and ideally the function) where the calls should go.

Never:

- Grep for `login` / `logout` / `signIn` and pick a file yourself.
- Insert calls into auth screens, hooks, or context providers based on heuristics.
- Refactor the auth layer or move state.
- Persist user IDs to disk on the user's behalf.

If the user says "add user identification to Pulse" without naming a file → respond with the API and a one-line suggestion of where it usually goes, then ask which file to edit.

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

- Package missing → tell user to run `/integrating-pulse-expo` first. Stop.
- `pulse.ts` wrapper found → use `PulseService.setUser` / `PulseService.clearUser`.
- Wrapper missing → use `Pulse.setUserId` / `Pulse.setUserProperties` direct from the SDK.

---

## API reference

| Call | Purpose |
|---|---|
| `Pulse.setUserId(id)` | Attach user ID to all subsequent telemetry |
| `Pulse.setUserId(null)` | Clear the user ID (logout) |
| `Pulse.setUserProperty(name, value)` | Set or update a single property |
| `Pulse.setUserProperty(name, null)` | Remove a single property |
| `Pulse.setUserProperties({...})` | Replace multiple properties at once |

Wrapper equivalents (created by `/integrating-pulse-expo`):

```typescript
PulseService.setUser(id: string, properties?: Record<string, AttributeValue>): void
PulseService.clearUser(): void
```

`setUser` calls `Pulse.setUserId(id)` and (if `properties` is passed) `Pulse.setUserProperties(properties)`. `clearUser` calls `Pulse.setUserId(null)`.

Supported property value types: `string`, `number`, `boolean`, and arrays of these. ID and properties persist for the process lifetime — clear them on logout.

---

## Suggested call points (suggest only — do not auto-insert)

After a successful login response is handled by the user's auth code:

```typescript
import { PulseService } from '@/config/pulse';
// no wrapper: import { Pulse } from '@dreamhorizonorg/pulse-react-native';

PulseService.setUser(user.id, {
  plan:     user.plan,
  region:   user.region,
  verified: user.emailVerified,
});
```

When the user signs out:

```typescript
PulseService.clearUser();
// direct SDK alternative: Pulse.setUserId(null);
```

To update a single property without overwriting others:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setUserProperty('plan', 'enterprise');
Pulse.setUserProperty('plan', null);   // remove this property only
```

---

## User-directed insertion

When the user names a file (e.g. "after `loginUser` resolves in `src/auth/AuthContext.tsx`, attach the user"), add only the suggested lines. Show the diff first. Do not modify anything else in the file.

---

## Native side (informational only — do not add unless user asks)

If user identity is set from native code before the JS bundle loads:

- Android (Kotlin): `Pulse.setUserId("usr_12345")` / `Pulse.setUserProperty("plan", "premium")` from `com.pulsereactnativeotel.Pulse`. `Pulse.setUserId(null)` to clear.
- iOS (Swift): `PulseSDK.setUserId("usr_12345")` from `PulseReactNativeOtel`. `PulseSDK.setUserId(nil)` to clear.

Surface these only if the user explicitly asks about native auth flows; do not modify native files as part of this skill.
