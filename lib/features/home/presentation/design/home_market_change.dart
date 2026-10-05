/// Presentation direction follows the rounded percentage visible to the user.
/// Missing quotes and changes rounding to zero must not imply a gain or loss.
class HomeMarketChange {
  final double? percent;

  HomeMarketChange(double? value)
      : percent = value != null && value.isFinite
            ? double.parse(value.toStringAsFixed(2))
            : null;

  int get direction => percent == null || percent == 0
      ? 0
      : percent! > 0
          ? 1
          : -1;

  String get sign => direction > 0
      ? '+'
      : direction < 0
          ? '-'
          : '';

  String? absoluteLabel({required bool decimalComma}) => percent
      ?.abs()
      .toStringAsFixed(2)
      .replaceAll('.', decimalComma ? ',' : '.');
}
