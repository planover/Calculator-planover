/// 设计令牌 —— 间距 / 圆角 / 字号 / 最小点击区等常量（架构 §T05 要点 8）。
///
/// 集中放常量，避免各处写魔法数字，也方便主题统一调整。
library;

/// 设计令牌。
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
