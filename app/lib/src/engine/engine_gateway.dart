/// 引擎网关抽象 —— L3 层对上暴露的唯一接口（架构 §1.2）。
///
/// 为什么要有这一层：
/// 1. **可测试**：`flutter test` 环境加载不了 `.so`（CI 会直接崩），
///    所有测试注入 [FakeEngine] 即可，绝不触碰 `dart:ffi`（架构 §T04 要点 8 / R3）。
/// 2. **可替换**：真机走 `NativeEngine`，未来若要换 JNI 或加缓存，只换实现不改调用方。
///
/// 方法全部**同步**：FFI 调用在 UI isolate 内微秒级返回（架构 §5.1"线程"一行：
/// 计算足够快，统一同步调用），没必要引入 Future 让状态机复杂化。
library;

import '../models/constant_info.dart';
import '../models/convert_result.dart';
import '../models/eval_result.dart';
import '../models/eval_settings.dart';
import '../models/unit_info.dart';
import '../models/variable_info.dart';

/// 引擎能力集合。方法名与 §5.2 的函数清单一一对应。
abstract class EngineGateway {
  /// 版本自检；返回 `{"version","engine","abi"}`。
  Map<String, dynamic> version();

  /// 预览求值：**无副作用**，不改 ans、不写变量。
  EvalResult evaluatePreview({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  });

  /// 提交求值：更新 `ans`，赋值语句写入变量。
  EvalResult evaluateCommit({
    required String expr,
    int? cursor,
    EvalSettings? settings,
  });

  /// 单位换算。`value+from+to` 与 `query` 二选一。
  ConvertResult convert({
    String? value,
    String? from,
    String? to,
    String? query,
  });

  /// 常量列表（≥12 个）。
  List<ConstantInfo> listConstants();

  /// 单位类别列表；`category` 为空返回全部 10 类。
  List<CategoryInfo> listUnits({String? category});

  /// 变量列表（含只读的 ans）。
  List<VariableInfo> listVariables();

  /// 按设置格式化一个数值表达式（不落会话）。
  FormattedValue formatNumber({
    required String value,
    EvalSettings? settings,
  });

  /// 定义/覆盖变量；右值先求值再存。
  VariableInfo setVariable({required String name, required String expr});

  /// 删除变量；返回被删除的变量名。
  String deleteVariable({required String name});

  /// 设置角度模式；返回落库后的模式 id。
  String setAngleMode(AngleMode mode);

  /// 设置位宽（8/16/32/64）；返回落库后的位宽。
  int setWordSize(int wordSize);

  /// 重置会话；默认保留 ans（Q9）。
  void resetSession({bool keepAns = true});

  /// 输入编辑纯函数（括号自动配对等）。
  ///
  /// [action] 取值与 Rust `EditAction::from_id` 一致：`insert` / `backspace` / `delete`。
  EditOutcome applyEdit({
    required String text,
    required int cursor,
    required String action,
    String payload = '',
  });
}
