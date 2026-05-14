# Navigation Tracking

`autoDetectNavigation: true` in `Pulse.start()` is a kill switch only — it does NOT add tracking. You must explicitly call `useNavigationTracking` to get screen events.

## React Navigation Setup

```typescript
import { NavigationContainer, type NavigationContainerRef } from '@react-navigation/native';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

function App() {
    const navigationRef = React.useRef<NavigationContainerRef>(null);
    const onReady = Pulse.useNavigationTracking(navigationRef, {
        screenSessionTracking: true,      // default: on — session time per screen
        screenNavigationTracking: true,   // default: on — navigation events
        screenInteractiveTracking: false, // default: off — time to interactive
    });

    return (
        <NavigationContainer ref={navigationRef} onReady={onReady}>
            {/* your navigator */}
        </NavigationContainer>
    );
}
```

## Screen Interactive Tracking

When `screenInteractiveTracking: true`, Pulse measures time-to-interactive for each screen. You must manually signal when the screen is ready:

```typescript
function HomeScreen() {
    useEffect(() => {
        fetchData().then(() => {
            Pulse.markContentReady();
        });
    }, []);
}
```

## Navigation Attributes

| Attribute | Description | Example |
|---|---|---|
| `pulse.type` | Event type | `"screen_load"`, `"screen_session"`, `"screen_interactive"` |
| `screen.name` | Current screen name | `"Home"` |
| `last.screen.name` | Previous screen (screen_load events only) | `"Profile"` |
| `routeKey` | Unique route identifier | — |
