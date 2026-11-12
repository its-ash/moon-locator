import 'dart:convert';

import 'package:flutter/services.dart';

import 'astro.dart';

const _channel = MethodChannel('com.itsash.moon_locator/widget');

String _ymd(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Builds the home-screen widget data: the next [days] days (phase, illumination,
/// rise/set when a location is known) and upcoming full/new moon times.
/// Times are epoch milliseconds; the widget formats them in the device locale.
Map<String, dynamic> buildWidgetData(DateTime now, {double? lat, double? lng, int days = 30}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < days; i++) {
    final start = DateTime(today.year, today.month, today.day + i);
    final end = DateTime(today.year, today.month, today.day + i + 1);
    final noon = start.add(const Duration(hours: 12));
    final st = moonState(noon, lat ?? 0, lng ?? 0);
    final entry = <String, dynamic>{
      'd': _ymd(start),
      'n': st.phaseName,
      'i': (st.fraction * 100).round(),
      'p': double.parse(st.phase.toStringAsFixed(3)),
    };
    if (lat != null && lng != null) {
      final samples = sampleSky(start, end.difference(start), const Duration(minutes: 10), lat, lng);
      final ev = moonEvents(samples);
      for (final e in ev) {
        final key = e.up ? 'r' : 's';
        entry.putIfAbsent(key, () => e.t.millisecondsSinceEpoch);
      }
    }
    out.add(entry);
  }

  // Full moon = phase crosses 0.5; new moon = phase wraps from ~1 to ~0.
  final full = <int>[], newer = <int>[];
  var prev = moonState(now, 0, 0).phase;
  for (var h = 1; h <= 24 * 62; h++) {
    final t = now.add(Duration(hours: h));
    final p = moonState(t, 0, 0).phase;
    if (prev < 0.5 && p >= 0.5) full.add(t.millisecondsSinceEpoch);
    if (prev > 0.9 && p < 0.1) newer.add(t.millisecondsSinceEpoch);
    prev = p;
  }

  return {'days': out, 'full': full, 'new': newer, 'located': lat != null && lng != null};
}

/// Writes the widget data to SharedPreferences (native side) and refreshes the widget.
Future<void> syncWidget({double? lat, double? lng}) async {
  try {
    final data = buildWidgetData(DateTime.now(), lat: lat, lng: lng);
    await _channel.invokeMethod('update', jsonEncode(data));
  } on MissingPluginException {
    // Not running on Android (e.g. tests).
  } catch (_) {
    // The widget is optional; never break the app.
  }
}
