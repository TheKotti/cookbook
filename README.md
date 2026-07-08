# Cookbook

A Flutter recipe manager: import recipes from URLs or JSON, browse and search
your collection, scale servings, tag/filter, and back up your data.

## Tech stack

- Flutter / Dart (Riverpod for state, Drift/sqflite for local storage)
- Android target `applicationId: dev.cookbook.app`

## Prerequisites

- Flutter SDK (this project was built and tested with Flutter 3.44.5). If
  Flutter isn't on your `PATH`, add it, e.g.:
  ```sh
  export PATH="$HOME/flutter/bin:$PATH"
  ```
- Android SDK + accepted licenses if you want to build/run for Android
  (`flutter doctor` will tell you what's missing).

## Setup

```sh
flutter pub get
```

Drift's generated database code (`lib/src/db/database.g.dart`) is checked in.
If you change `lib/src/db/database.dart`, regenerate it with:

```sh
dart run build_runner build --delete-conflicting-outputs
```

> **Note:** `sqlparser` is pinned to `>=0.44.0 <0.44.6` in `pubspec.yaml`
> because `drift_dev 2.34.0` depends on an API that later `sqlparser`
> versions removed, while newer `drift_dev` needs an `analyzer` version this
> Flutter's test tooling can't resolve. Revisit this pin after upgrading
> Flutter/Drift.

## Running the app

```sh
flutter run
```

Pick a connected device/emulator, or pass `-d <device-id>` (e.g. `-d chrome`,
`-d linux`, or an Android device/emulator id from `flutter devices`).

## Running tests

```sh
flutter test
```

Widget tests that touch Drift + Riverpod need a teardown flush after
`pumpWidget` to avoid a "pending timers" failure from Drift's stream-close
timer — see `flushTeardown` in `test/ui/recipe_list_screen_test.dart` for the
pattern to follow in new widget tests.

## Building for install

### Android APK

```sh
flutter clean   # always clean after touching plugin versions in pubspec.yaml
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Copy it
to a device and install it (enable "install from unknown sources" if
prompted), or install directly over adb:

```sh
flutter install
```

> **Gotcha:** Flutter's built-in-Kotlin migration can silently produce empty
> plugin AARs for plugins that still apply the Kotlin Gradle Plugin
> themselves, causing "cannot find symbol …Plugin" errors at compile time.
> This is why `file_picker` and `share_plus` are pinned to specific versions
> in `pubspec.yaml`. If you bump plugin versions and hit that error, run
> `flutter clean` before rebuilding.

### iOS

```sh
flutter build ios --release
```

Requires Xcode and a configured signing team in `ios/Runner.xcodeproj`.

## Project layout

- `lib/src/db/` — Drift database schema and generated code
- `lib/src/models/` — Recipe data models
- `lib/src/parser/` — Recipe/ingredient parsing and unit scaling
- `lib/src/import/` — URL and JSON recipe import
- `lib/src/backup/` — JSON backup export/import
- `lib/src/repository/` — Data access layer used by the UI
- `lib/src/ui/` — Screens (recipe list, detail, import, tag editor)
- `lib/src/share/` — Android share-target intent handling
- `test/` — mirrors the `lib/src` structure, plus `test/fixtures` for sample data

See [`DESIGN.md`](DESIGN.md) for the fuller design/architecture writeup.
