import 'dart:math';

const _rad = pi / 180;
const _dayMs = 86400000;
const _j1970 = 2440588;
const _j2000 = 2451545;
const _e = _rad * 23.4397;
const _sunDistKm = 149598000.0;

typedef Horiz = ({double az, double alt});
typedef Eq = ({double ra, double dec, double dist});

class MoonState {
  final double az, alt, dist, fraction, phase, angle;
  const MoonState(this.az, this.alt, this.dist, this.fraction, this.phase, this.angle);

  bool get waxing => phase < 0.5;

  String get phaseName => switch (phase) {
        < 0.03 || >= 0.97 => 'New Moon',
        < 0.22 => 'Waxing Crescent',
        < 0.28 => 'First Quarter',
        < 0.47 => 'Waxing Gibbous',
        < 0.53 => 'Full Moon',
        < 0.72 => 'Waning Gibbous',
        < 0.78 => 'Last Quarter',
        _ => 'Waning Crescent',
      };
}

double _days(DateTime t) => t.millisecondsSinceEpoch / _dayMs - 0.5 + _j1970 - _j2000;

double _ra(double l, double b) => atan2(sin(l) * cos(_e) - tan(b) * sin(_e), cos(l));

double _dec(double l, double b) => asin(sin(b) * cos(_e) + cos(b) * sin(_e) * sin(l));

double _sidereal(double d, double lw) => _rad * (280.16 + 360.9856235 * d) - lw;

double _refraction(double h) {
  final x = max(h, 0.0);
  return 0.0002967 / tan(x + 0.00312536 / (x + 0.08901179));
}

Eq _sunCoords(double d) {
  final m = _rad * (357.5291 + 0.98560028 * d);
  final c = _rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m));
  final l = m + c + _rad * 102.9372 + pi;
  return (ra: _ra(l, 0), dec: _dec(l, 0), dist: _sunDistKm);
}

Eq _moonCoords(double d) {
  final l0 = _rad * (218.316 + 13.176396 * d);
  final m = _rad * (134.963 + 13.064993 * d);
  final f = _rad * (93.272 + 13.229350 * d);
  final l = l0 + _rad * 6.289 * sin(m);
  final b = _rad * 5.128 * sin(f);
  return (ra: _ra(l, b), dec: _dec(l, b), dist: 385001 - 20905 * cos(m));
}

Horiz _horiz(Eq c, double d, double lat, double lng, {bool refract = false}) {
  final phi = _rad * lat;
  final h = _sidereal(d, _rad * -lng) - c.ra;
  var alt = asin(sin(phi) * sin(c.dec) + cos(phi) * cos(c.dec) * cos(h));
  if (refract) alt += _refraction(alt);
  final az = atan2(sin(h), cos(h) * sin(phi) - tan(c.dec) * cos(phi)) + pi;
  return (az: (az / _rad) % 360, alt: alt / _rad);
}

/// Sun altitude/azimuth in degrees (azimuth from north, clockwise).
Horiz sunPos(DateTime t, double lat, double lng) {
  final d = _days(t);
  return _horiz(_sunCoords(d), d, lat, lng);
}

/// Moon altitude/azimuth in degrees with refraction.
Horiz moonPos(DateTime t, double lat, double lng) {
  final d = _days(t);
  return _horiz(_moonCoords(d), d, lat, lng, refract: true);
}

MoonState moonState(DateTime t, double lat, double lng) {
  final d = _days(t);
  final s = _sunCoords(d), m = _moonCoords(d);
  final p = _horiz(m, d, lat, lng, refract: true);
  final phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra));
  final inc = atan2(s.dist * sin(phi), m.dist - s.dist * cos(phi));
  final angle = atan2(
    cos(s.dec) * sin(s.ra - m.ra),
    sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra),
  );
  return MoonState(
    p.az,
    p.alt,
    m.dist,
    (1 + cos(inc)) / 2,
    0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / pi,
    angle,
  );
}

/// One sample of the sky at a time.
typedef SkySample = ({DateTime t, double moonAlt, double sunAlt});

List<SkySample> sampleSky(DateTime from, Duration span, Duration step, double lat, double lng) {
  final n = span.inMinutes ~/ step.inMinutes;
  return [
    for (var i = 0; i <= n; i++)
      (() {
        final t = from.add(step * i);
        return (t: t, moonAlt: moonPos(t, lat, lng).alt, sunAlt: sunPos(t, lat, lng).alt);
      })(),
  ];
}

/// Moon rise (up = true) and set (up = false) events found in samples.
List<({DateTime t, bool up})> moonEvents(List<SkySample> s) => [
      for (var i = 1; i < s.length; i++)
        if ((s[i - 1].moonAlt < 0) != (s[i].moonAlt < 0))
          (() {
            final a = s[i - 1], b = s[i];
            final k = a.moonAlt / (a.moonAlt - b.moonAlt);
            final ms = a.t.millisecondsSinceEpoch +
                (k * (b.t.millisecondsSinceEpoch - a.t.millisecondsSinceEpoch)).round();
            return (t: DateTime.fromMillisecondsSinceEpoch(ms), up: b.moonAlt >= 0);
          })(),
    ];
