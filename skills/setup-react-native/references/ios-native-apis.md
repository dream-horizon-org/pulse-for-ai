# iOS Native Instrumentation

Configure iOS instrumentations in `PulseSDK.initialize()`.

```swift
import PulseReactNativeOtel

PulseSDK.initialize(
    apiKey: "YOUR_API_KEY",
    dataCollectionState: .allowed,
    instrumentations: { config in
        config.screenLifecycle { $0.enabled(false) }  // disable for RN — JS navigation handles screens
        config.urlSession       { $0.enabled(true) }
        config.crash            { $0.enabled(true) }
        config.appStartup       { $0.enabled(true) }
        config.appLifecycle     { $0.enabled(true) }
        config.interaction      { $0.enabled(true) }
        config.sessions { sessions in
            sessions.enabled(true)
            sessions.maxLifetime(4 * 60 * 60)              // 4 hours
            sessions.backgroundInactivityTimeout(15 * 60)  // 15 minutes
        }
    }
)
```

## Per-Instrumentation Notes

| Instrumentation | Default | Notes |
|---|---|---|
| `screenLifecycle` | on | **Disable for RN** — JS navigation handles screen tracking |
| `urlSession` | on | URLSession network monitoring |
| `crash` | on | Native crash detection |
| `appStartup` | on | Cold start timing |
| `appLifecycle` | on | Foreground/background transitions |
| `sessions` | on | Session boundary tracking |
| `interaction` | on | User tap/touch events |

## Filter Specific Requests

```swift
config.urlSession { urlSession in
    urlSession.enabled(true)
    urlSession.setShouldInstrument { request in
        request.url?.path != "/health"  // exclude health checks
    }
}
```

## Objective-C

```objc
#import <PulseReactNativeOtel-Swift.h>

PulseObjcInstrumentations *inst = [PulseObjcInstrumentations new];
inst.screenLifecycle = [PulseObjcEnabledConfig disabled];  // disable for RN
inst.urlSession      = [PulseObjcEnabledConfig enabled];
inst.crash           = [PulseObjcEnabledConfig enabled];
inst.appStartup      = [PulseObjcEnabledConfig enabled];
inst.appLifecycle    = [PulseObjcEnabledConfig enabled];
inst.interaction     = [PulseObjcEnabledConfig enabled];

[PulseSDK pulseInitialize:@"YOUR_API_KEY"
    dataCollectionState:@"ALLOWED"
       globalAttributes:nil
          configuration:nil
        instrumentations:inst];
```

## Runtime State Changes (Swift)

```swift
// Change consent
Pulse.shared.setDataCollectionState(.allowed)

// Set user identity
Pulse.shared.setUserId("usr_12345")
Pulse.shared.setUserProperties(["plan": AttributeValue.string("premium")])

// Shutdown
Pulse.shared.shutdown()
```
