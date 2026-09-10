/// 历史条目 —— **Dart 侧独有**的模型（Rust 不碰文件 IO，见架构 §1.2 关键不变量 4）。
///
/// 对应 `sqflite_history_repository.dart` 的表结构：
/// `history(id INTEGER PRIMARY KEY, expr TEXT, result TEXT, ts INTEGER, kind INTEGER)`。
///
/// 约定：
/// - `ts` 是 **毫秒时间戳**（`DateTime.now().millisecondsSinceEpoch`）；
/// - `kind` 以 **整数**落库（0=普通计算，1=单位换算），避免 SQLite 里存字符串的歧义。
///   ⚠️ 这是个**本轮做的假设**：架构只给了列名 `kind INTEGER`，没定义取值域，
///   这里定为 0/1，若 T05 需要更多类型（如"常量查询"）往后追加即可。
library;

import '../utils/json_helpers.dart';

/// 历史条目种类。
enum HistoryKind {
  /// 普通表达式计算。
  calculation,

  /// 单位换算。
  conversion,
}

/// `HistoryKind` ↔ 落库整数。
extension HistoryKindValue on HistoryKind {
  /// 落库的整数值。
  int get value => const <HistoryKind, int>{
        HistoryKind.calculation: 0,
        HistoryKind.conversion: 1,
      }[this]!;

  /// 由整数还原枚举；未知值一律按 [HistoryKind.calculation] 处理（不崩）。
  static HistoryKind fromValue(int v) {
    switch (v) {
      case 1:
        return HistoryKind.conversion;
      case 0:
      default:
        return HistoryKind.calculation;
    }
  }
}

/// 一条历史记录。
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.expr,
    required this.result,
    required this.ts,
    this.kind = HistoryKind.calculation,
  });

  /// 自增主键；尚未落库时为 `null`。
  final int? id;

  /// 用户输入的表达式。
  final String expr;

  /// 渲染好的结果串（不是数值 —— 历史只负责"当时显示了什么"）。
  final String result;

  /// 毫秒时间戳。
  final int ts;

  /// 条目种类。
  final HistoryKind kind;

  /// 从数据库行解析。
  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: readInt(map, 'id', 0),
        expr: readString(map, 'expr', ''),
        result: readString(map, 'result', ''),
        ts: readInt(map, 'ts', 0),
        kind: HistoryKindValue.fromValue(readInt(map, 'kind', 0)),
      );

  /// 转成数据库行（`id` 为 null 时不写，交给 SQLite 自增）。
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = <String, dynamic>{
      'expr': expr,
      'result': result,
      'ts': ts,
      'kind': kind.value,
    };
    final int? i = id;
    if (i != null) {
      map['id'] = i;
    }
    return map;
  }

  /// 从 JSON 解析（用于备份/导出等场景）。
  factory HistoryEntry.fromJson(Object? json) => HistoryEntry(
        id: json is Map && json['id'] != null ? readInt(json, 'id', 0) : null,
        expr: readString(json, 'expr', ''),
        result: readString(json, 'result', ''),
        ts: readInt(json, 'ts', 0),
        kind: HistoryKindValue.fromValue(readInt(json, 'kind', 0)),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => toMap();

  /// 局部复制（落库后回填自增 id 时用）。
  HistoryEntry copyWith({
    int? id,
    String? expr,
    String? result,
    int? ts,
    HistoryKind? kind,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      expr: expr ?? this.expr,
      result: result ?? this.result,
      ts: ts ?? this.ts,
      kind: kind ?? this.kind,
    );
  }

  @override
  String toString() => 'HistoryEntry(#$id $expr = $result)';
}
