/// 设置持久化 —— SharedPreferences 落地，读失败一律回落默认值。
///
/// 为什么抽象 + 双实现：
/// - [SharedPreferencesSettingsStore] 是真机实现；
/// - [MemorySettingsStore] 供 `flutter test` 注入，避免测试去碰平台插件通道
///   （架构 §T04 要点 8/R3 的同款思路：测试不加载任何原生依赖）。
///
/// ⚠️ 本轮假设：架构只说"8 项设置 + SharedPreferences"，没规定主题归属。
/// 这里把**主题模式**也纳入持久化（它是用户在设置页改的、需要记住的偏好），
/// 并用自建枚举 [AppThemeMode] 而不是 Flutter 的 `ThemeMode` ——
/// 目的是让本层**不依赖 material**，T05 的 `app_theme.dart` 再做一次映射。
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/eval_settings.dart';

/// 主题模式（与 Flutter `ThemeMode` 同构，但不引入 material 依赖）。
enum AppThemeMode { system, light, dark }

/// 设置存储。
abstract class SettingsStore {
  /// 读取求值/格式化设置；失败或从未存过时返回 [EvalSettings.defaults]。
  Future<EvalSettings> loadSettings();

  /// 写入求值/格式化设置。
  Future<void> saveSettings(EvalSettings settings);

  /// 读取主题模式；默认 [AppThemeMode.system]。
  Future<AppThemeMode> loadThemeMode();

  /// 写入主题模式。
  Future<void> saveThemeMode(AppThemeMode mode);
}

/// 基于 SharedPreferences 的实现。
///
/// 依赖在 `pubspec.yaml` 中声明为 `shared_preferences`；
/// 插件在 Android 上把值落到 `SharedPreferences`，进程重启后仍然有效。
class SharedPreferencesSettingsStore implements SettingsStore {
  /// 构造时可注入实例（测试里用 `SharedPreferences.setMockInitialValues` 即可）。
  const SharedPreferencesSettingsStore();

  // 键名集中在这里，避免散落各处拼错。
  static const String _kAngleMode = 'settings.angle_mode';
  static const String _kWordSize = 'settings.word_size';
  static const String _kNotation = 'settings.notation';
  static const String _kPrecisionMode = 'settings.precision_mode';
  static const String _kPrecision = 'settings.precision';
  static const String _kFractionMode = 'settings.fraction_mode';
  static const String _kGrouping = 'settings.grouping';
  static const String _kThemeMode = 'settings.theme_mode';

  @override
  Future<EvalSettings> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // 逐项读取并夹到合法区间：磁盘上的值可能来自旧版本或被外部改坏
    final int precision = _clamp(
      prefs.getInt(_kPrecision) ?? EvalSettings.defaults.precision,
      minPrecision,
      maxPrecision,
    );
    final int wordSize = validWordSizes.contains(prefs.getInt(_kWordSize))
        ? prefs.getInt(_kWordSize)!
        : EvalSettings.defaults.wordSize;
    return EvalSettings(
      angleMode: _enumFrom<AngleMode>(
        prefs.getString(_kAngleMode),
        const <String, AngleMode>{
          'deg': AngleMode.deg,
          'rad': AngleMode.rad,
          'grad': AngleMode.grad,
        },
        EvalSettings.defaults.angleMode,
      ),
      wordSize: wordSize,
      notation: _enumFrom<Notation>(
        prefs.getString(_kNotation),
        const <String, Notation>{
          'auto': Notation.auto,
          'scientific': Notation.scientific,
          'fixed': Notation.fixed,
        },
        EvalSettings.defaults.notation,
      ),
      precisionMode: _enumFrom<PrecisionMode>(
        prefs.getString(_kPrecisionMode),
        const <String, PrecisionMode>{
          'significant': PrecisionMode.significant,
          'decimal_places': PrecisionMode.decimalPlaces,
        },
        EvalSettings.defaults.precisionMode,
      ),
      precision: precision,
      fractionMode: _enumFrom<FractionMode>(
        prefs.getString(_kFractionMode),
        const <String, FractionMode>{
          'off': FractionMode.off,
          'improper': FractionMode.improper,
          'mixed': FractionMode.mixed,
        },
        EvalSettings.defaults.fractionMode,
      ),
      grouping: prefs.getBool(_kGrouping) ?? EvalSettings.defaults.grouping,
    );
  }

  @override
  Future<void> saveSettings(EvalSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAngleMode, settings.angleMode.id);
    await prefs.setInt(_kWordSize, settings.wordSize);
    await prefs.setString(_kNotation, settings.notation.id);
    await prefs.setString(_kPrecisionMode, settings.precisionMode.id);
    await prefs.setInt(_kPrecision, settings.precision);
    await prefs.setString(_kFractionMode, settings.fractionMode.id);
    await prefs.setBool(_kGrouping, settings.grouping);
  }

  @override
  Future<AppThemeMode> loadThemeMode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _enumFrom<AppThemeMode>(
      prefs.getString(_kThemeMode),
      const <String, AppThemeMode>{
        'system': AppThemeMode.system,
        'light': AppThemeMode.light,
        'dark': AppThemeMode.dark,
      },
      AppThemeMode.system,
    );
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  static int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  static T _enumFrom<T>(
    String? raw,
    Map<String, T> table,
    T fallback,
  ) {
    if (raw == null) {
      return fallback;
    }
    return table[raw] ?? fallback;
  }
}

/// 纯内存实现：测试注入用，行为与 SharedPreferences 版一致但不落盘。
class MemorySettingsStore implements SettingsStore {
  /// 初始为空表示"从未存过"，读时回落默认值。
  MemorySettingsStore({EvalSettings? settings, this.themeMode = AppThemeMode.system})
      : _settings = settings;

  EvalSettings? _settings;

  /// 当前主题（内存版直接暴露字段，便于测试断言）。
  AppThemeMode themeMode;

  @override
  Future<EvalSettings> loadSettings() async => _settings ?? EvalSettings.defaults;

  @override
  Future<void> saveSettings(EvalSettings settings) async {
    _settings = settings;
  }

  @override
  Future<AppThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    themeMode = mode;
  }
}
