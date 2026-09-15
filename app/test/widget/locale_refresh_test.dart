/// UX-01 逐屏刷新断言（`[D]`）：语言切换后，**订阅了** `LocaleController` 的
/// 展示文案必须全部刷新；`en ↔ zh-CN` 往返 3 次后回到初始态。
///
/// 覆盖 16 处缺陷涉及的全部展示位：
/// - 主界面标题（`home_screen`）；
/// - 设置页**每一行标题**（`settings_screen` 的 12 处）；
/// - 键盘**语义标签**（`keypad`，`ui.keypad.memory`）；
/// - 常量面板（`constants_panel`，需引擎常量名映射）；
/// - 记忆面板（`memory_sheet`）；
/// - 历史抽屉（`history_sheet` 的删除 tooltip）。
///
/// 铁律：仅 `FakeEngine`，不 import `dart:ffi`。
///
/// ─────────────────────────────────────────────────────────────────────────
/// 关于**有界泵帧**（`_settle`）而非 `pumpAndSettle()`（T01 修复，见第二例）：
/// `pumpAndSettle()` 会一直泵帧直到**帧管线归零**（`binding.hasScheduledFrame`
/// 为假）。但"**在已打开的 `showModalBottomSheet` 路由上做语言切换**"这一组合
/// 会让帧管线**始终有下一帧**：UX-01 把三个抽屉从 `listen: false` 改成
/// `listen: true` 之后，语言切换（`LocaleController.notifyListeners()`）会**重建
/// 打开中的抽屉路由**（`memory_sheet` / `history_sheet`），而 `MaterialApp.builder`
/// 这道"全应用唯一窄腰"（`app.dart` 注入 `MediaQuery` + `Directionality`）位于
/// `Navigator` 之上，语言切换会连同**整个路由栈（含打开中的底部抽屉）**一起重建；
/// 底部抽屉路由的入场动效 / `DraggableScrollableSheet` 机制随之被**重新激活**，
/// 于是帧被持续排队，`pumpAndSettle()` 直到其 10 分钟（假时钟）上限都不返回
/// ——CI 实测为 `TimeoutException after 0:10:00.000000`（见提交说明）。
/// 对照：第一例（只切语言、**不**开抽屉）与既有 `history_marker_test`
/// （开抽屉、**不**切语言）都能正常 settle —— 只有"两者同时发生"才挂死。
/// 故第二例统一改用**确定性的有界泵帧**：固定推进 N 帧，**保证终止**，
/// 同时足以越过路由 / 页签 / 抽屉过渡（约 300ms）与输入防抖（120ms）。
/// ─────────────────────────────────────────────────────────────────────────
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/engine/fake_engine.dart';
import 'package:calculator_planover/src/l10n/app_localizations.dart';
import 'package:calculator_planover/src/l10n/locale_registry.dart';
import 'package:calculator_planover/src/models/constant_info.dart';
import 'package:calculator_planover/src/ui/widgets/keypad.dart';

// harness 位于 `test/support/`，本文件在 `test/widget/` → 需向上一层。
import '../support/harness.dart';

/// 设置页在 `en` 下的全部展示文案（分组标题 + 各行标题 + 关于卡片标题）。
const List<String> _enSettings = <String>[
  'Settings', 'Appearance', 'Calculation', 'Display format', 'About',
  'Theme', 'Region format', 'Language', 'Angle', 'Word size',
  'Notation', 'Precision mode', 'Precision', 'Fractions', 'Digit grouping',
  'Submit mode', 'Version', 'Engine',
  'Memory (M) vs Answer (Ans)', 'Complex numbers',
];

/// 设置页在 `zh-CN` 下的同一批文案。
const List<String> _zhSettings = <String>[
  '设置', '外观', '计算', '显示格式', '关于',
  '主题', '区域格式', '语言', '角度', '位宽',
  '记数法', '精度模式', '精度', '分数', '数字分组',
  '提交方式', '版本', '计算引擎',
  '记忆寄存器（M）与 Ans 的区别', '复数',
];

/// **有界泵帧**（确定性、保证终止）—— 取代无界的 `pumpAndSettle()`。
///
/// 为什么必须有界：见文件头注释（语言切换 + 打开中的底部抽屉 → 帧管线不归零
/// → `pumpAndSettle()` 挂到 10 分钟上限）。这里固定推进 [frames] 帧、
/// 每帧 [step]（默认 8×120ms = 960ms），足以覆盖：
/// - `MaterialPageRoute` / 页签切换过渡（约 300ms）；
/// - `showModalBottomSheet` 入场（约 250ms）；
/// - `Debouncer` 输入防抖（120ms）。
Future<void> _settle(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 120),
}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// 用真实语言包 + 注入 `constants.π`（使常量面板文案随语言变化，可被断言）。
Future<Map<String, dynamic>> _loadEnriched(String tag) async {
  final String raw = await rootBundle.loadString('assets/i18n/$tag.json');
  final Map<String, dynamic> m =
      Map<String, dynamic>.from(jsonDecode(raw) as Map);
  final Map<String, dynamic> constants = Map<String, dynamic>.from(
    (m['constants'] as Map?) ?? const <String, dynamic>{},
  );
  constants['π'] = tag.startsWith('zh') ? '圆周率(译)' : 'Pi (translated)';
  m['constants'] = constants;
  return m;
}

