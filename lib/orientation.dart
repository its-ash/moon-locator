import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

const kSmooth = 0.12;

typedef V3 = ({double x, double y, double z});

V3 _cross(V3 a, V3 b) =>
    (x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x);

V3? _norm(V3 v) {
  final n = sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  return n < 1e-6 ? null : (x: v.x / n, y: v.y / n, z: v.z / n);
}

V3 _lerp(V3? a, V3 b) => a == null
    ? b
    : (x: a.x + (b.x - a.x) * kSmooth, y: a.y + (b.y - a.y) * kSmooth, z: a.z + (b.z - a.z) * kSmooth);

/// World axes (east, north, up) expressed in device coordinates.
class Pose {
  final V3 e, n, u;
  const Pose(this.e, this.n, this.u);

  /// World direction (azimuth, altitude in degrees) -> device vector.
  V3 toDevice(double az, double alt) {
    final a = az * pi / 180, h = alt * pi / 180;
    final we = cos(h) * sin(a), wn = cos(h) * cos(a), wu = sin(h);
    return (
      x: e.x * we + n.x * wn + u.x * wu,
      y: e.y * we + n.y * wn + u.y * wu,
      z: e.z * we + n.z * wn + u.z * wu,
    );
  }

  /// Back camera direction as azimuth/altitude in degrees.
  ({double az, double alt}) get aim {
    final we = -e.z, wn = -n.z, wu = -u.z;
    return (az: (atan2(we, wn) * 180 / pi) % 360, alt: asin(wu.clamp(-1.0, 1.0)) * 180 / pi);
  }
}

class PoseTracker extends ValueNotifier<Pose?> {
  PoseTracker() : super(null);

  StreamSubscription<AccelerometerEvent>? _acc;
  StreamSubscription<MagnetometerEvent>? _mag;
  V3? _g, _m;
  String? error;

  void start() {
    _acc = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (ev) => _g = _lerp(_g, (x: ev.x, y: ev.y, z: ev.z)),
      onError: (_) => _fail('Accelerometer not available'),
      cancelOnError: true,
    );
    _mag = magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (ev) {
        _m = _lerp(_m, (x: ev.x, y: ev.y, z: ev.z));
        _update();
      },
      onError: (_) => _fail('Compass not available'),
      cancelOnError: true,
    );
  }

  void _fail(String msg) {
    error = msg;
    notifyListeners();
  }

  void _update() {
    final g = _g, m = _m;
    if (g == null || m == null) return;
    final u = _norm(g);
    final e = _norm(_cross(m, g));
    if (u == null || e == null) return;
    value = Pose(e, _cross(u, e), u);
  }

  @override
  void dispose() {
    _acc?.cancel();
    _mag?.cancel();
    super.dispose();
  }
}
