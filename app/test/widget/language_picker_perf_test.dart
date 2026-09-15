/// UX-02 选择器（懒加载 / 首帧项 / 搜索）行为断言（`[D]`，架构 §3.2.2 / §3.2.3）：
/// 1. 打开选择器**首帧构建项 > 0 且 ≤ 30**（窄屏，411×1200）；
/// 2. 列表**确实是懒加载**：`childrenDelegate is SliverChildBuilderDelegate`
///    —— 窄屏 `ListView.builder`、宽屏（≥600dp）`GridView.builder` 两条路径都覆盖；
/// 3. 清单**不缩减**（childCount 仍为 216 + 1，"跟随系统"项）；
/// 4. 搜索可过滤、选择语言后生效且无异常。
///
/// ⚠️ **帧耗时（P95 / 单帧上限）不在本单元测试的覆盖范围内**：
/// `SchedulerBinding.addTimingsCallback` 的上报来自引擎光栅化阶段的 `onReportTimings`，
/// 而 `AutomatedTestWidgetsFlutterBinding` 用**假帧调度**跑 `pump()`（无真实光栅化），
/// 因此**收不到任何 `FrameTiming` 回调**。任何"采集不到帧时序就跳过 / 打印一行放过"
/// 的写法都是**恒绿假断言**（正是本次移除的缺陷）——它让红灯永远不会亮。
/// 帧耗时改由 `integration_test`（真机 / 模拟器）度量：见增量 PRD §8.2 提测清单 UX-02。
/// 本层改用**确定性结构断言**（delegate 类型 + 首帧项计数）守住"未一次性构建 216 项"
/// 这一卡死根因。
///
/// 铁律：仅 `FakeEngine`，不 import `dart:ffi`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/ui/screens/language_picker_screen.dart';

// harness 位于 `test/support/`，本文件在 `test/widget/` → 需向上一层。
import '../support/harness.dart';

/// 选择器子树内的 `ListTile` 数（只数可见窗口 + 缓冲，即"首帧构建项"）。
int _pickerTileCount() => find
    .descendant(
      of: find.byType(LanguagePickerScreen),
      matching: find.byType(ListTile),
    )
    .evaluate()
    .length;

/// 打开设置页 → 打开全屏语言选择器（停在**首帧**，不 settle）。
Future<AppHarness> _openPickerFirstFrame(WidgetTester tester, Size size) async {
  final AppHarness h = await pumpApp(tester, size: size);
  await tester.tap(find.byIcon(Icons.settings).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('openLanguagePicker')));
  await tester.pump(); // 路由推入首帧
  return h;
}

void main() {
  testWidgets('窄屏：真的懒加载（SliverChildBuilderDelegate）且首帧项 ∈ (0,30]',
      (WidgetTester tester) async {
    final AppHarness h =
        await _openPickerFirstFrame(tester, const Size(411, 1200));

    final int firstFrameTiles = _pickerTileCount();
    // 下界：若为 0 说明路由根本没推入 —— 此时"≤30"是假通过，必须失败。
    expect(
      firstFrameTiles,
      greaterThan(0),
      reason: '首帧未构建任何列表项 —— 路由可能未真正推入，本断言无效（禁止假通过）',
    );
    expect(
      firstFrameTiles,
      lessThanOrEqualTo(30),
      reason: '首帧构建 $firstFrameTiles 项 > 30 —— 未懒加载（216 项同步构建）',
    );
    // 兜底：绝不允许一次性构建全量。
    expect(
      firstFrameTiles,
      lessThan(LanguagePickerScreen.registryOptions().length),
      reason: '首帧即构建全部 216 项 —— 未懒加载',
    );

    // —— 可证伪的结构判据：委托必须是 `SliverChildBuilderDelegate` ——
    // 它由 `ListView.builder` / `GridView.builder` 产生；`ListView(children: [...])`
    // 用的是 `SliverChildListDelegate`，会被本断言判红 —— 这正是"真懒加载"的判据。
    final Finder listFinder = find.descendant(
      of: find.byType(LanguagePickerScreen),
      matching: find.byType(ListView),
    );
    expect(listFinder, findsOneWidget, reason: '窄屏应为单一 ListView.builder');
    final ListView listView = tester.widget<ListView>(listFinder);
    expect(
      listView.childrenDelegate,
      isA<SliverChildBuilderDelegate>(),
      reason: '窄屏列表委托不是 SliverChildBuilderDelegate —— 未使用 ListView.builder',
    );
    // 清单不缩减（LG-03）：项数 == 216 档 + 1 个"跟随系统"。
    // 用 `SliverChildDelegate.estimatedChildCount`（基类公共 getter）而非子类字段，
    // 避免依赖 `SliverChildBuilderDelegate.childCount` 的可见性。
    expect(
      listView.childrenDelegate.estimatedChildCount,
      LanguagePickerScreen.registryOptions().length + 1,
      reason: '列表项数应保持 216 + 1（LG-03 不缩减），仅改变懒加载呈现',
    );

    await tester.pumpAndSettle();
    h.dispose();
  });

  testWidgets('宽屏（≥600dp）：GridView.builder 同样懒加载、首帧项 < 全量',
      (WidgetTester tester) async {
    final AppHarness h =
        await _openPickerFirstFrame(tester, const Size(800, 1280));

    final Finder gridFinder = find.descendant(
      of: find.byType(LanguagePickerScreen),
      matching: find.byType(GridView),
    );
    expect(gridFinder, findsOneWidget,
        reason: '宽屏（可用宽 ≥600dp）应走 GridView.builder 双列');
    final GridView gridView = tester.widget<GridView>(gridFinder);
    expect(
      gridView.childrenDelegate,
      isA<SliverChildBuilderDelegate>(),
      reason: '宽屏列表委托不是 SliverChildBuilderDelegate —— 未使用 GridView.builder',
    );
    // 双列可视项更多，故不设 ≤30（那只是窄屏口径）；只要求"未一次性构建全量"。
    final int firstFrameTiles = _pickerTileCount();
    expect(
      firstFrameTiles,
      greaterThan(0),
      reason: '首帧未构建任何列表项 —— 路由可能未真正推入',
    );
    expect(
      firstFrameTiles,
      lessThan(LanguagePickerScreen.registryOptions().length),
      reason: '宽屏首帧即构建全部 216 项 —— 未懒加载',
    );

    await tester.pumpAndSettle();
    h.dispose();
  });

  testWidgets('搜索过滤 + 选中语言后生效且无异常', (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: const Size(411, 1200));

    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openLanguagePicker')));
    await tester.pumpAndSettle();

    // 过滤：'zh-CN' 只命中一项。
    await tester.enterText(
      find.byKey(const Key('languagePickerSearch')),
      'zh-CN',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lang_zh-CN')), findsOneWidget);
    expect(_pickerTileCount(), lessThanOrEqualTo(30));

    // 选中 → 返回并生效（设置页标题刷新为中文）。
    await tester.tap(find.byKey(const Key('lang_zh-CN')));
    await tester.pumpAndSettle();
    expect(h.locale.manualTag, 'zh-CN');
    expect(find.text('设置'), findsWidgets);
    expect(tester.takeException(), isNull);

    h.dispose();
  });
}
