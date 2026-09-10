/// FFI 边界抛出的异常 —— 对应 Rust 信封里的 `error` 对象。
///
/// 为什么不直接抛 [EngineError]：
/// [EngineError] 是"数据"（可以塞进状态里展示），而这个是"控制流"。
/// 架构 §1.2 关键不变量 2 要求"错误不跨 FFI 抛异常" —— Rust 一律回 JSON 信封，
/// 由 Dart 在这一层翻译成异常，UI 只需 catch [EngineException] 并按 [kind] 分支。
library;

import '../models/engine_error.dart';

/// 引擎调用失败。
class EngineException implements Exception {
  const EngineException({
    required this.code,
    required this.kind,
    this.message = '',
    this.span,
  });

  /// 数字错误码（如 2000 除零、4000 未定义变量、5001 非法设置、5002 内部错误）。
  final int code;

  /// 稳定的 snake_case 名称，如 `division_by_zero`。
  final String kind;

  /// 中文文案，可直接展示。
  final String message;

  /// 出错区间（char 偏移）；`null` 表示没有位置信息。
  final ErrorSpan? span;

  /// 由 [EngineError] 数据类转换而来。
  factory EngineException.fromError(EngineError e) => EngineException(
        code: e.code,
        kind: e.kind,
        message: e.message,
        span: e.span,
      );

  /// 架构 §10.2.3：写到一半的表达式不该报红，只给灰色提示。
  bool get isIncompleteExpression => kind == 'incomplete_expression';

  /// 是否是括号不匹配（UI 可在光标处提示补括号）。
  bool get isMismatchedParen => kind == 'mismatched_paren';

  @override
  String toString() => 'EngineException($code/$kind: $message)';
}
