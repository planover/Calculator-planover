/// UX-03 RTL 接入断言（`[D]`，架构 §3.3）：
/// 1. **消费方存在**：`lib/**` 下对 `isRtl` 的消费点 ≥ 1（`app.dart` 的 `Directionality` 注入）；
/// 2. **方向断言**：`ar-SA` → 根 `Directionality` 为 `rtl`；`en` → `ltr`；
/// 3. **布局镜像断言**：RTL 下 `AppBar` actions 左右互换（settings 在 history 右侧）；
/// 4. **键盘不反转断言**：`Keypad` 子树方向为 `ltr`，数字行视觉顺序仍为 `7,8,9`；
/// 5. **无异常**。
///
/// 铁律：仅 `FakeEngine`，不 import `dart:ffi`。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/ui/home_screen.dart';
import 'package:calculator_planover/src/ui/widgets/keypad.dart';

// harness 位于 `test/support/`，本文件在 `test/widget/` → 需向上一层。
import '../support/harness.dart';

/// 键盘子树内的语义标签 Finder（避免与结果显示区/其他屏文案撞名）。
Finder _keypadSemantics(String label) => find.descendant(
      of: find.byType(Keypad),
      matching: find.bySemanticsLabel(label),
    );

void main() {
  test('lib/ 下存在对 isRtl 的消费点（UX-03）', () {
    final Directory libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: '测试须在 app/ 包根目录运行（当前 cwd=${Directory.current.path}）',
    );
    int hits = 0;
    for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      for (final String line in entity.readAsLinesSync()) {
        if (line.contains('isRtl')) {
          hits++;
        }
      }
    }
    expect(hits, greaterThanOrEqualTo(1),
        reason: '未发现 isRtl 消费点 —— RTL 未接入渲染层');
  });

  testWidgets('ar-SA → rtl / en → ltr；键盘 ltr 且数字不反转；无异常',
      (WidgetTester tester) async {
    // ── RTL（ar-SA）──
    final AppHarness ar =
        await pumpApp(tester, localeTag: 'ar-SA', size: const Size(411, 891));
    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
      reason: 'ar-SA 下根方向不是 rtl',
    );

    // 键盘子树：钉死 ltr。
    expect(
      Directionality.of(tester.element(_keypadSemantics('7'))),
      TextDirection.ltr,
      reason: 'RTL 下键盘子树应为 ltr（数字网格不镜像）',
    );

    // 数字行视觉顺序仍为 7,8,9。
    final double x7 = tester.getCenter(_keypadSemantics('7')).dx;
    final double x8 = tester.getCenter(_keypadSemantics('8')).dx;
    final double x9 = tester.getCenter(_keypadSemantics('9')).dx;
    expect(x7 < x8 && x8 < x9, isTrue,
        reason: 'RTL 下数字网格被反转：x7=$x7 x8=$x8 x9=$x9');

    // 布局镜像：RTL 下 AppBar actions 左右互换（settings 在 history 右侧）。
    final double xSettings =
        tester.getCenter(find.byIcon(Icons.settings).first).dx;
    final double xHistory =
        tester.getCenter(find.byIcon(Icons.history).first).dx;
    expect(xSettings, greaterThan(xHistory),
        reason: 'RTL 下 AppBar actions 未镜像：settings=$xSettings history=$xHistory');

    expect(tester.takeException(), isNull);
    ar.dispose();

    // ── LTR（en）──
    final AppHarness en =
        await pumpApp(tester, localeTag: 'en', size: const Size(411, 891));
    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.ltr,
      reason: 'en 下根方向不是 ltr',
    );
    final double s2 = tester.getCenter(find.byIcon(Icons.settings).first).dx;
    final double h2 = tester.getCenter(find.byIcon(Icons.history).first).dx;
    expect(s2, lessThan(h2),
        reason: 'LTR 下 AppBar actions 顺序异常：settings=$s2 history=$h2');
    expect(tester.takeException(), isNull);
    en.dispose();
  });
}
