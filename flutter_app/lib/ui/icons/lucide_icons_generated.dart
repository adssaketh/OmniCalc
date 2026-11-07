// GENERATED FILE - DO NOT EDIT.
// Source of truth: lucide-react 0.546.0 (the web app's icon library), icons: copy, check, delete, corner-down-left, chevron-up, rotate-ccw.
// Regenerate with: node flutter_app/tools/gen_lucide_paths.mjs
// ignore_for_file: prefer_const_constructors

import 'dart:ui';

enum LucideIconId { copy, check, delete, cornerDownLeft, chevronUp, rotateCcw }

/// lucide "copy"
Path _lucideCopy() {
  final p = Path();
  p.addRRect(RRect.fromRectXY(Rect.fromLTWH(8.0, 8.0, 14.0, 14.0), 2.0, 2.0));
  p.moveTo(4.0, 16.0);
  p.cubicTo(2.9, 16.0, 2.0, 15.1, 2.0, 14.0);
  p.lineTo(2.0, 4.0);
  p.cubicTo(2.0, 2.9, 2.9, 2.0, 4.0, 2.0);
  p.lineTo(14.0, 2.0);
  p.cubicTo(15.1, 2.0, 16.0, 2.9, 16.0, 4.0);
  return p;
}

/// lucide "check"
Path _lucideCheck() {
  final p = Path();
  p.moveTo(20.0, 6.0);
  p.lineTo(9.0, 17.0);
  p.lineTo(4.0, 12.0);
  return p;
}

/// lucide "delete"
Path _lucideDelete() {
  final p = Path();
  p.moveTo(10.0, 5.0);
  p.arcToPoint(const Offset(8.656, 5.519), radius: const Radius.elliptical(2.0, 2.0), rotation: 0.0, largeArc: false, clockwise: false);
  p.lineTo(2.328, 11.259);
  p.arcToPoint(const Offset(2.328, 12.74), radius: const Radius.elliptical(1.0, 1.0), rotation: 0.0, largeArc: false, clockwise: false);
  p.lineTo(8.656, 18.481);
  p.arcToPoint(const Offset(10.0, 19.0), radius: const Radius.elliptical(2.0, 2.0), rotation: 0.0, largeArc: false, clockwise: false);
  p.lineTo(20.0, 19.0);
  p.arcToPoint(const Offset(22.0, 17.0), radius: const Radius.elliptical(2.0, 2.0), rotation: 0.0, largeArc: false, clockwise: false);
  p.lineTo(22.0, 7.0);
  p.arcToPoint(const Offset(20.0, 5.0), radius: const Radius.elliptical(2.0, 2.0), rotation: 0.0, largeArc: false, clockwise: false);
  p.close();
  p.moveTo(12.0, 9.0);
  p.lineTo(18.0, 15.0);
  p.moveTo(18.0, 9.0);
  p.lineTo(12.0, 15.0);
  return p;
}

/// lucide "corner-down-left"
Path _lucideCornerDownLeft() {
  final p = Path();
  p.moveTo(20.0, 4.0);
  p.lineTo(20.0, 11.0);
  p.arcToPoint(const Offset(16.0, 15.0), radius: const Radius.elliptical(4.0, 4.0), rotation: 0.0, largeArc: false, clockwise: true);
  p.lineTo(4.0, 15.0);
  p.moveTo(9.0, 10.0);
  p.lineTo(4.0, 15.0);
  p.lineTo(9.0, 20.0);
  return p;
}

/// lucide "chevron-up"
Path _lucideChevronUp() {
  final p = Path();
  p.moveTo(18.0, 15.0);
  p.lineTo(12.0, 9.0);
  p.lineTo(6.0, 15.0);
  return p;
}

/// lucide "rotate-ccw"
Path _lucideRotateCcw() {
  final p = Path();
  p.moveTo(3.0, 12.0);
  p.arcToPoint(const Offset(12.0, 3.0), radius: const Radius.elliptical(9.0, 9.0), rotation: 0.0, largeArc: true, clockwise: false);
  p.arcToPoint(const Offset(5.26, 5.74), radius: const Radius.elliptical(9.75, 9.75), rotation: 0.0, largeArc: false, clockwise: false);
  p.lineTo(3.0, 8.0);
  p.moveTo(3.0, 3.0);
  p.lineTo(3.0, 8.0);
  p.lineTo(8.0, 8.0);
  return p;
}

/// Builders of the 24 x 24 stroke icons.
final Map<LucideIconId, Path Function()> kLucideIconBuilders = <LucideIconId, Path Function()>{
  LucideIconId.copy: _lucideCopy,
  LucideIconId.check: _lucideCheck,
  LucideIconId.delete: _lucideDelete,
  LucideIconId.cornerDownLeft: _lucideCornerDownLeft,
  LucideIconId.chevronUp: _lucideChevronUp,
  LucideIconId.rotateCcw: _lucideRotateCcw,
};
