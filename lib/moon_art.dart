import 'dart:math';

import 'package:flutter/material.dart';

/// Lunar maria on the near side: unit-disc x, y, radius, darkness.
const _maria = [
  (-0.58, -0.02, 0.36, 0.55),
  (-0.32, -0.38, 0.27, 0.6),
  (0.14, -0.40, 0.17, 0.55),
  (0.30, -0.08, 0.21, 0.5),
  (0.63, -0.30, 0.12, 0.65),
  (0.52, 0.18, 0.14, 0.45),
  (0.36, 0.34, 0.10, 0.4),
  (-0.18, 0.34, 0.17, 0.4),
  (-0.47, 0.44, 0.10, 0.5),
  (-0.05, 0.05, 0.10, 0.3),
  (0.05, -0.62, 0.12, 0.3),
];

/// Craters: x, y, radius.
const _craters = [
  (-0.10, 0.70, 0.045),
  (-0.40, -0.10, 0.03),
  (0.22, 0.60, 0.04),
  (-0.62, 0.30, 0.035),
  (0.45, -0.58, 0.03),
  (0.70, 0.40, 0.035),
  (-0.25, 0.55, 0.03),
  (0.05, 0.42, 0.025),
  (-0.75, -0.40, 0.03),
  (0.60, 0.05, 0.025),
];

const _rays = [(-0.10, 0.70)];

/// Draws a shaded moon disc with phase, maria, craters, and glow.
void paintMoon(
  Canvas c,
  Offset o,
  double r,
  double fraction,
  bool waxing, {
  bool dim = false,
  double glow = 1,
}) {
  final a = dim ? 0.45 : 1.0;
  final disc = Rect.fromCircle(center: o, radius: r);

  if (glow > 0) {
    final g = (0.15 + 0.45 * fraction) * glow * a;
    c.drawCircle(
      o,
      r * 2.6,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFF3C4).withValues(alpha: g),
          const Color(0xFFFFF3C4).withValues(alpha: g * 0.25),
          const Color(0x00FFF3C4),
        ], stops: const [0.35, 0.55, 1]).createShader(Rect.fromCircle(center: o, radius: r * 2.6)),
    );
  }

  c.save();
  c.clipPath(Path()..addOval(disc));

  c.drawRect(
    disc,
    Paint()
      ..shader = RadialGradient(
        center: Alignment(waxing ? -0.4 : 0.4, -0.2),
        colors: [Color.fromRGBO(58, 64, 82, a), Color.fromRGBO(22, 25, 36, a)],
      ).createShader(disc),
  );

  final (lit, term) = _phasePaths(o, r, fraction, waxing);
  c
    ..save()
    ..clipPath(lit);
  _surface(c, o, r, waxing, a);
  c
    ..drawPath(
      term,
      Paint()
        ..color = Color.fromRGBO(30, 32, 44, 0.75 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, r * 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, r * 0.07)),
    )
    ..restore();

  c.drawCircle(
    o,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x00000000), Colors.black.withValues(alpha: 0.35 * a)],
        stops: const [0.72, 1],
      ).createShader(disc),
  );
  c.restore();
}

void _surface(Canvas c, Offset o, double r, bool waxing, double a) {
  final disc = Rect.fromCircle(center: o, radius: r);
  c.drawRect(
    disc,
    Paint()
      ..shader = RadialGradient(
        center: Alignment(waxing ? 0.35 : -0.35, -0.3),
        radius: 1.1,
        colors: [
          Color.fromRGBO(255, 251, 235, a),
          Color.fromRGBO(232, 226, 205, a),
          Color.fromRGBO(178, 170, 150, a),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(disc),
  );

  final blur = MaskFilter.blur(BlurStyle.normal, r * 0.08);
  for (final (x, y, s, d) in _maria) {
    c.drawOval(
      Rect.fromCenter(center: o + Offset(x, y) * r, width: s * r * 2.2, height: s * r * 1.8),
      Paint()
        ..color = Color.fromRGBO(110, 108, 100, d * a)
        ..maskFilter = blur,
    );
  }

  if (r < 14) return;
  for (final (x, y) in _rays) {
    final p = o + Offset(x, y) * r;
    final ray = Paint()
      ..color = Color.fromRGBO(255, 255, 245, 0.18 * a)
      ..strokeWidth = r * 0.02
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.01);
    for (var i = 0; i < 9; i++) {
      final t = i * pi * 2 / 9 + 0.3;
      c.drawLine(p, p + Offset(cos(t), sin(t)) * r * (0.35 + 0.25 * (i % 3) / 2), ray);
    }
  }
  for (final (x, y, s) in _craters) {
    final p = o + Offset(x, y) * r, cr = s * r;
    c
      ..drawCircle(p, cr, Paint()..color = Color.fromRGBO(120, 116, 104, 0.55 * a))
      ..drawCircle(p.translate(cr * 0.25, cr * 0.25), cr * 0.75, Paint()..color = Color.fromRGBO(245, 240, 222, 0.6 * a));
  }
}

/// Lit area and terminator arc. Waxing is lit on the right.
(Path, Path) _phasePaths(Offset o, double r, double fraction, bool waxing) {
  final f = fraction.clamp(0.0, 1.0);
  final circle = Rect.fromCircle(center: o, radius: r);
  final half = Path()
    ..moveTo(o.dx, o.dy - r)
    ..arcTo(circle, -pi / 2, pi, false)
    ..close();
  final ellRect = Rect.fromCenter(center: o, width: max(2 * r * (1 - 2 * f).abs(), 0.01), height: 2 * r);
  final crescent = f < 0.5;
  final lit = Path.combine(crescent ? PathOperation.difference : PathOperation.union, half, Path()..addOval(ellRect));
  final term = Path()..addArc(ellRect, crescent ? -pi / 2 : pi / 2, pi);
  if (waxing) return (lit, term);
  final m = (Matrix4.identity()
        ..translateByDouble(o.dx, 0, 0, 1)
        ..scaleByDouble(-1, 1, 1, 1)
        ..translateByDouble(-o.dx, 0, 0, 1))
      .storage;
  return (lit.transform(m), term.transform(m));
}

/// Widget wrapper for the moon art.
class MoonArt extends StatelessWidget {
  final double size, fraction;
  final bool waxing;
  final double glow;
  const MoonArt({super.key, required this.size, required this.fraction, required this.waxing, this.glow = 0.6});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MoonArtPainter(fraction, waxing, glow)),
      );
}

class _MoonArtPainter extends CustomPainter {
  final double fraction, glow;
  final bool waxing;
  _MoonArtPainter(this.fraction, this.waxing, this.glow);

  @override
  void paint(Canvas c, Size s) =>
      paintMoon(c, s.center(Offset.zero), s.shortestSide / (glow > 0 ? 3.2 : 2), fraction, waxing, glow: glow);

  @override
  bool shouldRepaint(_MoonArtPainter o) => o.fraction != fraction || o.waxing != waxing || o.glow != glow;
}
