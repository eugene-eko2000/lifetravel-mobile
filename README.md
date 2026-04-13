# LifeTravel Mobile

Flutter mobile client for the LifeTravel AI travel assistant. Provides the same chat-driven trip planning experience as the web application, optimized for Android and iOS devices.

## Overview

The app connects to the LifeTravel backend via WebSocket and lets users describe travel plans in natural language. The server responds with structured itineraries containing ranked flight and hotel options that users can browse, reorder, and inspect in detail.

### Key Features

- **Chat interface** — free-form text input with real-time streaming responses
- **Ranked trip cards** — itineraries with sortable flight and hotel options
- **Drag-and-drop reordering** — reprioritize flight/hotel options; totals recompute automatically
- **Trip modal** — full-screen detailed view of any itinerary
- **Debug panel** — bottom-sheet overlay showing raw server messages
- **Dark theme** — matches the web application's visual design

### Project Structure

```
lib/
├── main.dart                  # App entry point, environment config
├── theme.dart                 # Colors and ThemeData
├── models/
│   └── message.dart           # Message, TripBlock, DebugEntry
├── screens/
│   └── chat_screen.dart       # Main chat UI, WebSocket orchestration
├── services/
│   └── websocket_service.dart # WebSocket connection management
├── utils/
│   ├── trip_helpers.dart      # JSON extraction utilities
│   ├── trip_formatting.dart   # Flight/hotel display formatting
│   └── trip_ranked_model.dart # Ranking, sorting, total recomputation
└── widgets/
    ├── trip_card.dart         # Trip type dispatcher (simple / ranked)
    ├── ranked_trip_card.dart  # Full ranked itinerary with legs
    ├── trip_flights.dart      # Flight options with segments
    ├── trip_hotels.dart       # Hotel options with room details
    ├── dual_price_display.dart# Multi-currency price display
    └── json_viewer.dart       # Collapsible JSON tree viewer
```

## Prerequisites

- **Flutter SDK** >= 3.8.0 (stable channel)
- **Dart SDK** >= 3.8.0 (bundled with Flutter)
- **Android Studio** with Android SDK 35 and an emulator configured
- **Xcode** >= 15 (macOS only, for iOS builds)
- **CocoaPods** (macOS only, installed via `sudo gem install cocoapods`)

Verify your setup:

```bash
flutter doctor
```

## Getting Started

```bash
cd lifetravel-mobile
flutter pub get
```

## Configuration

The following Dart defines are available at compile time:

| Define | Default | Description |
|---|---|---|
| `WS_BASE_URL` | `wss://api.lifetravel.ai` | WebSocket backend URL |
| `APP_MODE` | `prod` | `dev` enables the debug panel; `prod` hides it |

To override them (e.g. for local development):

```bash
flutter run --dart-define=WS_BASE_URL=ws://10.0.2.2:8080 --dart-define=APP_MODE=dev   # Android emulator
flutter run --dart-define=WS_BASE_URL=ws://localhost:8080 --dart-define=APP_MODE=dev    # iOS simulator
```

> **Note:** Android emulators access the host machine at `10.0.2.2`, not `localhost`.

## Development — Android Emulator

1. **Start an emulator** from Android Studio (`Tools > Device Manager > ▶`) or via CLI:

   ```bash
   flutter emulators --launch <emulator_id>
   ```

   List available emulators with `flutter emulators`.

2. **Run the app:**

   ```bash
   flutter run
   ```

   If multiple devices are connected, specify the target:

   ```bash
   flutter run -d emulator-5554
   ```

3. **Hot reload** — press `r` in the terminal.  
   **Hot restart** — press `R`.

## Development — iOS Simulator

> Requires macOS with Xcode installed.

1. **Open a simulator:**

   ```bash
   open -a Simulator
   ```

   Or launch from Xcode (`Xcode > Open Developer Tool > Simulator`).

2. **Run the app:**

   ```bash
   flutter run
   ```

   Target a specific simulator:

   ```bash
   flutter run -d "iPhone 16"
   ```

3. **Hot reload / restart** — same as Android (`r` / `R`).

## Building for Android

### Debug APK

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

Install on a connected device:

```bash
flutter install
```

### Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (for Google Play)

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### With Custom Configuration

```bash
flutter build apk --release --dart-define=WS_BASE_URL=wss://custom.api.host --dart-define=APP_MODE=dev
```

### Release Signing

The current config uses debug signing keys. For production, create a keystore and configure `android/app/build.gradle.kts`:

1. Generate a keystore:

   ```bash
   keytool -genkey -v -keystore ~/lifetravel-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias lifetravel
   ```

2. Create `android/key.properties`:

   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=lifetravel
   storeFile=/path/to/lifetravel-release.jks
   ```

3. Reference it in `build.gradle.kts` under the `release` build type.

## Building for iOS

> Requires macOS with Xcode.

### Debug Build (no code signing)

```bash
flutter build ios --debug --no-codesign
```

### Release Build

```bash
flutter build ios --release
```

This produces a `.app` bundle in `build/ios/iphoneos/`.

### Archive for App Store / TestFlight

1. Open the Xcode workspace:

   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select **Product > Archive**.
3. In the Organizer, click **Distribute App** and follow the prompts.

### Code Signing

iOS release builds require an Apple Developer account. In Xcode:

1. Open `Runner.xcworkspace`
2. Select the **Runner** target > **Signing & Capabilities**
3. Choose your Team and let Xcode manage signing automatically

## Running Tests

```bash
flutter test
```

## Static Analysis

```bash
flutter analyze
```

## Package Info

| Property | Value |
|---|---|
| Package name | `lifetravel_mobile` |
| Android application ID | `ai.lifetravel.lifetravel_mobile` |
| iOS bundle identifier | `ai.lifetravel.lifetravelMobile` |
| Min Android SDK | Flutter default (21) |
| Target Android SDK | Flutter default (35) |
