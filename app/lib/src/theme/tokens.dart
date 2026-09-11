/// 设计令牌 —— 间距 / 圆角 / 字号 / 最小点击区 / 主题色彩语义 token
/// （架构 §T05 要点 8 / PRD §4.3）。
///
/// - 基础令牌（间距/圆角/字号/触摸区）集中放常量，避免各处写魔法数字；
/// - [ThemeTokens] 是 **15 个语义化色彩 token**（PRD §4.3 TH-01）：所有主题必须
///   实现全部 token，由 [ThemeTokens.fromScheme] 从 `ColorScheme` 派生，保证无缺失、
///   无硬编码兜底。TH-01 测试遍历全部主题 × 全部 token 断言非空。
library;

import 'package:flutter/material.dart';

/// 基础设计令牌（与主题无关的常量）。
class Tokens {
  const Tokens._();

  // 间距
  static const double padXs = 4.0;
  static const double padSm = 8.0;
  static const double padMd = 12.0;
  static const double padLg = 16.0;
  static const double padXl = 24.0;

  // 圆角
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusPill = 999.0;

  // 字号
  static const double fontSizeExpr = 28.0;
  static const double fontSizePreview = 22.0;
  static const double fontSizeResult = 40.0;
  static const double fontSizeKey = 22.0;
  static const double fontSizeLabel = 14.0;
  static const double fontSizeBase = 16.0;

  // 最小触摸区（P1-14 / PRD P0-24：按键 ≥ 44dp）
  static const double minTouch = 44.0;

  // 主显示区内边距
  static const double displayPad = 16.0;
}

/// 主题语义色彩令牌（PRD §4.3，15 个，所有主题必须全实现）。
///
/// 由 [ThemeTokens.fromScheme] 从 `ColorScheme` 派生 —— `ColorScheme` 已是 Material 3
/// 统一生成的、对比度安全的配色，派生出的 15 个 token 自然互不缺失、无硬编码兜底。
class ThemeTokens {
  /// 全量构造。
  const ThemeTokens({
    required this.colorBackground,
    required this.colorDisplayBackground,
    required this.colorExpressionBackground,
    required this.colorSurface,
    required this.colorAccent,
    required this.colorTextPrimary,
    required this.colorTextSecondary,
    required this.colorKeyBackground,
    required this.colorKeyText,
    required this.colorKeyPressed,
    required this.colorKeyOperator,
    required this.colorKeyFunction,
    required this.colorDivider,
    required this.colorError,
    required this.colorSuccess,
  });

  /// 应用主背景。
  final Color colorBackground;

  /// 结果显示区背景。
  final Color colorDisplayBackground;

  /// 表达式输入区背景。
  final Color colorExpressionBackground;

  /// 面板/抽屉/卡片背景。
  final Color colorSurface;

  /// 强调色（运算符键、选中态）。
  final Color colorAccent;

  /// 主文本。
  final Color colorTextPrimary;

  /// 次要文本（历史时间戳等）。
  final Color colorTextSecondary;

  /// 数字键背景。
  final Color colorKeyBackground;

  /// 数字键文本。
  final Color colorKeyText;

  /// 按键按下态。
  final Color colorKeyPressed;

  /// 运算符键强调色。
  final Color colorKeyOperator;

  /// 函数键背景。
  final Color colorKeyFunction;

  /// 分隔线/边框。
  final Color colorDivider;

  /// 错误态。
  final Color colorError;

  /// 成功/已保存态。
  final Color colorSuccess;

  /// 全部 15 个 token 的键名（TH-01 遍历断言用）。
  static const List<String> keys = <String>[
    'colorBackground',
    'colorDisplayBackground',
    'colorExpressionBackground',
    'colorSurface',
    'colorAccent',
    'colorTextPrimary',
    'colorTextSecondary',
    'colorKeyBackground',
    'colorKeyText',
    'colorKeyPressed',
    'colorKeyOperator',
    'colorKeyFunction',
    'colorDivider',
    'colorError',
    'colorSuccess',
  ];

  /// 把 15 个 token 拍平成 `key → Color` 映射（TH-01 测试断言每键非空）。
  Map<String, Color> toMap() => <String, Color>{
        'colorBackground': colorBackground,
        'colorDisplayBackground': colorDisplayBackground,
        'colorExpressionBackground': colorExpressionBackground,
        'colorSurface': colorSurface,
        'colorAccent': colorAccent,
        'colorTextPrimary': colorTextPrimary,
        'colorTextSecondary': colorTextSecondary,
        'colorKeyBackground': colorKeyBackground,
        'colorKeyText': colorKeyText,
        'colorKeyPressed': colorKeyPressed,
        'colorKeyOperator': colorKeyOperator,
        'colorKeyFunction': colorKeyFunction,
        'colorDivider': colorDivider,
        'colorError': colorError,
        'colorSuccess': colorSuccess,
      };

  /// 从 `ColorScheme` 派生全套 15 token（保证无空值、无硬编码兜底）。
  factory ThemeTokens.fromScheme(ColorScheme scheme) => ThemeTokens(
        colorBackground: scheme.surface,
        colorDisplayBackground: scheme.surfaceContainerLowest,
        colorExpressionBackground: scheme.surfaceContainerLow,
        colorSurface: scheme.surfaceContainer,
        colorAccent: scheme.primary,
        colorTextPrimary: scheme.onSurface,
        colorTextSecondary: scheme.onSurfaceVariant,
        colorKeyBackground: scheme.surfaceContainerLow,
        colorKeyText: scheme.onSurface,
        colorKeyPressed: scheme.surfaceContainerHigh,
        colorKeyOperator: scheme.primary,
        colorKeyFunction: scheme.surfaceContainerHigh,
        colorDivider: scheme.outlineVariant,
        colorError: scheme.error,
        colorSuccess: scheme.tertiary,
      );
}
