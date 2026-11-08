import 'package:flutter/widgets.dart';

import '../../state/navigation_state.dart';
import 'guide_sheet.dart';
import 'history_tape_sheet.dart';
import 'settings_sheet.dart';

/// The layers above the shell, in the stacking order of App.tsx: the History tape, Settings (with the sheets it opens)
/// and the User guide. Each one stays in the tree while closed (as the web components do) and draws nothing once its
/// exit animation is over.
List<Widget> appOverlays(BuildContext context, NavigationState nav) => const [
      Positioned.fill(child: HistoryTapeSheet()),
      Positioned.fill(child: SettingsSheet()),
      Positioned.fill(child: GuideSheet()),
    ];
