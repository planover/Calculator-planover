/// 主题测试（PRD §4 TH-01 / TH-04 / TH-07 / TH-08）。
///
/// 验证：全部主题实现了 15 个语义色彩 token（无空值）；主题选项数 ≥ 17
/// （≥16 固定主题 + 跟随系统）；`system` 跟随系统深浅色。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/storage/settings_store.dart';
import 'package:calculator_planover/src/theme/app_theme.dart';
import 'package:calculator_planover/src/theme/tokens.dart';

void main() {
  group('主题 token 完整性（TH-01）', () {
    test('每个主题的 15 个语义 token 均非空', () {
      for (final AppThemeMode mode in AppThemeMode.values) {
        final ThemeTokens t = themeTokensForMode(mode);
        final Map<String, Color> map = t.toMap();
        for (final String key in ThemeTokens.keys) {
          expect(map[key], isNotNull, reason: '$mode.$key 不应为空');
        }
        expect(map.length, 15);
      }
    });
  });

  group('主题数量（TH-07 / TH-08）', () {
    test('固定主题 ≥ 16，合计选项 ≥ 17', () {
      final int total = AppThemeMode.values.length;
      final int fixed = AppThemeMode.values.where((AppThemeMode m) => m != AppThemeMode.system).length;
      expect(fixed, greaterThanOrEqualTo(16));
      expect(total, greaterThanOrEqualTo(17));
    });
  });

  group('跟随系统（TH-04）', () {
    test('system → ThemeMode.system；固定主题强制明暗', () {
      expect(toFlutterThemeMode(AppThemeMode.system), ThemeMode.system);
      expect(toFlutterThemeMode(AppThemeMode.dark), ThemeMode.dark);
      expect(toFlutterThemeMode(AppThemeMode.light), ThemeMode.light);
      expect(toFlutterThemeMode(AppThemeMode.monokai), ThemeMode.dark);
      expect(toFlutterThemeMode(AppThemeMode.solarizedLight), ThemeMode.light);
    });
  });
}
