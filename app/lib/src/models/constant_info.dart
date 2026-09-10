/// 物理 / 数学常量展示信息 —— 镜像 `api.rs` 的 `ConstantInfoDto`。
///
/// 注意 `value` 在 JSON 里是**字符串**（`ConstantInfoDto::of` 专门用
/// `plain_decimal` 转成串），目的是避免 Dart 端二次解析造成精度损失；
/// 因此这里也存 String，展示时原样输出。
library;

import '../utils/json_helpers.dart';

/// 一个常量。
class ConstantInfo {
  const ConstantInfo({
    this.symbol = '',
    this.name = '',
    this.unit = '',
    this.value = '',
    this.category = '',
    this.aliases = const <String>[],
  });

  /// 符号，如 `π`。
  final String symbol;

  /// 中文名，如 `圆周率`。
  final String name;

  /// 单位，如 `m/s`（无单位时为空串）。
  final String unit;

  /// 数值（字符串形态，避免精度损失）。
  final String value;

  /// 分类，如 `math` / `physics`。
  final String category;

  /// 别名，如 `pi`。
  final List<String> aliases;

  /// 宽容解析。
  factory ConstantInfo.fromJson(Object? json) => ConstantInfo(
        symbol: readString(json, 'symbol', ''),
        name: readString(json, 'name', ''),
        unit: readString(json, 'unit', ''),
        value: readString(json, 'value', ''),
        category: readString(json, 'category', ''),
        aliases: readStringList(json, 'aliases'),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'symbol': symbol,
        'name': name,
        'unit': unit,
        'value': value,
        'category': category,
        'aliases': aliases,
      };

  @override
  String toString() => 'ConstantInfo($symbol = $value$unit)';
}
