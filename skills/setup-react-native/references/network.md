# Network Monitoring

Pulse automatically intercepts HTTP requests via `fetch`, `XMLHttpRequest`, and `axios` when `autoDetectNetwork: true` (default).

## Disable Auto-Detection

```typescript
Pulse.start({ autoDetectNetwork: false });
```

## Captured Network Attributes

| Attribute | Description | Example |
|---|---|---|
| `pulse.type` | `network.<status_code>` | `network.200`, `network.404` |
| `http.method` | HTTP method | `"GET"`, `"POST"` |
| `http.url` | Full request URL | `"https://api.example.com/users/123"` |
| `http.status_code` | Response status code | `200`, `404` |
| `http.host` | Hostname | `"api.example.com"` |
| `http.target` | Path + query string | `"/users/123"` |
| `error` | `true` on 4xx/5xx or network failure | `true` |
| `graphql.operation.name` | GraphQL operation name (auto-detected) | `"GetUser"` |
| `graphql.operation.type` | GraphQL operation type (auto-detected) | `"query"` |
| `http.request.body.size` | Request body size in bytes | `42` |
| `http.response.body.size` | Response body size in bytes | `2048` |

## Capture Custom Headers

```typescript
Pulse.start({
    autoDetectNetwork: true,
    networkHeaders: {
        requestHeaders: ['x-request-id', 'x-trace-id'],
        responseHeaders: ['x-response-time', 'cache-control'],
    },
});
```

## Android: Image & FastImage

`Image` and `FastImage` use OkHttp on Android — their requests are not intercepted by the JS layer. To monitor them, enable OkHttp instrumentation in the native Android config:

```kotlin
Pulse.initialize(
    application = this,
    apiKey = "YOUR_API_KEY",
    dataCollectionState = PulseDataCollectionConsent.ALLOWED
) {
    network { enabled(true) }
}
```

## iOS

URLSession is tracked by default — no extra config needed.
