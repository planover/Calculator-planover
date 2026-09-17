/// IC-17 通用**布局护栏**（架构 §1.7 Q2/Q3，T01.4）：主界面在**全档**（§1.5 六档，
/// 含 `M(411)` 触发档 / `S(320)` 最窄档）与**窄带扫掠** `{320,360,411,480}` 下，
/// 置**最坏状态**（`M` 与 `Ans` **同时**显示，把显示区那一行撑到最宽）后，断言
/// **无 `RenderFlex overflow`**。
///
/// 为什么需要它：`display_panel.dart:42` 原本的 4 段角度 `SegmentedButton`
/// （增量新增第 4 档 `TURNS`）在 `M(411dp)` 内宽仅 379px 时即
/// `RenderFlex overflowed by 75 pixels`，320dp 更甚（可用 288px）；Release 下
/// 溢出静默裁切 = 用户「界面错章杂乱」的真实构成。改成单芯片（IC-17）后，
/// 本护栏**常驻**防回归。
///
/// 本文件另含一条**芯片契约**用例，锁定 T01.4 ①必须保留的两项语义契约：
/// `Key('angleModeSwitch')` 与 `Semantics(label: 'angle mode')`，并端到端验证
/// 「点按芯片 → 弹 4 选 1 → 选中下发引擎」链路未退化。
///
/// 铁律：仅 `FakeEngine`，不 import `dart:ffi`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/models/eval_settings.dart';

// harness 位于 `test/support/`，本文件在 `test/widget/` → 需向上一层。
import '../support/harness.dart';

/// 把主界面置到**最坏状态**：`M` 与 `Ans` **同时**显示（显示区那一行最宽）。
///
/// - `M`：`setText('5')` 后 `M+` → `MemoryState` 非零 → `hasMemory == true`；
/// - `Ans`：`commit()` 后 `resultText` 必非空（**不依赖** `submitMode`）→
///   `_AnsIndicator` 显示。
///
/// 顺序不可颠倒：`commit()` 会清空表达式，若先 `commit()` 再 `M+`，操作数退化为
/// `ans`（Fake 解析为 0）→ `M` 不显示。故先累加记忆、再提交。
Future<void> _worstCase(WidgetTester tester, AppHarness h) async {
  h.calculator.setText('5');
  h.calculator.memoryAdd(); // M+（操作数 = 当前表达式 '5'）→ hasMemory=true
  await h.calculator.commit(); // 提交 → Ans 显示（不动记忆）
  // 一次即时帧（让 M / Ans 出现）+ 一次越过 120ms 输入防抖的帧（清空悬挂 Timer）。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  // ① §1.5 全量六档（**必含** `M(411)` 触发档与 `S(320)` 最窄档）。
  for (final DeviceClass d in DeviceClass.all) {
    final String where = '${d.name}(${d.size.width.toInt()}×'
        '${d.size.height.toInt()}dp)';
    testWidgets('主界面最坏状态无布局溢出 @$where', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(
        tester,
        size: d.size,
        devicePixelRatio: d.dpr,
      );
      await _worstCase(tester, h);
      expectNoLayoutOverflow(tester, where: where);
      h.dispose();
    });
  }

  // ② 窄带扫掠（含 §4.1 compact 阈值 360），防边界值回归。
  const List<double> widths = <double>[320, 360, 411, 480];
  for (final double w in widths) {
    final String where = '窄带 ${w.toInt()}dp';
    testWidgets('主界面最坏状态无布局溢出 @$where', (WidgetTester tester) async {
      final AppHarness h = await pumpApp(tester, size: Size(w, 891));
      await _worstCase(tester, h);
      expectNoLayoutOverflow(tester, where: where);
      h.dispose();
    });
  }

  // ③ 芯片契约（T01.4 ①）：Key / 语义标签**必须保留**，且 4 选 1 交互可下发引擎。
  testWidgets('角度芯片契约：Key + 语义标签保留，点按弹 4 选 1 且下发引擎',
      (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: const Size(411, 891));

    // Key 保留（供测试点击）。
    expect(find.byKey(const Key('angleModeSwitch')), findsOneWidget);

    // 语义标签保留（`Semantics(label: 'angle mode')`）——以 widget 树为准，确定性最强。
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.label == 'angle mode',
      ),
      findsOneWidget,
    );

    // 当前模式常显（默认 DEG）。
    expect(h.calculator.angleMode, AngleMode.deg);

    // 点按芯片 → 弹出 4 选 1 → 选中 RAD → 经控制器下发引擎。
    await tester.tap(find.byKey(const Key('angleModeSwitch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('angleModeOption-rad')), findsOneWidget);
    await tester.tap(find.byKey(const Key('angleModeOption-rad')));
    await tester.pumpAndSettle();
    expect(h.calculator.angleMode, AngleMode.rad);

    // 换档后仍应无溢出（芯片文本变化不改变宽度上限）。
    expectNoLayoutOverflow(tester, where: 'contract/after-select-RAD');

    h.dispose();
  });
}
