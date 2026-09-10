/// Material 3 主题（架构 §T05 要点 8）。
///
/// 主题只依赖 `AppThemeMode`（来自 storage 层，不引入 material），
/// 由本文件把它映射成 Flutter 的 `ThemeData` / `ThemeMode`。
library;

import 'package:flutter/material.dart';

import '../storage/settings_store.dart';

/// 主色种子（与占位入口保持一致，统一视觉）。
const Color _seedColor = Colors.indigo;

/// 由 [AppThemeMode] 生成一套 `ThemeData`。
///
/// `system` 态给浅色基线，运行时由 `MaterialApp.themeMode` 再切深色，
/// 这样同一套 `ColorScheme` 同时服务明暗两套。
ThemeData buildTheme(AppThemeMode mode) {
  final Brightness brightness =
      mode == AppThemeMode.dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: brightness,
  );
}

/// [AppThemeMode] → Flutter `ThemeMode`。
ThemeMode toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
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
