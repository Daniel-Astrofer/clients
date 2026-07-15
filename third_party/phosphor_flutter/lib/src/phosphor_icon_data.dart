import 'package:flutter/widgets.dart';

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
