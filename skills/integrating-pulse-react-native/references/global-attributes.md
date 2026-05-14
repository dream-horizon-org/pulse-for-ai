---
name: pulse-global-attributes
description: Attach build metadata (env, version, release channel, CodePush) to every Pulse signal in an existing bare React Native setup for dashboard filtering.
category: sdk-feature
invoke-when: global attributes, tag crashes, env version release channel, build metadata, filter dashboard, OTA tracking, CodePush metadata, tag all telemetry
allowed-tools: Read, Edit, Bash
---

## Invoke When

- User asks "add environment/version metadata to Pulse" in a React Native app
- User wants to filter the dashboard by `env`, `version`, or build number
- User wants to tag CodePush/OTA update info on all telemetry
- Pulse is already set up

---

## Guard — Pulse Must Be Installed

```bash
grep '"@dreamhorizonorg/pulse-react-native"' package.json 2>/dev/null
```

If not found → tell user to run `/integrating-pulse-react-native` first. Do not proceed.

```bash
find . -name "pulse.ts" -not -path "*/node_modules/*" 2>/dev/null | head -1
```

Use `PulseService` from the wrapper if found; otherwise use `Pulse` directly from `@dreamhorizonorg/pulse-react-native`.

---

## Set at Startup via start()

Pass `globalAttributes` to `start()` in the JS entry point (`App.tsx`):

**With wrapper (`src/config/pulse.ts`):**

```typescript
import { PulseService } from './src/config/pulse';

PulseService.start({
  globalAttributes: {
    env:          __DEV__ ? 'development' : 'production',
    app_version:  '2.1.0',
  },
});
```

**Direct SDK (no wrapper):**

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.start({
  globalAttributes: {
    env:          __DEV__ ? 'development' : 'production',
    app_version:  '2.1.0',
  },
});
```

---

## Set Dynamically After Start

For values not known at startup (A/B test assignment, feature flags), use the SDK directly — `setGlobalAttribute` is not in the wrapper:

```typescript
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

Pulse.setGlobalAttribute('experiment_new_checkout', 'variant_b');
Pulse.setGlobalAttribute('dark_mode_enabled', true);
Pulse.setGlobalAttribute('release_channel', 'beta');
```

**Supported types:** `string`, `number`, `boolean`, and arrays of these types.

Call after `start()`. Attributes persist for the app session.

---

## CodePush Tracking

Tag which CodePush bundle is running so crashes map to the right source map:

```typescript
import codePush from 'react-native-code-push';
import { Pulse } from '@dreamhorizonorg/pulse-react-native';

const update = await codePush.getUpdateMetadata();
Pulse.setGlobalAttribute('codeBundleId', update?.label ?? 'embedded');
Pulse.setGlobalAttribute('codepush_version', update?.appVersion ?? 'embedded');
```

Pass the same `codeBundleId` value as `--bundle-id` when uploading source maps with `pulse-cli`.

---

## Difference from User Properties

| | Global Attributes | User Properties |
|---|---|---|
| Scope | All telemetry | Tied to user identity |
| API | `setGlobalAttribute` | `setUserProperties` / `setUserId` |
| Cleared on logout? | No | Yes (when you call `setUserId(null)`) |
| Typical use | App config, experiments | User plan, region, cohort |
