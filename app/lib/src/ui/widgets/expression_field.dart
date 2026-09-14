/// 表达式输入行（架构 §T05 要点 4 / P1-12 / PRD §4.1 ① / LC-09）。
///
/// 把 [CalculatorController] 作为 `ChangeNotifier` 依赖：复用其 `text` / `selection`
/// 状态，避免两份真相。用户在软键盘上的输入经 `onExpressionChanged` 回写控制器；
/// 控制器经引擎编辑（括号配对）产生的文本变化再反向同步回本组件的
/// [TextEditingController]（光标任意位置可点、跟随滚动）。
///
/// **LC-09 双向映射**：控制器内部语法恒为 `.`（引擎约定，A4）。当区域格式使用
/// 非 `.` 小数分隔符（如 de-DE 的 `,`）时：
/// - **显示**：把 `.` 反向映射为区域分隔符再交给 [TextField]（[TextEditingController] 读到 `,`）；
/// - **输入**：用户在文本框里敲的 `,` 由控制器注入的规范化器统一转回 `.`（见 `main.dart`）。
///
/// 反向映射只在本组件内做**逐字符**替换：`.` 与区域分隔符都是单字符，替换保持长度不变，
/// 因此光标偏移不变、无需重算 selection。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/calculator_controller.dart';
import '../../state/region_format_controller.dart';
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

  /// 当前用于**显示**的区域小数分隔符（`null`/`.` 时不做映射）。
  String? _displaySeparator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    // 区域格式可选注入：测试/预览未提供时不做显示映射（A3 / LC-09）。
    final RegionFormatController? region =
        Provider.of<RegionFormatController?>(context, listen: false);
    if (_calc != calc) {
      _calc?.removeListener(_syncFromController);
      _calc = calc;
      calc.addListener(_syncFromController);
    }
    _displaySeparator = _effectiveSeparator(region);
    _syncFromController();
  }

  @override
  void dispose() {
    _calc?.removeListener(_syncFromController);
    _tec.dispose();
    super.dispose();
  }

  /// 解析"显示屏用的"区域分隔符：跟随系统（区域为 null）或 `.` 时返回 null（不映射）。
  ///
  /// 显示映射只取决于区域格式（A3），故不引入语言 CLDR 依赖。
  String? _effectiveSeparator(RegionFormatController? region) {
    final String? sep = region?.decimalSeparator;
    if (sep == null || sep == '.') {
      return null;
    }
    return sep;
  }

  /// 内部 `.` → 显示分隔符。
  String _toDisplay(String internalText) {
    final String? sep = _displaySeparator;
    if (sep == null) {
      return internalText;
    }
    return internalText.replaceAll('.', sep);
  }

  /// 显示分隔符 → 内部 `.`（用于文本框回读时兜底，main 的规范化器是主路径）。
  String _toInternal(String displayText) {
    final String? sep = _displaySeparator;
    if (sep == null) {
      return displayText;
    }
    return displayText.replaceAll(sep, '.');
  }

  /// 控制器文本/光标变化 → 同步回 TextField（避免回环：自身更新时跳过）。
  void _syncFromController() {
    final CalculatorController? calc = _calc;
    if (calc == null) {
      return;
    }
    final String display = _toDisplay(calc.text);
    if (_tec.text != display) {
      _selfUpdating = true;
      _tec.value = TextEditingValue(
        text: display,
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
    // 文本里可能是区域分隔符（如 `,`），控制器注入的规范化器会转回内部 `.`。
    _calc?.onExpressionChanged(_toInternal(value), _tec.selection);
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
    );
  }
}
