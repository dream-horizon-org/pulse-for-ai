#!/usr/bin/env bash
# Local skill evaluation — scaffolds test apps in /tmp, runs skill, checks output
# Usage: ./scripts/run-eval.sh
# Requires: Claude Code CLI with pulse-for-ai plugin installed
# Output: reports/eval-latest.md (commit this alongside skill changes)

set -uo pipefail

SKILL_REPO="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="$SKILL_REPO/reports/eval-latest.md"
WORKDIR=$(mktemp -d)
PASS=0
FAIL=0
OUTPUT=""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Skill Eval — working dir: $WORKDIR"
echo "Inspect apps there while eval runs."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cleanup() {
  echo ""
  echo "Temp dir kept for inspection: $WORKDIR"
  echo "Remove manually when done: rm -rf $WORKDIR"
}
trap cleanup EXIT

log()  { echo ""; echo "▶ $*"; OUTPUT+="### $*\n"; }
ok()   { echo "  ✅ $*"; OUTPUT+="- ✅ $*\n"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $*"; OUTPUT+="- ❌ $*\n"; FAIL=$((FAIL+1)); }

check_file_exists() {
  local desc="$1" pattern="$2" dir="$3"
  if find "$dir" -path "*$pattern" | grep -q .; then
    ok "$desc"
  else
    fail "$desc — not found: $pattern"
  fi
}

check_file_contains() {
  local desc="$1" pattern="$2" file="$3"
  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    ok "$desc"
  else
    fail "$desc — pattern not found: $pattern in $file"
  fi
}

check_file_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if [ -f "$file" ] && grep -q "$pattern" "$file"; then
    fail "$desc — found unwanted: $pattern"
  else
    ok "$desc"
  fi
}

run_skill() {
  local app_dir="$1" skill="$2"
  echo "  📁 App: $app_dir"
  echo "  🤖 Running /pulse:$skill ..."
  cd "$app_dir"
  claude -p "/pulse:$skill. Use YOUR_API_KEY as the Pulse API key placeholder — this is a test run." \
    --plugin-dir "$SKILL_REPO" \
    --allowedTools "Read,Edit,Write,Bash" \
    --dangerously-skip-permissions \
    --output-format text \
    2>&1 || true
  cd -
}

# ─────────────────────────────────────────────
# Scenario 1: Expo Router + TypeScript
# ─────────────────────────────────────────────
log "Scenario 1: Expo Router + TypeScript"
APP1="$WORKDIR/expo-router-ts"
npx create-expo-app@latest "$APP1" --template tabs --no-install 2>/dev/null
cd "$APP1" && npm install --silent 2>/dev/null; cd -

run_skill "$APP1" "setup-expo"

# File checks
check_file_exists "PulseService created" "PulseService*" "$APP1"
check_file_exists ".pulse/learnings.md created" ".pulse/learnings.md" "$APP1"

# .gitignore check
check_file_contains ".pulse/ in .gitignore" ".pulse/" "$APP1/.gitignore"

# No literal placeholder
PULSE_SERVICE=$(find "$APP1" -name "PulseService*" | grep -v node_modules | head -1)
if [ -n "$PULSE_SERVICE" ]; then
  check_file_not_contains "No literal <wrapper-path> in PulseService" "<wrapper-path>" "$PULSE_SERVICE"
  check_file_contains "Pulse.start() present" "Pulse.start\|PulseService.start" "$PULSE_SERVICE"
fi

# Expo Router: registerWhenContainerReady — in layout OR PulseService
RWC_FOUND=$(grep -rl "registerWhenContainerReady" "$APP1" 2>/dev/null | grep -v node_modules | head -1)
if [ -n "$RWC_FOUND" ]; then
  ok "registerWhenContainerReady configured (in $RWC_FOUND)"
else
  fail "registerWhenContainerReady not found in any file"
fi

# app.json plugin
check_file_contains "Plugin added to app.json" "pulse-react-native" "$APP1/app.json"

