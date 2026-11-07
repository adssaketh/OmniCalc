import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../state/app_settings.dart';
import '../../state/navigation_state.dart';
import '../../state/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Overlay set used until Phase 5 supplies the History tape, the Settings modal and the Guide: a small sheet that edits
/// the settings the shell reads (theme, colour mode, bars, edge effect). It is scaffolding, not a port, and Phase 5
/// replaces it with `SettingsModal`.
List<Widget> devOverlays(BuildContext context, NavigationState nav) {
  return [
    if (nav.isSettingsOpen) const _DevSettingsSheet(),
  ];
}

class _DevSettingsSheet extends StatelessWidget {
  const _DevSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final t = M3Theme.of(context);
    final nav = context.read<NavigationState>();
    final store = context.watch<SettingsStore>();
    final s = store.settings;

    void pickTheme(String id) {
      store.markThemeUserSet();
      store.update((c) => c.copyWith(theme: id));
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => nav.setSettingsOpen(false),
              child: ColoredBox(color: t.scrim),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings (Phase 3 preview)', style: appText(size: 18, weight: FontWeight.w700, color: t.onSurface)),
                      const SizedBox(height: 4),
                      Text('Replaced by the real Settings modal in Phase 5.', style: appText(size: 12, color: t.onSurfaceVariant)),
                      _group(t, 'Theme', [
                        for (final id in const [
                          ThemeIds.dynamic,
                          ThemeIds.iris,
                          ThemeIds.ocean,
                          ThemeIds.forest,
                          ThemeIds.sunset,
                          ThemeIds.amoled,
                        ])
                          _Chip(t, id, s.theme == id, () => pickTheme(id)),
                      ]),
                      _group(t, 'Colour mode', [
                        for (final m in ColorMode.values)
                          _Chip(t, m.name, s.colorMode == m, () => store.update((c) => c.copyWith(colorMode: m))),
                      ]),
                      _group(t, 'Bars', [
                        for (final b in BarStyle.values)
                          _Chip(t, b.name, s.barStyle == b, () => store.update((c) => c.copyWith(barStyle: b))),
                        _Chip(t, 'glass edge', s.glassEdge, () => store.update((c) => c.copyWith(glassEdge: !c.glassEdge))),
                      ]),
                      _group(t, 'Glass blur', [
                        for (final b in GlassBlur.values)
                          _Chip(t, b.name, s.glassBlur == b, () => store.update((c) => c.copyWith(glassBlur: b))),
                      ]),
                      _group(t, 'Glass transparency', [
                        for (final v in const [40, 55, 70, 85])
                          _Chip(t, '$v', s.glassTransparency == v, () => store.update((c) => c.copyWith(glassTransparency: v))),
                      ]),
                      _group(t, 'Edge effect', [
                        for (final e in EdgeEffect.values)
                          _Chip(t, e.name, s.edgeEffect == e, () => store.update((c) => c.copyWith(edgeEffect: e))),
                      ]),
                      _group(t, 'Fade height', [
                        for (final f in FadeHeight.values)
                          _Chip(t, f.name, s.fadeHeight == f, () => store.update((c) => c.copyWith(fadeHeight: f))),
                      ]),
                      _group(t, 'Tabs', [
                        _Chip(t, 'physics', s.enablePhysics, () => store.update((c) => c.copyWith(enablePhysics: !c.enablePhysics))),
                        _Chip(t, 'grapher', s.enableGrapher, () => store.update((c) => c.copyWith(enableGrapher: !c.enableGrapher))),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(M3Tokens t, String title, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: appText(size: 12, weight: FontWeight.w600, color: t.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.t, this.label, this.selected, this.onTap);

  final M3Tokens t;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? t.secondaryContainer : t.surfaceContainerHigh,
            borderRadius: const BorderRadius.all(Radius.circular(9999)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: appText(
                size: 12,
                weight: FontWeight.w600,
                color: selected ? t.onSecondaryContainer : t.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
