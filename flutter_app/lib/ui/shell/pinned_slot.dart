import 'package:flutter/widgets.dart';

/// The `pinnedSlot` of App.tsx: a place under the header where the calculator parks its answer display (the web app
/// portals into it). A screen calls [set] with the widget and [clear] when it goes away; the shell shows the slot only
/// while it holds something (`empty:hidden`).
class PinnedSlotController extends ChangeNotifier {
  Widget? _widget;

  Widget? get widget => _widget;
  bool get isEmpty => _widget == null;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void set(Widget? w) {
    // a screen may clear the slot in a post-frame callback after the shell (the owner) is gone
    if (_disposed || identical(_widget, w)) return;
    _widget = w;
    notifyListeners();
  }

  void clear() => set(null);
}
