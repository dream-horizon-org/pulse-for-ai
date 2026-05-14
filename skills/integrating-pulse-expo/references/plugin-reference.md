---
name: pulse-plugin-reference
description: Canonical option list for the @dreamhorizonorg/pulse-react-native Expo plugin. Use when modifying plugin config beyond /integrating-pulse-expo defaults.
category: sdk-reference
invoke-when: plugin config, app.json plugin, instrumentation toggles, okHttpInstrumentation, coreLibraryDesugaring, fragment screenLifecycle, plugin options, per-platform overrides
allowed-tools: Read, Edit, Bash
---

## Scope

Canonical option list for the `@dreamhorizonorg/pulse-react-native` Expo plugin. Use when the user wants a deeper plugin tweak than `/integrating-pulse-expo` covers.

## Guardrails

Modify only the existing plugin entry in the active Expo config (`app.json` / `app.config.js` / `app.config.ts`). Do not restructure the file, do not add other plugins, and re-run `npx expo prebuild --clean` after **any** change to plugin config.

---

## Minimal config

```json
[
  "@dreamhorizonorg/pulse-react-native",
  {
    "apiKey": "YOUR_API_KEY",
    "dataCollectionState": "ALLOWED"
  }
]
```

`apiKey` and `dataCollectionState` at the plugin root apply to both platforms. Override per-platform inside `android` / `ios` blocks.

## Top-level options

| Option | Required | Values | Description |
|---|---|---|---|
| `apiKey` | Yes | string | Project API key from the Pulse dashboard |
| `dataCollectionState` | Yes | `"ALLOWED"`, `"PENDING"`, `"DENIED"` | Initial data-collection state |
| `android` | No | object | Android-specific overrides |
| `ios` | No | object | iOS-specific overrides |

## `android` options

| Option | Description |
|---|---|
| `apiKey` | Override API key for Android only |
| `dataCollectionState` | Override consent for Android only (`"ALLOWED"`, `"PENDING"`, `"DENIED"`) |
| `globalAttributes` | Key/value pairs attached to all Android telemetry. Values: `string`, `number`, `boolean`, or arrays of these. |
| `logLevel` | Native log verbosity — debugging only, **never set in production**. `"VERBOSE"`, `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`, `"NONE"` (default). Case-insensitive. |
| `coreLibraryDesugaring` | `{ "enabled": true }` — **required if `minSdkVersion < 26`** |
| `okHttpInstrumentation` | `{ "enabled": true }` — native OkHttp spans (Image / FastImage / native HTTP). Optionally set `"byteBuddyGradlePluginVersion"` to override the default (`"1.17.8"`). |
| `instrumentation` | Per-collector toggles — see below |

`android.instrumentation` (each takes `{ "enabled": boolean }`):

| Key | Description |
|---|---|
| `crash` | Native crash detection |
| `network` | Network monitoring |
| `activity` | Activity lifecycle — powers AppStart span. Keep enabled. |
| `fragment` | Fragment lifecycle — **set `false` for RN apps** to avoid double-counting screens |
| `anr` | ANR detection |
| `slowRendering` | Slow / jank-frame detection |
| `interaction` | Touch / tap events |

## `ios` options

| Option | Description |
|---|---|
| `apiKey` | Override API key for iOS only |
| `dataCollectionState` | Override consent for iOS only (`"ALLOWED"`, `"PENDING"`, `"DENIED"`) |
| `globalAttributes` | Key/value pairs attached to all iOS telemetry. Values: `string`, `number`, `boolean`, or arrays of these. |
| `logLevel` | Native log verbosity — debugging only, **never set in production**. Same accepted values as Android. |
| `configuration` | Attribute-bundle toggles — see below |
| `instrumentation` | Per-collector toggles — see below |

`ios.configuration` (booleans):

| Key | Description |
|---|---|
| `includeScreenAttributes` | Attach screen metadata to telemetry |
| `includeNetworkAttributes` | Attach network metadata to telemetry |
| `includeGlobalAttributes` | Attach global attributes to telemetry |

`ios.instrumentation` (each takes `{ "enabled": boolean }`):

| Key | Description |
|---|---|
| `crash` | Native crash detection |
| `appLifecycle` | Foreground / background transitions |
| `screenLifecycle` | UIViewController tracking — **set `false` for Expo Router** to avoid double-counting screens |
| `appStartup` | Cold-start timing |
| `location` | Location updates |

> URLSession is instrumented automatically — there is no plugin toggle. URL filters and header capture are configured via `Pulse.start({ networkHeaders: ... })` (see `rn-start-config.md`).

## OkHttp / Image / FastImage on Android

`Image`, `FastImage`, and other native components on Android use OkHttp. Their requests **bypass the JS layer** and are not captured by the JS network instrumentation. To capture them, enable the native OkHttp instrumentation:

```json
"android": {
  "okHttpInstrumentation": { "enabled": true }
}
```

This wires the Pulse OkHttp artifacts and the ByteBuddy Gradle plugin at prebuild time. Re-run `npx expo prebuild --clean` after enabling.

## Full example

```json
{
  "expo": {
    "plugins": [
      [
        "@dreamhorizonorg/pulse-react-native",
        {
          "apiKey": "YOUR_API_KEY",
          "dataCollectionState": "ALLOWED",
          "android": {
            "globalAttributes": { "env": "production" },
            "coreLibraryDesugaring": { "enabled": true },
            "okHttpInstrumentation": { "enabled": true },
            "instrumentation": {
              "fragment":      { "enabled": false },
              "crash":         { "enabled": true  },
              "network":       { "enabled": true  },
              "anr":           { "enabled": true  },
              "slowRendering": { "enabled": true  },
              "interaction":   { "enabled": true  }
            }
          },
          "ios": {
            "globalAttributes": { "env": "production" },
            "configuration": {
              "includeScreenAttributes":  true,
              "includeNetworkAttributes": true
            },
            "instrumentation": {
              "crash":           { "enabled": true  },
              "screenLifecycle": { "enabled": false },
              "appStartup":      { "enabled": true  }
            }
          }
        }
      ]
    ]
  }
}
```

## Data-collection consent states (recap)

| State | Behavior |
|---|---|
| `ALLOWED` | Telemetry collected and exported immediately |
| `PENDING` | SDK initialized — data buffered in memory, nothing exported |
| `DENIED` | Terminal — buffer cleared, SDK shuts down |

Valid runtime transitions:

- `PENDING → ALLOWED` flushes buffer, starts exporting
- `PENDING → DENIED` clears buffer, shuts down
- `ALLOWED → DENIED` clears buffer, shuts down
- `DENIED → anything` invalid — requires app restart

> **After every plugin-config change**, re-run `npx expo prebuild --clean` and rebuild iOS / Android. Surface this command — do not run it yourself.