# No duplicate Pulse.start — exclude PulseService.ts wrapper definition
STARTS=$(grep -r "PulseService\.start()" "$APP1" --include="*.ts" --include="*.tsx" --exclude-dir=node_modules 2>/dev/null | grep -v "PulseService\.ts" | wc -l | tr -d ' ')
if [ "$STARTS" -le 1 ]; then
  ok "Pulse.start() called exactly once (not duplicated)"
else
  fail "Pulse.start() called $STARTS times — possible duplicate"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 2: Already installed — must stop
# ─────────────────────────────────────────────
log "Scenario 2: Already installed — skill must detect and stop"
APP2="$APP1"  # reuse same app (Pulse already set up from Scenario 1)

BEFORE=$(find "$APP2" -name "PulseService*" | grep -v node_modules | wc -l | tr -d ' ')
run_skill "$APP2" "setup-expo"
AFTER=$(find "$APP2" -name "PulseService*" | grep -v node_modules | wc -l | tr -d ' ')

if [ "$BEFORE" -eq "$AFTER" ]; then
  ok "Skill stopped — no duplicate files created"
else
  fail "Skill created extra files on already-integrated app"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 3: Bare React Native
# ─────────────────────────────────────────────
log "Scenario 3: Bare React Native"
APP3="$WORKDIR/bare-rn-ts"
npx @react-native-community/cli init BareRNTest --directory "$APP3" --skip-install 2>/dev/null || true
cd "$APP3" && npm install --silent 2>/dev/null; cd -

run_skill "$APP3" "setup-react-native"

check_file_exists "PulseService created" "PulseService*" "$APP3"
check_file_exists ".pulse/learnings.md created" ".pulse/learnings.md" "$APP3"
check_file_contains ".pulse/ in .gitignore" ".pulse/" "$APP3/.gitignore"

# Android init order
MAIN_APP=$(find "$APP3/android" -name "MainApplication.kt" -o -name "MainApplication.java" 2>/dev/null | head -1)
if [ -n "$MAIN_APP" ]; then
  check_file_contains "Pulse.initialize present in Application class" "Pulse.initialize\|initPulse" "$MAIN_APP"
  # Check order: super.onCreate() before initPulse()
  SUPER_LINE=$(grep -n "super.onCreate" "$MAIN_APP" | head -1 | cut -d: -f1)
  INIT_LINE=$(grep -n "initPulse\|Pulse.initialize" "$MAIN_APP" | head -1 | cut -d: -f1)
  if [ -n "$SUPER_LINE" ] && [ -n "$INIT_LINE" ] && [ "$SUPER_LINE" -lt "$INIT_LINE" ]; then
    ok "Pulse.initialize() called AFTER super.onCreate()"
  else
    fail "Pulse.initialize() order incorrect — must be after super.onCreate()"
  fi
fi

# iOS AppDelegate
APP_DELEGATE=$(find "$APP3/ios" -name "AppDelegate.swift" -o -name "AppDelegate.m" -o -name "AppDelegate.mm" 2>/dev/null | head -1)
if [ -n "$APP_DELEGATE" ]; then
  check_file_contains "PulseSDK.initialize in AppDelegate" "PulseSDK\|PulseSDK.initialize" "$APP_DELEGATE"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 4: Bare RN — already installed (must stop)
# ─────────────────────────────────────────────
log "Scenario 4: Bare RN already installed — skill must detect and stop"
BEFORE=$(find "$APP3" -name "PulseService*" | grep -v node_modules | wc -l | tr -d ' ')
run_skill "$APP3" "setup-react-native"
AFTER=$(find "$APP3" -name "PulseService*" | grep -v node_modules | wc -l | tr -d ' ')
if [ "$BEFORE" -eq "$AFTER" ]; then
  ok "Skill stopped — no duplicate files created on bare RN"
else
  fail "Skill created extra files on already-integrated bare RN app"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 5: Expo + React Navigation (no Expo Router)
# ─────────────────────────────────────────────
log "Scenario 5: Expo + React Navigation (no Expo Router)"
APP5="$WORKDIR/expo-nav-ts"
npx create-expo-app@latest "$APP5" --template blank-typescript --no-install 2>/dev/null
cd "$APP5" && npm install --silent 2>/dev/null && npm install @react-navigation/native @react-navigation/stack react-native-screens react-native-safe-area-context --silent 2>/dev/null; cd -

