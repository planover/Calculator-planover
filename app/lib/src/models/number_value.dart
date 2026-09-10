/// 引擎数值 —— 镜像 `api.rs` 的 `NumDto`（内部标签 `kind`）。
///
/// Rust 侧是 `enum NumDto { Rational{num,den}, Float{value}, Special{which} }`，
/// 用 `#[serde(tag = "kind")]` 打成内部标签，Dart 侧用 `kind` 字段区分三态。
///
/// 注意：Dart 字段名刻意写成 `numerator/denominator` 而不是 `num/den` ——
/// `num` 是 Dart 内置的数值类型名，用作字段会遮蔽类型，容易在类内部写出歧义代码；
/// JSON 键仍然严格是 `num` / `den`（见 [toJson]）。
library;

import '../utils/json_helpers.dart';

/// 数值形态。
enum NumberKind {
  /// 精确有理数（整数与有限小数都走这条路径）。
  rational,

  /// 浮点近似值（三角/对数等无法精确表示的结果）。
  float,

  /// 非有限值：NaN / ±∞。
  special,
}

/// `special` 形态下的具体取值（对应 Rust `which`）。
enum SpecialKind {
  /// 非数，如 `0/0`。
  nan,

  /// 正无穷。
  inf,

  /// 负无穷。
  negInf,
}

/// 一个引擎数值。
class NumberValue {
  const NumberValue({
    required this.kind,
    this.numerator,
    this.denominator,
    this.value,
    this.which,
  });

  /// 形态。
  final NumberKind kind;

  /// 有理数的分子（JSON: `num`）。
  final int? numerator;

  /// 有理数的分母（JSON: `den`）。
  final int? denominator;

  /// 浮点值（JSON: `value`）。
  final double? value;

  /// 非有限值的种类（JSON: `which`），取值 `nan` / `inf` / `-inf`。
  final SpecialKind? which;

  /// 一个默认值（有理数 0），用于"读不到"时的兜底。
  static const NumberValue zero = NumberValue(
    kind: NumberKind.rational,
    numerator: 0,
    denominator: 1,
  );

  /// 宽容解析：任何字段缺失/类型不符都回落到安全值，绝不 throw。
  factory NumberValue.fromJson(Object? json) {
    final String kindText = readString(json, 'kind', 'rational');
    switch (kindText) {
      case 'float':
        return NumberValue(
          kind: NumberKind.float,
          value: readDouble(json, 'value', 0.0),
        );
      case 'special':
        return NumberValue(
          kind: NumberKind.special,
          which: _specialFromId(readString(json, 'which', 'nan')),
        );
      case 'rational':
      default:
        // 分母读到 0 时退化成 1，避免 Dart 侧做除法时抛 IntegerDivisionByZero
        final int den = readInt(json, 'den', 1);
        return NumberValue(
          kind: NumberKind.rational,
          numerator: readInt(json, 'num', 0),
          denominator: den == 0 ? 1 : den,
        );
    }
  }

  /// 转成请求/存储用的 JSON。
  Map<String, dynamic> toJson() {
    switch (kind) {
      case NumberKind.float:
        return <String, dynamic>{'kind': 'float', 'value': value ?? 0.0};
      case NumberKind.special:
        return <String, dynamic>{
          'kind': 'special',
          'which': _specialToId(which ?? SpecialKind.nan),
        };
      case NumberKind.rational:
        return <String, dynamic>{
          'kind': 'rational',
          'num': numerator ?? 0,
          'den': denominator ?? 1,
        };
    }
  }

  /// 粗略数值：仅供 UI 展示/比较，精确值请以 [kind] 分支处理。
  double toDouble() {
    switch (kind) {
      case NumberKind.rational:
        final int d = denominator ?? 1;
        if (d == 0) {
          return 0.0;
        }
        return (numerator ?? 0) / d;
      case NumberKind.float:
        return value ?? 0.0;
      case NumberKind.special:
        switch (which) {
          case SpecialKind.nan:
            return double.nan;
          case SpecialKind.inf:
            return double.infinity;
          case SpecialKind.negInf:
            return double.negativeInfinity;
          case null:
            return 0.0;
        }
    }
  }

  @override
  String toString() => 'NumberValue(${toJson()})';

  @override
  bool operator ==(Object other) =>
      other is NumberValue &&
      other.kind == kind &&
      other.numerator == numerator &&
      other.denominator == denominator &&
      other.value == value &&
      other.which == which;

  @override
  int get hashCode => Object.hash(kind, numerator, denominator, value, which);

  static SpecialKind _specialFromId(String id) {
    switch (id) {
      case 'inf':
        return SpecialKind.inf;
      case '-inf':
        return SpecialKind.negInf;
      case 'nan':
      default:
        return SpecialKind.nan;
    }
  }

  static String _specialToId(SpecialKind k) {
    switch (k) {
      case SpecialKind.inf:
        return 'inf';
      case SpecialKind.negInf:
        return '-inf';
      case SpecialKind.nan:
        return 'nan';
    }
  }
}
