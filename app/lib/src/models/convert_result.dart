/// 单位换算结果 —— 镜像 `api.rs` 的 `ConvertResultDto`。
library;

import 'number_value.dart';
import 'unit_info.dart';
import '../utils/json_helpers.dart';

/// 一次单位换算的完整结果。
class ConvertResult {
  const ConvertResult({
    required this.from,
    required this.to,
    required this.inputValue,
    required this.outputValue,
    this.inputDisplay = '',
    this.outputDisplay = '',
  });

  /// 源单位。
  final UnitInfo from;

  /// 目标单位。
  final UnitInfo to;

  /// 输入数值。
  final NumberValue inputValue;

  /// 输出数值。
  final NumberValue outputValue;

  /// 输入显示串（含单位符号），如 `12.7 inch`。
  final String inputDisplay;

  /// 输出显示串（含单位符号），如 `322.58 mm`。
  final String outputDisplay;

  /// 宽容解析。
  factory ConvertResult.fromJson(Object? json) => ConvertResult(
        from: UnitInfo.fromJson(json is Map ? json['from'] : null),
        to: UnitInfo.fromJson(json is Map ? json['to'] : null),
        inputValue: NumberValue.fromJson(json is Map ? json['input_value'] : null),
        outputValue: NumberValue.fromJson(json is Map ? json['output_value'] : null),
        inputDisplay: readString(json, 'input_display', ''),
        outputDisplay: readString(json, 'output_display', ''),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'from': from.toJson(),
        'to': to.toJson(),
        'input_value': inputValue.toJson(),
        'output_value': outputValue.toJson(),
        'input_display': inputDisplay,
        'output_display': outputDisplay,
      };

  @override
  String toString() => 'ConvertResult($inputDisplay → $outputDisplay)';
}
