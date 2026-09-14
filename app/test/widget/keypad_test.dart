/// 科学键盘组件测试（架构 §T05 要点 6 / PRD §3.2 主键盘 5×5）。
///
/// 注入 [FakeEngine]，渲染 [Keypad] 并触发按键：验证严格 5×5 键位、不含 `=`、
/// 光标移动、`%`、智能括号、记忆/函数/历史入口。语义标签用 l10n key 名
/// （测试 bundle 为空，tr 回退到 key）。
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
import 'package:calculator_planover/src/state/region_format_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/ui/widgets/key_button.dart';
import 'package:calculator_planover/src/ui/widgets/keypad.dart';

Widget _harness(CalculatorController calc, LocaleController locale,
    RegionFormatController region, HistoryController history) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<CalculatorController>.value(value: calc),
      ChangeNotifierProvider<LocaleController>.value(value: locale),
      ChangeNotifierProvider<RegionFormatController>.value(value: region),
      ChangeNotifierProvider<HistoryController>.value(value: history),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 480, child: Keypad()),
      ),
    ),
  );
}

/// 构造一套测试用控制器。
({CalculatorController calc, LocaleController locale, RegionFormatController region,
  HistoryController history}) _make() {
  final SettingsController settings = SettingsController(store: MemorySettingsStore());
  final HistoryController history = HistoryController(MemoryHistoryRepository());
  final LocaleController locale = LocaleController(store: MemorySettingsStore());
  final RegionFormatController region = RegionFormatController();
  final CalculatorController calc = CalculatorController(
    engine: FakeEngine(),
    settings: settings,
    history: history,
  );
  return (calc: calc, locale: locale, region: region, history: history);
}

void main() {
  testWidgets('主键盘严格 5×5，且不含 = 键', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    // 25 个按键均存在（含 M / π / ƒ / 🕘 等语义键）。
    expect(find.byType(KeyButton), findsNWidgets(25));
    // 不含 = 键（UI-10）。
    expect(find.text('='), findsNothing);
    expect(find.bySemanticsLabel('ui.keypad.equal'), findsNothing);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('数字键更新 controller.text', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    await tester.tap(find.bySemanticsLabel('7'));
    await tester.tap(find.bySemanticsLabel('9'));
    await tester.pumpAndSettle();

    expect(m.calc.text, '79');

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('← / → 移动光标（UI-16）', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    m.calc.setText('1+2');
    await tester.pumpAndSettle();
    m.calc.moveCursorLeft();
    expect(m.calc.selection.baseOffset, 2);
    m.calc.moveCursorRight();
    expect(m.calc.selection.baseOffset, 3);
    // 边界不动且不报错。
    m.calc.moveCursorRight();
    expect(m.calc.selection.baseOffset, 3);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('% 键插入百分号', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    await tester.tap(find.bySemanticsLabel('ui.keypad.percent'));
    await tester.pumpAndSettle();
    expect(m.calc.text, '%');

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('( ) 合并键智能插入括号（UI-09）', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    m.calc.setText('1+2');
    await tester.pumpAndSettle();
    m.calc.insertSmartParen();
    expect(m.calc.text, '1+2(');

    m.calc.setText('(1+2');
    await tester.pumpAndSettle();
    m.calc.insertSmartParen();
    expect(m.calc.text, '(1+2)');

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('长按 C 清空输入', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    m.calc.setText('123');
    await tester.pumpAndSettle();
    await tester.longPress(find.bySemanticsLabel('ui.keypad.clear'));
    await tester.pumpAndSettle();
    expect(m.calc.text, '');

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('M 键展开记忆面板（UI-05）', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    await tester.tap(find.bySemanticsLabel('ui.keypad.memory'));
    await tester.pumpAndSettle();
    // 记忆面板含标题与四项操作。
    expect(find.text('ui.memory.title'), findsWidgets);
    expect(find.text('ui.memory.add'), findsWidgets);
    expect(find.text('ui.memory.subtract'), findsWidgets);
    expect(find.text('ui.memory.clear'), findsWidgets);
    expect(find.text('ui.memory.recall'), findsWidgets);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('ƒ 键展开科学函数面板（UI-07）', (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    await tester.tap(find.bySemanticsLabel('ui.keypad.science'));
    await tester.pumpAndSettle();
    expect(find.text('ƒ'), findsWidgets);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });

  testWidgets('🕘 键拉起历史抽屉（UI-08）', (WidgetTester tester) async {
    final m = _make();
    await m.history.load();
    await tester.pumpWidget(_harness(m.calc, m.locale, m.region, m.history));

    await tester.tap(find.bySemanticsLabel('ui.keypad.history'));
    await tester.pumpAndSettle();
    expect(find.text('ui.history.title'), findsWidgets);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
    m.region.dispose();
  });
}
