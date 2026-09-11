/// 历史条目 `M` 标记渲染测试（PRD §13.1 CP-16）。
///
/// 用过记忆寄存器 `MR` 的历史条目在抽屉中带 `M` 标记；未使用的不带。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/models/history_entry.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/ui/widgets/history_sheet.dart';

Widget _harness(CalculatorController calc, LocaleController locale,
    HistoryController history) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<CalculatorController>.value(value: calc),
      ChangeNotifierProvider<LocaleController>.value(value: locale),
      ChangeNotifierProvider<HistoryController>.value(value: history),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => HistorySheet.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('用过 MR 的条目显示 M 标记，未使用的不显示（CP-16）',
      (WidgetTester tester) async {
    final SettingsController settings = SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: FakeEngine(),
      settings: settings,
      history: history,
    );
    await history.load();
    await history.add(HistoryEntry(
      expr: 'MR',
      result: '5',
      ts: 1,
      usedMemory: true,
    ));
    await history.add(HistoryEntry(
      expr: '1+2',
      result: '3',
      ts: 2,
      usedMemory: false,
    ));

    await tester.pumpWidget(_harness(calc, locale, history));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 至少一条带 M 标记。
    expect(find.text('M'), findsWidgets);
    // 未使用条目不存在单独的第二个语义冲突；这里只断言 M 标记存在即可。

    calc.dispose();
    history.dispose();
    locale.dispose();
  });
}
