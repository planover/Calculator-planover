/// 设置控制器 —— L2 状态层，持有并广播用户设置（架构 §1.2 / §T05 要点 7）。
///
/// 职责边界：
/// - **不碰 `dart:ffi`**：它只和 [SettingsStore] 打交道；把设置真正下发给 Rust 引擎
///   是 T05 里 `calculator_controller` 的活（调 `setAngleMode` / `setWordSize`）。
/// - **回退可观测**：未注入 [SettingsStore] 时（测试/预览）直接用默认值，不抛异常。
library;

import 'package:flutter/foundation.dart';

import '../models/eval_settings.dart';
import '../storage/settings_store.dart';

/// 设置状态。
class SettingsController extends ChangeNotifier {
  /// [store] 可空：为空时所有改动只留在内存里，不落盘（测试用）。
  SettingsController({SettingsStore? store}) : _store = store;

  final SettingsStore? _store;

  EvalSettings _settings = EvalSettings.defaults;
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _loaded = false;

  /// 当前求值/格式化设置。
  EvalSettings get settings => _settings;

  /// 当前主题模式。
  AppThemeMode get themeMode => _themeMode;

  /// 是否已从存储载入过（避免 UI 在载入前用默认值闪一下）。
  bool get isLoaded => _loaded;

  /// 从存储恢复；没有存储时保持默认值。
  Future<void> load() async {
    final SettingsStore? store = _store;
    if (store != null) {
      _settings = await store.loadSettings();
      _themeMode = await store.loadThemeMode();
    }
    _loaded = true;
    notifyListeners();
  }

  /// 整体替换设置并落盘。
  Future<void> update(EvalSettings next) async {
    _settings = next;
    notifyListeners();
    await _store?.saveSettings(next);
  }

  /// 改角度模式。
  Future<void> setAngleMode(AngleMode mode) =>
      update(_settings.copyWith(angleMode: mode));

  /// 改位宽；非法值直接忽略（UI 层也应只给 8/16/32/64 四个选项）。
  Future<void> setWordSize(int wordSize) {
    if (!validWordSizes.contains(wordSize)) {
      return Future<void>.value();
    }
    return update(_settings.copyWith(wordSize: wordSize));
  }

  /// 改记数法。
  Future<void> setNotation(Notation notation) =>
      update(_settings.copyWith(notation: notation));

  /// 改精度模式。
  Future<void> setPrecisionMode(PrecisionMode mode) =>
      update(_settings.copyWith(precisionMode: mode));

  /// 改精度；自动夹到 1..15（与 Rust 的校验区间一致，避免下发后被拒）。
  Future<void> setPrecision(int precision) {
    final int clamped = precision < minPrecision
        ? minPrecision
        : (precision > maxPrecision ? maxPrecision : precision);
    return update(_settings.copyWith(precision: clamped));
  }

  /// 改分数显示。
  Future<void> setFractionMode(FractionMode mode) =>
      update(_settings.copyWith(fractionMode: mode));

  /// 改千位分隔。
  Future<void> setGrouping(bool grouping) =>
      update(_settings.copyWith(grouping: grouping));

  /// 改主题模式。
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _store?.saveThemeMode(mode);
  }

  /// 恢复默认。
  Future<void> reset() => update(EvalSettings.defaults);
}
