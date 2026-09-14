/// 记忆寄存器状态 —— 镜像 Rust `MemoryDto`（PRD §13.1 CP-01~07）。
///
/// 单一记忆寄存器，初值 0，独立于 `ans`。UI 据此决定是否显示 `M` 指示器，
/// 以及 `MR` 时把 [text]（负值形如 `(-5)`）插回表达式。
library;

import '../utils/json_helpers.dart';

/// 记忆寄存器当前状态。
class MemoryState {
  /// 构造记忆状态。
  const MemoryState({
    this.value = '0',
    this.display = '0',
    this.text = '0',
    this.isZero = true,
  });

  /// 规范数值串（rational 形如 `a/b` 或 `a`；float 形如 `1.5`）。
  final String value;

  /// 按当前格式设置渲染好的显示串（结果区/记忆面板用）。
  final String display;

  /// 可原样回插到表达式的字面量（`MR` 用；负值形如 `(-5)`）。
  final String text;

  /// 是否为 0（UI 据此决定是否显示 `M` 指示器）。
  final bool isZero;

  /// 从 Rust `MemoryDto` 的 JSON 解析（宽容，缺失字段回落默认值）。
  factory MemoryState.fromJson(Object? json) {
    final Map<String, dynamic>? m = readMap(json, 'data');
    final Map<String, dynamic> data =
        m ?? (json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{});
    return MemoryState(
      value: _numToString(readMap(data, 'value')),
      display: readString(data, 'display', '0'),
      text: readString(data, 'text', '0'),
      isZero: readBool(data, 'is_zero', true),
    );
  }

  /// 把 Rust `NumDto`（rational / float）转成可读串。
  static String _numToString(Object? v) {
    if (v is! Map) {
      return '0';
    }
    final Map<String, dynamic> n = Map<String, dynamic>.from(v);
    final String kind = readString(n, 'kind', '');
    if (kind == 'rational') {
      final int num = readInt(n, 'num', 0);
      final int den = readInt(n, 'den', 1);
      if (den == 0) {
        return '0';
      }
      return den == 1 ? '$num' : '$num/$den';
    }
    final double f = readDouble(n, 'f', 0.0);
    return f.toString();
  }

  @override
  String toString() => 'MemoryState($display, zero=$isZero)';
}
