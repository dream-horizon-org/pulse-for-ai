# Navigation Tracking Options

`autoDetectNavigation: true` in `Pulse.start()` is a kill switch only — it does NOT add tracking. You must call `useNavigationTracking` to get screen events.

For Expo Router specifically, see [expo-router.md](./expo-router.md).

## Standard React Navigation (App.tsx)

```typescript
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import type { NavigationContainerRef, ParamListBase } from '@react-navigation/native';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

function App() {
    const navigationRef = React.useRef<NavigationContainerRef<ParamListBase>>(null);
    const onReady = Pulse.useNavigationTracking(navigationRef, {
        screenSessionTracking: true,      // default: on — session duration per screen
        screenNavigationTracking: true,   // default: on — navigation events
        screenInteractiveTracking: false, // default: off — time-to-interactive (opt-in)
    });

    return (
        <NavigationContainer ref={navigationRef} onReady={onReady}>
            {/* your navigator */}
        </NavigationContainer>
    );
}
```

## Options Reference

| Option | Default | Description |
|---|---|---|
| `screenSessionTracking` | `true` | Tracks time spent on each screen (`screen_session`) |
| `screenNavigationTracking` | `true` | Tracks screen transitions (`screen_load`) |
| `screenInteractiveTracking` | `false` | Tracks time-to-interactive (`screen_interactive`) — requires `markContentReady()` |
| `registerWhenContainerReady` | `false` | Set `true` for Expo Router — registers when container ref is ready, without `onReady` prop |

## Screen Interactive Tracking

When `screenInteractiveTracking: true`, call `Pulse.markContentReady()` once content has loaded:

```typescript
function HomeScreen() {
    useEffect(() => {
        fetchData().then(() => {
            Pulse.markContentReady();
        });
    }, []);
}
```

Without `markContentReady()`, the interactive span never closes — it stays open until the next navigation.

## Navigation Attributes

| Attribute | Description | Example |
|---|---|---|
| `pulse.type` | Event type | `"screen_load"`, `"screen_session"`, `"screen_interactive"` |
| `screen.name` | Current screen name | `"Home"` |
| `last.screen.name` | Previous screen (`screen_load` events only) | `"Profile"` |
| `routeKey` | Unique route identifier | — |
