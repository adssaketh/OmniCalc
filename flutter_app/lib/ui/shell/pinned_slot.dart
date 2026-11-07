import 'package:flutter/widgets.dart';

/// The `pinnedSlot` of App.tsx: a place under the header where the calculator parks its answer display (the web app
/// portals into it). A screen calls [set] with the widget and [clear] when it goes away; the shell shows the slot only
/// while it holds something (`empty:hidden`).
class PinnedSlotController extends ChangeNotifier {
  Widget? _widget;

  Widget? get widget => _widget;
  bool get isEmpty => _widget == null;

  void set(Widget? w) {
    if (identical(_widget, w)) return;
    _widget = w;
    notifyListeners();
  }

  void clear() => set(null);
}
