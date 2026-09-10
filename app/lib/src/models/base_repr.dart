/// 同一数值在四种进制下的表示 —— 镜像 `api.rs` 的 `BaseRepr`。
///
/// Rust 侧 `BaseRepr { dec, hex, oct, bin, word_size, is_integer }`，
/// 全部 `#[serde(rename_all = "snake_case")]`。
/// 非整数时 `hex/oct/bin` 是空串（Rust 只填 `dec`），Dart 侧照原样保留空串。
library;

import '../utils/json_helpers.dart';

/// 四种进制表示。
class BaseRepr {
  const BaseRepr({
    this.dec = '',
    this.hex = '',
    this.oct = '',
    this.bin = '',
    this.wordSize = 64,
    this.isInteger = false,
  });

  /// 十进制串。
  final String dec;

  /// 十六进制串（大写；负数按位宽取补码后的无符号形式）。
  final String hex;

  /// 八进制串。
  final String oct;

  /// 二进制串。
  final String bin;

  /// 位宽 8/16/32/64。
  final int wordSize;

  /// 是否整数；`false` 时只应展示 [dec]。
  final bool isInteger;

  /// 兜底空表示。
  static const BaseRepr empty = BaseRepr();

  /// 宽容解析。
  factory BaseRepr.fromJson(Object? json) => BaseRepr(
        dec: readString(json, 'dec', ''),
        hex: readString(json, 'hex', ''),
        oct: readString(json, 'oct', ''),
        bin: readString(json, 'bin', ''),
        wordSize: readInt(json, 'word_size', 64),
        isInteger: readBool(json, 'is_integer', false),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'dec': dec,
        'hex': hex,
        'oct': oct,
        'bin': bin,
        'word_size': wordSize,
        'is_integer': isInteger,
      };

  @override
  String toString() => 'BaseRepr($dec, hex=$hex, ws=$wordSize)';
}
