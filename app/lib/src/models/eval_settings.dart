/// 求值 / 格式化设置 —— 镜像 `session.rs` 的 `EngineSettings`
/// 与 `api.rs` 的 `SettingsDto` / `FormatDto`。
///
/// 为什么一个类要兼容两种 JSON 形状：
/// - `evaluate_preview/commit` 的 `settings` 是 **嵌套**的 `SettingsDto`
///   （`angle_mode` / `word_size` / `number_format{...}`）；
/// - `format_number` 的 `settings` 是 **扁平**的 `FormatDto`
///   （直接是 `notation` / `precision` …）。
/// 两者来自同一份用户设置，Dart 侧没必要拆成两个类，于是 [EvalSettings.fromJson]
/// 同时接受两种写法，[toJson] / [toFormatJson] 分别产出对应形状。
library;

import '../utils/json_helpers.dart';

/// 角度模式（对应 `AngleMode`）。
enum AngleMode { deg, rad, grad }

/// 记数法（对应 `Notation`）。
enum Notation { auto, scientific, fixed }

/// 精度模式（对应 `PrecisionMode`）。
enum PrecisionMode { significant, decimalPlaces }

/// 分数显示模式（对应 `FractionMode`）。
enum FractionMode { off, improper, mixed }

/// 精度合法下界（与 Rust `MIN_PRECISION` 一致）。
const int minPrecision = 1;

/// 精度合法上界（与 Rust `MAX_PRECISION` 一致）。
const int maxPrecision = 15;

/// 合法位宽集合（与 Rust `WORD_SIZES` 一致）。
const List<int> validWordSizes = <int>[8, 16, 32, 64];

/// 枚举 → JSON 字符串。
extension AngleModeId on AngleMode {
  /// 稳定标识。
  String get id => const <AngleMode, String>{
        AngleMode.deg: 'deg',
        AngleMode.rad: 'rad',
        AngleMode.grad: 'grad',
      }[this]!;
}

/// 枚举 → JSON 字符串。
extension NotationId on Notation {
  /// 稳定标识。
  String get id => const <Notation, String>{
        Notation.auto: 'auto',
        Notation.scientific: 'scientific',
        Notation.fixed: 'fixed',
      }[this]!;
}

/// 枚举 → JSON 字符串。
extension PrecisionModeId on PrecisionMode {
  /// 稳定标识。
  String get id => const <PrecisionMode, String>{
        PrecisionMode.significant: 'significant',
        PrecisionMode.decimalPlaces: 'decimal_places',
      }[this]!;
}

/// 枚举 → JSON 字符串。
extension FractionModeId on FractionMode {
  /// 稳定标识。
  String get id => const <FractionMode, String>{
        FractionMode.off: 'off',
        FractionMode.improper: 'improper',
        FractionMode.mixed: 'mixed',
      }[this]!;
}

/// 一套完整的引擎设置。默认值与 Rust `EngineSettings::default()` 逐项对齐。
class EvalSettings {
  const EvalSettings({
    this.angleMode = AngleMode.deg,
    this.wordSize = 64,
    this.notation = Notation.auto,
    this.precisionMode = PrecisionMode.significant,
    this.precision = 10,
    this.fractionMode = FractionMode.off,
    this.grouping = true,
  });

  /// 角度模式。
  final AngleMode angleMode;

  /// 位宽 8/16/32/64。
  final int wordSize;

  /// 记数法。
  final Notation notation;

  /// 精度模式。
  final PrecisionMode precisionMode;

  /// 精度值，合法区间 1..15。
  final int precision;

  /// 分数显示。
  final FractionMode fractionMode;

  /// 千位分隔。
  final bool grouping;

  /// 默认设置（供"读失败回落"使用，见架构 §T04 要点 7）。
  static const EvalSettings defaults = EvalSettings();

  /// 宽容解析；同时接受嵌套 `SettingsDto` 与扁平 `FormatDto`。
  factory EvalSettings.fromJson(Object? json) {
    // number_format 存在就用它，否则把根对象本身当作扁平的 FormatDto
    final Map<String, dynamic>? nested = readMap(json, 'number_format');
    final Object? fmt = nested ?? json;

    final int raw = readInt(fmt, 'precision', 10);
    return EvalSettings(
      angleMode: readEnum<AngleMode>(
        json,
        'angle_mode',
        AngleMode.deg,
        const <String, AngleMode>{
          'deg': AngleMode.deg,
          'rad': AngleMode.rad,
          'grad': AngleMode.grad,
        },
      ),
      wordSize: readInt(json, 'word_size', 64),
      notation: readEnum<Notation>(
        fmt,
        'notation',
        Notation.auto,
        const <String, Notation>{
          'auto': Notation.auto,
          'scientific': Notation.scientific,
          'fixed': Notation.fixed,
        },
      ),
      precisionMode: readEnum<PrecisionMode>(
        fmt,
        'precision_mode',
        PrecisionMode.significant,
        const <String, PrecisionMode>{
          'significant': PrecisionMode.significant,
          'decimal_places': PrecisionMode.decimalPlaces,
        },
      ),
      // 越界的精度会被 Rust 判为 InvalidSettings，这里先夹回合法区间
      precision: raw < minPrecision
          ? minPrecision
          : (raw > maxPrecision ? maxPrecision : raw),
      fractionMode: readEnum<FractionMode>(
        fmt,
        'fraction_mode',
        FractionMode.off,
        const <String, FractionMode>{
          'off': FractionMode.off,
          'improper': FractionMode.improper,
          'mixed': FractionMode.mixed,
        },
      ),
      grouping: readBool(fmt, 'grouping', true),
    );
  }

  /// 产出嵌套的 `SettingsDto`（给 `evaluate_preview` / `evaluate_commit`）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'angle_mode': angleMode.id,
        'word_size': wordSize,
        'number_format': toFormatJson(),
      };

  /// 产出扁平的 `FormatDto`（给 `format_number`）。
  Map<String, dynamic> toFormatJson() => <String, dynamic>{
        'notation': notation.id,
        'precision_mode': precisionMode.id,
        'precision': precision,
        'fraction_mode': fractionMode.id,
        'grouping': grouping,
      };

  /// 局部修改。
  EvalSettings copyWith({
    AngleMode? angleMode,
    int? wordSize,
    Notation? notation,
    PrecisionMode? precisionMode,
    int? precision,
    FractionMode? fractionMode,
    bool? grouping,
  }) {
    return EvalSettings(
      angleMode: angleMode ?? this.angleMode,
      wordSize: wordSize ?? this.wordSize,
      notation: notation ?? this.notation,
      precisionMode: precisionMode ?? this.precisionMode,
      precision: precision ?? this.precision,
      fractionMode: fractionMode ?? this.fractionMode,
      grouping: grouping ?? this.grouping,
    );
  }

  @override
  String toString() =>
      'EvalSettings(${angleMode.id}, ws=$wordSize, ${notation.id}/${precisionMode.id}@$precision, ${fractionMode.id}, group=$grouping)';
}
