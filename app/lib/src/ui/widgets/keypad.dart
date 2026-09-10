/// 科学键盘（架构 §T05 要点 6 / PRD §4.1 ⑦）。
///
/// 5×5 网格，每个键都有行为、无死键。所有插入 / 删除均经
/// [CalculatorController.applyEdit] 走引擎（R1：Dart 不实现编辑逻辑）。
/// 运算符用引擎接受的 Unicode 字形（`×` `÷` `−`），与 Rust lexer 对齐。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../widgets/key_button.dart';

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

    final List<List<Widget>> rows = <List<Widget>>[
      <Widget>[
        KeyButton(
          label: Text(l10n.tr('ui.keypad.clear')),
          semanticLabel: l10n.tr('ui.keypad.clear'),
          tone: KeyTone.danger,
          onTap: calc.clearInput,
          onLongPress: calc.reset,
        ),
        _insert('(', l10n.tr('ui.keypad.openParen'), calc),
        _insert(')', l10n.tr('ui.keypad.closeParen'), calc),
        KeyButton(
          label: const Text('⌫'),
          semanticLabel: l10n.tr('ui.keypad.backspace'),
          tone: KeyTone.function,
          onTap: () => calc.applyEdit('backspace'),
          onLongPressStart: () => calc.applyEdit('backspace'),
          onLongPressEnd: () {},
        ),
        _insert('÷', l10n.tr('ui.keypad.divide'), calc),
      ],
      <Widget>[
        _digit('7', calc),
        _digit('8', calc),
        _digit('9', calc),
        _insert('×', l10n.tr('ui.keypad.multiply'), calc),
        _insert('^', l10n.tr('ui.keypad.power'), calc),
      ],
      <Widget>[
        _digit('4', calc),
        _digit('5', calc),
        _digit('6', calc),
        _insert('−', l10n.tr('ui.keypad.minus'), calc),
        _insert('√(', l10n.tr('ui.keypad.sqrt'), calc),
      ],
      <Widget>[
        _digit('1', calc),
        _digit('2', calc),
        _digit('3', calc),
        _insert('+', l10n.tr('ui.keypad.plus'), calc),
        _insert('ans', l10n.tr('ui.keypad.ans'), calc),
      ],
      <Widget>[
        _digit('0', calc, span: 2),
        _insert('.', l10n.tr('ui.keypad.decimal'), calc),
        _insert('(-', l10n.tr('ui.keypad.negate'), calc),
        KeyButton(
          label: Text(l10n.tr('ui.keypad.equal')),
          semanticLabel: l10n.tr('ui.keypad.equal'),
          tone: KeyTone.accent,
          onTap: () => calc.commit(),
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

KeyButton _digit(String d, CalculatorController calc, {int span = 1}) =>
    KeyButton(
      label: Text(d),
      semanticLabel: d,
      tone: KeyTone.normal,
      span: span,
      onTap: () => calc.applyEdit('insert', payload: d),
    );

KeyButton _insert(
  String sym,
  String semantic,
  CalculatorController calc, {
  KeyTone tone = KeyTone.function,
}) =>
    KeyButton(
      label: Text(sym),
      semanticLabel: semantic,
      tone: tone,
      onTap: () => calc.applyEdit('insert', payload: sym),
    );
