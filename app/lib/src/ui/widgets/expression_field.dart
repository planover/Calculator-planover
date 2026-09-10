/// 表达式输入行（架构 §T05 要点 4 / P1-12 / PRD §4.1 ①）。
///
/// 把 [CalculatorController] 作为 `ChangeNotifier` 依赖：复用其 `text` / `selection`
/// 状态，避免两份真相。用户在软键盘上的输入经 `onExpressionChanged` 回写控制器；
/// 控制器经引擎编辑（括号配对）产生的文本变化再反向同步回本组件的
/// [TextEditingController]（光标任意位置可点、跟随滚动）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/calculator_controller.dart';
import '../../theme/tokens.dart';

/// 表达式输入行。
class ExpressionField extends StatefulWidget {
  /// 构造输入行。
  const ExpressionField({super.key});

  @override
  State<ExpressionField> createState() => _ExpressionFieldState();
}

class _ExpressionFieldState extends State<ExpressionField> {
  final TextEditingController _tec = TextEditingController();
  CalculatorController? _calc;
  bool _selfUpdating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    if (_calc != calc) {
      _calc?.removeListener(_syncFromController);
      _calc = calc;
      calc.addListener(_syncFromController);
    }
    _syncFromController();
  }

  @override
  void dispose() {
    _calc?.removeListener(_syncFromController);
    _tec.dispose();
    super.dispose();
  }

  /// 控制器文本/光标变化 → 同步回 TextField（避免回环：自身更新时跳过）。
  void _syncFromController() {
    final CalculatorController? calc = _calc;
    if (calc == null) {
      return;
    }
    if (_tec.text != calc.text) {
      _selfUpdating = true;
      _tec.value = TextEditingValue(
        text: calc.text,
        selection: calc.selection,
        composing: TextRange.empty,
      );
      _selfUpdating = false;
    } else if (_tec.selection != calc.selection && calc.selection.isValid) {
      // 文本相同但光标移动（如历史回填），同步光标。
      _selfUpdating = true;
      _tec.selection = calc.selection;
      _selfUpdating = false;
    }
  }

  void _onChanged(String value) {
    if (_selfUpdating) {
      return;
    }
    _calc?.onExpressionChanged(value, _tec.selection);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'expression',
      textField: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.displayPad,
          vertical: Tokens.padSm,
        ),
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: TextField(
            controller: _tec,
            onChanged: _onChanged,
            // 自定义键盘为主输入，避免软键盘与按键区重叠（P1-12 仍支持点击定位光标）。
            keyboardType: TextInputType.none,
            textAlign: TextAlign.right,
            autofocus: false,
            cursorColor: Theme.of(context).colorScheme.primary,
            style: TextStyle(
              fontSize: Tokens.fontSizeExpr,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: const InputDecoration.collapsed(hintText: ''),
          ),
        ),
      ),
    );
  }
}
