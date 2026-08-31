# Atelier Android apps

One Gradle build produces five Jetpack Compose applications for Android phone
and tablet. All apps require API 29 or newer.

## Build and test

Use the checked-in Gradle 8.12 wrapper with JDK 17 or 21 and an Android SDK
containing API 35:

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
