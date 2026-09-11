/// 记忆寄存器测试（PRD §13.1 CP-07 / CP-16）。
///
/// - `M` 指示器：记忆为 0 时隐藏，非零时显示（CP-07）；
/// - 历史标记：用过 `MR` 的表达式提交后，历史条目 `usedMemory` 为 true（CP-16）。
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
import 'package:calculator_planover/src/ui/widgets/display_panel.dart';

/// 构造一套测试用控制器。
({CalculatorController calc, LocaleController locale, HistoryController history}) _make() {
  final SettingsController settings = SettingsController(store: MemorySettingsStore());
  final HistoryController history = HistoryController(MemoryHistoryRepository());
  final LocaleController locale = LocaleController(store: MemorySettingsStore());
  final CalculatorController calc = CalculatorController(
    engine: FakeEngine(),
    settings: settings,
    history: history,
  );
  return (calc: calc, locale: locale, history: history);
}

Widget _panel(CalculatorController calc, LocaleController locale) => MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CalculatorController>.value(value: calc),
        ChangeNotifierProvider<LocaleController>.value(value: locale),
      ],
      child: const MaterialApp(home: Scaffold(body: DisplayPanel())),
    );

void main() {
  testWidgets('M 指示器：记忆为 0 隐藏，非零显示（CP-07）',
      (WidgetTester tester) async {
    final m = _make();
    await tester.pumpWidget(_panel(m.calc, m.locale));

    // 初始记忆为 0：无 M 徽标。
    expect(m.calc.hasMemory, isFalse);
    expect(find.text('M'), findsNothing);

    // 累加记忆：文本 5 → M+ → 记忆 = 5。
    m.calc.setText('5');
    await tester.pumpAndSettle();
    m.calc.memoryAdd();
    await tester.pumpAndSettle();

    expect(m.calc.hasMemory, isTrue);
    expect(find.text('M'), findsWidgets);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
  });

  test('用过 MR 的表达式提交后历史标记 usedMemory=true（CP-16）', () async {
    final m = _make();
    await m.history.load();

    // MR 回插记忆值（FakeEngine 记忆初始为 0，text='0'），标记 usedMemory。
    m.calc.memoryRecall();
    expect(m.calc.hasMemory, isFalse); // MR 不改 hasMemory 判断，但置位 usedMemory
    await m.calc.commit();

    expect(m.history.entries, hasLength(1));
    expect(m.history.entries.first.usedMemory, isTrue);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
  });

  test('未用 MR 的表达式提交后 usedMemory=false', () async {
    final m = _make();
    await m.history.load();

    m.calc.setText('1+2');
    await m.calc.commit();

    expect(m.history.entries.first.usedMemory, isFalse);

    m.calc.dispose();
    m.history.dispose();
    m.locale.dispose();
  });
}
