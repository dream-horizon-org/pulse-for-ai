# Skill Eval Report

Generated: 2026-05-22T13:00:24Z

| | Count |
|---|---|
| ✅ Pass | 58 |
| ❌ Fail | 0 |

### Scenario 1: Expo Router + TypeScript
- ✅ PulseService created
- ✅ .pulse/learnings.md created
- ✅ .pulse/ in .gitignore
- ✅ No literal <wrapper-path> in PulseService
- ✅ Pulse.start() present
- ✅ registerWhenContainerReady configured (in /var/folders/jb/kbqzmmyd23q_m5d_fvhd8mfh0000gp/T/tmp.hgcM3EGbIW/expo-router-ts/PulseService.ts)
- ✅ Plugin added to app.json
- ✅ Pulse.start() called exactly once (not duplicated)
### Scenario 2: Already installed — skill must detect and stop
- ✅ Skill stopped — no duplicate files created
### Scenario 3: Bare React Native
- ✅ PulseService created
- ✅ .pulse/learnings.md created
- ✅ .pulse/ in .gitignore
- ✅ Pulse.initialize present in Application class
- ✅ Pulse.initialize() called AFTER super.onCreate()
- ✅ PulseSDK.initialize in AppDelegate
### Scenario 4: Bare RN already installed — skill must detect and stop
- ✅ Skill stopped — no duplicate files created on bare RN
### Scenario 5: Expo + React Navigation (no Expo Router)
- ✅ PulseService created
- ✅ .pulse/learnings.md created
- ✅ .pulse/ in .gitignore
- ✅ Plugin added to app.json
- ✅ onReady wired (in /var/folders/jb/kbqzmmyd23q_m5d_fvhd8mfh0000gp/T/tmp.hgcM3EGbIW/expo-nav-ts/App.tsx)
- ✅ NavigationContainer ref present (in /var/folders/jb/kbqzmmyd23q_m5d_fvhd8mfh0000gp/T/tmp.hgcM3EGbIW/expo-nav-ts/App.tsx)
### Scenario 6: Expo + JavaScript (no TypeScript)
- ✅ PulseService created
- ✅ PulseService created as .js (correct for JS project)
### Scenario 7: Bare RN — android/ folder missing (fresh clone without native)
- ✅ Skill correctly stopped — no PulseService without native folders
### Scenario 8: Expo + app.config.js — plugin must be written as JS module.exports
- ✅ Plugin added to app.config.js
- ✅ app.config.js uses JS object syntax (no raw JSON braces)
- ✅ app.json not created — config correctly kept in app.config.js
- ✅ PulseService created
### Scenario 9: Expo SDK ≤ 52 — kotlin19Compat added to plugin config
- ✅ kotlin19Compat added for Expo SDK ≤ 52
- ✅ Plugin in app.json
- ✅ PulseService created
### Scenario 10: Expo + minSdkVersion < 26 — coreLibraryDesugaring added to plugin config
- ✅ coreLibraryDesugaring added to plugin config
- ✅ Plugin in app.json
### Scenario 11: Expo + no navigation library — PulseService has no useNavigationTracking
- ✅ PulseService created
- ✅ start() present in no-nav PulseService
- ✅ No useNavigationTracking in no-nav wrapper
### Scenario 12: Expo + src/services/ exists — PulseService placed in src/services/
- ✅ PulseService placed in src/services/
### Scenario 13: Expo + .pulse/learnings.md exists — project memory loaded, no double-setup
- ✅ Only one PulseService file — no duplicate created
### Scenario 14: Bare RN — package installed, no Pulse.start → skip native steps, wire JS
- ✅ PulseService created
- ✅ PulseService.start wired in App.tsx
### Scenario 15: Bare RN + minSdkVersion < 26 — coreLibraryDesugaring added to build.gradle
- ✅ coreLibraryDesugaringEnabled added to build.gradle
- ✅ coreLibraryDesugaring dep added
### Scenario 16: Bare RN + yarn.lock — package manager detected as yarn
- ✅ PulseService created
- ✅ .pulse/learnings.md created
- ✅ learnings.md records yarn package manager
### Scenario 17: Bare RN + @react-navigation/native — PulseService includes useNavigationTracking
- ✅ PulseService created
- ✅ useNavigationTracking in PulseService
- ✅ onReady wired in NavigationContainer file
### Scenario 18: Bare RN + react-native-navigation (Wix) — nav tracking skipped
- ✅ PulseService created
- ✅ No useNavigationTracking for Wix nav
- ✅ start() present in Wix nav wrapper
### Scenario 19: Bare RN + no tsconfig — PulseService created as .js
- ✅ PulseService created as .js (correct for JS-only bare RN project)
### Scenario 20: Bare RN + Objective-C AppDelegate.m — ObjC init pattern used
- ✅ ObjC header imported in AppDelegate.m
- ✅ PulseService created
### Scenario 21: Expo Router detected — fragment and screenLifecycle instrumentation disabled
- ✅ fragment instrumentation disabled in plugin config
- ✅ screenLifecycle instrumentation disabled in plugin config
- ✅ Plugin added to app.json

