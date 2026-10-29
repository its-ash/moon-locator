# Moon Locator

Flutter app (Android, iOS). It shows the moon position on the live camera view. The position comes from GPS and the selected time.

## Layout
- `lib/astro.dart`: moon and sun position, phase, rise and set (SunCalc algorithm, no network).
- `lib/orientation.dart`: device pose from accelerometer and magnetometer (`sensors_plus`).
- `lib/sky_painter.dart`: camera overlay. It draws the horizon, compass points, the moon, and an arrow when the moon is off screen.
- `lib/timeline.dart`: moon altitude chart with day and night bands.
- `lib/home.dart`: screen, camera, location, time slider.
- `lib/moon_art.dart`: moon image renderer (phase, maria, craters, glow).
- `lib/heading_tape.dart`: compass strip with the moon marker.

## Rules
- Portrait only. The projection uses `kCamVFov` in `sky_painter.dart`.
- Azimuth is from true north, clockwise, in degrees. The compass gives magnetic north (no declination correction).
- Commands: `make run`, `make build`, `make deploy`.
- `make deploy` pushes `main`, tags the next patch version (`vX.Y.Z`), and makes a GitHub release with `build/moon-locator.apk`.
- `index.html` is the project page. Its download button links to `releases/latest/download/moon-locator.apk`. Keep that asset name.
