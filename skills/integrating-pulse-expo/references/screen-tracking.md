---
name: pulse-screen-tracking
description: Surface what Pulse tracks per screen and how to opt-in to screen_interactive via markContentReady(). Suggestion-only — never calls markContentReady() automatically.
category: sdk-feature
invoke-when: screen tracking, screen load, screen session, screen interactive, time to interactive, TTI per screen, markContentReady, screen attributes
allowed-tools: Read, Edit, Bash
---

## Scope

Screen tracking is configured **once, globally**, when wiring `useNavigationTracking` (already covered by `/integrating-pulse-expo` Step 5–6). This reference only explains:

1. What is tracked automatically.
2. How to opt-in to `screen_interactive` and where the user must call `Pulse.markContentReady()` themselves.

**Never call `markContentReady()` on the user's behalf** — only the user knows when their screen is meaningfully interactive. Suggest the call site, do not insert it.

---

## What gets tracked

Once `Pulse.useNavigationTracking(navigationRef, ...)` is wired in the entry point, the SDK emits three signals per screen:

| Signal | What it measures | Default |
|---|---|---|
| `screen_load` | Time from navigation start → screen displayed | on |
| `screen_session` | Time the screen is in focus → user navigates away | on |
| `screen_interactive` | Time from screen displayed → user-defined "ready" point | **off** (opt-in) |

## Opt-in: `screen_interactive`

Enable in the hook options where `useNavigationTracking` is already wired (do **not** add a new wiring site):

```typescript
Pulse.useNavigationTracking(navigationRef, {
  registerWhenContainerReady: true,    // Expo Router
  screenInteractiveTracking:  true,    // opt-in
});
```

Then, **the user must call** `Pulse.markContentReady()` from inside each screen they want measured — typically after the data fetch resolves and the meaningful UI is on screen.

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

function HomeScreen() {
  useEffect(() => {
    fetchData().then(() => {
      Pulse.markContentReady();
    });
  }, []);
}
```

If the user navigates away before `markContentReady()` is called, the span is discarded.

## When to suggest calling it

| Screen pattern | Suggest call point |
|---|---|
| Loads data from an API | After the fetch resolves and the list/content renders |
| Renders cached data immediately | On first render |
| Has a loading skeleton | When the skeleton is replaced with real content |
| Streams content | When enough is visible to be useful |

## Disable / fine-tune individual signals

```typescript
Pulse.useNavigationTracking(navigationRef, {
  registerWhenContainerReady: true,
  screenSessionTracking:      true,    // default: on
  screenNavigationTracking:   true,    // default: on
  screenInteractiveTracking:  false,   // default: off
});
```

To turn navigation tracking off entirely:

```typescript
Pulse.start({ autoDetectNavigation: false });
```

## Span attributes

| Attribute | Description |
|---|---|
| `pulse.type` | `"screen_load"`, `"screen_session"`, or `"screen_interactive"` |
| `screen.name` | Current screen name |
| `last.screen.name` | Previous screen (on `screen_load` only) |
| `routeKey` | Unique route identifier |

## Guardrails for this reference

- **Never** call `markContentReady()` automatically anywhere in the user's screens — suggest call sites, then let the user add them or explicitly ask.
- **Never** introduce a new `useNavigationTracking` wiring site. If the entry point already wires it (from `/integrating-pulse-expo`), only modify its options object.
- **Never** restructure screens or move components to wire this.
