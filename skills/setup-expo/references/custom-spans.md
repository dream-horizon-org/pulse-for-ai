# Custom Spans

Measure duration of any operation — API calls, data processing, user flows.

## Closure-Based (Recommended)

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

// Async operation
const users = await Pulse.trackSpan('fetch_users', {}, () => api.fetchUsers());

// With attributes
const result = Pulse.trackSpan(
  'parse_response',
  { attributes: { format: 'json' } },
  () => JSON.parse(data)
);
```

## Manual Start/End

```typescript
import { Pulse, SpanStatusCode } from '@dreamhorizonorg/pulse-react-native';

const span = Pulse.startSpan('image_upload', {
  attributes: { size_bytes: fileData.length },
});

try {
  await performUpload(fileData);
  span.setAttributes({ items_uploaded: 1 });
  span.end(SpanStatusCode.OK);
} catch (error) {
  span.recordException(error);
  span.end(SpanStatusCode.ERROR);
}
```

**Always call `span.end()`** — leaked spans are flushed eventually but will have incorrect duration.

## Span Methods

```typescript
span.setAttributes({ key: 'value' });          // add attributes
span.addEvent('checkpoint', { step: 'parse' }); // add event marker
span.recordException(error);                    // attach error
span.end(SpanStatusCode.OK);                    // OK | ERROR | UNSET
```