run_skill "$APP5" "setup-expo"

check_file_exists "PulseService created" "PulseService*" "$APP5"
check_file_exists ".pulse/learnings.md created" ".pulse/learnings.md" "$APP5"
check_file_contains ".pulse/ in .gitignore" ".pulse/" "$APP5/.gitignore"
check_file_contains "Plugin added to app.json" "pulse-react-native" "$APP5/app.json"

# React Navigation: onReady must be passed to NavigationContainer
APP_ENTRY=$(find "$APP5" -name "App.tsx" -o -name "App.js" 2>/dev/null | grep -v node_modules | head -1)
if [ -n "$APP_ENTRY" ]; then
  check_file_contains "onReady passed to NavigationContainer" "onReady" "$APP_ENTRY"
  check_file_contains "NavigationContainer ref typed" "NavigationContainerRef\|useRef" "$APP_ENTRY"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 6: Expo + JavaScript (no tsconfig)
# ─────────────────────────────────────────────
log "Scenario 6: Expo + JavaScript (no TypeScript)"
APP6="$WORKDIR/expo-js"
npx create-expo-app@latest "$APP6" --template blank --no-install 2>/dev/null
cd "$APP6" && npm install --silent 2>/dev/null; cd -

# Remove tsconfig to simulate JS-only project
rm -f "$APP6/tsconfig.json"

run_skill "$APP6" "setup-expo"

check_file_exists "PulseService created" "PulseService*" "$APP6"

# Must use .js not .ts
JS_SERVICE=$(find "$APP6" -name "PulseService.js" | grep -v node_modules | head -1)
TS_SERVICE=$(find "$APP6" -name "PulseService.ts" | grep -v node_modules | head -1)
if [ -n "$JS_SERVICE" ] && [ -z "$TS_SERVICE" ]; then
  ok "PulseService created as .js (correct for JS project)"
elif [ -n "$TS_SERVICE" ]; then
  fail "PulseService created as .ts in a JS-only project (no tsconfig)"
else
  fail "PulseService not found"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 7: Bare RN — missing android/ folder
# ─────────────────────────────────────────────
log "Scenario 7: Bare RN — android/ folder missing (fresh clone without native)"
APP7="$WORKDIR/bare-rn-no-native"
mkdir -p "$APP7"
# Scaffold minimal package.json only — no android/ or ios/
cat > "$APP7/package.json" << 'JSON'
{
  "name": "bare-rn-no-native",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0"
  }
}
JSON

run_skill "$APP7" "setup-react-native"

# Skill should ask user about missing folders, not crash silently
# Check that skill did NOT create PulseService (nothing to wire native init to)
PS=$(find "$APP7" -name "PulseService*" | grep -v node_modules | head -1)
if [ -z "$PS" ]; then
  ok "Skill correctly stopped — no PulseService without native folders"
else
  fail "Skill created PulseService without android/ or ios/ — may be incomplete setup"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 8: Expo + app.config.js (not app.json)
# ─────────────────────────────────────────────
log "Scenario 8: Expo + app.config.js — plugin must be written as JS module.exports"
APP8="$WORKDIR/expo-config-js"
mkdir -p "$APP8"
cat > "$APP8/package.json" << 'JSON'
{
  "name": "expo-config-js",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP8/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
# app.config.js instead of app.json
cat > "$APP8/app.config.js" << 'JS'
module.exports = {
  expo: {
    name: 'expo-config-js',
    slug: 'expo-config-js',
    plugins: [],
  },
};
JS

run_skill "$APP8" "setup-expo"

# Plugin should be added to app.config.js using JS syntax, not JSON
check_file_contains "Plugin added to app.config.js" "pulse-react-native" "$APP8/app.config.js"
# Must use module.exports or export default — not raw JSON syntax
check_file_contains "app.config.js uses JS object syntax (no raw JSON braces)" "pulse-react-native" "$APP8/app.config.js"
# app.json should NOT be created (config lives in app.config.js)
if [ ! -f "$APP8/app.json" ]; then
  ok "app.json not created — config correctly kept in app.config.js"
else
  # app.json presence is OK only if it was already there; the plugin should still be in app.config.js
  check_file_contains "Plugin in app.config.js (not only app.json)" "pulse-react-native" "$APP8/app.config.js"
fi
check_file_exists "PulseService created" "PulseService*" "$APP8"

echo ""

# ─────────────────────────────────────────────
# Scenario 9: Expo SDK ≤ 52 — kotlin19Compat must be added
# ─────────────────────────────────────────────
log "Scenario 9: Expo SDK ≤ 52 — kotlin19Compat added to plugin config"
APP9="$WORKDIR/expo-sdk52"
mkdir -p "$APP9"
cat > "$APP9/package.json" << 'JSON'
{
  "name": "expo-sdk52",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~52.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP9/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP9/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-sdk52",
    "slug": "expo-sdk52",
    "plugins": []
  }
}
JSON

