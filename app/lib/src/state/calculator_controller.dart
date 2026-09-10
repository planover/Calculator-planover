/// 计算器主状态机（架构 §T05 要点 3 / §10.2.3）。
///
/// 职责：
/// - 持有表达式文本 / 光标、预览显示串、错误与进制表示；
/// - 表达式变化经 120ms 防抖后调引擎预览求值（架构 §10：防抖统一用 [Debouncer]）；
/// - `=` 提交求值并写入历史、清空输入；
/// - 编辑走引擎 `applyEdit`（括号配对等），Dart 侧不实现任何插入/删除逻辑（R1）；
/// - 设置（角度/位宽）变化经 [SettingsController] 持久化后**同步下发引擎**并立即重算预览。
///
/// 铁律：本文件**不 import `dart:ffi` / `native_engine.dart`**，只依赖
/// [EngineGateway] 抽象（架构风险 R3）。
library;

import 'package:flutter/foundation.dart';

import '../engine/engine_exception.dart';
import '../engine/engine_gateway.dart';
import '../models/base_repr.dart';
import '../models/eval_result.dart';
import '../models/eval_settings.dart';
import '../models/engine_error.dart';
import '../state/debouncer.dart';
import '../state/settings_controller.dart';
import 'history_controller.dart';

/// 计算器主控制器。
class CalculatorController extends ChangeNotifier {
  /// 装配：引擎 + 设置控制器 + 历史控制器。
  CalculatorController({
    required EngineGateway engine,
    required SettingsController settings,
    required HistoryController history,
  })  : _engine = engine,
        _settings = settings,
        _history = history {
    _settings.addListener(_onSettingsChanged);
    // 把已载入的设置下发引擎（角度/位宽），并做首次预览。
    _pushSettingsToEngine();
    _recomputePreview();
  }

  final EngineGateway _engine;
  final SettingsController _settings;
  final HistoryController _history;

  final Debouncer _debouncer = Debouncer();

  String _text = '';
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  String _preview = '';
  BaseRepr? _base;
  EngineException? _error;
  ErrorSpan? _errorSpan;

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

  /// 表达式变化（来自软键盘 / 粘贴 / IME）。
  ///
  /// 立即更新文本让输入跟手，再经防抖触发预览求值。
  void onExpressionChanged(String text, TextSelection selection) {
    _text = text;
    _selection = selection;
    notifyListeners();
    _debouncer.call(_recomputePreview);
  }

  /// 用一段新表达式整体替换（如从历史载入）。
  void setText(String text) {
    _text = text;
    _selection = TextSelection.collapsed(offset: text.length);
    notifyListeners();
    _debouncer.call(_recomputePreview);
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
    notifyListeners();
    _debouncer.call(_recomputePreview);
  }

  /// 清空当前输入（C 短按）。
  void clearInput() => setText('');

  /// 提交求值（= 键）。
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
    ));
    _preview = result.display;
    _base = result.base;
    _error = null;
    _errorSpan = null;
    _text = '';
    _selection = const TextSelection.collapsed(offset: 0);
    notifyListeners();
  }

  /// 切换角度模式：持久化 → 下发引擎 → 重算（由 [SettingsController] 监听器触发）。
  Future<void> setAngleMode(AngleMode mode) => _settings.setAngleMode(mode);

  /// 切换位宽：持久化 → 下发引擎 → 重算。
  Future<void> setWordSize(int wordSize) => _settings.setWordSize(wordSize);

  /// 重置会话（C 长按）：保留 ans（Q9），清空输入与错误态。
  void reset() {
    _engine.resetSession(keepAns: true);
    _text = '';
    _selection = const TextSelection.collapsed(offset: 0);
    _error = null;
    _errorSpan = null;
    _base = null;
    _preview = '';
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
