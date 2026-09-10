/// 测试替身 —— 给 `flutter test` 与组件测试注入用的 [EngineGateway] 实现。
///
/// 两条铁律：
/// 1. **不 import `dart:ffi`、不加载 `.so`**（架构风险 R3）：
///    测试进程是宿主机，找不到 APK 里的 `lib/<abi>/*.so`，一加载就崩。
/// 2. **绝不重新实现数学**（约束 C8）：
///    这里只吐**固定值**，任何"看起来像计算"的逻辑都不允许出现在 Dart 侧——
///    数值语义的唯一权威是 Rust 引擎，测试里伪造一份只会掩盖真实回归。
///
/// 唯一的例外是 [applyEdit] 的字符串插入/删除：它操作的是**文本**而不是数值，
/// 不属于 C8 禁止的"数值运算"，且 UI 组件测试需要它来验证括号配对交互。
library;

import '../models/base_repr.dart';
import '../models/constant_info.dart';
import '../models/convert_result.dart';
import '../models/eval_result.dart';
import '../models/eval_settings.dart';
import '../models/number_value.dart';
import '../models/unit_info.dart';
import '../models/variable_info.dart';
import 'engine_gateway.dart';

/// 固定值引擎。
class FakeEngine implements EngineGateway {
  /// 构造时一次性给定所有"固定答案"，测试按需覆盖。
  FakeEngine({
    this.previewDisplay = '7',
    this.commitDisplay = '7',
    this.formattedDisplay = '0.3333333333',
    this.constants = const <ConstantInfo>[],
    this.categories = const <CategoryInfo>[],
    this.variables = const <VariableInfo>[],
    this.convertFrom,
    this.convertTo,
  });

  /// 预览求值固定返回的显示串。
  final String previewDisplay;

  /// 提交求值固定返回的显示串。
  final String commitDisplay;

  /// `formatNumber` 固定返回的显示串。
  final String formattedDisplay;

  /// 常量列表。
  final List<ConstantInfo> constants;

  /// 单位类别列表。
  final List<CategoryInfo> categories;

  /// 变量列表。
  final List<VariableInfo> variables;

  /// 换算的源单位（缺省时给一个占位 UnitInfo）。
  final UnitInfo? convertFrom;

  /// 换算的目标单位。
  final UnitInfo? convertTo;

  /// 预览被调用的次数（供测试断言"防抖后只调一次"）。
  int previewCalls = 0;

  /// 提交被调用的次数。
  int commitCalls = 0;

  EvalResult _fixedEval(String display) => EvalResult(
        // 固定用有理数 0 承载：Fake 不参与数值语义
        value: const NumberValue(
          kind: NumberKind.rational,
          numerator: 0,
          denominator: 1,
        ),
        display: display,
        base: const BaseRepr(
          dec: '0',
          hex: '0',
          oct: '0',
          bin: '0',
          wordSize: 64,
          isInteger: true,
        ),
        assignments: const <VariableInfo>[
          VariableInfo(name: 'ans', display: '7', readonly: true),
        ],
        isInteger: true,
      );

  @override
  Map<String, dynamic> version() => const <String, dynamic>{
        'version': '0.0.0-fake',
        'engine': 'fake',
        'abi': 1,
      };

  @override
  EvalResult evaluatePreview({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  }) {
    previewCalls++;
    return _fixedEval(previewDisplay);
  }

  @override
  EvalResult evaluateCommit({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  }) {
    commitCalls++;
    return _fixedEval(commitDisplay);
  }

  @override
  ConvertResult convert({
    String? value,
    String? from,
    String? to,
    String? query,
  }) {
    return ConvertResult(
      from: convertFrom ??
          const UnitInfo(id: 'inch', symbol: 'inch', name: '英寸'),
      to: convertTo ?? const UnitInfo(id: 'mm', symbol: 'mm', name: '毫米'),
      inputValue: const NumberValue(
        kind: NumberKind.rational,
        numerator: 0,
        denominator: 1,
      ),
      outputValue: const NumberValue(
        kind: NumberKind.rational,
        numerator: 0,
        denominator: 1,
      ),
      inputDisplay: '12.7 inch',
      outputDisplay: '322.58 mm',
    );
  }

  @override
  List<ConstantInfo> listConstants() => constants;

  @override
  List<CategoryInfo> listUnits({String? category}) => categories;

  @override
  List<VariableInfo> listVariables() => variables;

  @override
  FormattedValue formatNumber({
    required String value,
    EvalSettings? settings,
  }) {
    return FormattedValue(display: formattedDisplay, isInteger: false);
  }

  @override
  VariableInfo setVariable({required String name, required String expr}) {
    return VariableInfo(name: name, display: commitDisplay);
  }

  @override
  String deleteVariable({required String name}) => name;

  /// 角度模式：只回显，不做任何换算（换算属于数学，交给 Rust）。
  @override
  String setAngleMode(AngleMode mode) => mode.id;

  /// 位宽：只回显。
  @override
  int setWordSize(int wordSize) => wordSize;

  @override
  void resetSession({bool keepAns = true}) {}

  /// 文本编辑替身：**只做字符串插入/删除**，不碰任何数值语义。
  @override
  EditOutcome applyEdit({
    required String text,
    required int cursor,
    required String action,
    String payload = '',
  }) {
    // clamp 的静态返回类型是 num，这里显式转回 int
    final int at = cursor.clamp(0, text.length).toInt();
    switch (action) {
      case 'backspace':
        if (at <= 0 || text.isEmpty) {
          return EditOutcome(text: text, cursor: at, changed: false);
        }
        return EditOutcome(
          text: text.substring(0, at - 1) + text.substring(at),
          cursor: at - 1,
          changed: true,
        );
      case 'delete':
        if (at >= text.length) {
          return EditOutcome(text: text, cursor: at, changed: false);
        }
        return EditOutcome(
          text: text.substring(0, at) + text.substring(at + 1),
          cursor: at,
          changed: true,
        );
      case 'insert':
      default:
        if (payload.isEmpty) {
          return EditOutcome(text: text, cursor: at, changed: false);
        }
        return EditOutcome(
          text: text.substring(0, at) + payload + text.substring(at),
          cursor: at + payload.length,
          changed: true,
        );
    }
  }
}