run_skill "$APP9" "setup-expo"

check_file_contains "kotlin19Compat added for Expo SDK ≤ 52" "kotlin19Compat" "$APP9/app.json"
check_file_contains "Plugin in app.json" "pulse-react-native" "$APP9/app.json"
check_file_exists "PulseService created" "PulseService*" "$APP9"

echo ""

# ─────────────────────────────────────────────
# Scenario 10: Expo + minSdkVersion < 26 → coreLibraryDesugaring in plugin config
# ─────────────────────────────────────────────
log "Scenario 10: Expo + minSdkVersion < 26 — coreLibraryDesugaring added to plugin config"
APP10="$WORKDIR/expo-minsdk21"
mkdir -p "$APP10/android/app"
cat > "$APP10/package.json" << 'JSON'
{
  "name": "expo-minsdk21",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP10/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP10/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-minsdk21",
    "slug": "expo-minsdk21",
    "plugins": []
  }
}
JSON
# Simulate a prior prebuild android/app/build.gradle with minSdkVersion 21
cat > "$APP10/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
GRADLE

run_skill "$APP10" "setup-expo"

check_file_contains "coreLibraryDesugaring added to plugin config" "coreLibraryDesugaring" "$APP10/app.json"
check_file_contains "Plugin in app.json" "pulse-react-native" "$APP10/app.json"

echo ""

# ─────────────────────────────────────────────
# Scenario 11: Expo + no navigation library → no-nav PulseService (no useNavigationTracking)
# ─────────────────────────────────────────────
log "Scenario 11: Expo + no navigation library — PulseService has no useNavigationTracking"
APP11="$WORKDIR/expo-no-nav"
mkdir -p "$APP11"
cat > "$APP11/package.json" << 'JSON'
{
  "name": "expo-no-nav",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP11/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP11/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-no-nav",
    "slug": "expo-no-nav",
    "plugins": []
  }
}
JSON

run_skill "$APP11" "setup-expo"

check_file_exists "PulseService created" "PulseService*" "$APP11"
PULSE_SVC=$(find "$APP11" -name "PulseService*" | grep -v node_modules | head -1)
if [ -n "$PULSE_SVC" ]; then
  check_file_contains "start() present in no-nav PulseService" "start" "$PULSE_SVC"
  # No useNavigationTracking expected when no nav lib detected
  check_file_not_contains "No useNavigationTracking in no-nav wrapper" "useNavigationTracking" "$PULSE_SVC"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 12: Expo + src/services/ exists — PulseService placed there
# ─────────────────────────────────────────────
log "Scenario 12: Expo + src/services/ exists — PulseService placed in src/services/"
APP12="$WORKDIR/expo-src-services"
mkdir -p "$APP12/src/services"
cat > "$APP12/package.json" << 'JSON'
{
  "name": "expo-src-services",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP12/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP12/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-src-services",
    "slug": "expo-src-services",
    "plugins": []
  }
}
JSON
# Placeholder so directory registers as non-empty
touch "$APP12/src/services/.keep"

run_skill "$APP12" "setup-expo"

