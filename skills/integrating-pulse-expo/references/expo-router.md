---
name: pulse-expo-router
description: Wire Pulse navigation tracking in projects that already use Expo Router. Detect-and-wire only — never installs expo-router itself, never restructures the layout.
category: sdk-feature
invoke-when: expo router, useNavigationContainerRef, registerWhenContainerReady, app/_layout.tsx, screen tracking with expo router, Stack RootLayout
allowed-tools: Read, Edit, Bash
---

## Scope

Wire Pulse navigation tracking when the project **already uses Expo Router**. Detection happens in `/integrating-pulse-expo` Step 1; this reference is the canonical wiring + options snippet.

**Never install `expo-router` as part of Pulse setup.** If `app/_layout.tsx` does not exist and `expo-router` is not in `package.json`, fall back to React Navigation wiring or "no navigation" (covered in the main skill).

---

## Detection (recap)

`expo-router` is in use if **either** is true:

```bash
ls app/_layout.tsx app/_layout.jsx app/_layout.js 2>/dev/null
grep -E '"expo-router"' package.json
```

If neither matches, this reference does not apply — do not add `expo-router`.

## Why Expo Router needs special wiring

Expo Router owns the `NavigationContainer` internally — there is no consumer-supplied `<NavigationContainer ref={...}>`. Pulse must hook in once the container is mounted, so:

- Get the ref from `useNavigationContainerRef` exported by `expo-router`
- Pass `registerWhenContainerReady: true` so Pulse defers attachment until the container is ready
- **Do not** wire an `onReady` callback — Expo Router does not expose one for the root container

## Setup (additive only)

The `/integrating-pulse-expo` skill adds this in `app/_layout.tsx`. Only modify what's shown — do not restructure the layout, change the navigator type, or move providers.

```tsx
import { Stack, useNavigationContainerRef } from 'expo-router';
import { PulseService } from '../src/config/pulse';   // or '../pulse' if no src/

PulseService.start();

export default function RootLayout() {
  const navigationRef = useNavigationContainerRef();
  PulseService.useNavigationTracking(navigationRef);

  return <Stack />;   // existing tree — do not change
}
```

The `useNavigationTracking` wrapper in `src/config/pulse.ts` already passes `{ registerWhenContainerReady: true }` for Expo Router.

## What gets tracked automatically

`screen_load` and `screen_session` start emitting on the next navigation. `screen_interactive` is off by default — see `screen-tracking.md` to opt in (requires the user to call `Pulse.markContentReady()`).

## Plugin coupling

When Expo Router is detected, `/integrating-pulse-expo` Step 3 also disables redundant native screen tracking to avoid double-counting:

```json
{
  "android": { "instrumentation": { "fragment":        { "enabled": false } } },
  "ios":     { "instrumentation": { "screenLifecycle": { "enabled": false } } }
}
```

Keep `activity` (Android) and `appLifecycle` / `appStartup` (iOS) **enabled** — they power the AppStart span.

## Navigation attributes

| Attribute | Description | Example |
|---|---|---|
| `pulse.type` | Event type | `"screen_load"`, `"screen_session"`, `"screen_interactive"` |
| `screen.name` | Current screen name | `"(tabs)/index"` |
| `last.screen.name` | Previous screen (on `screen_load` only) | `"(tabs)/profile"` |
| `routeKey` | Unique route identifier | `"_sitemap-..."` |

## Guardrails for this reference

- **Never** install `expo-router`, `react-native-screens`, `react-native-safe-area-context`, or any other navigation library.
- **Never** convert React Navigation to Expo Router (or vice-versa) as part of Pulse setup.
- **Never** add new providers, wrappers, or top-level components beyond the two lines documented above.
- If `app/_layout.tsx` already calls `PulseService.start()` or `useNavigationTracking`, **stop and ask** before adding anything.
