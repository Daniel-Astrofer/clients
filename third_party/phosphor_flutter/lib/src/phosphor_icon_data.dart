import 'package:flutter/widgets.dart';
// Dynamic font tables cannot satisfy IconData's const-parameter lint.
// ignore_for_file: non_const_argument_for_const_parameter

/// Legacy alias — Phosphor tables now use plain [IconData].
typedef PhosphorIconData = IconData;

/// Build a Phosphor [IconData] for the given style suffix (non-const helper).
IconData phosphorIcon(int codePoint, String style) {
  return IconData(
    codePoint,
    fontFamily: 'Phosphor$style',
    fontPackage: 'phosphor_flutter',
    matchTextDirection: true,
  );
}
