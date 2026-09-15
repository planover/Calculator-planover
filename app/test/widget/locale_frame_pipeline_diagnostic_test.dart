/// 诊断（非功能断言）：**语言切换 + 打开中的底部抽屉**是否会让**帧管线持续排队**。
///
/// 目的：把"用户反馈的『切换语言界面卡死』"从"测试写法问题"里**剥离**出来，
/// 变成一条**确定性信号**。`pumpAndSettle()` 挂死只能说明"帧管线没归零"，
/// 而"没归零"有两种截然不同的可能：
///   (a) 应用层存在**持续重绘 / 永不结束的动画**（真机 = 掉帧 / 发热 / 点不动的"卡死"）
///       ——【必须修源码】；
///   (b) 只是 `pumpAndSettle()` 的泵帧策略不当 ——【测试侧问题】。
///
/// 本诊断用**有界泵帧**（**永不挂死**）推进足够长的时间（30 × 50ms = 1500ms，
/// 远超任何有限动画 ≤ 300ms），再读取两个**决定性**信号：
///   - `tester.binding.hasScheduledFrame` —— 帧管线是否仍在排队；
///   - `tester.binding.transientCallbackCount` —— 仍在活动的**瞬时回调 / 动画（Ticker）**数。
///
/// 判读（决定性）：
///   - `hasScheduledFrame == false` 且 `transientCallbackCount == 0`
///       ⇒ 帧管线最终归零 ⇒ **(b) 测试写法问题**，应用侧无持续重绘，收工；
///   - `hasScheduledFrame == true` 或 `transientCallbackCount > 0`
///       ⇒ **(a) 应用层无限排帧 / 有动画永不结束** ⇒ 真机卡死根因，
///          **必须定位帧源并修源码**，不得用"测试改有界泵帧"掩盖。
///
/// 本文件的四条用例做**单变量对照**，用于把帧源**定位**到具体控件：
///   对照A 仅开记忆抽屉（不切语言）   —— 基线：抽屉本身是否已无限排帧；
///   判定① 记忆抽屉打开时切语言        —— 抽屉 + `showModalBottomSheet` 路由；
///   判定② 历史抽屉（Draggable）打开时切语言 —— `DraggableScrollableSheet` 的 extent 动效；
///   对照B 无抽屉、仅切语言（HomeScreen TabBar）—— 更上游（TabBar / AppBar / DisplayPanel）。
///
/// ⚠️ 用宽屏 800×1400 规避**既有的 `display_panel` 溢出**（那是另一条**独立缺陷**，
/// 与本诊断无关），确保只测"排帧"，不被溢出异常污染判读。
///
/// 铁律：仅 `FakeEngine`，不 import `dart:ffi`。
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/ui/widgets/keypad.dart';

// harness 位于 `test/support/`，本文件在 `test/widget/` → 需向上一层。
import '../support/harness.dart';

/// 宽屏尺寸：规避既有 display_panel 溢出（见文件头）。
const Size _kSize = Size(800, 1400);

/// 有界泵帧（**保证终止**）：推进 [frames] 帧 × [step]。
Future<void> _advance(
  WidgetTester tester, {
  int frames = 30,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// 键盘子树语义标签 Finder（避免与其他屏文案撞名）。
Finder _keypadSemantics(String label) => find.descendant(
      of: find.byType(Keypad),
      matching: find.bySemanticsLabel(label),
    );

/// 断言"泵帧后帧管线已归零、且无动画仍在活动"，并把**决定性信号打进 CI 日志**。
void _expectQuiescent(WidgetTester tester, String label, String hint) {
  final bool scheduled = tester.binding.hasScheduledFrame;
  final int tickers = tester.binding.transientCallbackCount;
  debugPrint('[DIAG] $label -> hasScheduledFrame=$scheduled '
      'transientCallbackCount=$tickers');
  expect(
    scheduled,
    isFalse,
    reason: '[$label] 帧管线仍在排队 —— 应用层持续重绘（真机＝卡顿/发热/卡死）。'
        '不是测试写法问题，必须修源码。线索：$hint',
  );
  expect(
    tickers,
    0,
    reason: '[$label] 仍有 $tickers 个活动动画/瞬时回调（Ticker）—— '
        '存在一个**永不结束的动画**，即持续重绘的帧源。线索：$hint',
  );
}

void main() {
  testWidgets('对照A：仅打开记忆抽屉（不切语言）→ 帧管线应归零',
      (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: _kSize);
    await tester.tap(_keypadSemantics('Memory'));
    await _advance(tester);
    _expectQuiescent(
      tester,
      'controlA:memorySheet-no-locale',
      '若此对照也为真，说明抽屉本身（不切语言）就已无限排帧，基线不成立',
    );
    h.dispose();
  });

  testWidgets('判定①：记忆抽屉打开状态下切语言 → 是否持续排帧',
      (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: _kSize);
    await tester.tap(_keypadSemantics('Memory'));
    await _advance(tester);
    await h.locale.setLocale('zh-CN');
    await _advance(tester);
    _expectQuiescent(
      tester,
      'case1:memorySheet+localeSwitch',
      '抽屉（_MemorySheetBody）已随 UX-01 订阅 LocaleController；'
          'MaterialApp.builder 窄腰位于 Navigator 之上，切语言重建含抽屉的整条路由栈',
    );
    h.dispose();
  });

  testWidgets('判定②：历史抽屉（DraggableScrollableSheet）打开状态下切语言 → 是否持续排帧',
      (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: _kSize);
    h.calculator.setText('1+1');
    await h.calculator.commit();
    await _advance(tester);
    await tester.tap(find.byIcon(Icons.history).first);
    await _advance(tester);
    await h.locale.setLocale('zh-CN');
    await _advance(tester);
    _expectQuiescent(
      tester,
      'case2:historySheet+localeSwitch',
      'DraggableScrollableSheet 的 extent 动效是否被重建反复激活',
    );
    h.dispose();
  });

  testWidgets('对照B：无抽屉、仅切语言（HomeScreen + TabBar）→ 帧管线应归零',
      (WidgetTester tester) async {
    final AppHarness h = await pumpApp(tester, size: _kSize);
    await h.locale.setLocale('zh-CN');
    await _advance(tester);
    _expectQuiescent(
      tester,
      'controlB:locale-no-sheet',
      '若此对照为真，则帧源在更上游（TabBar / AppBar / DisplayPanel），与抽屉无关',
    );
    h.dispose();
  });
}
