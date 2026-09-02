# Atelier Android apps

One Gradle build produces five Jetpack Compose applications for Android phone
and tablet. All apps require API 29 or newer.

## Build and test

Use the checked-in Gradle wrapper with JDK 17 or 21 and an Android SDK
containing API 37:

```sh
cd apps/android
./gradlew testDebugUnitTest
./gradlew :app-atelier:assembleDebug
./gradlew :app-notes:assembleDebug
./gradlew :app-mail:assembleDebug
./gradlew :app-calendar:assembleDebug
./gradlew :app-tasks:assembleDebug
```

The deterministic CI verification command is:

```sh
./gradlew --no-daemon --stacktrace testDebugUnitTest \
  :app-atelier:assembleDebug :app-notes:assembleDebug \
  :app-mail:assembleDebug :app-calendar:assembleDebug \
  :app-tasks:assembleDebug
```

Gradle, Android Gradle Plugin, Kotlin, Compose, and application dependency
versions are pinned in the wrapper and version catalog.
AGP provides built-in Kotlin support; do not apply the legacy Kotlin Android
plugin. The root build explicitly aligns its Kotlin compiler with the version
used by the Compose compiler plugin.
The Compose BOM requires compile SDK 37. Minimum SDK 29 and target SDK 35 remain
unchanged, so this build-time requirement does not opt apps into newer Android
runtime behavior or remove supported devices.

The visible content is supplied by `MockLocalWorkspaceRepository`. It is
explicitly local-only and does not claim that ATProto, provider, persistence,
or Iroh services are connected.

## Modules

- `core`, `contracts`, `persistence`, and `collaboration` contain platform
  contracts and boundaries.
- `design` provides the shared Compose theme.
- `editor` provides the native Compose Markdown surface and reducer.
- `app-ui` provides the adaptive phone/tablet shell used by every app.
- `app-*` modules contain only product identity, manifest, and packaging.
