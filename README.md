<p align="center"><img src="assets/icon.png" width="96" alt="Moon Locator icon"></p>

<h1 align="center">Moon Locator</h1>

<p align="center">Point your phone at the sky and find the moon. Move the time slider to see when you can see it.</p>

<p align="center">
  <a href="https://github.com/its-ash/moon-locator/releases/latest/download/moon-locator.apk"><b>⬇ Download APK</b></a> ·
  <a href="https://github.com/its-ash/moon-locator/releases">All releases</a>
</p>

## Features

- **Camera view**: the live camera shows the moon position, the horizon, and compass points.
- **Pointer**: when the moon is off screen, an arrow shows where to turn.
- **Heading strip**: shows your phone heading and how far to turn (left, right, up, down).
- **Time slider**: move from 12 hours back to 48 hours ahead. Tap the date to go to any day.
- **Altitude chart**: shows the moon height over time on day, twilight, and night colors.
- **Moonrise, moonset, best view**: tap a tile to jump to that time.
- **Phase**: realistic moon image with phase, percent lit, and distance.
- **Offline**: all calculations run on the phone. No network is necessary.

## How it works

| Part | Method |
|---|---|
| Moon and sun position | SunCalc algorithm (`lib/astro.dart`) |
| Phone direction | Accelerometer and magnetometer (`lib/orientation.dart`) |
| Projection | Pinhole camera model, portrait, `kCamVFov = 62°` (`lib/sky_painter.dart`) |
| Location | GPS through `geolocator` |

> The compass gives magnetic north. The app does not correct for magnetic declination. Move the phone in a figure 8 to calibrate the compass.

## Permissions

- **Camera**: to show the sky.
- **Location**: to calculate the moon position for your place.

## Development

Requirements: Flutter 3.44 or newer, Android SDK or Xcode.

```sh
make run     # run on a connected device
make build   # build a release APK to build/moon-locator.apk
make deploy  # build, commit, push to main, tag the next version, and make a GitHub release
```

`make deploy` finds the latest `vX.Y.Z` tag and increments the patch number (for example `v1.0.4` → `v1.0.5`). It needs the `gh` CLI with a login.

## Project layout

```
lib/
  main.dart          app entry, portrait lock
  home.dart          screen, camera, location, time controls
  astro.dart         moon and sun math
  orientation.dart   sensor fusion
  sky_painter.dart   camera overlay
  moon_art.dart      moon image renderer
  heading_tape.dart  compass strip
  timeline.dart      altitude chart
index.html           project web page
```
