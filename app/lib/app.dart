/// App 装配（架构 §T05 要点 2）。
///
/// 用 `MultiProvider` 注入四个控制器，再构建 `MaterialApp`：
/// - 主题来自 [app_theme]（Material 3）；
/// - `locale` 取 [LocaleController.l10n.locale]，`supportedLocales` 由
///   [MaterialSupportedLocales]（**收敛后的交集**，UX-02）映射；
/// - `localizationsDelegates` 含官方 Material 本地化代理；
/// - `builder` 注入字号 clamp（UX-07）与 RTL 方向（UX-03）；
/// - 引擎初始化失败则渲染错误页（不崩）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'src/l10n/material_supported_locales.dart';
import 'src/state/calculator_controller.dart';
import 'src/state/history_controller.dart';
import 'src/state/locale_controller.dart';
import 'src/state/region_format_controller.dart';
import 'src/state/settings_controller.dart';
import 'src/storage/settings_store.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/home_screen.dart';

/// 系统字号缩放下限（v3 §4.5 / UX-07）。
const double kTextScaleMin = 0.8;

/// 系统字号缩放上限（v3 §4.5 / UX-07）。
const double kTextScaleMax = 1.5;

/// 把系统字号缩放到 `[kTextScaleMin, kTextScaleMax]`（v3 §4.5 / UX-07）。
///
/// 默认 `1.0` 时原样返回，与原状态**逐位等价**（IC-6，不破坏既有 widget 测试）。
/// ⚠️ 架构 §1.4 示例引用的是 T02 的 `TextScale.clamp`；T02 落地后此处改为委托调用。
double clampTextScale(double raw) {
  if (raw < kTextScaleMin) {
    return kTextScaleMin;
  }
  if (raw > kTextScaleMax) {
    return kTextScaleMax;
  }
  return raw;
}

/// 根组件。
class MyApp extends StatelessWidget {
  /// 构造根组件。
  const MyApp({
    super.key,
    required this.settings,
    required this.locale,
    required this.region,
    required this.history,
    required this.calculator,
    required this.engineOk,
  });

  final SettingsController settings;
  final LocaleController locale;
  final RegionFormatController region;
  final HistoryController history;
  final CalculatorController calculator;

  /// 引擎是否初始化成功（失败则显示错误页）。
  final bool engineOk;

  @override
  Widget build(BuildContext context) {
    if (!engineOk) {
      return MaterialApp(
        title: 'Calculator-planover',
        theme: buildTheme(AppThemeMode.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '计算内核初始化失败，无法启动。请检查应用安装或重新安装。',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<LocaleController>.value(value: locale),
        ChangeNotifierProvider<RegionFormatController>.value(value: region),
        ChangeNotifierProvider<HistoryController>.value(value: history),
        ChangeNotifierProvider<CalculatorController>.value(value: calculator),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    final LocaleController locale =
        Provider.of<LocaleController>(context, listen: true);
    final AppThemeMode mode = settings.themeMode;
    final bool isSystem = mode == AppThemeMode.system;
    // 固定主题：theme / darkTheme 同时设为该主题，配合 themeMode 强制生效，
    // 不受系统深浅色切换影响（TH-04 仅对 system 生效）。
    final ThemeData themed = isSystem
        ? buildTheme(AppThemeMode.light)
        : buildTheme(mode);
    final ThemeData darkThemed = isSystem
        ? buildTheme(AppThemeMode.dark)
        : buildTheme(mode);
    return MaterialApp(
      title: locale.l10n.tr('ui.app.title', fallback: 'Calculator-planover'),
      theme: themed,
      darkTheme: darkThemed,
      themeMode: toFlutterThemeMode(mode),
      locale: locale.l10n.locale,
      // UX-02：**收敛后的交集**（不再等于 216）；见 material_supported_locales.dart。
      supportedLocales: MaterialSupportedLocales.tags
          .map(toFlutterLocale)
          .toList(growable: false),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // builder 是**全应用唯一**穿过的窄腰：一处施加字号 clamp 与 RTL 方向，
      // 全局（含 Dialog / 独立路由页 / 弹层）生效（架构 §1.4 / §3.3）。
      builder: (BuildContext ctx, Widget? child) {
        final MediaQueryData mq = MediaQuery.of(ctx);
        // 1) 字号 clamp [0.8, 1.5]（UX-07）。
        final double rawScale = mq.textScaler.scale(1.0);
        final TextScaler clamped = TextScaler.linear(clampTextScale(rawScale));
        // 2) RTL 注入（UX-03）：只要 `l10n.isRtl` 为真即镜像 —— 不依赖 MaterialApp
        //    是否把该 locale 解析进 supportedLocales（31 档 RTL 里有不在此交集者）。
        final TextDirection dir =
            locale.l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: Directionality(
            textDirection: dir,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