/// 注入型 loader：真实 UI 文案 + 语言相关的常量名。
Future<AppLocalizations> _enrichedLoader(String? tag) async {
  final String resolved = LocaleRegistry.canonicalize(tag);
  final Map<String, dynamic> bundle = await _loadEnriched(resolved);
  final Map<String, dynamic> fallback = resolved == LocaleRegistry.fallbackTag
      ? const <String, dynamic>{}
      : await _loadEnriched(LocaleRegistry.fallbackTag);
  return AppLocalizations(resolved, bundle: bundle, fallback: fallback);
}

/// 键盘子树内的语义标签（避免与结果显示区文案撞名）。
Finder _keypadSemantics(String label) => find.descendant(
      of: find.byType(Keypad),
      matching: find.bySemanticsLabel(label),
    );

void main() {
  testWidgets('en↔zh-CN：主界面/设置页逐行/键盘语义全部刷新，往返 3 次回到初始态',
      (WidgetTester tester) async {
    final AppHarness h =
        await pumpApp(tester, size: const Size(411, 2400));

    // ── en 初始态 ──
    expect(find.text('Calculator'), findsWidgets);
    expect(_keypadSemantics('Memory'), findsOneWidget);

    // 打开设置页，逐行断言 en 文案。
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pumpAndSettle();
    for (final String label in _enSettings) {
      expect(find.text(label), findsWidgets, reason: 'en 设置页缺行标题: $label');
    }

    // ── 切到 zh-CN：设置页每一行必须刷新 ──
    await h.locale.setLocale('zh-CN');
    await tester.pumpAndSettle();
    for (final String label in _zhSettings) {
      expect(find.text(label), findsWidgets, reason: 'zh 设置页缺行标题: $label');
    }
    expect(find.text('Settings'), findsNothing,
        reason: '语言切换后设置页标题未刷新（listen:false 缺陷）');

    // 回主界面：标题与键盘语义刷新。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('计算器'), findsWidgets);
    expect(_keypadSemantics('记忆'), findsOneWidget);
    expect(_keypadSemantics('Memory'), findsNothing);

    // ── en → zh-CN → en 往返 3 次 ──
    for (int i = 0; i < 3; i++) {
      await h.locale.setLocale('en');
      await tester.pumpAndSettle();
      expect(find.text('Calculator'), findsWidgets, reason: '第 $i 次回到 en 失败');
      await h.locale.setLocale('zh-CN');
      await tester.pumpAndSettle();
      expect(find.text('计算器'), findsWidgets, reason: '第 $i 次切到 zh 失败');
    }

    // 回到初始态（en）。
    await h.locale.setLocale('en');
    await tester.pumpAndSettle();
    expect(find.text('Calculator'), findsWidgets);
    expect(_keypadSemantics('Memory'), findsOneWidget);

    h.dispose();
  });

  testWidgets('常量面板 / 记忆面板 / 历史抽屉 随语言刷新', (WidgetTester tester) async {
    final FakeEngine engine = FakeEngine(
      constants: const <ConstantInfo>[
        ConstantInfo(symbol: 'π', name: 'Pi', value: '3.141592653589793'),
      ],
    );
    final AppHarness h = await pumpApp(
      tester,
      size: const Size(411, 2400),
      engine: engine,
      loader: _enrichedLoader,
    );

    // 说明：本用例涉及"在打开的抽屉上切语言"——`pumpAndSettle()` 会挂死
    // （根因见文件头）。故全程改用有界泵帧 `_settle()`。

    // ── 常量面板（constants_panel 缺陷）──
    await tester.tap(find.text('Constants'));
    await _settle(tester);
    expect(find.text('Pi (translated)'), findsWidgets);
    await h.locale.setLocale('zh-CN');
    await _settle(tester);
    expect(find.text('圆周率(译)'), findsWidgets,
        reason: '常量面板未随语言刷新（listen:false 缺陷）');
    expect(find.text('Pi (translated)'), findsNothing);
    await h.locale.setLocale('en');
    await _settle(tester);

    // ── 记忆面板（memory_sheet 缺陷）──
    await tester.tap(_keypadSemantics('Memory'));
    await _settle(tester);
    expect(find.text('Memory'), findsWidgets); // 面板标题（en）
    await h.locale.setLocale('zh-CN');
    await _settle(tester);
    expect(find.text('记忆寄存器'), findsWidgets,
        reason: '记忆面板未随语言刷新（listen:false 缺陷）');
    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester);
    await h.locale.setLocale('en');
    await _settle(tester);

    // ── 历史抽屉（history_sheet 的 _HistoryTile 缺陷）──
    // `setText` 返回 void（不可 await）；`commit` 返回 Future<void>（应 await）。
    h.calculator.setText('1+1');
    await h.calculator.commit();
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.history).first);
    await _settle(tester);
    expect(find.byTooltip('Delete'), findsWidgets);
    await h.locale.setLocale('zh-CN');
    await _settle(tester);
    expect(find.byTooltip('删除'), findsWidgets,
        reason: '历史条目未随语言刷新（listen:false 缺陷）');

    h.dispose();
  });
}
