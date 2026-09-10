/// 防抖器测试。
///
/// 用真实计时器（延迟取 20ms 而非 120ms）而不是 `FakeAsync`：
/// 这样可以少引一个 `fake_async` 依赖，且 20ms 对真实 Timer 足够稳定。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/state/debouncer.dart';

void main() {
  test('连续调用只触发最后一次', () async {
    final Debouncer d = Debouncer(delay: const Duration(milliseconds: 20));
    int calls = 0;

    d.call(() => calls++);
    d.call(() => calls++);
    d.call(() => calls++);

    // 静默窗口内不应触发
    expect(calls, 0);
    expect(d.isPending, true);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 1);
    expect(d.isPending, false);

    d.dispose();
  });

  test('cancel 后不再触发', () async {
    final Debouncer d = Debouncer(delay: const Duration(milliseconds: 20));
    int calls = 0;

    d.call(() => calls++);
    d.cancel();
    expect(d.isPending, false);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(calls, 0);

    d.dispose();
  });

  test('默认延迟是 120ms（架构 §T05）', () {
    final Debouncer d = Debouncer();
    expect(d.delay, const Duration(milliseconds: 120));
    d.dispose();
  });
}
