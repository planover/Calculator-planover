/// 科学键盘组件测试（架构 §T05 要点 6 / PRD §4.1 ⑦）。
///
/// 注入 [FakeEngine]，渲染 [Keypad] 并触发按键：数字键更新文本、长按 `C` 清空、
/// `=` 触发提交写入历史。语义标签用 l10n key 名（测试 bundle 为空，tr 回退到 key）。
///
/// 铁律：不 import `native_engine.dart` / `dart:ffi`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/ui/widgets/keypad.dart';

Widget _harness(CalculatorController calc, LocaleController locale) => MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CalculatorController>.value(value: calc),
        ChangeNotifierProvider<LocaleController>.value(value: locale),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 480, child: Keypad()),
        ),
      ),
    );

void main() {
  testWidgets('点击数字键更新 controller.text', (WidgetTester tester) async {
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
    await tester.tap(find.bySemanticsLabel('9'));
    await tester.pumpAndSettle();

    expect(calc.text, '79');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  testWidgets('长按 C 清空输入', (WidgetTester tester) async {
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
    calc.setText('123');
    await tester.pumpAndSettle();

    await tester.longPress(find.bySemanticsLabel('ui.keypad.clear'));
    await tester.pumpAndSettle();

    expect(calc.text, '');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  testWidgets('= 触发提交并写入历史', (WidgetTester tester) async {
    final FakeEngine fake =
        FakeEngine(previewDisplay: '7', commitDisplay: '9');
    final SettingsController settings =
        SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    await history.load();
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: fake,
      settings: settings,
      history: history,
    );

    await tester.pumpWidget(_harness(calc, locale));
    calc.setText('1+2');
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('ui.keypad.equal'));
    await tester.pumpAndSettle();

    expect(history.entries, hasLength(1));
    expect(calc.text, '');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });
}
