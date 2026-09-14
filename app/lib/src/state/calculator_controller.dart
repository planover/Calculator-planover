/// 计算器主状态机（架构 §T05 要点 3 / §10.2.3）。
///
/// 职责：
/// - 持有表达式文本 / 光标、预览显示串、错误与进制表示；
/// - 表达式变化经 120ms 防抖后调引擎预览求值（架构 §10：防抖统一用 [Debouncer]）；
/// - `=` / Enter / 结果长按 提交求值并写入历史、清空输入；
/// - 编辑走引擎 `applyEdit`（括号配对等），Dart 侧不实现任何插入/删除逻辑（R1）；
/// - 设置（角度/位宽）变化经 [SettingsController] 持久化后**同步下发引擎**并立即重算预览；
/// - 记忆寄存器（PRD §13.1）：M+/M-/MC/MR 经引擎 `memory_*` 方法，UI 据此显示 `M` 指示器；
/// - 提交方式（PRD §3.2 UI-11~13）：默认 calculate-on-fly（实时预览），手动模式需显式提交。
///
/// 铁律：本文件**不 import `dart:ffi` / `native_engine.dart`**，只依赖
/// [EngineGateway] 抽象（架构风险 R3）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../engine/engine_exception.dart';
import '../engine/engine_gateway.dart';
import '../models/base_repr.dart';
import '../models/eval_result.dart';
import '../models/eval_settings.dart';
import '../models/engine_error.dart';
import '../models/history_entry.dart';
import '../models/memory_state.dart';
import '../models/submit_mode.dart';
import '../state/debouncer.dart';
import '../state/settings_controller.dart';
import 'history_controller.dart';

/// 计算器主控制器。
class CalculatorController extends ChangeNotifier {
  /// 装配：引擎 + 设置控制器 + 历史控制器。
  ///
  /// [normalizeInput] 可注入：把用户输入中的**区域小数分隔符**规范化成引擎内部
  /// 语法 `.`（LC-09 / A4）。为 null 时不做规范化（测试/无区域场景）。
  CalculatorController({
    required EngineGateway engine,
    required SettingsController settings,
    required HistoryController history,
    String Function(String expr)? normalizeInput,
  })  : _engine = engine,
        _settings = settings,
        _history = history,
        _normalizeInput = normalizeInput {
    _settings.addListener(_onSettingsChanged);
    // 把已载入的设置下发引擎（角度/位宽），并做首次预览。
    _pushSettingsToEngine();
    _refreshMemory();
    _recomputePreview();
  }

  final EngineGateway _engine;
  final SettingsController _settings;
  final HistoryController _history;

  /// 输入规范化回调（LC-09）：区域 `,` → 引擎内部 `.`。
  final String Function(String expr)? _normalizeInput;

  final Debouncer _debouncer = Debouncer();

  String _text = '';
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  String _preview = '';
  BaseRepr? _base;
  EngineException? _error;
  ErrorSpan? _errorSpan;

  /// 记忆寄存器当前状态（初值 0）。
  MemoryState _memory = const MemoryState();

  /// 当前表达式是否用过 `MR` 插回记忆值（用于历史条目标记，CP-16）。
  bool _usedMemory = false;

  /// 手动模式下，是否已有一次显式提交结果可供展示。
  bool _resultExplicit = true;

  /// 当前表达式文本。
  String get text => _text;

  /// 当前光标 / 选区（char 偏移）。
  TextSelection get selection => _selection;

  /// 预览显示串（成功时）。
  String get preview => _preview;

  /// 当前结果的进制表示（成功且为整数时有值）。
  BaseRepr? get base => _base;

  /// 当前错误（成功时为 null）。
  EngineException? get error => _error;

  /// 出错区间（无位置信息时为空）。
  ErrorSpan? get errorSpan => _errorSpan;

  /// 当前角度模式（角度唯一来源是引擎，Dart 只缓存）。
  AngleMode get angleMode => _settings.settings.angleMode;

  /// 暴露引擎抽象，供 UI（常量/变量面板、单位换算）拉取只读列表。
  /// UI 只依赖 [EngineGateway]，绝不触碰 `dart:ffi` / `native_engine`。
  EngineGateway get engine => _engine;