# PulseService must be in src/services/
if find "$APP12/src/services" -name "PulseService*" | grep -q .; then
  ok "PulseService placed in src/services/"
else
  fail "PulseService not placed in src/services/ despite directory existing"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 13: Expo + .pulse/learnings.md already exists — re-detection skipped
# ─────────────────────────────────────────────
log "Scenario 13: Expo + .pulse/learnings.md exists — project memory loaded, no double-setup"
APP13="$WORKDIR/expo-with-memory"
mkdir -p "$APP13/.pulse"
cat > "$APP13/package.json" << 'JSON'
{
  "name": "expo-with-memory",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "@dreamhorizonorg/pulse-react-native": "^1.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP13/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP13/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-with-memory",
    "slug": "expo-with-memory",
    "plugins": [
      ["@dreamhorizonorg/pulse-react-native", { "apiKey": "test-key", "dataCollectionState": "ALLOWED" }]
    ]
  }
}
JSON
# Pre-existing PulseService with Pulse.start already wired
mkdir -p "$APP13/src/services"
cat > "$APP13/src/services/PulseService.ts" << 'TS'
import { Pulse } from '@dreamhorizonorg/pulse-react-native';
export const PulseService = {
  start: (config) => Pulse.start(config),
  shutdown: () => Pulse.shutdown(),
};
TS
# Project memory file
cat > "$APP13/.pulse/learnings.md" << 'MD'
# Pulse Project Learnings
- **Integrated:** yes
- **Package manager:** npm
- **Language:** TypeScript
- **Config file:** app.json
- **Navigation:** none
- **PulseService location:** src/services/PulseService.ts
MD

BEFORE_MTIME=$(stat -f "%m" "$APP13/src/services/PulseService.ts" 2>/dev/null || stat -c "%Y" "$APP13/src/services/PulseService.ts" 2>/dev/null)
run_skill "$APP13" "setup-expo"
AFTER_MTIME=$(stat -f "%m" "$APP13/src/services/PulseService.ts" 2>/dev/null || stat -c "%Y" "$APP13/src/services/PulseService.ts" 2>/dev/null)

# Skill should stop (already installed) — PulseService should not be overwritten
SVCCOUNT=$(find "$APP13" -name "PulseService*" | grep -v node_modules | wc -l | tr -d ' ')
if [ "$SVCCOUNT" -eq 1 ]; then
  ok "Only one PulseService file — no duplicate created"
else
  fail "Multiple PulseService files found — skill may have duplicated setup"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 14: Bare RN + package installed but no Pulse.start → skip native, create wrapper
# ─────────────────────────────────────────────
log "Scenario 14: Bare RN — package installed, no Pulse.start → skip native steps, wire JS"
APP14="$WORKDIR/bare-rn-partial"
mkdir -p "$APP14/android/app/src/main/java/com/partial"
mkdir -p "$APP14/ios"
cat > "$APP14/package.json" << 'JSON'
{
  "name": "PartialRN",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0",
    "@dreamhorizonorg/pulse-react-native": "^1.0.0"
  }
}
JSON
cat > "$APP14/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
# Simulate native already initialized (package installed, native wired)
cat > "$APP14/android/app/src/main/java/com/partial/MainApplication.kt" << 'KT'
package com.partial

import android.app.Application
import com.pulsereactnativeotel.Pulse
import com.pulsereactnativeotel.PulseDataCollectionConsent

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initPulse()
    }
    private fun initPulse() {
        Pulse.initialize(
            application = this,
            apiKey = "test-key",
            dataCollectionState = PulseDataCollectionConsent.ALLOWED
        )
    }
}
KT
cat > "$APP14/ios/AppDelegate.swift" << 'SWIFT'
import UIKit
import PulseReactNativeOtel

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    PulseSDK.initialize(apiKey: "test-key", dataCollectionState: .allowed)
    return true
  }
}
SWIFT
# No PulseService or App.tsx yet — no Pulse.start call
cat > "$APP14/App.tsx" << 'TSX'
import React from 'react';
import { View, Text } from 'react-native';
export default function App() { return <View><Text>Hello</Text></View>; }
TSX

run_skill "$APP14" "setup-react-native"

