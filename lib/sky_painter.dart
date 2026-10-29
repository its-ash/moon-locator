import 'dart:math';

import 'package:flutter/material.dart';

import 'astro.dart';
import 'moon_art.dart';
import 'orientation.dart';

/// Vertical field of view of the back camera in portrait, degrees.
const kCamVFov = 62.0;
const kMoonR = 30.0;
const kEdge = 64.0;
const kLockDeg = 4.0;
const kGold = Color(0xFFFFD580);
const kHorizon = Color(0xFF9BE7C4);

class SkyPainter extends CustomPainter {
  final Pose? pose;
  final MoonState moon;

  /// Screen area covered by panels; the off-screen pointer stays out of it.
  final EdgeInsets pad;
  SkyPainter(this.pose, this.moon, {this.pad = EdgeInsets.zero});

  static const _cardinals = {0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW'};

  @override
  void paint(Canvas canvas, Size s) {
    final p = pose;
    if (p == null) return;
    final f = (s.height / 2) / tan(kCamVFov * pi / 360);
    final ctr = s.center(Offset.zero);
    final view = Offset.zero & s;

    Offset? proj(V3 v) => v.z < -0.02 ? Offset(ctr.dx + f * v.x / -v.z, ctr.dy - f * v.y / -v.z) : null;

    _horizon(canvas, s, p, proj);

    final v = p.toDevice(moon.az, moon.alt);
    final off = acos((-v.z).clamp(-1.0, 1.0)) * 180 / pi;
    _reticle(canvas, ctr, off <= kLockDeg);

    final q = proj(v);
    final below = moon.alt < 0;
    if (q != null && view.inflate(-kMoonR).contains(q)) {
      paintMoon(canvas, q, kMoonR, moon.fraction, moon.waxing, dim: below);
      _ring(canvas, q, kMoonR + 10, below ? Colors.white38 : kGold);
      _pill(
        canvas,
        below ? 'BELOW HORIZON  ${moon.alt.toStringAsFixed(0)}°' : 'MOON  ${moon.alt.toStringAsFixed(1)}°',
        q.translate(0, kMoonR + 30),
        fg: below ? Colors.white70 : kGold,
      );
      return;
    }

    var d = Offset(v.x, -v.y);
    d = d.distance < 1e-4 ? const Offset(0, 1) : d / d.distance;
    final area = pad.deflateRect(view).deflate(kEdge);
    final hw = max(area.width / 2, 0.0), hh = max(area.height / 2, 0.0);
    final t = min(
      d.dx.abs() < 1e-6 ? double.infinity : hw / d.dx.abs(),
      d.dy.abs() < 1e-6 ? double.infinity : hh / d.dy.abs(),
    );
    final at = area.center + d * t;
    _pointer(canvas, at, d, off, below);
  }

  void _horizon(Canvas c, Size s, Pose p, Offset? Function(V3) proj) {
    final glow = Paint()
      ..color = kHorizon.withValues(alpha: 0.25)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..color = kHorizon.withValues(alpha: 0.85)
      ..strokeWidth = 1.4;
    final lim = s.longestSide * 3;
    final pts = <Offset?>[for (var az = 0; az <= 360; az += 2) proj(p.toDevice(az.toDouble(), 0))];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if (a == null || b == null || (a - b).distance > lim) continue;
      c
        ..drawLine(a, b, glow)
        ..drawLine(a, b, line);
    }
    final view = (Offset.zero & s).inflate(-12);
    for (var az = 0; az < 360; az += 15) {
      final q = pts[az ~/ 2];
      if (q == null || !view.contains(q)) continue;
      final lbl = _cardinals[az];
      if (lbl == null) {
        c.drawLine(q.translate(0, -4), q.translate(0, 4), line);
        _text(c, '$az', q.translate(0, 14), 9, kHorizon.withValues(alpha: 0.7));
      } else {
        c.drawLine(q.translate(0, -9), q.translate(0, 9), line..strokeWidth = 2);
        line.strokeWidth = 1.4;
        _pill(c, lbl, q.translate(0, 24), fg: az % 90 == 0 ? Colors.white : kHorizon, size: az % 90 == 0 ? 13 : 11);
      }
    }
  }

  void _reticle(Canvas c, Offset o, bool locked) {
    final col = locked ? kGold : Colors.white.withValues(alpha: 0.7);
    final pen = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = locked ? 2.4 : 1.4
      ..strokeCap = StrokeCap.round;
    const r = 26.0;
    for (var i = 0; i < 4; i++) {
      c.drawArc(Rect.fromCircle(center: o, radius: r), i * pi / 2 + 0.25, pi / 2 - 0.5, false, pen);
    }
    c.drawCircle(o, 2, Paint()..color = col);
    if (locked) _pill(c, 'ON TARGET', o.translate(0, -r - 22), fg: Colors.black, bg: kGold);
  }

  void _ring(Canvas c, Offset o, double r, Color col) {
    final pen = Paint()
      ..color = col.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const n = 24;
    for (var i = 0; i < n; i += 2) {
      c.drawArc(Rect.fromCircle(center: o, radius: r), i * 2 * pi / n, 2 * pi / n * 0.8, false, pen);
    }
  }

  void _pointer(Canvas c, Offset at, Offset d, double off, bool below) {
    final ang = atan2(d.dy, d.dx);
    c.drawCircle(at, 30, Paint()..color = Colors.black.withValues(alpha: 0.45));
    c.drawCircle(
      at,
      30,
      Paint()
        ..color = kGold.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    paintMoon(c, at.translate(0, -5), 10, moon.fraction, moon.waxing, dim: below, glow: 0);
    _text(c, '${off.round()}°', at.translate(0, 13), 11, kGold, bold: true);
    final tip = at + d * 44;
    Offset side(double k) => at + Offset(cos(ang + k), sin(ang + k)) * 34;
    c.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(side(0.42).dx, side(0.42).dy)
        ..lineTo(side(-0.42).dx, side(-0.42).dy)
        ..close(),
      Paint()..color = kGold,
    );
  }

  void _pill(Canvas c, String s, Offset at, {Color fg = Colors.white, Color? bg, double size = 11}) {
    final tp = _tp(s, size, fg, bold: true, spacing: 1.2);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: tp.width + 16, height: tp.height + 8),
      const Radius.circular(20),
    );
    c.drawRRect(box, Paint()..color = bg ?? Colors.black.withValues(alpha: 0.5));
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _text(Canvas c, String s, Offset at, double size, Color col, {bool bold = false}) {
    final tp = _tp(s, size, col, bold: bold);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  TextPainter _tp(String s, double size, Color col, {bool bold = false, double spacing = 0}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: col,
            fontSize: size,
            letterSpacing: spacing,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            shadows: const [Shadow(blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  bool shouldRepaint(SkyPainter old) => old.pose != pose || old.moon != moon || old.pad != pad;
}
