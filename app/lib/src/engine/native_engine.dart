/// 真机实现：[EngineGateway] 的 FFI 版本 —— **全项目唯一 import `dart:ffi` 的文件**。
///
/// 为什么只允许这一个文件碰 FFI（架构 §1.2 / §T04 要点 8、风险 R3）：
/// `flutter test` 跑在宿主机上，加载不到 APK 里的 `lib/<abi>/libcalculator_ffi.so`，
/// 一旦某处 import 链把它带进测试进程就会直接崩。把它**物理隔离**在 L3 网关内，
/// 上层（状态/UI）与测试一律只认 [EngineGateway] 抽象，测试注入 [FakeEngine] 即可。
///
/// 内存契约（架构 §5.1，逐条兑现）：
/// - 入参用 `toNativeUtf8()` 分配、`malloc.free` 释放；
/// - 返回值由 Rust 用 `CString::into_raw()` 分配，**必须在 finally 里 `calc_string_free`**，
///   且**同一指针只释放一次**；
/// - Rust 侧 `catch_unwind` 保证 panic 不跨 FFI，因此这里拿到的永远是合法 JSON 信封。
library;

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'engine_exception.dart';
import 'engine_gateway.dart';
import 'ffi_bindings.dart';
import '../models/constant_info.dart';
import '../models/convert_result.dart';
import '../models/engine_error.dart';
import '../models/eval_result.dart';
import '../models/eval_settings.dart';
import '../models/unit_info.dart';
import '../models/variable_info.dart';
import '../utils/json_helpers.dart';

/// 通过 `dart:ffi` 直连 `libcalculator_ffi.so` 的引擎实现。
class NativeEngine implements EngineGateway {
  /// 打开动态库并做版本自检。
  ///
  /// [bindings] 允许调用方注入已打开的库（便于复用 / 测试）；
  /// [checkVersion] 关闭自检仅供调试，正常路径必须开。
  NativeEngine({FfiBindings? bindings, bool checkVersion = true})
      : _bindings = bindings ?? FfiBindings() {
    if (checkVersion) {
      _checkVersion();
    }
  }

  /// C ABI 版本号，必须与 Rust `ABI_VERSION` 一致，否则说明 .so 与 Dart 侧不同步。
  static const int expectedAbi = 1;

  final FfiBindings _bindings;

  void _checkVersion() {
    final Map<String, dynamic> info = version();
    final Object? abi = info['abi'];
    if (abi is! int || abi != expectedAbi) {
      throw EngineException(
        code: 5002,
        kind: 'internal_error',
        message: '引擎 ABI 不匹配：期望 $expectedAbi，实得 $abi',
      );
    }
  }

  // ── 统一调用骨架 ────────────────────────────────────────────

  /// 调一个 `(req) -> *mut c_char` 形式的函数并把结果解成 `data`。
  Map<String, dynamic> _invoke(
    Pointer<Utf8> Function(Pointer<Utf8>) fn, {
    String payload = '{}',
  }) {
    final Pointer<Utf8> request = payload.toNativeUtf8();
    Pointer<Utf8>? response;
    try {
      response = fn(request);
      return _decode(response.toDartString());
    } finally {
      // 请求串是本端分配的，必须用 malloc 释放
      malloc.free(request);
      // 响应串是 Rust 分配的，交给 calc_string_free；只释放一次
      final Pointer<Utf8>? r = response;
      if (r != null) {
        _bindings.free(r);
      }
    }
  }

  /// 把响应串解成信封：成功给 `data`，失败抛 [EngineException]。
  Map<String, dynamic> _decode(String text) {
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map) {
      return const <String, dynamic>{};
    }
    final Map<String, dynamic> envelope = Map<String, dynamic>.from(decoded);
    if (envelope['ok'] == true) {
      final Object? data = envelope['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return const <String, dynamic>{};
    }
    throw EngineException.fromError(EngineError.fromJson(envelope['error']));
  }

  /// 构造请求 JSON；`null` 字段整省略（与 Rust 的 Option 语义一致）。
  static String _payload(Map<String, Object?> fields) {
    fields.removeWhere((String _, Object? v) => v == null);
    return jsonEncode(fields);
  }

  // ── EngineGateway 实现 ─────────────────────────────────────

