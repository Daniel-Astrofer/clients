import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// Simple binary calculator state for amount entry.
class AmountCalculatorState {
  final String? lhs;
  final String? op;
  final String display;

  const AmountCalculatorState({
    this.lhs,
    this.op,
    this.display = '0',
  });

  AmountCalculatorState copyWith({
    String? lhs,
    String? op,
    String? display,
    bool clearLhs = false,
    bool clearOp = false,
  }) {
    return AmountCalculatorState(
      lhs: clearLhs ? null : (lhs ?? this.lhs),
      op: clearOp ? null : (op ?? this.op),
      display: display ?? this.display,
    );
  }
}

/// Applies calculator ops (+ − × ÷ =) over an editable amount string.
class AmountCalculator {
  AmountCalculator._();

  static AmountCalculatorState onOperator({
    required AmountCalculatorState state,
    required String operator,
    required Currency currency,
  }) {
    if (operator == '=') {
      return _equals(state, currency);
    }

    final current = state.display.trim().isEmpty ? '0' : state.display;
    if (state.op != null && state.lhs != null) {
      final evaluated = _equals(state, currency);
      return AmountCalculatorState(
        lhs: evaluated.display,
        op: operator,
        display: '0',
      );
    }

    return AmountCalculatorState(
      lhs: current,
      op: operator,
      display: '0',
    );
  }

  static AmountCalculatorState _equals(
    AmountCalculatorState state,
    Currency currency,
  ) {
    final op = state.op;
    final lhsRaw = state.lhs;
    if (op == null || lhsRaw == null) return state;

    final a = MoneyDisplay.parseEditableInput(lhsRaw);
    final b = MoneyDisplay.parseEditableInput(state.display);
    double result;
    switch (op) {
      case '+':
        result = a + b;
      case '−':
      case '-':
        result = a - b;
      case '×':
      case '*':
        result = a * b;
      case '÷':
      case '/':
        result = b == 0 ? a : a / b;
      default:
        return state;
    }

    if (result.isNaN || result.isInfinite || result < 0) {
      result = 0;
    }

    final formatted = _formatResult(result, currency);
    return AmountCalculatorState(display: formatted);
  }

  static String _formatResult(double value, Currency currency) {
    final maxDecimals = currency == Currency.btc ? 8 : 2;
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    if (text.isEmpty || text == '-') text = '0';
    return MoneyDisplay.sanitizeEditableInput(
      rawValue: text,
      currency: currency,
      maxLength: currency == Currency.btc ? 16 : 14,
    );
  }
}

/// Rounded operator pills shown above the native keyboard / CTA.
class AmountCalculatorToolbar extends StatelessWidget {
  final ValueChanged<String> onOperator;

  const AmountCalculatorToolbar({
    super.key,
    required this.onOperator,
  });

  static const _ops = ['+', '−', '×', '÷', '='];

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, keyboardOpen ? 0 : 4, 20, keyboardOpen ? 0 : 4),
      child: Row(
        children: [
          for (final op in _ops) ...[
            if (op != _ops.first) const SizedBox(width: 8),
            Expanded(
              child: _CalcOpPill(
                label: op,
                onTap: () => onOperator(op),
                compact: keyboardOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalcOpPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _CalcOpPill({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_CalcOpPill> createState() => _CalcOpPillState();
}

class _CalcOpPillState extends State<_CalcOpPill>
    with SingleTickerProviderStateMixin {
  static const _pressScale = 0.94;
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1, end: _pressScale).animate(
      CurvedAnimation(
        parent: _press,
        curve: Curves.easeInCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    widget.onTap();
    if (!mounted || KeroseneMotion.reduceMotion(context)) return;
    await _press.forward(from: 0);
    if (mounted) await _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _handleTap,
          child: SizedBox(
            height: widget.compact ? 36 : 40,
            child: Center(
              child: Text(
                widget.label,
                style: AppTypography.inter(
                  color: Colors.white,
                  fontSize: widget.compact ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
