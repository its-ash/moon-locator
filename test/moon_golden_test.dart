import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moon_locator/moon_art.dart';

void main() {
  testWidgets('moon phases', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ColoredBox(
          color: const Color(0xFF0B1026),
          child: RepaintBoundary(
            child: Wrap(
              children: [
                for (final (f, w) in [(0.08, true), (0.3, true), (0.5, true), (0.75, true), (1.0, true), (0.7, false), (0.4, false), (0.15, false)])
                  MoonArt(size: 200, fraction: f, waxing: w, glow: 0.8),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('moon.png'));
  });
}