  @override
  Map<String, dynamic> version() {
    final Pointer<Utf8> response = _bindings.version();
    try {
      return _decode(response.toDartString());
    } finally {
      _bindings.free(response);
    }
  }

  @override
  EvalResult evaluatePreview({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  }) {
    final Map<String, dynamic> data = _invoke(
      _bindings.evaluatePreview,
      payload: _payload(<String, Object?>{
        'expr': expr,
        'cursor': cursor,
        'settings': settings?.toJson(),
      }),
    );
    return EvalResult.fromJson(data);
  }

  @override
  EvalResult evaluateCommit({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  }) {
    final Map<String, dynamic> data = _invoke(
      _bindings.evaluateCommit,
      payload: _payload(<String, Object?>{
        'expr': expr,
        'cursor': cursor,
        'settings': settings?.toJson(),
      }),
    );
    return EvalResult.fromJson(data);
  }

  @override
  ConvertResult convert({
    String? value,
    String? from,
    String? to,
    String? query,
  }) {
    final Map<String, dynamic> data = _invoke(
      _bindings.convert,
      payload: _payload(<String, Object?>{
        'value': value,
        'from': from,
        'to': to,
        'query': query,
      }),
    );
    return ConvertResult.fromJson(data);
  }

  @override
  List<ConstantInfo> listConstants() {
    final Map<String, dynamic> data =
        _invoke(_bindings.listConstants);
    return readMapList(data, 'constants')
        .map(ConstantInfo.fromJson)
        .toList(growable: false);
  }

  @override
  List<CategoryInfo> listUnits({String? category}) {
    final Map<String, dynamic> data = _invoke(
      _bindings.listUnits,
      payload: _payload(<String, Object?>{'category': category}),
    );
    return readMapList(data, 'categories')
        .map(CategoryInfo.fromJson)
        .toList(growable: false);
  }

  @override
  List<VariableInfo> listVariables() {
    final Map<String, dynamic> data =
        _invoke(_bindings.listVariables);
    return readMapList(data, 'variables')
        .map(VariableInfo.fromJson)
        .toList(growable: false);
  }

  @override
  FormattedValue formatNumber({
    required String value,
    EvalSettings? settings,
  }) {
    final Map<String, dynamic> data = _invoke(
      _bindings.formatNumber,
      payload: _payload(<String, Object?>{
        'value': value,
        // format_number 的 settings 是**扁平**的 FormatDto（见 EvalSettings 文档）
        'settings': settings?.toFormatJson(),
      }),
    );
    return FormattedValue.fromJson(data);
  }

  @override
  VariableInfo setVariable({required String name, required String expr}) {
    final Map<String, dynamic> data = _invoke(
      _bindings.setVariable,
      payload: _payload(<String, Object?>{'name': name, 'expr': expr}),
    );
    return VariableInfo.fromJson(data);
  }

  @override
  String deleteVariable({required String name}) {
    final Map<String, dynamic> data = _invoke(
      _bindings.deleteVariable,
      payload: _payload(<String, Object?>{'name': name}),
    );
    return readString(data, 'name', name);
  }

  @override
  String setAngleMode(AngleMode mode) {
    final Map<String, dynamic> data = _invoke(
      _bindings.setAngleMode,
      payload: _payload(<String, Object?>{'angle_mode': mode.id}),
    );
    return readString(data, 'angle_mode', mode.id);
  }

  @override
  int setWordSize(int wordSize) {
    final Map<String, dynamic> data = _invoke(
      _bindings.setWordSize,
      payload: _payload(<String, Object?>{'word_size': wordSize}),
    );
    return readInt(data, 'word_size', wordSize);
  }

  @override
  void resetSession({bool keepAns = true}) {
    _invoke(
      _bindings.resetSession,
      payload: _payload(<String, Object?>{'keep_ans': keepAns}),
    );
  }

  @override
  EditOutcome applyEdit({
    required String text,
    required int cursor,
    required String action,
    String payload = '',
  }) {
    final Map<String, dynamic> data = _invoke(
      _bindings.applyEdit,
      payload: jsonEncode(<String, Object?>{
        'text': text,
        'cursor': cursor,
        'action': action,
        'payload': payload,
      }),
    );
    return EditOutcome.fromJson(data);
  }
}
