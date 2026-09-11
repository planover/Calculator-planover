/// Material 3 主题（架构 §T05 要点 8 / PRD §4 主题需求）。
///
/// - 主题只依赖 [AppThemeMode]（来自 storage 层，不引入 material 之外的反向依赖）；
/// - 由本文件把它映射成 Flutter 的 `ThemeData` / `ThemeMode`；
/// - 提供 **≥16 个固定主题 + 跟随系统**（PRD §4.2 TH-07/TH-08），每个主题都通过一套
///   **15 个语义色彩 token**（[ThemeTokens]，PRD §4.3 TH-01）驱动，保证全主题 token 完整；
/// - TH-04「跟随系统深浅色」由 `AppThemeMode.system` + `ThemeMode.system` 实现。
library;

import 'package:flutter/material.dart';

import '../storage/settings_store.dart';
import 'tokens.dart';

/// 单主题元数据：内在明暗 + 主色种子（M3 据此生成整套 ColorScheme）。
class _ThemeMeta {
  const _ThemeMeta({required this.dark, required this.seed});
  final bool dark;
  final Color seed;
}

/// 全部主题的元数据表（PRD §4.2 主题清单表）。
///
/// 前 9 个与原版 6 个可选 + 3 个遗留主题一一对应，其后为本产品新增。
const Map<AppThemeMode, _ThemeMeta> _themeMeta =
    <AppThemeMode, _ThemeMeta>{
  AppThemeMode.system: _ThemeMeta(dark: false, seed: Colors.indigo),
  AppThemeMode.dark: _ThemeMeta(dark: true, seed: Color(0xFF9E9E9E)),
  AppThemeMode.darkAmoled: _ThemeMeta(dark: true, seed: Color(0xFFBB86FC)),
  AppThemeMode.light: _ThemeMeta(dark: false, seed: Color(0xFF26A69A)),
  AppThemeMode.metroBlue: _ThemeMeta(dark: false, seed: Color(0xFF2196F3)),
  AppThemeMode.metroGreen: _ThemeMeta(dark: false, seed: Color(0xFF43A047)),
  AppThemeMode.metroPurple: _ThemeMeta(dark: false, seed: Color(0xFF8E24AA)),
  AppThemeMode.oldGray: _ThemeMeta(dark: false, seed: Color(0xFF607D8B)),
  AppThemeMode.violet: _ThemeMeta(dark: false, seed: Color(0xFF7C4DFF)),
  AppThemeMode.blue: _ThemeMeta(dark: false, seed: Color(0xFF1565C0)),
  AppThemeMode.highContrast: _ThemeMeta(dark: true, seed: Color(0xFFFFEB3B)),
  AppThemeMode.nord: _ThemeMeta(dark: true, seed: Color(0xFF88C0D0)),
  AppThemeMode.dracula: _ThemeMeta(dark: true, seed: Color(0xFFBD93F9)),
  AppThemeMode.oneDark: _ThemeMeta(dark: true, seed: Color(0xFF61AFEF)),
  AppThemeMode.solarizedLight: _ThemeMeta(dark: false, seed: Color(0xFF268BD2)),
  AppThemeMode.solarizedDark: _ThemeMeta(dark: true, seed: Color(0xFF268BD2)),
  AppThemeMode.gruvboxDark: _ThemeMeta(dark: true, seed: Color(0xFFFABD2F)),
  AppThemeMode.monokai: _ThemeMeta(dark: true, seed: Color(0xFFA6E22E)),
};

/// 主题展示名对应的 i18n key（设置页下拉框用，避免硬编码文案）。
const Map<AppThemeMode, String> themeNameKey = <AppThemeMode, String>{
  AppThemeMode.system: 'ui.settings.themeSystem',
  AppThemeMode.dark: 'ui.settings.themeDark',
  AppThemeMode.darkAmoled: 'ui.settings.themeDarkAmoled',
  AppThemeMode.light: 'ui.settings.themeLight',
  AppThemeMode.metroBlue: 'ui.settings.themeMetroBlue',
  AppThemeMode.metroGreen: 'ui.settings.themeMetroGreen',
  AppThemeMode.metroPurple: 'ui.settings.themeMetroPurple',
  AppThemeMode.oldGray: 'ui.settings.themeOldGray',
  AppThemeMode.violet: 'ui.settings.themeViolet',
  AppThemeMode.blue: 'ui.settings.themeBlue',
  AppThemeMode.highContrast: 'ui.settings.themeHighContrast',
  AppThemeMode.nord: 'ui.settings.themeNord',
  AppThemeMode.dracula: 'ui.settings.themeDracula',
  AppThemeMode.oneDark: 'ui.settings.themeOneDark',
  AppThemeMode.solarizedLight: 'ui.settings.themeSolarizedLight',
  AppThemeMode.solarizedDark: 'ui.settings.themeSolarizedDark',
  AppThemeMode.gruvboxDark: 'ui.settings.themeGruvboxDark',
  AppThemeMode.monokai: 'ui.settings.themeMonokai',
};

/// 由 [AppThemeMode] 生成一套 `ColorScheme`（M3 fromSeed，对比度安全）。
///
/// `system` 态给一套中性浅色基线；运行时由 `MaterialApp.themeMode` 再切深色。
ColorScheme schemeForMode(AppThemeMode mode) {
  final _ThemeMeta meta = _themeMeta[mode] ??
      const _ThemeMeta(dark: false, seed: Colors.indigo);
  return ColorScheme.fromSeed(
    seedColor: meta.seed,
    brightness: meta.dark ? Brightness.dark : Brightness.light,
  );
}

/// 由 [AppThemeMode] 生成一套 `ThemeData`。
ThemeData buildTheme(AppThemeMode mode) {
  final ColorScheme scheme = schemeForMode(mode);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
  );
}

/// 全部 15 个语义色彩 token（PRD §4.3 TH-01），由主题 [AppThemeMode] 派生。
ThemeTokens themeTokensForMode(AppThemeMode mode) =>
    ThemeTokens.fromScheme(schemeForMode(mode));

/// [AppThemeMode] → Flutter `ThemeMode`。
///
/// `system` 跟随系统深浅色（TH-04）；其余固定主题按自身明暗强制生效
/// （与 `app.dart` 里 `theme`/`darkTheme` 同时设为该主题配合，确保不受系统切换影响）。
ThemeMode toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.system:
      return ThemeMode.system;
    default:
      final _ThemeMeta meta = _themeMeta[mode] ??
          const _ThemeMeta(dark: false, seed: Colors.indigo);
      return meta.dark ? ThemeMode.dark : ThemeMode.light;
  }
}

/// BCP-47 标签 → Flutter `Locale`（如 `zh-CN` → `zh_CN`）。
Locale toFlutterLocale(String tag) {
  final List<String> parts = tag.split('-');
  if (parts.length >= 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0]);
}
