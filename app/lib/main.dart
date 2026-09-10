/// 应用入口（架构 §T05 要点 1 / 2）。
///
/// 装配顺序：`ensureInitialized` → 构造 `NativeEngine`（失败也记录错误、不崩）
/// → 构造各 Controller（store 注入）→ `runApp(MyApp)`。
///
/// 这是**全项目唯一允许 import `native_engine.dart` / `dart:ffi`** 的地方
/// （架构风险 R3：测试进程加载不到 `.so` 会崩，故测试只注入 [FakeEngine]）。
library;

import 'package:flutter/material.dart';

import 'src/engine/native_engine.dart';
import 'src/engine/fake_engine.dart';
import 'src/engine/engine_gateway.dart';
import 'src/state/calculator_controller.dart';
import 'src/state/history_controller.dart';
import 'src/state/locale_controller.dart';
import 'src/state/settings_controller.dart';
import 'src/storage/settings_store.dart';
import 'src/storage/sqflite_history_repository.dart';
import 'app.dart';

/// 应用入口。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 构造引擎：失败也要能显示错误页，不要崩（架构 §T05 要点 1）。
  EngineGateway? engine;
  try {
    engine = NativeEngine();
  } catch (e, stack) {
    // 记录错误，交给 MyApp 渲染错误页。
    debugPrint('引擎初始化失败：$e');
    debugPrint(stack.toString());
  }

  final SettingsStore store = SharedPreferencesSettingsStore();
  final SettingsController settings = SettingsController(store: store);
  final LocaleController locale = LocaleController(store: store);
  await settings.load();
  await locale.load();

  final HistoryController history = HistoryController(SqfliteHistoryRepository());
  await history.load();

  // 引擎初始化失败时退回 FakeEngine 占位，保证 UI 仍能装配（错误页叠加显示）。
  final EngineGateway activeEngine = engine ?? FakeEngine();
  final CalculatorController calc = CalculatorController(
    engine: activeEngine,
    settings: settings,
    history: history,
  );

  runApp(MyApp(
    settings: settings,
    locale: locale,
    history: history,
    calculator: calc,
    engineOk: engine != null,
  ));
}
