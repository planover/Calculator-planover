/// 区域格式 JSON 负载 —— Dart 侧向 Rust `set_region_format` 传递的**数字/货币**配置镜像。
///
/// 契约来源：`docs/ARCHITECTURE-INCREMENT-v2.md` §3.1（Rust↔Dart 共同遵守的固定契约）。
/// 本文件只负责"把一个区域标签 + 用户覆盖项 → `set_region_format` 的请求 JSON"，
/// **不实现任何数字/货币格式化**（那是 Rust 侧 `format.rs` 的职责，架构 A1）。
///
/// 全部字段可选（`null` 省略），缺省即 Rust 侧"现状行为"，保证既有 238 个
/// `cargo test` 不被破坏。字段名一律 `snake_case`（与 serde 对齐）。
library;

/// 分组方式（RF-N-04）：标准 `3;0` 或印度式 `3;2;0`。
enum GroupPattern {
  /// `123,456,789`。
  standard,

  /// `12,34,56,789`。
  indian,
}

/// `GroupPattern` ↔ Rust 契约字符串。
extension GroupPatternWire on GroupPattern {
  /// 传给 Rust 的字符串（`serde(rename)` 值）。
  String get wire => this == GroupPattern.indian ? '3;2;0' : '3;0';
}

/// 负数格式（RF-N-06，5 选 1）。
enum NegativeNumberFormat {
  /// `(1.1)`。
  minusParen,

  /// `-1.1`。
  minusPlain,

  /// `- 1.1`。
  minusSpace,

  /// `1.1-`。
  trailingMinus,

  /// `1.1 -`。
  trailingMinusSpace,
}

/// `NegativeNumberFormat` ↔ Rust 契约字符串（`serde(rename_all = "snake_case")`）。
extension NegativeNumberFormatWire on NegativeNumberFormat {
  /// 传给 Rust 的字符串。
  String get wire {
    switch (this) {
      case NegativeNumberFormat.minusParen:
        return 'minus_paren';
      case NegativeNumberFormat.minusPlain:
        return 'minus_plain';
      case NegativeNumberFormat.minusSpace:
        return 'minus_space';
      case NegativeNumberFormat.trailingMinus:
        return 'trailing_minus';
      case NegativeNumberFormat.trailingMinusSpace:
        return 'trailing_minus_space';
    }
  }
}

/// 货币正数格式（RF-C-02，4 选 1）。
enum CurrencyPositiveFormat {
  /// `$1.1`。
  before,

  /// `1.1$`。
  after,

  /// `$ 1.1`。
  beforeSpace,

  /// `1.1 $`。
  afterSpace,
}

/// `CurrencyPositiveFormat` ↔ Rust 契约字符串。
extension CurrencyPositiveFormatWire on CurrencyPositiveFormat {
  /// 传给 Rust 的字符串。
  String get wire {
    switch (this) {
      case CurrencyPositiveFormat.before:
        return 'before';
      case CurrencyPositiveFormat.after:
        return 'after';
      case CurrencyPositiveFormat.beforeSpace:
        return 'before_space';
      case CurrencyPositiveFormat.afterSpace:
        return 'after_space';
    }
  }
}

/// 货币负数"符号位"（RF-C-03，4 选 1）。
enum CurrencyNegativeSign {
  /// `(¥3.50)`。
  paren,

  /// `-¥3.50`。
  before,

  /// `- ¥3.50`。
  beforeSpace,

  /// `¥3.50-`。
  trailing,
}

/// `CurrencyNegativeSign` ↔ Rust 契约字符串。
extension CurrencyNegativeSignWire on CurrencyNegativeSign {
  /// 传给 Rust 的字符串。
  String get wire {
    switch (this) {
      case CurrencyNegativeSign.paren:
        return 'paren';
      case CurrencyNegativeSign.before:
        return 'before';
      case CurrencyNegativeSign.beforeSpace:
        return 'before_space';
      case CurrencyNegativeSign.trailing:
        return 'trailing';
    }
  }
}

