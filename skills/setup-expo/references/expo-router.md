# Expo Router Navigation

Expo Router requires `registerWhenContainerReady: true` in `useNavigationTracking` because the navigation container is not immediately available when the root layout mounts.

## Full Setup

```tsx
import { Stack, useNavigationContainerRef } from 'expo-router';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.start();

function RootLayout() {
    const navigationRef = useNavigationContainerRef();

    Pulse.useNavigationTracking(navigationRef, {
        registerWhenContainerReady: true,   // required for Expo Router
        screenSessionTracking: true,        // session duration per screen
        screenNavigationTracking: true,     // navigation events
        screenInteractiveTracking: false,   // time-to-interactive — opt-in
    });

    return <Stack />;
}

export default RootLayout;
```

## Screen Interactive Tracking

When `screenInteractiveTracking: true`, you must call `Pulse.markContentReady()` on each screen to signal it has finished loading:

```typescript
function HomeScreen() {
    useEffect(() => {
        loadData().then(() => {
            Pulse.markContentReady();
        });
    }, []);
}
```

Without calling `markContentReady()`, the interactive span will never close.

## Navigation Attributes

| Attribute | Description | Example |
|---|---|---|
| `pulse.type` | Event type | `"screen_load"`, `"screen_session"`, `"screen_interactive"` |
| `screen.name` | Current screen name | `"(tabs)/index"` |
| `last.screen.name` | Previous screen (screen_load only) | `"(tabs)/profile"` |