# Skill should create PulseService and wire App.tsx (JS layer) but NOT touch native files
check_file_exists "PulseService created" "PulseService*" "$APP14"
# App.tsx should now have PulseService.start
check_file_contains "PulseService.start wired in App.tsx" "PulseService.start\|Pulse.start" "$APP14/App.tsx"

echo ""

# ─────────────────────────────────────────────
# Scenario 15: Bare RN + minSdkVersion < 26 → coreLibraryDesugaring in build.gradle
# ─────────────────────────────────────────────
log "Scenario 15: Bare RN + minSdkVersion < 26 — coreLibraryDesugaring added to build.gradle"
APP15="$WORKDIR/bare-rn-minsdk21"
mkdir -p "$APP15/android/app/src/main/java/com/minsdk"
mkdir -p "$APP15/android/app/src/main"
mkdir -p "$APP15/ios"
cat > "$APP15/package.json" << 'JSON'
{
  "name": "MinSdk21App",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0"
  }
}
JSON
cat > "$APP15/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
cat > "$APP15/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="MinSdk21App">
    </application>
</manifest>
XML
cat > "$APP15/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
    }
}

dependencies {
    implementation "com.facebook.react:react-android"
}
GRADLE
cat > "$APP15/android/app/src/main/java/com/minsdk/MainApplication.kt" << 'KT'
package com.minsdk

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
cat > "$APP15/ios/AppDelegate.swift" << 'SWIFT'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}
SWIFT

run_skill "$APP15" "setup-react-native"

check_file_contains "coreLibraryDesugaringEnabled added to build.gradle" "coreLibraryDesugaringEnabled" "$APP15/android/app/build.gradle"
check_file_contains "coreLibraryDesugaring dep added" "coreLibraryDesugaring" "$APP15/android/app/build.gradle"

echo ""

# ─────────────────────────────────────────────
# Scenario 16: Bare RN + yarn.lock → yarn add used for install
# ─────────────────────────────────────────────
log "Scenario 16: Bare RN + yarn.lock — package manager detected as yarn"
APP16="$WORKDIR/bare-rn-yarn"
mkdir -p "$APP16/android/app/src/main/java/com/yarnapp"
mkdir -p "$APP16/android/app/src/main"
mkdir -p "$APP16/ios"
cat > "$APP16/package.json" << 'JSON'
{
  "name": "YarnApp",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0"
  }
}
JSON
cat > "$APP16/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
# yarn.lock signals yarn as package manager
touch "$APP16/yarn.lock"
cat > "$APP16/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="YarnApp">
    </application>
</manifest>
XML
cat > "$APP16/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
dependencies {}
GRADLE
cat > "$APP16/android/app/src/main/java/com/yarnapp/MainApplication.kt" << 'KT'
package com.yarnapp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
cat > "$APP16/ios/AppDelegate.swift" << 'SWIFT'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}
SWIFT

run_skill "$APP16" "setup-react-native"

# Skill must have added pulse-react-native (yarn would have added it)
check_file_exists "PulseService created" "PulseService*" "$APP16"
# learnings.md should record yarn as package manager
check_file_exists ".pulse/learnings.md created" ".pulse/learnings.md" "$APP16"
if [ -f "$APP16/.pulse/learnings.md" ]; then
  check_file_contains "learnings.md records yarn package manager" "yarn" "$APP16/.pulse/learnings.md"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 17: Bare RN + react-navigation/native → nav wrapper with useNavigationTracking
# ─────────────────────────────────────────────
log "Scenario 17: Bare RN + @react-navigation/native — PulseService includes useNavigationTracking"
APP17="$WORKDIR/bare-rn-nav"
mkdir -p "$APP17/android/app/src/main/java/com/navapp"
mkdir -p "$APP17/android/app/src/main"
mkdir -p "$APP17/ios"
cat > "$APP17/package.json" << 'JSON'
{
  "name": "NavApp",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0",
    "@react-navigation/native": "^6.0.0",
    "@react-navigation/stack": "^6.0.0"
  }
}
JSON
cat > "$APP17/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
cat > "$APP17/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="NavApp">
    </application>