/// 货币负数格式 = 符号位 × 正数格式（16 组合，RF-C-03）。
class CurrencyNegativeFormat {
  /// 构造。
  const CurrencyNegativeFormat({required this.sign, required this.symbol});

  /// 符号位。
  final CurrencyNegativeSign sign;

  /// 符号相对数字的位置。
  final CurrencyPositiveFormat symbol;

  /// 转 Rust 契约的嵌套 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'sign': sign.wire,
        'symbol': symbol.wire,
      };
}

/// 货币格式化配置（RF-C-01~07）。
class CurrencyFormatConfig {
  /// 构造；各字段可选。
  const CurrencyFormatConfig({
    this.symbol,
    this.positiveFormat,
    this.negativeFormat,
    this.decimalSeparator,
    this.decimalDigits,
    this.groupSeparator,
    this.groupPattern,
  });

  /// 货币符号（如 `¥`/`$`/`€`/`CNY`）。
  final String? symbol;

  /// 正数格式。
  final CurrencyPositiveFormat? positiveFormat;

  /// 负数格式（16 组合）。
  final CurrencyNegativeFormat? negativeFormat;

  /// 货币小数分隔符（独立于普通小数分隔符）。
  final String? decimalSeparator;

  /// 货币小数位数（JPY=0、CNY=2）。
  final int? decimalDigits;

  /// 货币分组符。
  final String? groupSeparator;

  /// 货币分组方式。
  final GroupPattern? groupPattern;

  /// 转 Rust 契约 JSON（`null` 字段省略）。
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> m = <String, dynamic>{};
    if (symbol != null) {
      m['symbol'] = symbol;
    }
    if (positiveFormat != null) {
      m['positive_format'] = positiveFormat!.wire;
    }
    if (negativeFormat != null) {
      m['negative_format'] = negativeFormat!.toJson();
    }
    if (decimalSeparator != null) {
      m['decimal_separator'] = decimalSeparator;
    }
    if (decimalDigits != null) {
      m['decimal_digits'] = decimalDigits;
    }
    if (groupSeparator != null) {
      m['group_separator'] = groupSeparator;
    }
    if (groupPattern != null) {
      m['group_pattern'] = groupPattern!.wire;
    }
    return m;
  }
}

/// 区域格式请求负载（数字/货币部分）—— 对应 Rust `RegionFormatConfig`。
///
/// 注意：**时间/日期不在此对象内**（A2：时间/日期永远不进 Rust）。
/// 本对象只承载数字/货币规则，经 `set_region_format` 传给引擎。
class RegionFormatRequest {
  /// 构造；各字段可选（`null` = 用 Rust 侧现状默认）。
  const RegionFormatRequest({
    this.decimalSeparator,
    this.groupSeparator,
    this.groupPattern,
    this.leadingZero,
    this.negativeFormat,
    this.listSeparator,
    this.currency,
  });

  /// 小数分隔符（RF-N-01）。
  final String? decimalSeparator;

  /// 分组符（RF-N-03）。
  final String? groupSeparator;

  /// 分组方式（RF-N-04）。
  final GroupPattern? groupPattern;

  /// 是否显示前导零（RF-N-07）。
  final bool? leadingZero;

  /// 负数格式（RF-N-06）。
  final NegativeNumberFormat? negativeFormat;

  /// 列表分隔符（RF-N-09，P2）。
  final String? listSeparator;

  /// 货币配置（RF-C-*）。
  final CurrencyFormatConfig? currency;

  /// 转 `set_region_format` 的请求 JSON（省略 `null` 字段）。
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> m = <String, dynamic>{};
    if (decimalSeparator != null) {
      m['decimal_separator'] = decimalSeparator;
    }
    if (groupSeparator != null) {
      m['group_separator'] = groupSeparator;
    }
    if (groupPattern != null) {
      m['group_pattern'] = groupPattern!.wire;
    }
    if (leadingZero != null) {
      m['leading_zero'] = leadingZero;
    }
    if (negativeFormat != null) {
      m['negative_format'] = negativeFormat!.wire;
    }
    if (listSeparator != null) {
      m['list_separator'] = listSeparator;
    }
    if (currency != null) {
      m['currency'] = currency!.toJson();
    }
    return m;
  }
}

