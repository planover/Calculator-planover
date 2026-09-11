/// 科学键盘（架构 §T05 要点 6 / PRD §3.2 主键盘 5×5）。
///
/// **严格 5 行 × 5 列，每行等权 5 键**（UI-04），**不含 `=` 键**（UI-10 / 裁决 D1）。
/// 键位严格仿照 Calculator++ 2.3.3：
/// - 行1：`←` `→` `%` `⌫` `C`
/// - 行2：`7` `8` `9` `÷` `M`（记忆）
/// - 行3：`4` `5` `6` `×` `π`（常量）
/// - 行4：`1` `2` `3` `−` `ƒ`（科学函数）
/// - 行5：`( )`（智能括号）`0` `.`（区域小数键面）`+` `🕘`（历史）
///
/// 所有插入 / 删除均经 [CalculatorController.applyEdit] 走引擎（R1：Dart 不实现编辑逻辑）。
/// 运算符用引擎接受的 Unicode 字形（`×` `÷` `−`），与 Rust lexer 对齐。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../state/region_format_controller.dart';
import '../widgets/function_sheet.dart';
import '../widgets/history_sheet.dart';
import '../widgets/key_button.dart';
import '../widgets/memory_sheet.dart';

/// 科学键盘。
class Keypad extends StatelessWidget {
  /// 构造键盘。
  const Keypad({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final RegionFormatController region =
        Provider.of<RegionFormatController>(context, listen: false);
    // 小数点键面：优先区域格式决定的符号，否则回落语言 CLDR（LC-09）。
    // 内部始终插入规范语法 `.`，由表达式渲染层负责反向映射（如需）。
    final String decimal = region.decimalSeparator ?? l10n.decimalSeparator;

    final List<List<Widget>> rows = <List<Widget>>[
      <Widget>[
        _key(
          context,
          label: '←',
          semantic: l10n.tr('ui.keypad.cursorLeft'),
          tone: KeyTone.function,
          onTap: calc.moveCursorLeft,
        ),
        _key(
          context,
          label: '→',
          semantic: l10n.tr('ui.keypad.cursorRight'),
          tone: KeyTone.function,
          onTap: calc.moveCursorRight,
        ),
        _key(
          context,
          label: '%',
          semantic: l10n.tr('ui.keypad.percent'),
          tone: KeyTone.function,
          onTap: () => calc.applyEdit('insert', payload: '%'),
        ),
        _backspace(l10n, calc),
        _clear(l10n, calc),
      ],
      <Widget>[
        _digit(calc, '7'),
        _digit(calc, '8'),
        _digit(calc, '9'),
        _op(l10n, calc, '÷', 'ui.keypad.divide'),
        _key(
          context,
          label: 'M',
          semantic: l10n.tr('ui.keypad.memory'),
          tone: KeyTone.function,
          onTap: () => MemorySheet.show(context),
        ),
      ],
      <Widget>[
        _digit(calc, '4'),
        _digit(calc, '5'),
        _digit(calc, '6'),
        _op(l10n, calc, '×', 'ui.keypad.multiply'),
        _key(
          context,
          label: 'π',
          semantic: l10n.tr('ui.keypad.pi'),
          tone: KeyTone.function,
          onTap: () => calc.applyEdit('insert', payload: 'π'),
        ),
      ],
      <Widget>[
        _digit(calc, '1'),
        _digit(calc, '2'),
        _digit(calc, '3'),
        _op(l10n, calc, '−', 'ui.keypad.minus'),
        _key(
          context,
          label: 'ƒ',
          semantic: l10n.tr('ui.keypad.science'),
          tone: KeyTone.function,
          onTap: () => FunctionSheet.show(context),
        ),
      ],
      <Widget>[
        _key(
          context,
          label: '( )',
          semantic: l10n.tr('ui.keypad.openCloseParen'),
          tone: KeyTone.function,
          onTap: calc.insertSmartParen,
        ),
        _digit(calc, '0'),
        _key(
          context,
          label: decimal,
          semantic: l10n.tr('ui.keypad.decimal'),
          tone: KeyTone.normal,
          onTap: () => calc.applyEdit('insert', payload: '.'),
        ),
        _op(l10n, calc, '+', 'ui.keypad.plus'),
        _key(
          context,
          label: '🕘',
          semantic: l10n.tr('ui.keypad.history'),
          tone: KeyTone.function,
          onTap: () => HistorySheet.show(context),
        ),
      ],
    ];

    return Column(
      children: rows
          .map(
            (List<Widget> row) => Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: row,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// 通用按键构造器。
KeyButton _key(
  BuildContext context, {
  required String label,
  required String semantic,
  required KeyTone tone,
  required VoidCallback onTap,
}) =>
    KeyButton(
      label: Text(label),
      semanticLabel: semantic,
      tone: tone,
      onTap: onTap,
    );

/// 数字键。
KeyButton _digit(CalculatorController calc, String d) => KeyButton(
      label: Text(d),
      semanticLabel: d,
      tone: KeyTone.normal,
      onTap: () => calc.applyEdit('insert', payload: d),
    );

/// 运算符键（Unicode 字形与 Rust lexer 对齐）。
KeyButton _op(
  AppLocalizations l10n,
  CalculatorController calc,
  String sym,
  String semanticKey,
) =>
    KeyButton(
      label: Text(sym),
      semanticLabel: l10n.tr(semanticKey),
      tone: KeyTone.function,
      onTap: () => calc.applyEdit('insert', payload: sym),
    );

/// 退格键（长按连发，UI-17）。
KeyButton _backspace(AppLocalizations l10n, CalculatorController calc) =>
    KeyButton(
      label: const Text('⌫'),
      semanticLabel: l10n.tr('ui.keypad.backspace'),
      tone: KeyTone.function,
      onTap: () => calc.applyEdit('backspace'),
      onLongPressStart: () => calc.applyEdit('backspace'),
      onLongPressEnd: () {},
    );

/// 清除键（短按清输入，长按 reset_session）。
KeyButton _clear(AppLocalizations l10n, CalculatorController calc) => KeyButton(
      label: Text(l10n.tr('ui.keypad.clear')),
      semanticLabel: l10n.tr('ui.keypad.clear'),
      tone: KeyTone.danger,
      onTap: calc.clearInput,
      onLongPress: calc.reset,
    );
