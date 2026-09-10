/// 表达式输入行组件测试（架构 §T05 要点 4 / P1-12）。
///
/// 注入 [FakeEngine] + [MemorySettingsStore]，用 `MaterialApp` + `MultiProvider`
/// 包一个 [ExpressionField]（并附带 [Keypad] 以便触发按键交互）。验证：按键编辑、
/// 光标位置、括号插入。
///
/// 铁律：不 import `native_engine.dart` / `dart:ffi`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/ui/widgets/expression_field.dart';
import 'package:calculator_planover/src/ui/widgets/keypad.dart';

Widget _harness(CalculatorController calc, LocaleController locale) => MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CalculatorController>.value(value: calc),
        ChangeNotifierProvider<LocaleController>.value(value: locale),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              const ExpressionField(),
              SizedBox(height: 420, child: Keypad()),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('点击数字键更新表达式文本', (WidgetTester tester) async {
    final FakeEngine fake = FakeEngine();
    final SettingsController settings =
        SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: fake,
      settings: settings,
      history: history,
    );

    await tester.pumpWidget(_harness(calc, locale));

    await tester.tap(find.bySemanticsLabel('7'));
    await tester.pumpAndSettle();
    expect(calc.text, '7');

    await tester.tap(find.bySemanticsLabel('ui.keypad.plus'));
    await tester.pumpAndSettle();
    expect(calc.text, '7+');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  testWidgets('光标随插入移动', (WidgetTester tester) async {
    final FakeEngine fake = FakeEngine();
    final SettingsController settings =
        SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: fake,
      settings: settings,
      history: history,
    );

    await tester.pumpWidget(_harness(calc, locale));

    await tester.tap(find.bySemanticsLabel('7'));
    await tester.tap(find.bySemanticsLabel('8'));
    await tester.pumpAndSettle();

    expect(calc.text, '78');
    expect(calc.selection.baseOffset, 2);

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  testWidgets('插入括号更新文本与光标', (WidgetTester tester) async {
    final FakeEngine fake = FakeEngine();
    final SettingsController settings =
        SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: fake,
      settings: settings,
      history: history,
    );

    await tester.pumpWidget(_harness(calc, locale));

    await tester.tap(find.bySemanticsLabel('ui.keypad.openParen'));
    await tester.pumpAndSettle();
    expect(calc.text, '(');
    expect(calc.selection.baseOffset, 1);

    await tester.tap(find.bySemanticsLabel('ui.keypad.closeParen'));
    await tester.pumpAndSettle();
    expect(calc.text, '()');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });
}
