/// 求值结果 —— 镜像 `api.rs` 的 `EvalResultDto`。
///
/// 本文件**同时**承载 `FormattedValue` 与 `EditOutcome`：
/// T04 的文件清单没有为这两个 DTO 单列 `.dart` 文件，为避免擅自新增文件破坏清单，
/// 把它们放在语义最接近的本文件里（`FormattedValue` 是"数值格式化结果"，
/// `EditOutcome` 是"一次输入编辑的结果"，都属于一次引擎调用的返回体）。
library;

import 'base_repr.dart';
import 'number_value.dart';
import 'variable_info.dart';
import '../utils/json_helpers.dart';

/// 一次求值（预览或提交）的完整结果。
class EvalResult {
  const EvalResult({
    required this.value,
    this.approx = 0.0,
    this.display = '',
    this.fraction,
    required this.base,
    this.assignments = const <VariableInfo>[],
    this.isInteger = false,
  });

  /// 精确数值。
  final NumberValue value;

  /// f64 近似值（仅供展示/比较）。
  final double approx;

  /// 已按格式设置渲染好的显示串，UI 直接展示这一项。
  final String display;

  /// 分数模式下的表示；`null` 表示当前不是分数模式。
  final String? fraction;

  /// 四种进制表示。
  final BaseRepr base;

  /// 本次执行产生的变量 / ans 变更（提交时至少含 `ans`）。
  final List<VariableInfo> assignments;

  /// 结果是否整数（UI 决定是否展示进制行）。
  final bool isInteger;

  /// 宽容解析。
  factory EvalResult.fromJson(Object? json) => EvalResult(
        value: NumberValue.fromJson(json is Map ? json['value'] : null),
        approx: readDouble(json, 'approx', 0.0),
        display: readString(json, 'display', ''),
        fraction: readNullableString(json, 'fraction'),
        base: BaseRepr.fromJson(json is Map ? json['base'] : null),
        assignments: readMapList(json, 'assignments')
            .map(VariableInfo.fromJson)
            .toList(growable: false),
        isInteger: readBool(json, 'is_integer', false),
      );

  /// 转成 JSON（主要用于测试往返与本地缓存）。
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'value': value.toJson(),
      'approx': approx,
      'display': display,
      'base': base.toJson(),
      'assignments':
          assignments.map((VariableInfo v) => v.toJson()).toList(),
      'is_integer': isInteger,
    };
    final String? f = fraction;
    if (f != null) {
      out['fraction'] = f;
    }
    return out;
  }

  @override
  String toString() => 'EvalResult($display, int=$isInteger)';
}

/// `format_number` 的返回体 —— 镜像 `api.rs` 的 `FormattedValueDto`。
class FormattedValue {
  const FormattedValue({
    this.display = '',
    this.fraction,
    this.approx = 0.0,
    this.isInteger = false,
  });

  /// 显示串。
  final String display;

  /// 分数串；`null` 表示非分数模式。
  final String? fraction;

  /// f64 近似值。
  final double approx;

  /// 是否整数。
  final bool isInteger;

  /// 宽容解析。
  factory FormattedValue.fromJson(Object? json) => FormattedValue(
        display: readString(json, 'display', ''),
        fraction: readNullableString(json, 'fraction'),
        approx: readDouble(json, 'approx', 0.0),
        isInteger: readBool(json, 'is_integer', false),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'display': display,
      'approx': approx,
      'is_integer': isInteger,
    };
    final String? f = fraction;
    if (f != null) {
      out['fraction'] = f;
    }
    return out;
  }

  @override
  String toString() => 'FormattedValue($display)';
}

/// `apply_edit` 的返回体 —— 镜像 `api.rs` 的 `EditResultDto`。
class EditOutcome {
  const EditOutcome({
    this.text = '',
    this.cursor = 0,
    this.changed = false,
  });

  /// 编辑后的新文本。
  final String text;

  /// 编辑后的新光标位置（char 偏移）。
  final int cursor;

  /// 是否真的发生了变化（UI 可据此决定是否刷新）。
  final bool changed;

  /// 宽容解析。
  factory EditOutcome.fromJson(Object? json) => EditOutcome(
        text: readString(json, 'text', ''),
        cursor: readInt(json, 'cursor', 0),
        changed: readBool(json, 'changed', false),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'cursor': cursor,
        'changed': changed,
      };

  @override
  String toString() => 'EditOutcome("$text" @$cursor, changed=$changed)';
}