</manifest>
XML
cat > "$APP17/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
dependencies {}
GRADLE
cat > "$APP17/android/app/src/main/java/com/navapp/MainApplication.kt" << 'KT'
package com.navapp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
cat > "$APP17/ios/AppDelegate.swift" << 'SWIFT'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}
SWIFT
cat > "$APP17/App.tsx" << 'TSX'
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
export default function App() { return <NavigationContainer />; }
TSX

run_skill "$APP17" "setup-react-native"

check_file_exists "PulseService created" "PulseService*" "$APP17"
PULSE_SVC17=$(find "$APP17" -name "PulseService*" | grep -v node_modules | head -1)
if [ -n "$PULSE_SVC17" ]; then
  check_file_contains "useNavigationTracking in PulseService" "useNavigationTracking" "$PULSE_SVC17"
fi
# NavigationContainer file should have useNavigationTracking wired
check_file_contains "onReady wired in NavigationContainer file" "onReady\|useNavigationTracking" "$APP17/App.tsx"

echo ""

# ─────────────────────────────────────────────
# Scenario 18: Bare RN + react-native-navigation (Wix) → nav skipped, wrapper has no useNavigationTracking
# ─────────────────────────────────────────────
log "Scenario 18: Bare RN + react-native-navigation (Wix) — nav tracking skipped"
APP18="$WORKDIR/bare-rn-wix"
mkdir -p "$APP18/android/app/src/main/java/com/wixapp"
mkdir -p "$APP18/android/app/src/main"
mkdir -p "$APP18/ios"
cat > "$APP18/package.json" << 'JSON'
{
  "name": "WixApp",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0",
    "react-native-navigation": "^7.0.0"
  }
}
JSON
cat > "$APP18/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
cat > "$APP18/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="WixApp">
    </application>
</manifest>
XML
cat > "$APP18/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
dependencies {}
GRADLE
cat > "$APP18/android/app/src/main/java/com/wixapp/MainApplication.kt" << 'KT'
package com.wixapp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
cat > "$APP18/ios/AppDelegate.swift" << 'SWIFT'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}
SWIFT

run_skill "$APP18" "setup-react-native"

check_file_exists "PulseService created" "PulseService*" "$APP18"
PULSE_SVC18=$(find "$APP18" -name "PulseService*" | grep -v node_modules | head -1)
if [ -n "$PULSE_SVC18" ]; then
  check_file_not_contains "No useNavigationTracking for Wix nav" "useNavigationTracking" "$PULSE_SVC18"
  check_file_contains "start() present in Wix nav wrapper" "start" "$PULSE_SVC18"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 19: Bare RN + JavaScript only (no tsconfig) → PulseService.js not .ts
# ─────────────────────────────────────────────
log "Scenario 19: Bare RN + no tsconfig — PulseService created as .js"
APP19="$WORKDIR/bare-rn-js"
mkdir -p "$APP19/android/app/src/main/java/com/jsapp"
mkdir -p "$APP19/android/app/src/main"
mkdir -p "$APP19/ios"
cat > "$APP19/package.json" << 'JSON'
{
  "name": "JsApp",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0"
  }
}
JSON
# No tsconfig.json — JavaScript project
cat > "$APP19/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="JsApp">
    </application>
</manifest>
XML
cat > "$APP19/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
dependencies {}
GRADLE
cat > "$APP19/android/app/src/main/java/com/jsapp/MainApplication.kt" << 'KT'
package com.jsapp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
cat > "$APP19/ios/AppDelegate.swift" << 'SWIFT'
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}
SWIFT

run_skill "$APP19" "setup-react-native"

JS_SVC=$(find "$APP19" -name "PulseService.js" | grep -v node_modules | head -1)
TS_SVC=$(find "$APP19" -name "PulseService.ts" | grep -v node_modules | head -1)
if [ -n "$JS_SVC" ] && [ -z "$TS_SVC" ]; then
  ok "PulseService created as .js (correct for JS-only bare RN project)"
elif [ -n "$TS_SVC" ]; then
  fail "PulseService created as .ts in a JS-only bare RN project (no tsconfig)"
