import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'astro.dart';
import 'heading_tape.dart';
import 'moon_art.dart';
import 'orientation.dart';
import 'sky_painter.dart';
import 'timeline.dart';

const kPast = Duration(hours: 12);
const kSpan = Duration(hours: 60);
const kStep = Duration(minutes: 10);
const kSnapMin = 5;
const kDarkSun = -6.0;
const kMinAlt = 5.0;
const kTopPad = 190.0;
const kBottomPad = 330.0;

const _tab = [FontFeature.tabularFigures()];
const _dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];

String compassDir(double az) => _dirs[((az % 360) / 22.5).round() % 16];

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final _pose = PoseTracker();
  CameraController? _cam;
  String? _camErr, _locErr;
  Position? _pos;
  late DateTime _base = DateTime.now();
  late DateTime _at = _base;
  bool _live = true;
  List<SkySample> _samples = const [];
  Timer? _tick;

  static final _hm = DateFormat('HH:mm');
  static final _day = DateFormat('EEE, d MMM');
  static final _short = DateFormat('EEE HH:mm');

  DateTime get _from => _base.subtract(kPast);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pose.start();
    _initCam();
    _initLoc();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_live) _setBase(DateTime.now(), live: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _cam?.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final c = _cam;
    if (s == AppLifecycleState.inactive && c != null && c.value.isInitialized) {
      _cam = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (s == AppLifecycleState.resumed && _cam == null) {
      _initCam();
    }
  }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'No camera found');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (!mounted) return c.dispose();
      setState(() {
        _cam = c;
        _camErr = null;
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _camErr = e.description ?? e.code);
    }
  }

  Future<void> _initLoc() async {
    setState(() => _locErr = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Turn on location services';
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        throw 'Location permission is needed to find the moon';
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) _setPos(last);
      final cur = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 20)),
      );
      if (mounted) _setPos(cur);
    } catch (e) {
      if (mounted && _pos == null) setState(() => _locErr = e is String ? e : 'Could not get location');
    }
  }

  void _setPos(Position p) {
    _pos = p;
    _setBase(_base, live: _live);
  }

  void _setBase(DateTime b, {required bool live}) {
    final p = _pos;
    setState(() {
      final keep = _at.difference(_base);
      _base = b;
      _live = live;
      _at = live ? b : b.add(keep);
      if (p != null) _samples = sampleSky(_from, kSpan, kStep, p.latitude, p.longitude);
    });
  }

  void _pickTime(DateTime t) {
    final snap = DateTime.fromMillisecondsSinceEpoch(
      (t.millisecondsSinceEpoch / (kSnapMin * 60000)).round() * kSnapMin * 60000,
    );
    final end = _from.add(kSpan);
    setState(() {
      _at = snap.isBefore(_from) ? _from : (snap.isAfter(end) ? end : snap);
      _live = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    final b = DateTime(d.year, d.month, d.day, _at.hour, _at.minute);
    _setBase(b, live: false);
    setState(() => _at = b);
  }

  DateTime? _next({required bool up}) {
    for (final e in moonEvents(_samples)) {
      if (e.up == up && e.t.isAfter(_at)) return e.t;
    }
    return null;
  }

  DateTime? get _nextView {
    for (final s in _samples) {
      if (!s.t.isBefore(_at) && s.moonAlt >= kMinAlt && s.sunAlt <= kDarkSun) return s.t;
    }
    return null;
  }

  String _relative(DateTime t) {
    final d = t.difference(DateTime.now());
    final m = d.inMinutes.abs();
    if (m < 3) return 'Now';
    final txt = m < 60 ? '${m}m' : '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
    return d.isNegative ? '$txt ago' : 'in $txt';
  }

  @override
  Widget build(BuildContext context) {
    final p = _pos;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _preview(),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
                  stops: [0, 0.25, 0.6, 1],
                ),
              ),
            ),
          ),
          if (p != null) ...[
            Builder(builder: (_) {
              final m = moonState(_at, p.latitude, p.longitude);
              return ValueListenableBuilder(
                valueListenable: _pose,
                builder: (_, pose, _) => CustomPaint(
                  painter: SkyPainter(
                    pose,
                    m,
                    pad: EdgeInsets.only(top: pad.top + kTopPad, bottom: pad.bottom + kBottomPad),
                  ),
                ),
              );
            }),
            SafeArea(child: Align(alignment: Alignment.topCenter, child: _hud(p))),
            Align(alignment: Alignment.bottomCenter, child: _panel()),
          ] else
            _status(),
        ],
      ),
    );
  }

  Widget _preview() {
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A2350), Color(0xFF050816)],
          ),
        ),
        child: _camErr == null
            ? null
            : SafeArea(
                child: Align(
                  alignment: const Alignment(0, -0.45),
                  child: _Pill(icon: Icons.videocam_off_rounded, text: 'Camera: $_camErr'),
                ),
              ),
      );
    }
    final sz = c.value.previewSize;
    return sz == null
        ? CameraPreview(c)
        : ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: sz.height, height: sz.width, child: CameraPreview(c)),
            ),
          );
  }

  Widget _status() {
    final t = Theme.of(context).textTheme;
    final m = moonState(DateTime.now(), 0, 0);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoonArt(size: 180, fraction: m.fraction, waxing: m.waxing, glow: 1),
              const SizedBox(height: 8),
              Text('Moon Locator', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 16),
              if (_locErr == null) ...[
                const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(height: 14),
                Text('Finding your location…', style: t.bodyMedium?.copyWith(color: Colors.white70)),
              ] else ...[
                Text(_locErr!, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _initLoc,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Try again'),
                ),
                TextButton(onPressed: Geolocator.openAppSettings, child: const Text('Open settings')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(Position p) {
    final m = moonState(_at, p.latitude, p.longitude);
    final t = Theme.of(context).textTheme;
    final up = m.alt >= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: _Glass(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                MoonArt(size: 76, fraction: m.fraction, waxing: m.waxing),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.phaseName,
                          style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(up ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 14, color: up ? kGold : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            '${(m.fraction * 100).round()}% lit · ${up ? 'Above horizon' : 'Below horizon'}',
                            style: t.bodySmall?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Stat('ALT', '${m.alt.toStringAsFixed(1)}°'),
                          _Stat('AZ', '${m.az.toStringAsFixed(0)}° ${compassDir(m.az)}'),
                          _Stat('DIST', '${(m.dist / 1000).toStringAsFixed(0)}k km'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _pose,
              builder: (_, pose, _) {
                final err = _pose.error;
                if (err != null) return _Pill(icon: Icons.explore_off_rounded, text: err);
                final a = pose?.aim;
                return a == null
                    ? const _Pill(icon: Icons.explore_rounded, text: 'Waiting for compass…')
                    : HeadingTape(heading: a.az, pitch: a.alt, target: m.az, targetAlt: m.alt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel() {
    final t = Theme.of(context).textTheme;
    final rise = _next(up: true), set = _next(up: false), view = _nextView;
    final now = DateTime.now();
    return _Glass(
      radius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _hm.format(_at),
                style: t.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                  fontFeatures: _tab,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_day.format(_at),
                                style: t.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more_rounded, size: 18, color: Colors.white70),
                          ],
                        ),
                        Text(_relative(_at), style: t.bodySmall?.copyWith(color: kGold, fontFeatures: _tab)),
                      ],
                    ),
                  ),
                ),
              ),
              _live
                  ? const _LiveBadge()
                  : FilledButton.tonalIcon(
                      onPressed: () => _setBase(DateTime.now(), live: true),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Now'),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          Timeline(samples: _samples, at: _at, now: now, onPick: _pickTime),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: kGold,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: kGold.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              showValueIndicator: ShowValueIndicator.onDrag,
              valueIndicatorColor: kGold,
              valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
            child: Slider(
              value: _at.difference(_from).inMinutes.clamp(0, kSpan.inMinutes).toDouble(),
              max: kSpan.inMinutes.toDouble(),
              divisions: kSpan.inMinutes ~/ kSnapMin,
              label: _short.format(_at),
              semanticFormatterCallback: (_) => '${_day.format(_at)} ${_hm.format(_at)}',
              onChanged: (v) => _pickTime(_from.add(Duration(minutes: v.round()))),
            ),
          ),
          Row(
            children: [
              _EventTile(icon: Icons.north_east_rounded, label: 'Moonrise', t: rise, onTap: _pickTime),
              const SizedBox(width: 8),
              _EventTile(icon: Icons.south_east_rounded, label: 'Moonset', t: set, onTap: _pickTime),
              const SizedBox(width: 8),
              _EventTile(
                icon: Icons.nights_stay_rounded,
                label: view != null && view.difference(_at) < kStep ? 'Visible' : 'Best view',
                t: view,
                accent: true,
                onTap: _pickTime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius radius;
  const _Glass({required this.child, this.padding = EdgeInsets.zero, this.radius = const BorderRadius.all(Radius.circular(24))});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF141A33).withValues(alpha: 0.72), const Color(0xFF070A18).withValues(alpha: 0.82)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600, fontFeatures: _tab)),
          ],
        ),
      );
}

class _EventTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? t;
  final bool accent;
  final ValueChanged<DateTime> onTap;
  const _EventTile({required this.icon, required this.label, required this.t, required this.onTap, this.accent = false});

  static final _hm = DateFormat('HH:mm');
  static final _wd = DateFormat('EEE');

  @override
  Widget build(BuildContext context) {
    final v = t;
    final col = accent ? kGold : Colors.white;
    return Expanded(
      child: Material(
        color: accent ? kGold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: v == null ? null : () => onTap(v),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: col.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: col.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(v == null ? '—' : _hm.format(v),
                    style: TextStyle(color: col, fontSize: 18, fontWeight: FontWeight.w600, fontFeatures: _tab)),
                Text(v == null ? 'Not in range' : _wd.format(v),
                    style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
          ],
        ),
      );
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Live time',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 6),
              const Text('LIVE',
                  style: TextStyle(color: Color(0xFF7CF5B0), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ],
          ),
        ),
      );
}
