/// 测试脚手架（架构 §1.5）：把被测 Widget 包进可注入尺寸 / 语言 / 主题的宿主。
///
/// 放在 `test/support/` 而非 `lib/`，避免污染产物。
///
/// 铁律：仅依赖 [FakeEngine]，**不 import `dart:ffi` / `native_engine`**。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:calculator_planover/app.dart';
import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/l10n/app_localizations.dart';
import 'package:calculator_planover/src/state/calculator_controller.dart';
import 'package:calculator_planover/src/state/history_controller.dart';
import 'package:calculator_planover/src/state/locale_controller.dart';
import 'package:calculator_planover/src/state/region_format_controller.dart';
import 'package:calculator_planover/src/state/settings_controller.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';
import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/theme/app_theme.dart';

/// 一档设备（代表设备 + Size）。
class DeviceClass {
  /// 构造一档设备。
  const DeviceClass(this.name, this.size, {this.dpr = 1.0});

  /// 档位名（如 `S` / `P-short`）。
  final String name;

  /// 逻辑尺寸（dp）。
  final Size size;

  /// 设备像素比。
  final double dpr;

  /// 内置档位（v3 §4.2 + Q1 两套横屏）：S/M/L/XL 竖屏 + 横屏 short/tall。
  static const List<DeviceClass> all = <DeviceClass>[
    DeviceClass('S', Size(320, 640)), // < 360
    DeviceClass('M', Size(411, 891)), // 360–599（§4.1 参照档）
    DeviceClass('L', Size(480, 1000)), // 410–599
    DeviceClass('XL', Size(800, 1280)), // ≥ 600（平板竖屏）
    DeviceClass('P-short', Size(891, 411)), // 横屏 h<480 → 强制分栏（无入口）
    DeviceClass('P-tall', Size(1024, 600)), // 横屏 h≥480 → 可切换（分栏/堆叠）
  ];
}

/// 一套测试控制器（供断言驱动）。
class AppHarness {
  /// 构造控制器套件。
  AppHarness({
    required this.settings,
    required this.locale,
    required this.region,
    required this.history,
    required this.calculator,
  });

  /// 设置控制器。
  final SettingsController settings;

  /// 语言控制器。
  final LocaleController locale;

  /// 区域格式控制器。
  final RegionFormatController region;

  /// 历史控制器。
  final HistoryController history;

  /// 计算器控制器。
  final CalculatorController calculator;

  /// 释放控制器（与既有 widget 测试的释放集合保持一致）。
  void dispose() {
    calculator.dispose();
    history.dispose();
    locale.dispose();
    region.dispose();
  }
}

/// 把被测 Widget 包进可注入尺寸 / 语言 / 主题的宿主，返回可断言的控制器套件。
///
/// - [child] 为 null 时 pump **真实** [MyApp]（含 `MaterialApp.builder` 的字号 clamp
///   与 RTL 注入 —— 方向断言需要它）；否则用 `MultiProvider + MaterialApp` 包 [child]。
/// - [localeTag] 仅在未注入 [locale] 时生效（预载指定语言）。
///
/// 注：系统字号注入（`textScaler`）由 T02 的 `text_scaler_test` 按当时 SDK 的正确 API 追加，
/// 本批不引入（避免依赖可能已被重命名/弃用的测试 API）。
Future<AppHarness> pumpApp(
  WidgetTester tester, {
  Widget? child,
  Size size = const Size(411, 891),
  double devicePixelRatio = 1.0,
  String? localeTag = 'en',
  AppThemeMode theme = AppThemeMode.system,
  LocaleController? locale,
  CalculatorController? calculator,
  HistoryController? history,
  RegionFormatController? region,
  SettingsController? settings,
  FakeEngine? engine,
  Future<AppLocalizations> Function(String?)? loader,
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  final SettingsController settingsCtl =
      settings ?? SettingsController(store: MemorySettingsStore());
  final HistoryController historyCtl =
      history ?? HistoryController(MemoryHistoryRepository());
  final RegionFormatController regionCtl = region ?? RegionFormatController();
  final LocaleController localeCtl = locale ??
      LocaleController(
        store: MemorySettingsStore(),
        loader: loader ?? AppLocalizations.load,
      );
  final CalculatorController calcCtl = calculator ??
      CalculatorController(
        engine: engine ?? FakeEngine(),
        settings: settingsCtl,
        history: historyCtl,
      );

  if (locale == null && localeTag != null) {
    await localeCtl.setLocale(localeTag);
  }
  if (history == null) {
    await historyCtl.load();
  }

  final Widget app;
  if (child == null) {
    app = MyApp(
      settings: settingsCtl,
      locale: localeCtl,
      region: regionCtl,
      history: historyCtl,
      calculator: calcCtl,
      engineOk: true,
    );
  } else {
    app = MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settingsCtl),
        ChangeNotifierProvider<LocaleController>.value(value: localeCtl),
        ChangeNotifierProvider<RegionFormatController>.value(value: regionCtl),
        ChangeNotifierProvider<HistoryController>.value(value: historyCtl),
        ChangeNotifierProvider<CalculatorController>.value(value: calcCtl),
      ],
      child: MaterialApp(
        theme: buildTheme(theme),
        home: child,
      ),
    );
  }

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  return AppHarness(
    settings: settingsCtl,
    locale: localeCtl,
    region: regionCtl,
    history: historyCtl,
    calculator: calcCtl,
  );
}

/// 在 §4.2 全部档位（含横竖屏 short/tall）上遍历执行 [body] —— 无溢出 / 触摸区断言的统一入口。
Future<void> forEachDeviceClass(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester, DeviceClass device) body,
) async {
  for (final DeviceClass device in DeviceClass.all) {
    tester.view
      ..physicalSize = device.size * device.dpr
      ..devicePixelRatio = device.dpr;
    addTearDown(tester.view.reset);
    await body(tester, device);
  }
}