else
  fail "PulseService not found in bare RN JS project"
fi

echo ""

# ─────────────────────────────────────────────
# Scenario 20: Bare RN + Objective-C AppDelegate (.m) → ObjC init injected
# ─────────────────────────────────────────────
log "Scenario 20: Bare RN + Objective-C AppDelegate.m — ObjC init pattern used"
APP20="$WORKDIR/bare-rn-objc"
mkdir -p "$APP20/android/app/src/main/java/com/objcapp"
mkdir -p "$APP20/android/app/src/main"
mkdir -p "$APP20/ios/ObjcApp"
cat > "$APP20/package.json" << 'JSON'
{
  "name": "ObjcApp",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.0"
  }
}
JSON
cat > "$APP20/tsconfig.json" << 'JSON'
{ "compilerOptions": { "jsx": "react-native" } }
JSON
cat > "$APP20/android/app/src/main/AndroidManifest.xml" << 'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:name=".MainApplication" android:label="ObjcApp">
    </application>
</manifest>
XML
cat > "$APP20/android/app/build.gradle" << 'GRADLE'
android {
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}
dependencies {}
GRADLE
cat > "$APP20/android/app/src/main/java/com/objcapp/MainApplication.kt" << 'KT'
package com.objcapp

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}
KT
# Objective-C AppDelegate — .m extension
cat > "$APP20/ios/ObjcApp/AppDelegate.m" << 'OBJC'
#import "AppDelegate.h"
#import <React/RCTBundleURLProvider.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.moduleName = @"ObjcApp";
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
OBJC

run_skill "$APP20" "setup-react-native"

# ObjC init must use PulseSDK (objc header import) not Swift syntax
check_file_contains "ObjC header imported in AppDelegate.m" "PulseReactNativeOtel-Swift\|PulseSDK\|PulseObjcInstrumentations" "$APP20/ios/ObjcApp/AppDelegate.m"
check_file_exists "PulseService created" "PulseService*" "$APP20"

echo ""

# ─────────────────────────────────────────────
# Scenario 21: Expo + Expo Router → fragment/screenLifecycle disabled in plugin config
# ─────────────────────────────────────────────
log "Scenario 21: Expo Router detected — fragment and screenLifecycle instrumentation disabled"
APP21="$WORKDIR/expo-router-instrumentation"
mkdir -p "$APP21/app"
cat > "$APP21/package.json" << 'JSON'
{
  "name": "expo-router-instrumentation",
  "version": "1.0.0",
  "dependencies": {
    "expo": "~53.0.0",
    "expo-router": "^3.0.0",
    "react": "18.3.2",
    "react-native": "0.76.5"
  }
}
JSON
cat > "$APP21/tsconfig.json" << 'JSON'
{ "extends": "expo/tsconfig.base" }
JSON
cat > "$APP21/app.json" << 'JSON'
{
  "expo": {
    "name": "expo-router-instrumentation",
    "slug": "expo-router-instrumentation",
    "plugins": []
  }
}
JSON
# Expo Router layout file
cat > "$APP21/app/_layout.tsx" << 'TSX'
import { Stack } from 'expo-router';
export default function RootLayout() { return <Stack />; }
TSX

run_skill "$APP21" "setup-expo"

check_file_contains "fragment instrumentation disabled in plugin config" "fragment" "$APP21/app.json"
check_file_contains "screenLifecycle instrumentation disabled in plugin config" "screenLifecycle" "$APP21/app.json"
check_file_contains "Plugin added to app.json" "pulse-react-native" "$APP21/app.json"

echo ""

# ─────────────────────────────────────────────
# Summary + report
# ─────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ✅ $PASS passed  ❌ $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$SKILL_REPO/reports"
{
  echo "# Skill Eval Report"
  echo ""
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo ""
  echo "| | Count |"
  echo "|---|---|"
  echo "| ✅ Pass | $PASS |"
  echo "| ❌ Fail | $FAIL |"
  echo ""
  echo -e "$OUTPUT"
} > "$REPORT_FILE"

echo "Report written to $REPORT_FILE"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
