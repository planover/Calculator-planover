/// 变量展示信息 —— 镜像 `session.rs` 的 `VariableInfo`
/// （`api.rs` 的 `VariableInfoDto` 与之同构）。
library;

import '../utils/json_helpers.dart';

/// 一个变量（含只读的 `ans`）。
class VariableInfo {
  const VariableInfo({
    required this.name,
    this.display = '',
    this.readonly = false,
  });

  /// 变量/常量名。
  final String name;

  /// 已按当前格式设置渲染好的值。
  final String display;

  /// 是否只读（`ans` 为 true，UI 应禁止删除）。
  final bool readonly;

  /// 宽容解析。
  factory VariableInfo.fromJson(Object? json) => VariableInfo(
        name: readString(json, 'name', ''),
        display: readString(json, 'display', ''),
        readonly: readBool(json, 'readonly', false),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'display': display,
        'readonly': readonly,
      };

  @override
  String toString() => 'VariableInfo($name = $display${readonly ? ' [ro]' : ''})';
}
