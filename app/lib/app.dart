/// App 装配（架构 §T05 要点 2）。
///
/// 用 `MultiProvider` 注入四个控制器，再构建 `MaterialApp`：
/// - 主题来自 [app_theme]（Material 3）；
/// - `locale` 取 [LocaleController.l10n.locale]，`supportedLocales` 由
///   [LocaleRegistry] 映射；
/// - `localizationsDelegates` 含官方 Material 本地化代理；
/// - 引擎初始化失败则渲染错误页（不崩）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'src/l10n/locale_registry.dart';
import 'src/state/calculator_controller.dart';
import 'src/state/history_controller.dart';
import 'src/state/locale_controller.dart';
import 'src/state/settings_controller.dart';
import 'src/storage/settings_store.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/home_screen.dart';

/// 根组件。
class MyApp extends StatelessWidget {
  /// 构造根组件。
  const MyApp({
    super.key,
    required this.settings,
    required this.locale,
    required this.history,
    required this.calculator,
    required this.engineOk,
  });

  final SettingsController settings;
  final LocaleController locale;
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
    return MaterialApp(
      title: locale.l10n.tr('ui.app.title', fallback: 'Calculator-planover'),
      theme: buildTheme(AppThemeMode.light),
      darkTheme: buildTheme(AppThemeMode.dark),
      themeMode: toFlutterThemeMode(settings.themeMode),
      locale: locale.l10n.locale,
      supportedLocales:
          LocaleRegistry.supported.map((AppLocale a) => toFlutterLocale(a.tag)).toList(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