  /// 当前位宽（供设置页读取）。
  int get settingsWordSize => _settings.settings.wordSize;

  /// 记忆寄存器状态（UI 据此显示 `M` 指示器与记忆面板）。
  MemoryState get memory => _memory;

  /// 记忆寄存器是否非零（非零时显示 `M` 指示器，CP-07）。
  bool get hasMemory => !_memory.isZero;

  /// 提交方式：是否开启 calculate-on-fly（边输入边出结果，UI-11）。
  bool get livePreview => _settings.submitMode == SubmitMode.auto;

  /// 结果区是否应当展示结果（手动模式下仅显式提交后展示，UI-12）。
  bool get resultVisible => livePreview || _resultExplicit;

  /// 结果区应当展示的文本（手动模式下未提交时为空，UI-12）。
  String get resultText => resultVisible ? _preview : '';

  /// 当前表达式变化（来自软键盘 / 粘贴 / IME）。
  ///
  /// 立即更新文本让输入跟手，再经防抖触发预览求值。
  void onExpressionChanged(String text, TextSelection selection) {
    _text = _applyNormalize(text);
    _selection = selection;
    _markEdited();
    notifyListeners();
    _debouncer.call(_recomputePreview);
  }

  /// 用一段新表达式整体替换（如从历史载入）。
  void setText(String text) {
    _text = _applyNormalize(text);
    _selection = TextSelection.collapsed(offset: _text.length);
    _markEdited();
    notifyListeners();
    _debouncer.call(_recomputePreview);
  }

  /// 把用户输入的区域小数分隔符规范化成引擎内部 `.`（LC-09 / A4）。
  ///
  /// 未注入规范化器时原样返回（Dart 侧不做任何语法改写，保持"编辑逻辑归 Rust"）。
  String _applyNormalize(String text) {
    final String Function(String)? f = _normalizeInput;
    if (f == null) {
      return text;
    }
    return f(text);
  }

  /// 走引擎的纯函数编辑（插入 / 退格 / 删除，含括号配对）。
  ///
  /// [action] 取 `'insert' | 'backspace' | 'delete'`，[payload] 为插入文本。
  void applyEdit(String action, {String payload = ''}) {
    final EditOutcome outcome = _engine.applyEdit(
      text: _text,
      cursor: _selection.baseOffset,
      action: action,
      payload: payload,
    );
    if (!outcome.changed) {
      return;
    }
    _text = outcome.text;
    _selection = TextSelection.collapsed(offset: outcome.cursor);
    _markEdited();
    notifyListeners();
    _debouncer.call(_recomputePreview);
  }

  /// 智能括号键 `( )`（键盘第 5 行第 1 位，UI-09）：依据当前表达式未配对的
  /// 左括号数，自动决定插入 `(` 还是 `)`。只有一个 `Expanded` 占位的合并键。
  void insertSmartParen() {
    final int open = '('.allMatches(_text).length;
    final int close = ')'.allMatches(_text).length;
    final String paren = open > close ? ')' : '(';
    applyEdit('insert', payload: paren);
  }

  /// 光标左移一格（键盘 `←`，UI-16）；到边界不动且不报错。
  void moveCursorLeft() {
    final int at =
        (_selection.baseOffset - 1).clamp(0, _text.length).toInt();
    _selection = TextSelection.collapsed(offset: at);
    notifyListeners();
  }

  /// 光标右移一格（键盘 `→`，UI-16）；到边界不动且不报错。
  void moveCursorRight() {
    final int at =
        (_selection.baseOffset + 1).clamp(0, _text.length).toInt();
    _selection = TextSelection.collapsed(offset: at);
    notifyListeners();
  }

  /// 清空当前输入（C 短按）。
  void clearInput() => setText('');

