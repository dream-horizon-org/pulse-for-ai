# Custom Spans

Measure duration of any operation — API calls, data processing, user flows — and attach structured context.

## Closure-Based (Recommended)

Use `trackSpan` when you can wrap the operation:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Sync
const result = Pulse.trackSpan(
    'parse_response',
    { attributes: { format: 'json' } },
    () => JSON.parse(data)
);

// Async
const users = await Pulse.trackSpan(
    'fetch_users',
    {},
    () => api.fetchUsers()
);
```

## Manual Start/End

Use `startSpan` when you need explicit control:

```typescript
import { Pulse, SpanStatusCode } from '@dreamhorizonorg/pulse-react-native';

const span = Pulse.startSpan('file_upload', {
    attributes: { size_bytes: fileData.length },
    inheritContext: true, // default: becomes the active parent span
});

try {
    await performUpload(fileData);
    span.setAttributes({ items_processed: 42 });
    span.addEvent('checkpoint', { step: 'validate' });
    span.end(SpanStatusCode.OK);
} catch (error) {
    span.recordException(error);
    span.end(SpanStatusCode.ERROR);
}
```

**Always call `span.end()`** — leaked spans are eventually flushed but will have incorrect duration.

## Native Span APIs

**Kotlin (Android):**
```kotlin
import com.pulsereactnativeotel.Pulse

Pulse.trackSpan(
    spanName = "native_task",
    params = emptyMap(),
) {
    // your work
}
```

**Swift (iOS):**
```swift
import PulseReactNativeOtel

PulseSDK.trackSpan(name: "native_task", params: [:]) {
    // your work
}
```
