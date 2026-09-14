/// 区域格式配置（Dart 侧）—— 时间/日期的**显示规则**载体（PRD §5 I3 / §6.3 / §6.4）。
///
/// 职责边界（架构 A1/A2/A3）：
/// - **数字 / 货币**格式化在 Rust 侧（`set_region_format`），本模型**不实现**它们，
///   只持有"用户选了哪个区域"这一事实（[tag]），再把它转成 Rust 契约 payload；
/// - **时间 / 日期**格式化在本模型 + `utils/region_date_format.dart` 完成（A2/Q4）；
/// - 绝不使用 `Intl.defaultLocale`（A3：语言与区域彻底解耦）——月份/星期名按
///   **区域格式**的语言取（RF-D-02），与界面文案语言无关。
///
/// 本模型由 [RegionFormatPresets] 按 BCP-47 标签构造，`null` 区域（跟随系统）
/// 由调用方回落到语言 CLDR。
library;

/// 短/长时间模式串（RF-T-02 / RF-T-03）。
///
/// 只覆盖需求点名的预设；自定义模式串（RF-X-02）走 [RegionFormatConfig.customTimePattern]。
enum TimePattern {
  /// `H:mm`，24 小时制、不补零小时（如 `9:05`）。
  hmm24,

  /// `HH:mm`，24 小时制、补零小时（如 `09:05`）。
  hhmm24,

  /// `h:mm tt`，12 小时制、不补零小时（如 `9:05 AM`）。
  hmm12,

  /// `hh:mm tt`，12 小时制、补零小时（如 `09:05 AM`）。
  hhmm12,
}

/// 日期模式串（RF-D-01 短日期）。
enum DatePattern {
  /// `M/d/yyyy`（美式，如 `9/9/2025`）。
  mdy,

  /// `yyyy-MM-dd`（ISO，如 `2025-09-09`）。
  ymd,

  /// `dd/MM/yyyy`（多数欧式，如 `09/09/2025`）。
  dmy,

  /// `M/d/yy`（两位数年份，如 `9/9/25`）。
  mdyy,
}

/// 每周第一天（RF-D-03）。
enum WeekStart {
  /// 周一（ISO 8601）。
  monday,

  /// 周六。
  saturday,

  /// 周日（多数美洲/东亚）。
  sunday,
}

/// 一档区域格式的**时间/日期**配置（数字/货币在 Rust 侧，此处只镜像选择）。
class RegionFormatConfig {
  /// 构造一档区域格式配置。
  const RegionFormatConfig({
    required this.tag,
    this.timePattern = TimePattern.hmm24,
    this.datePattern = DatePattern.mdy,
    this.weekStart = WeekStart.sunday,
    this.amSymbol = 'AM',
    this.pmSymbol = 'PM',
    this.timeSeparator = ':',
    this.customTimePattern,
    this.customDatePattern,
    this.regionLanguage = 'en',
  });

  /// BCP-47 区域标签（如 `de-DE` / `en-US` / `zh-CN`）。
  final String tag;

  /// 短时间模式串（RF-T-02）。
  final TimePattern timePattern;

  /// 短日期模式串（RF-D-01）。
  final DatePattern datePattern;

  /// 每周第一天（RF-D-03）。
  final WeekStart weekStart;

  /// 上午符号（RF-T-04），默认 `AM`。
  final String amSymbol;

  /// 下午符号（RF-T-04），默认 `PM`。
  final String pmSymbol;

  /// 时间分隔符（RF-T-01），默认 `:`。
  final String timeSeparator;

  /// 自定义长时间模式串（RF-X-02）；为 `null` 时用 [timePattern]。
  final String? customTimePattern;

  /// 自定义日期模式串（RF-X-02）；为 `null` 时用 [datePattern]。
  final String? customDatePattern;

  /// 月份/星期名所用的**语言**（区域格式的语言，RF-D-02，非界面语言）。
  final String regionLanguage;

  /// 是否为 12 小时制（由短时间模式串推导，RF-T-05）。
  bool get use12h =>
      timePattern == TimePattern.hmm12 || timePattern == TimePattern.hhmm12;

  /// 小时是否补零（12/24 制共用）。
  bool get padHour =>
      timePattern == TimePattern.hhmm24 || timePattern == TimePattern.hhmm12;

  /// 复制并覆盖部分字段。
  RegionFormatConfig copyWith({
    String? tag,
    TimePattern? timePattern,
    DatePattern? datePattern,
    WeekStart? weekStart,
    String? amSymbol,
    String? pmSymbol,
    String? timeSeparator,
    String? customTimePattern,
    String? customDatePattern,
    String? regionLanguage,
  }) {
    return RegionFormatConfig(
      tag: tag ?? this.tag,
      timePattern: timePattern ?? this.timePattern,
      datePattern: datePattern ?? this.datePattern,
      weekStart: weekStart ?? this.weekStart,
      amSymbol: amSymbol ?? this.amSymbol,
      pmSymbol: pmSymbol ?? this.pmSymbol,
      timeSeparator: timeSeparator ?? this.timeSeparator,
      customTimePattern: customTimePattern ?? this.customTimePattern,
      customDatePattern: customDatePattern ?? this.customDatePattern,
      regionLanguage: regionLanguage ?? this.regionLanguage,
    );
  }

  @override
  String toString() => 'RegionFormatConfig($tag, time=$timePattern, date=$datePattern)';
}
