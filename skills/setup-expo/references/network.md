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

## Android: Image & FastImage (OkHttp)

Built-in `Image`, `FastImage`, and other native Android components use OkHttp — their requests bypass the JS layer and are **not** captured by `autoDetectNetwork`.

Enable via the Expo config plugin in `app.json`:

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED",
    "android": {
      "okHttpInstrumentation": { "enabled": true }
    }
  }
]
```

Re-run `npx expo prebuild --clean` after adding this. OkHttp instrumentation uses ByteBuddy at the native level — it captures all Android HTTP traffic including `Image`, `FastImage`, and any native SDK making HTTP calls.

## iOS

URLSession is instrumented automatically — all `Image`, `FastImage`, and native network traffic is captured without any extra plugin config. See the [iOS network guide](https://pulse-ux.com/docs/developer-guide/sdk/ios/instrumentation/network) for URL filters and header capture.
