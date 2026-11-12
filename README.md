# Moon Locator

Point your phone at the sky and find the moon. Slide through time to see when you can see it.

**[Website](https://moon-locator.itsash.in)** · **[Download APK](https://github.com/its-ash/moon-locator/releases/latest/download/moon-locator.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Camera view**: the live camera shows the moon position, the horizon, and compass points.
- **Pointer**: when the moon is off screen, an arrow shows where to turn.
- **Heading strip**: shows your phone heading and how far to turn (left, right, up, down).
- **Time slider**: move from 12 hours back to 48 hours ahead. Tap the date to go to any day.
- **Altitude chart**: shows the moon height over time on day, twilight, and night colors.
- **Moonrise, moonset, best view**: tap a tile to jump to that time.
- **Phase**: realistic moon image with phase, percent lit, and distance.
- **Offline**: all calculations run on the phone. The internet is used only to check for app updates.

How it works: moon and sun positions use the SunCalc algorithm (`lib/astro.dart`), the phone
direction comes from the accelerometer and magnetometer (`lib/orientation.dart`), and the overlay
uses a portrait pinhole camera model with `kCamVFov = 62°` (`lib/sky_painter.dart`). The compass
gives magnetic north, without declination correction; move the phone in a figure 8 to calibrate it.

Permissions: **Camera** to show the sky, **Location** to compute the moon position for your place.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Moon Locator from it.
- **APK**: download the [latest APK](https://github.com/its-ash/moon-locator/releases/latest/download/moon-locator.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 7.0 or newer (Flutter's default minimum).

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make test     # flutter analyze
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `moon-locator.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
  main.dart             app entry (UiApp), portrait lock
  home.dart             screen, camera, location, time controls
  settings_screen.dart  settings: appearance, updates, developer
  astro.dart            moon and sun math
  orientation.dart      sensor fusion
  sky_painter.dart      camera overlay
  moon_art.dart         moon image renderer
  heading_tape.dart     compass strip
  timeline.dart         altitude chart
assets/icon/            two-color pixel-art app icon (SVG sources + 1024 px PNGs)
index.html              landing page (moon-locator.itsash.in)
store.json              Ash Store manifest
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
