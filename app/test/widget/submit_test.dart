/// 提交方式测试（PRD §3.2 UI-13）。
///
/// 默认 auto（calculate-on-fly）：结果实时可见；切到 manual 后编辑时隐藏结果，
/// 显式提交后再次可见。验证 [CalculatorController.livePreview] / [resultVisible]。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/models/submit_mode.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';

void main() {
  test('默认 auto：livePreview 开启', () {
    final SettingsController settings = SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: FakeEngine(),
      settings: settings,
      history: history,
    );

    expect(settings.submitMode, SubmitMode.auto);
    expect(calc.livePreview, isTrue);
    expect(calc.resultVisible, isTrue);

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  test('切到 manual：编辑时隐藏结果，提交后可见（UI-13）', () async {
    final SettingsController settings = SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: FakeEngine(),
      settings: settings,
      history: history,
    );

    await settings.setSubmitMode(SubmitMode.manual);
    expect(calc.livePreview, isFalse);

    // 开始输入 → 未显式提交 → 结果区隐藏。
    calc.setText('1+2');
    expect(calc.resultVisible, isFalse);

    // 显式提交 → 结果再次可见。
    await calc.commit();
    expect(calc.resultVisible, isTrue);

    calc.dispose();
    history.dispose();
    locale.dispose();
  });

  test('manual 模式提交写入历史', () async {
    final SettingsController settings = SettingsController(store: MemorySettingsStore());
    final HistoryController history = HistoryController(MemoryHistoryRepository());
    await history.load();
    final LocaleController locale = LocaleController(store: MemorySettingsStore());
    final CalculatorController calc = CalculatorController(
      engine: FakeEngine(commitDisplay: '9'),
      settings: settings,
      history: history,
    );

    await settings.setSubmitMode(SubmitMode.manual);
    calc.setText('1+2');
    await calc.commit();
    expect(history.entries, hasLength(1));
    expect(calc.text, '');

    calc.dispose();
    history.dispose();
    locale.dispose();
  });
}
