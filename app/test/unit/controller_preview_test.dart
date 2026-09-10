/// 主状态机测试 —— 验证防抖、错误态、提交与编辑（架构 §T05 要点 3）。
///
/// 铁律：**只注入 [FakeEngine]，绝不 import `native_engine.dart` / `dart:ffi`**（R3）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/engine/engine_exception.dart';
import 'package:calculator_planover/src/engine/engine_gateway.dart';
import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/models/eval_result.dart';
import 'package:calculator_planover/src/models/eval_settings.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';

/// 让 `evaluatePreview` 抛出 `incomplete_expression` 的替身，用于错误态测试。
class _IncompleteFakeEngine extends FakeEngine {
  @override
  EvalResult evaluatePreview({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  }) {
    previewCalls++;
    throw EngineException(
      code: 1,
      kind: 'incomplete_expression',
      message: '表达式不完整',
    );
  }
}

void main() {
  group('CalculatorController', () {
    test('连续输入经防抖后只调一次 evaluatePreview', () async {
      final FakeEngine fake = FakeEngine(previewDisplay: '7');
      final SettingsController settings =
          SettingsController(store: MemorySettingsStore());
      final HistoryController history =
          HistoryController(MemoryHistoryRepository());
      final CalculatorController calc = CalculatorController(
        engine: fake,
        settings: settings,
        history: history,
      );

      // 构造时已同步求值一次，清零以隔离本次断言。
      fake.previewCalls = 0;

      calc.onExpressionChanged('1+', const TextSelection.collapsed(offset: 2));
      calc.onExpressionChanged('1+2', const TextSelection.collapsed(offset: 3));
      calc.onExpressionChanged('1+2+', const TextSelection.collapsed(offset: 4));

      // 静默窗口内不应触发。
      expect(fake.previewCalls, 0);
      await Future<void>.delayed(const Duration(milliseconds: 220));
      // 防抖后只触发一次。
      expect(fake.previewCalls, 1);

      calc.dispose();
      history.dispose();
    });

    test('incomplete_expression 不崩且呈灰色态（error 为 null 或 isIncompleteExpression）',
        () async {
      final _IncompleteFakeEngine fake = _IncompleteFakeEngine();
      final SettingsController settings =
          SettingsController(store: MemorySettingsStore());
      final HistoryController history =
          HistoryController(MemoryHistoryRepository());
      final CalculatorController calc = CalculatorController(
        engine: fake,
        settings: settings,
        history: history,
      );

      expect(
        () => calc.onExpressionChanged(
          '1+',
          const TextSelection.collapsed(offset: 2),
        ),
        returnsNormally,
      );
      await Future<void>.delayed(const Duration(milliseconds: 220));

      // 不崩：error 为空或类型为 incomplete_expression（灰色提示）。
      expect(calc.error?.isIncompleteExpression ?? true, isTrue);

      calc.dispose();
      history.dispose();
    });

    test('commit 写入历史并清空输入', () async {
      final FakeEngine fake =
          FakeEngine(previewDisplay: '7', commitDisplay: '9');
      final SettingsController settings =
          SettingsController(store: MemorySettingsStore());
      final HistoryController history =
          HistoryController(MemoryHistoryRepository());
      await history.load();
      final CalculatorController calc = CalculatorController(
        engine: fake,
        settings: settings,
        history: history,
      );

      calc.setText('1+2');
      await calc.commit();

      expect(history.entries, hasLength(1));
      expect(calc.text, '');
      expect(calc.preview, '9');

      calc.dispose();
      history.dispose();
    });

    test('applyEdit(insert) 更新文本与光标', () {
      final FakeEngine fake = FakeEngine();
      final SettingsController settings =
          SettingsController(store: MemorySettingsStore());
      final HistoryController history =
          HistoryController(MemoryHistoryRepository());
      final CalculatorController calc = CalculatorController(
        engine: fake,
        settings: settings,
        history: history,
      );

      calc.setText('12');
      calc.applyEdit('insert', payload: '+');

      expect(calc.text, '12+');
      expect(calc.selection.baseOffset, 3);

      calc.dispose();
      history.dispose();
    });
  });
}
