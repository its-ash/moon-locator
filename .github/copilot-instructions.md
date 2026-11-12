# Moon Locator (package: moon_locator / com.itsash.moon_locator)

Flutter app (Android). It shows the moon position on the live camera view. The position comes from GPS and the selected time.

## Layout
- `lib/main.dart`: `UiApp` root (shared theme at `../theme`), portrait lock.
- `lib/astro.dart`: moon and sun position, phase, rise and set (SunCalc algorithm, no network).
- `lib/orientation.dart`: device pose from accelerometer and magnetometer (`sensors_plus`).
- `lib/sky_painter.dart`: camera overlay. It draws the horizon, compass points, the moon, and an arrow when the moon is off screen.
- `lib/timeline.dart`: moon altitude chart with day and night bands.
- `lib/home.dart`: screen, camera, location, time slider. The gear in the top HUD opens Settings.
- `lib/settings_screen.dart`: Compass and Privacy notes, then `UiAppearanceSection()`, `UiUpdateSection(storeId: 'moon-locator')`, `UiDeveloperSection()`.
- `lib/moon_art.dart`: moon image renderer (phase, maria, craters, glow).
- `lib/heading_tape.dart`: compass strip with the moon marker.

## Rules
- Portrait only. The projection uses `kCamVFov` in `sky_painter.dart`.
- Azimuth is from true north, clockwise, in degrees. The compass gives magnetic north (no declination correction).
- The camera HUD keeps its own fixed dark colors (it sits on the camera image). Settings and any new screens use only `theme` widgets (read `../theme/COMPONENTS.md`).
- Only network use: `UiUpdateSection` (needs `INTERNET` in the manifest).
- Commands: `make run`, `make build`, `make test` (analyze), `make clean`.
- Icon: two-color pixel art in `assets/icon/*.svg` → `rsvg-convert -w 1024 -h 1024` to `*-1024.png`, then `dart run flutter_launcher_icons` (config in `pubspec.yaml`).
- `index.html` is a custom landing page. Its download button links to `releases/latest/download/moon-locator.apk`. Keep that asset name.

## Release (Ash Store)
- `store.json` (id `moon-locator`, repo its-ash/moon-locator), `store.mk`, `index.html` + `CNAME` (`moon-locator.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub release with `moon-locator.apk` → topics, homepage, Pages. Never create releases, tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run `make store-sync` at the workspace root.