/// 按 BCP-47 区域标签构造该区域的**数字/货币**默认请求（Dart 侧镜像）。
///
/// 与 Rust 侧 `RegionFormatConfig` 字段一一对应；未列出的区域回落 en-US 风格。
/// 这只是"给引擎的初始建议"，用户可在区域设置页覆盖各字段。
abstract final class RegionFormatWire {
  /// 解析区域标签 → 数字/货币请求负载。
  static RegionFormatRequest forRegion(String? tag) {
    final String normalized = (tag ?? 'en-US').replaceAll('_', '-');
    switch (normalized) {
      case 'de-DE':
      case 'it-IT':
      case 'es-ES':
        return const RegionFormatRequest(
          decimalSeparator: ',',
          groupSeparator: '.',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'fr-FR':
        return const RegionFormatRequest(
          decimalSeparator: ',',
          groupSeparator: ' ',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'nl-NL':
        return const RegionFormatRequest(
          decimalSeparator: ',',
          groupSeparator: '.',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'sv-SE':
        return const RegionFormatRequest(
          decimalSeparator: ',',
          groupSeparator: ' ',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'pt-BR':
        return const RegionFormatRequest(
          decimalSeparator: ',',
          groupSeparator: '.',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'zh-CN':
        return const RegionFormatRequest(
          decimalSeparator: '.',
          groupSeparator: ',',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
          currency: CurrencyFormatConfig(
            symbol: '¥',
            positiveFormat: CurrencyPositiveFormat.before,
            negativeFormat: CurrencyNegativeFormat(
              sign: CurrencyNegativeSign.paren,
              symbol: CurrencyPositiveFormat.before,
            ),
            decimalDigits: 2,
          ),
        );
      case 'zh-TW':
        return const RegionFormatRequest(
          decimalSeparator: '.',
          groupSeparator: ',',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
          currency: CurrencyFormatConfig(
            symbol: r'NT$',
            positiveFormat: CurrencyPositiveFormat.before,
            negativeFormat: CurrencyNegativeFormat(
              sign: CurrencyNegativeSign.paren,
              symbol: CurrencyPositiveFormat.before,
            ),
            decimalDigits: 2,
          ),
        );
      case 'hi-IN':
        return const RegionFormatRequest(
          decimalSeparator: '.',
          groupSeparator: ',',
          groupPattern: GroupPattern.indian,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'ja-JP':
        return const RegionFormatRequest(
          decimalSeparator: '.',
          groupSeparator: ',',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
          currency: CurrencyFormatConfig(
            symbol: '¥',
            positiveFormat: CurrencyPositiveFormat.before,
            negativeFormat: CurrencyNegativeFormat(
              sign: CurrencyNegativeSign.paren,
              symbol: CurrencyPositiveFormat.before,
            ),
            decimalDigits: 0,
          ),
        );
      case 'ar-SA':
        return const RegionFormatRequest(
          decimalSeparator: '٫',
          groupSeparator: '٬',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
        );
      case 'en-US':
      default:
        return const RegionFormatRequest(
          decimalSeparator: '.',
          groupSeparator: ',',
          groupPattern: GroupPattern.standard,
          leadingZero: true,
          negativeFormat: NegativeNumberFormat.minusPlain,
          currency: CurrencyFormatConfig(
            symbol: r'$',
            positiveFormat: CurrencyPositiveFormat.before,
            negativeFormat: CurrencyNegativeFormat(
              sign: CurrencyNegativeSign.paren,
              symbol: CurrencyPositiveFormat.before,
            ),
            decimalDigits: 2,
          ),
        );
    }
  }
}