  /// 提交求值（= / Enter / 结果长按）。
  ///
  /// 成功：结果写入历史、预览更新为该结果、清空输入、光标归零。
  /// 失败（含不完整表达式）：保留错误态与输入，不入历史。
  Future<void> commit() async {
    EvalResult result;
    try {
      result = _engine.evaluateCommit(
        expr: _text,
        cursor: _selection.baseOffset,
        settings: _settings.settings,
      );
    } on EngineException catch (e) {
      _error = e;
      _errorSpan = e.span;
      _base = null;
      notifyListeners();
      return;
    }
    await _history.add(HistoryEntry(
      expr: _text,
      result: result.display,
      ts: DateTime.now().millisecondsSinceEpoch,
      usedMemory: _usedMemory,
    ));
    _preview = result.display;
    _base = result.base;
    _error = null;
    _errorSpan = null;
    _text = '';
    _selection = const TextSelection.collapsed(offset: 0);
    _usedMemory = false;
    _resultExplicit = true;
    notifyListeners();
  }

  /// 记忆寄存器 `M+`：把"当前结果"累加进记忆（不动 `ans`）。
  void memoryAdd() {
    _memory = _engine.memoryAdd(_memoryOperand);
    notifyListeners();
  }

  /// 记忆寄存器 `M-`：把"当前结果"从记忆中减去（不动 `ans`）。
  void memorySubtract() {
    _memory = _engine.memorySubtract(_memoryOperand);
    notifyListeners();
  }

  /// 记忆寄存器 `MC`：清零（幂等）。
  void memoryClear() {
    _memory = _engine.memoryClear();
    notifyListeners();
  }

  /// 记忆寄存器 `MR`：把记忆值插回表达式当前光标处（负值形如 `(-5)`）。
  ///
  /// 同时标记"本表达式用过 MR"，供历史条目打 `M` 标记（CP-16）。
  void memoryRecall() {
    final String literal = _memory.text;
    _memory = _engine.memoryRecall();
    applyEdit('insert', payload: literal);
    _usedMemory = true;
    notifyListeners();
  }

  /// 切换角度模式：持久化 → 下发引擎 → 重算（由 [SettingsController] 监听器触发）。
  Future<void> setAngleMode(AngleMode mode) => _settings.setAngleMode(mode);

  /// 切换位宽：持久化 → 下发引擎 → 重算。
  Future<void> setWordSize(int wordSize) => _settings.setWordSize(wordSize);

  /// 重置会话（C 长按）：清空输入与错误态、清零记忆（随 reset_session）。
  void reset() {
    _engine.resetSession(keepAns: true);
    _text = '';
    _selection = const TextSelection.collapsed(offset: 0);
    _error = null;
    _errorSpan = null;
    _base = null;
    _preview = '';
    _usedMemory = false;
    _resultExplicit = true;
    _refreshMemory();
    _recomputePreview();
    notifyListeners();
  }

  /// 设置变化：重新下发引擎并立即重算预览（角度/位宽切换后预览需立刻更新）。
  void _onSettingsChanged() {
    _pushSettingsToEngine();
    _recomputePreview();
  }

  void _pushSettingsToEngine() {
    final EvalSettings s = _settings.settings;
    _engine.setAngleMode(s.angleMode);
    _engine.setWordSize(s.wordSize);
  }

  /// 记忆操作数：当前表达式文本（先求值）；为空时退回 `ans`。
  String get _memoryOperand =>
      _text.trim().isNotEmpty ? _text : 'ans';

  /// 从引擎重新拉取记忆状态（reset / 构造时调用）。
  void _refreshMemory() {
    _memory = _engine.memoryRecall();
  }

  /// 文本被编辑后：清除"用过 MR"标记；手动模式下隐藏上一次提交的结果。
  void _markEdited() {
    _usedMemory = false;
    if (!livePreview) {
      _resultExplicit = false;
    }
  }

  void _recomputePreview() {
    try {
      final EvalResult r = _engine.evaluatePreview(
        expr: _text,
        cursor: _selection.baseOffset,
        settings: _settings.settings,
      );
      _preview = r.display;
      _base = r.base;
      _error = null;
      _errorSpan = null;
    } on EngineException catch (e) {
      // §10.2.3：不完整表达式给灰色提示（error 仍保留，preview_line 按
      // isIncompleteExpression 选灰色）；其余红色 + span 高亮。
      _error = e;
      _errorSpan = e.span;
      if (!e.isIncompleteExpression) {
        _base = null;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _debouncer.dispose();
    super.dispose();
  }
}
