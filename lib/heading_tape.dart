import 'package:flutter/material.dart';

import 'moon_art.dart';
import 'sky_painter.dart';

const kTapeSpan = 120.0;
const kTapeH = 40.0;

/// Compass strip centered on the phone heading with a moon marker.
class HeadingTape extends StatelessWidget {
  final double heading, pitch, target, targetAlt;
  const HeadingTape({super.key, required this.heading, required this.pitch, required this.target, required this.targetAlt});

  @override
  Widget build(BuildContext context) {
    final turn = ((target - heading + 540) % 360) - 180;
    final tilt = targetAlt - pitch;
    final hint = turn.abs() < kLockDeg && tilt.abs() < kLockDeg
        ? 'On target'
        : [
            if (turn.abs() >= kLockDeg) '${turn > 0 ? 'Right' : 'Left'} ${turn.abs().round()}°',
            if (tilt.abs() >= kLockDeg) '${tilt > 0 ? 'Up' : 'Down'} ${tilt.abs().round()}°',
          ].join(' · ');
    return Semantics(
      label: 'Heading ${heading.round()} degrees. Moon: $hint',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kTapeH,
            width: double.infinity,
            child: CustomPaint(painter: _TapePainter(heading, target)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${heading.round()}°',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
              Text('  ·  tilt ${pitch.round()}°', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              Icon(hint == 'On target' ? Icons.gps_fixed_rounded : Icons.near_me_rounded, size: 14, color: kGold),
              const SizedBox(width: 4),
              Text(hint, style: const TextStyle(color: kGold, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  final double heading, target;
  _TapePainter(this.heading, this.target);

  static const _names = {0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW'};

  @override
  void paint(Canvas c, Size s) {
    final pxDeg = s.width / kTapeSpan;
    final cx = s.width / 2;
    double rel(double az) => ((az - heading + 540) % 360) - 180;

    final bg = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(12));
    c
      ..drawRRect(bg, Paint()..color = Colors.white.withValues(alpha: 0.05))
      ..saveLayer(Offset.zero & s, Paint())
      ..clipRRect(bg);

    final tick = Paint()..color = Colors.white38;
    final start = (heading - kTapeSpan / 2).floor() ~/ 5 * 5 - 5;
    for (var d = start; d <= heading + kTapeSpan / 2 + 5; d += 5) {
      final az = d % 360;
      final x = cx + rel(az.toDouble()) * pxDeg;
      final name = _names[az];
      final major = az % 15 == 0;
      c.drawLine(Offset(x, s.height - (major ? 12 : 6)), Offset(x, s.height), tick..strokeWidth = major ? 1.4 : 1);
      if (name != null || az % 30 == 0) {
        _label(c, name ?? '$az', Offset(x, 11), name != null ? (az % 90 == 0 ? Colors.white : kHorizon) : Colors.white54,
            name != null ? 12 : 10);
      }
    }

    final mr = rel(target);
    final half = kTapeSpan / 2 - 4;
    final mx = cx + mr.clamp(-half, half) * pxDeg;
    if (mr.abs() <= half) {
      paintMoon(c, Offset(mx, s.height - 15), 7, 1, true, glow: 0.8);
    } else {
      final dir = mr > 0 ? 1.0 : -1.0;
      c.drawPath(
        Path()
          ..moveTo(mx + dir * 7, s.height - 15)
          ..lineTo(mx - dir * 3, s.height - 22)
          ..lineTo(mx - dir * 3, s.height - 8)
          ..close(),
        Paint()..color = kGold,
      );
    }

    final fade = Paint()
      ..shader = LinearGradient(colors: const [
        Color(0xFF0B0F22),
        Color(0x000B0F22),
        Color(0x000B0F22),
        Color(0xFF0B0F22),
      ], stops: const [0, 0.15, 0.85, 1]).createShader(Offset.zero & s)
      ..blendMode = BlendMode.dstOut;
    c
      ..drawRect(Offset.zero & s, fade)
      ..restore();

    c.drawPath(
      Path()
        ..moveTo(cx - 6, 0)
        ..lineTo(cx + 6, 0)
        ..lineTo(cx, 7)
        ..close(),
      Paint()..color = kGold,
    );
    c.drawLine(Offset(cx, 0), Offset(cx, s.height), Paint()
      ..color = kGold.withValues(alpha: 0.7)
      ..strokeWidth = 1.5);
  }

  void _label(Canvas c, String s, Offset at, Color col, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TapePainter o) => o.heading != heading || o.target != target;
}
