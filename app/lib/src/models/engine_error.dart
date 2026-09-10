/// 错误信封模型 —— 镜像 `api.rs` 的 `ErrorDto` 与 `span.rs` 的 `Span`。
///
/// Rust 侧 `ErrorDto { code: u16, kind: &'static str, message: String, span: Option<Span> }`；
/// 其中 `span` 缺失时**整字段消失**（`skip_serializing_if`），Dart 侧对应 `null`。
///
/// 这里是**纯数据**模型；真正被 throw 出去的是 `engine/engine_exception.dart` 的
/// [EngineException]，两者字段一一对应，便于 UI 直接展示。
library;

import '../utils/json_helpers.dart';

/// 出错区间，使用 **char（Unicode 标量）偏移**，Dart 可直接 `substring(start, end)`。
class ErrorSpan {
  const ErrorSpan({required this.start, required this.end});

  /// 起始下标（含）。
  final int start;

  /// 结束下标（不含）。
  final int end;

  /// 是否为空区间。
  bool get isEmpty => end <= start;

  /// 宽容解析。
  factory ErrorSpan.fromJson(Object? json) => ErrorSpan(
        start: readInt(json, 'start', 0),
        end: readInt(json, 'end', 0),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{'start': start, 'end': end};

  @override
  String toString() => 'ErrorSpan($start, $end)';
}

/// 引擎返回的错误载荷。
class EngineError {
  const EngineError({
    required this.code,
    required this.kind,
    this.message = '',
    this.span,
  });

  /// 数字错误码（如 2000 除零、5002 内部错误）。
  final int code;

  /// 稳定的 snake_case 名称，如 `division_by_zero` / `incomplete_expression`。
  final String kind;

  /// 中文文案，可直接展示给用户。
  final String message;

  /// 出错区间；`null` 表示 Rust 没给出位置。
  final ErrorSpan? span;

  /// 从信封里的 `error` 字段解析。
  factory EngineError.fromJson(Object? json) {
    final Object? rawSpan = json is Map ? json['span'] : null;
    return EngineError(
      code: readInt(json, 'code', 0),
      kind: readString(json, 'kind', 'internal_error'),
      message: readString(json, 'message', ''),
      span: rawSpan == null ? null : ErrorSpan.fromJson(rawSpan),
    );
  }

  /// 转成 JSON。
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = <String, dynamic>{
      'code': code,
      'kind': kind,
      'message': message,
    };
    final ErrorSpan? s = span;
    if (s != null) {
      out['span'] = s.toJson();
    }
    return out;
  }

  @override
  String toString() => 'EngineError($code/$kind: $message)';
}
