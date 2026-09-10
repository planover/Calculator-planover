/// `libcalculator_ffi.so` 的符号绑定 —— **全项目唯一声明 C 函数签名的地方**。
///
/// 架构 §5.1 内存契约要点（在 `native_engine.dart` 里兑现）：
/// - 入参 `Pointer<Utf8>` 必须是以 `\0` 结尾的 C 字符串（`toNativeUtf8()` 保证）；
/// - 返回值由 Rust 用 `CString::into_raw()` 分配，**永不 NULL**，且必须由 Dart
///   调 `calc_string_free` 释放，同一指针只能释放一次。
///
/// ⚠️ **每个导出都写成"Native / Dart 一对"typedef**，这是 `dart:ffi` 的硬性要求：
/// `lookupFunction<T extends Function, F extends Function>` 需要两个类型参数，
/// 前者描述 **C 侧**签名（返回 [Void]、[Pointer]），后者描述 **Dart 侧**签名
/// （返回 [void]、[Pointer]）。少写一个或写成同一个都会在分析期报错。
/// 尤其是 `void` 返回的 `calc_string_free`：**不能**用 `Void Function(...)` 简写，
/// 必须 `FreeNative = Void Function(...)` 配 `FreeDart = void Function(...)`。
library;

import 'dart:ffi';

// ── 1. calc_version()：注意它**没有入参** ──────────────────────
/// C 侧：`calc_version() -> *mut c_char`。
typedef VersionNative = Pointer<Utf8> Function();

/// Dart 侧：`calc_version()`。
typedef VersionDart = Pointer<Utf8> Function();

// ── 2~14. 十三个 `(req: *const c_char) -> *mut c_char` ──────────
// 签名雷同但逐一列出：这样改动某个函数时不会误伤其它绑定，
// 也让"15 个导出是否都绑上了"这件事在代码里一眼可数。

/// C 侧：`calc_evaluate_preview`。
typedef EvaluatePreviewNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_evaluate_preview`。
typedef EvaluatePreviewDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_evaluate_commit`。
typedef EvaluateCommitNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_evaluate_commit`。
typedef EvaluateCommitDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_convert`。
typedef ConvertNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_convert`。
typedef ConvertDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_list_constants`。
typedef ListConstantsNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_list_constants`。
typedef ListConstantsDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_list_units`。
typedef ListUnitsNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_list_units`。
typedef ListUnitsDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_list_variables`。
typedef ListVariablesNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_list_variables`。
typedef ListVariablesDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_format_number`。
typedef FormatNumberNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_format_number`。
typedef FormatNumberDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_set_variable`。
typedef SetVariableNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_set_variable`。
typedef SetVariableDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_delete_variable`。
typedef DeleteVariableNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_delete_variable`。
typedef DeleteVariableDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_set_angle_mode`。
typedef SetAngleModeNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_set_angle_mode`。
typedef SetAngleModeDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_set_word_size`。
typedef SetWordSizeNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_set_word_size`。
typedef SetWordSizeDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_reset_session`。
typedef ResetSessionNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_reset_session`。
typedef ResetSessionDart = Pointer<Utf8> Function(Pointer<Utf8>);

/// C 侧：`calc_apply_edit`。
typedef ApplyEditNative = Pointer<Utf8> Function(Pointer<Utf8>);

/// Dart 侧：`calc_apply_edit`。
typedef ApplyEditDart = Pointer<Utf8> Function(Pointer<Utf8>);

// ── 15. calc_string_free：返回 void ────────────────────────────
/// C 侧：`calc_string_free(*mut c_char)`，**返回 void**。
typedef FreeNative = Void Function(Pointer<Utf8>);

/// Dart 侧：`calc_string_free`。返回值是 Dart 的 `void`（不是 [Void]）。
typedef FreeDart = void Function(Pointer<Utf8>);

/// 动态库句柄与全部函数指针。
///
/// Android 上 `DynamicLibrary.open('libcalculator_ffi.so')` 会自动在 APK 的
/// `lib/<abi>/` 下查找，因此**不要**写绝对路径。
class FfiBindings {
  /// 打开动态库；测试可传入自己的 [library] 做替身。
  FfiBindings({DynamicLibrary? library})
      : _lib = library ?? DynamicLibrary.open(libraryName);

  /// 库名（Android 按 ABI 目录自动搜索）。
  static const String libraryName = 'libcalculator_ffi.so';

  final DynamicLibrary _lib;

  /// 底层句柄，供高级用法（如手动 lookup）使用。
  DynamicLibrary get library => _lib;

  // 1
  /// `calc_version`。
  late final VersionDart version =
      _lib.lookupFunction<VersionNative, VersionDart>('calc_version');

  // 2
  /// `calc_evaluate_preview`。
  late final EvaluatePreviewDart evaluatePreview = _lib
      .lookupFunction<EvaluatePreviewNative, EvaluatePreviewDart>(
          'calc_evaluate_preview');

  // 3
  /// `calc_evaluate_commit`。
  late final EvaluateCommitDart evaluateCommit = _lib
      .lookupFunction<EvaluateCommitNative, EvaluateCommitDart>(
          'calc_evaluate_commit');

  // 4
  /// `calc_convert`。
  late final ConvertDart convert =
      _lib.lookupFunction<ConvertNative, ConvertDart>('calc_convert');

  // 5
  /// `calc_list_constants`。
  late final ListConstantsDart listConstants = _lib
      .lookupFunction<ListConstantsNative, ListConstantsDart>(
          'calc_list_constants');

  // 6
  /// `calc_list_units`。
  late final ListUnitsDart listUnits =
      _lib.lookupFunction<ListUnitsNative, ListUnitsDart>('calc_list_units');

  // 7
  /// `calc_list_variables`。
  late final ListVariablesDart listVariables = _lib
      .lookupFunction<ListVariablesNative, ListVariablesDart>(
          'calc_list_variables');

  // 8
  /// `calc_format_number`。
  late final FormatNumberDart formatNumber = _lib
      .lookupFunction<FormatNumberNative, FormatNumberDart>(
          'calc_format_number');

  // 9
  /// `calc_set_variable`。
  late final SetVariableDart setVariable = _lib
      .lookupFunction<SetVariableNative, SetVariableDart>('calc_set_variable');

  // 10
  /// `calc_delete_variable`。
  late final DeleteVariableDart deleteVariable = _lib
      .lookupFunction<DeleteVariableNative, DeleteVariableDart>(
          'calc_delete_variable');

  // 11
  /// `calc_set_angle_mode`。
  late final SetAngleModeDart setAngleMode = _lib
      .lookupFunction<SetAngleModeNative, SetAngleModeDart>(
          'calc_set_angle_mode');

  // 12
  /// `calc_set_word_size`。
  late final SetWordSizeDart setWordSize = _lib
      .lookupFunction<SetWordSizeNative, SetWordSizeDart>('calc_set_word_size');

  // 13
  /// `calc_reset_session`。
  late final ResetSessionDart resetSession = _lib
      .lookupFunction<ResetSessionNative, ResetSessionDart>(
          'calc_reset_session');

  // 14
  /// `calc_apply_edit`。
  late final ApplyEditDart applyEdit =
      _lib.lookupFunction<ApplyEditNative, ApplyEditDart>('calc_apply_edit');

  // 15
  /// `calc_string_free`：释放 Rust 分配的字符串。
  late final FreeDart free =
      _lib.lookupFunction<FreeNative, FreeDart>('calc_string_free');
}
