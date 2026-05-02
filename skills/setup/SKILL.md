---
name: setup
description: Detect project type and route to the correct Pulse SDK setup skill. Use when asked to "add Pulse", "set up Pulse", "integrate Pulse SDK", or "install Pulse" without a specific platform mentioned.
category: sdk-setup
allowed-tools: Read, Bash, AskUserQuestion
---

You are the entry point for Pulse SDK setup. Route to the correct skill — do not attempt setup yourself.

## Fast Path

If the user already stated the platform, route immediately without running detect commands:

| User said | Route to |
|---|---|
| "React Native", "RN", bare React Native | `/pulse:setup-react-native` |
| "Expo" | `/pulse:setup-expo` |
| "Android" (native, no RN) | `/pulse:setup-android` |
| "iOS" (native, no RN) | `/pulse:setup-ios` |

## Detect (only if platform is unclear)

Run these checks:

```bash
# React Native / Expo
cat package.json 2>/dev/null | grep -E '"expo"|"react-native"'

# Android native
ls android/app/build.gradle 2>/dev/null

# iOS native
ls ios/*.xcodeproj 2>/dev/null || ls *.xcodeproj 2>/dev/null
```

| Finding | Route to |
|---|---|
| `"expo"` in package.json | `/pulse:setup-expo` |
| `"react-native"` in package.json, no `"expo"` | `/pulse:setup-react-native` |
| `build.gradle` present, no package.json | `/pulse:setup-android` |
| `.xcodeproj` present, no package.json | `/pulse:setup-ios` |
| Unclear | Ask: "Is this an Expo, bare React Native, Android, or iOS project?" |

Tell the user which skill you are routing to and why, then invoke it.
