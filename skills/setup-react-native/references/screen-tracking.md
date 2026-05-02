# Screen Tracking

Pulse tracks three types of screen events when `useNavigationTracking` is configured:

| Type | What it measures | Default |
|---|---|---|
| `screen_session` | Time spent on a screen from arrival to departure | on |
| `screen_load` | Navigation event — how the user arrived | on |
| `screen_interactive` | Time from screen load until content is ready | off |

## Enable / Disable Per Type

```typescript
Pulse.useNavigationTracking(navigationRef, {
  screenSessionTracking:     true,   // time on screen
  screenNavigationTracking:  true,   // navigation events
  screenInteractiveTracking: true,   // time-to-interactive — requires markContentReady()
});
```

## Time-to-Interactive

When `screenInteractiveTracking: true`, Pulse starts a timer on each navigation. You must call `Pulse.markContentReady()` to close it — otherwise the span stays open until the next navigation.

```typescript
function HomeScreen() {
  useEffect(() => {
    fetchData().then(() => {
      Pulse.markContentReady();  // signals content is loaded and interactive
    });
  }, []);
}
```

Call it after your primary content has finished loading — typically after the first meaningful data fetch or render.

## Screen Attributes

| Attribute | Description |
|---|---|
| `screen.name` | Current screen name |
| `last.screen.name` | Previous screen (on `screen_load` events) |
| `pulse.type` | `screen_load`, `screen_session`, or `screen_interactive` |
