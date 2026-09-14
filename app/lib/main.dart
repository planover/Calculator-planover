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
import 'src/models/region_format_request.dart';
import 'src/state/calculator_controller.dart';
import 'src/state/history_controller.dart';
import 'src/state/locale_controller.dart';
import 'src/state/region_format_controller.dart';
import 'src/state/settings_controller.dart';
import 'src/storage/region_format_store.dart';
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

  final SettingsStore store = const SharedPreferencesSettingsStore();
  final SettingsController settings = SettingsController(store: store);
  final LocaleController locale = LocaleController(store: store);

  final HistoryController history = HistoryController(SqfliteHistoryRepository());
  await history.load();

  // 引擎初始化失败时退回 FakeEngine 占位，保证 UI 仍能装配（错误页叠加显示）。
  final EngineGateway activeEngine = engine ?? FakeEngine();

  // 区域格式 → 引擎：把 Dart 侧镜像的数字/货币配置经 `set_region_format` 下发（A1）。
  // 回调捕获 `activeEngine`；启动时若引擎不可用，activeEngine 为 FakeEngine（无害替身）。
  final RegionFormatController region = RegionFormatController(
    store: const SharedPreferencesRegionFormatStore(),
    onRegionFormatChanged: (RegionFormatRequest request) {
      try {
        activeEngine.setRegionFormat(request);
      } catch (e) {
        // 引擎下发失败不应阻断 UI（如引擎未就绪）；记录即可。
        debugPrint('区域格式下发引擎失败：$e');
      }
    },
  );

  await settings.load();
  await locale.load();
  await region.load();

  final CalculatorController calc = CalculatorController(
    engine: activeEngine,
    settings: settings,
    history: history,
    // LC-09 / A4：把区域小数分隔符（如 de-DE 的 `,`）规范化为引擎内部 `.`。
    // 仅在区域用非 `.` 分隔符时介入；用 Rust `normalize_expression` 保证与引擎一致。
    normalizeInput: (String expr) {
      final String? sep = region.decimalSeparator;
      if (sep == null || sep == '.') {
        return expr;
      }
      try {
        return activeEngine.normalizeExpression(
          expr: expr,
          decimalSeparator: sep,
        );
      } catch (e) {
        debugPrint('表达式规范化失败：$e');
        return expr;
      }
    },
  );

  runApp(MyApp(
    settings: settings,
    locale: locale,
    region: region,
    history: history,
    calculator: calc,
    engineOk: engine != null,
  ));
}
