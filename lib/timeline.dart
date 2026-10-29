import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'astro.dart';

const kTimelineH = 92.0;
const _day = Color(0xFF5B86C5);
const _twilight = Color(0xFF2B3A73);
const _night = Color(0xFF070B1F);
const _moon = Color(0xFFFFD580);

Color skyColor(double sun) => sun >= 0
    ? Color.lerp(_twilight, _day, (sun / 10).clamp(0.0, 1.0))!
    : Color.lerp(_night, _twilight, ((sun + 18) / 18).clamp(0.0, 1.0))!;

/// Moon altitude chart over time with sky color bands and a cursor.
class Timeline extends StatelessWidget {
  final List<SkySample> samples;
  final DateTime at, now;
  final ValueChanged<DateTime> onPick;
  const Timeline({super.key, required this.samples, required this.at, required this.now, required this.onPick});

  void _pick(Offset p, double w) {
    if (samples.length < 2 || w <= 0) return;
    final a = samples.first.t.millisecondsSinceEpoch, b = samples.last.t.millisecondsSinceEpoch;
    final k = (p.dx / w).clamp(0.0, 1.0);
    onPick(DateTime.fromMillisecondsSinceEpoch(a + ((b - a) * k).round()));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => Semantics(
          label: 'Moon altitude timeline. Drag to change time.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _pick(d.localPosition, c.maxWidth),
            onHorizontalDragUpdate: (d) => _pick(d.localPosition, c.maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(size: Size(c.maxWidth, kTimelineH), painter: _TimelinePainter(samples, at, now)),
              ),
            ),
          ),
        ),
      );
}

class _TimelinePainter extends CustomPainter {
  final List<SkySample> s;
  final DateTime at, now;
  _TimelinePainter(this.s, this.at, this.now);

  static final _hh = DateFormat('HH:mm');
  static final _dd = DateFormat('EEE d');

  @override
  void paint(Canvas c, Size z) {
    if (s.length < 2) return;
    final a = s.first.t.millisecondsSinceEpoch.toDouble(), b = s.last.t.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) => (t.millisecondsSinceEpoch - a) / (b - a) * z.width;
    const top = 16.0;
    final mid = z.height * 0.62;
    double y(double alt) => mid - alt.clamp(-90.0, 90.0) / 90 * (mid - top);
    final dx = z.width / (s.length - 1);
    final full = Offset.zero & z;

    c.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          colors: [for (final e in s) skyColor(e.sunAlt)],
          stops: [for (var i = 0; i < s.length; i++) i / (s.length - 1)],
        ).createShader(full),
    );
    c.drawRect(
      Rect.fromLTRB(0, mid, z.width, z.height),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    final line = Path();
    for (var i = 0; i < s.length; i++) {
      final p = Offset(i * dx, y(s[i].moonAlt));
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(z.width, mid)
      ..lineTo(0, mid)
      ..close();
    c
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, z.width, mid))
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_moon.withValues(alpha: 0.45), _moon.withValues(alpha: 0.05)],
          ).createShader(Rect.fromLTRB(0, top, z.width, mid)),
      )
      ..restore()
      ..drawLine(Offset(0, mid), Offset(z.width, mid), Paint()..color = Colors.white30)
      ..drawPath(
        line,
        Paint()
          ..color = _moon.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawPath(
        line,
        Paint()
          ..color = _moon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.round,
      );

    final tick = Paint()..color = Colors.white.withValues(alpha: 0.12);
    var t = DateTime(s.first.t.year, s.first.t.month, s.first.t.day, s.first.t.hour);
    while (t.isBefore(s.last.t)) {
      if (t.hour % 6 == 0 && !t.isBefore(s.first.t)) {
        final px = x(t);
        c.drawLine(Offset(px, 0), Offset(px, z.height), tick);
        _label(c, t.hour == 0 ? _dd.format(t).toUpperCase() : _hh.format(t), Offset(px + 4, z.height - 15),
            bold: t.hour == 0);
      }
      t = t.add(const Duration(hours: 1));
    }

    final nx = x(now);
    if (nx >= 0 && nx <= z.width) {
      c.drawLine(Offset(nx, 0), Offset(nx, 8), Paint()
        ..color = Colors.white70
        ..strokeWidth = 2);
      _label(c, 'NOW', Offset(nx + 4, 2), bold: true);
    }

    final cx = x(at);
    final cy = y(_altAt(at));
    c
      ..drawLine(
        Offset(cx, 0),
        Offset(cx, z.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.5,
      )
      ..drawCircle(Offset(cx, cy), 9, Paint()..color = _moon.withValues(alpha: 0.3))
      ..drawCircle(Offset(cx, cy), 5.5, Paint()..color = Colors.white)
      ..drawCircle(Offset(cx, cy), 3, Paint()..color = _moon);
  }

  double _altAt(DateTime t) {
    final a = s.first.t.millisecondsSinceEpoch, b = s.last.t.millisecondsSinceEpoch;
    final k = ((t.millisecondsSinceEpoch - a) / (b - a) * (s.length - 1)).clamp(0.0, s.length - 1.0);
    final i = k.floor().clamp(0, s.length - 2);
    final f = k - i;
    return s[i].moonAlt * (1 - f) + s[i + 1].moonAlt * f;
  }

  void _label(Canvas c, String txt, Offset o, {bool bold = false}) => (TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            color: Colors.white.withValues(alpha: bold ? 0.9 : 0.6),
            fontSize: 9.5,
            letterSpacing: 0.6,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout())
          .paint(c, o);

  @override
  bool shouldRepaint(_TimelinePainter old) => old.s != s || old.at != at || old.now != now;
}
