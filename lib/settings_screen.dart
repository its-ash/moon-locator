import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UiScaffold(
      appBar: UiAppBar(title: 'Settings'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiListGroup(
            header: 'Compass',
            children: [
              UiListTile(
                'Calibrate the compass',
                subtitle: 'If the moon marker drifts, move the phone in a figure 8 a few times. '
                    'Headings are magnetic north, not corrected for declination.',
                icon: Icons.explore_rounded,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiListGroup(
            header: 'Privacy',
            children: [
              UiListTile(
                'Everything stays on this phone',
                subtitle: 'Your location and the camera are used only to place the moon on screen. '
                    'Moon Locator uses the internet only to check for app updates.',
                icon: Icons.lock_rounded,
                iconStatus: UiStatus.success,
              ),
            ],
          ),
          UiGap(UiSpace.lg),
          UiAppearanceSection(),
          UiGap(UiSpace.lg),
          UiUpdateSection(storeId: 'moon-locator'),
          UiGap(UiSpace.lg),
          UiDeveloperSection(),
        ],
      ),
    );
  }
}
