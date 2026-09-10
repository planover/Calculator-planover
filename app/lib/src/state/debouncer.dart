/// 防抖器 —— 把"连续输入"压成"最后一次稳定后的单次调用"（架构 §T05 要点 2）。
///
/// 为什么必须有它：输入 `sin(30)+2(` 的过程中每一次按键都会触发预览求值，
/// 逐个求值既浪费又会让界面在"写到一半"时闪红。120ms 的静默窗口之后才真正求值，
/// 既跟手又不抖。
library;

import 'dart:async';

/// 单次防抖。
class Debouncer {
  /// [delay] 默认 120ms（架构 §T05 给定值）。
  Debouncer({this.delay = defaultDelay});

  /// 默认静默窗口。
  static const Duration defaultDelay = Duration(milliseconds: 120);

  /// 静默窗口时长。
  final Duration delay;

  Timer? _timer;

  /// 是否有一次尚未触发的调用在等待。
  bool get isPending => _timer?.isActive ?? false;

  /// 提交一次动作：**取消上一次未触发的**，重新计时。
  void call(void Function() action) {
    cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  /// [call] 的别名，读起来更像"跑一次"。
  void run(void Function() action) => call(action);

  /// 取消挂起的动作（不执行）。页面销毁时调，避免回调打到已卸载的 State 上。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源；等价于 [cancel]。
  void dispose() => cancel();
}
