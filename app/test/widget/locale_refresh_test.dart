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
/// 关于**有界泵帧**（`_settle`）而非无界的 `pumpAndSettle()`（见第二例）：
/// `pumpAndSettle()` 会一直泵帧直到**帧管线归零**（`binding.hasScheduledFrame`
/// 为假）；第二例（"在打开的抽屉上切语言"）CI 实测会挂到 10 分钟上限
/// （`TimeoutException after 0:10:00.000000`）。故本文件统一改用**确定性的有界
/// 泵帧**：固定推进 N 帧、**保证终止**，且足以越过路由 / 页签 / 抽屉过渡
/// （约 300ms）与输入防抖（120ms）。
///
/// ⚠️ **根因尚未定论（勿误读）**：原假设"语言切换重建打开中的抽屉路由 → 帧管线
/// 无限排队"已被诊断用例 `locale_frame_pipeline_diagnostic_test.dart` **证伪**
/// ——4 组对照全部 `hasScheduledFrame=false` / `transientCallbackCount=0`，即
/// **应用层没有无限排帧**。故"改用有界泵帧"只保证**测试终止**，**不等于**应用不卡；
/// 真正的挂死点仍由 `[LOCALE-REFRESH-2] step=N` 与 `[harness] ...` 进度标记定位
/// （第二例开头 `harnessTrace = true` 打开脚手架内部标记）。**严禁**用更短的
/// test timeout 掩盖挂死——标记只用于**定位**，不改变任何断言强度。
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
/// 为什么必须有界：见文件头注释（第二例 CI 实测挂到 10 分钟上限）。这里固定推进
/// [frames] 帧、每帧 [step]（默认 8×120ms = 960ms），足以覆盖：
/// - `MaterialPageRoute` / 页签切换过渡（约 300ms）；
/// - `showModalBottomSheet` 入场（约 250ms）；
/// - `Debouncer` 输入防抖（120ms）。
/// 注：它只保证**测试终止**，**不**代表应用不卡——真正的挂死点用进度标记定位。
Future<void> _settle(
  WidgetTester tester, {
  int frames = 8,
  Duration step = const Duration(milliseconds: 120),
}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// 语言包**原始 Map 缓存**（复用 `AppLocalizations.load` 的「同 tag 只读一次」缓存语义）。
///
/// 为什么：`_enrichedLoader` 原先是**裸** `rootBundle.loadString`（绕过
/// `AppLocalizations._loadBundle` 的 static `_cache` 与 try/catch 兜底）——这是对
/// 「第二例 10 分钟挂死」的**重点怀疑点**之一（任务 B ③）。这里与
/// `AppLocalizations._cache` 对齐：**同 tag 只读一次**，其余命中内存，既排除重复裸读，
/// 又保持可观测语义等价。
final Map<String, Map<String, dynamic>> _rawBundleCache =
    <String, Map<String, dynamic>>{};

/// 用真实语言包 + 注入 `constants.π`（使常量面板文案随语言变化，可被断言）。
Future<Map<String, dynamic>> _loadEnriched(String tag) async {
  final Map<String, dynamic>? hit = _rawBundleCache[tag];
  if (hit != null) {
    return hit;
  }
  final String raw = await rootBundle.loadString('assets/i18n/$tag.json');
  final Map<String, dynamic> m =
      Map<String, dynamic>.from(jsonDecode(raw) as Map);
  final Map<String, dynamic> constants = Map<String, dynamic>.from(
    (m['constants'] as Map?) ?? const <String, dynamic>{},
  );
  constants['π'] = tag.startsWith('zh') ? '圆周率(译)' : 'Pi (translated)';
  m['constants'] = constants;
  _rawBundleCache[tag] = m;
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
    // ── 超时定位（任务 B ①）──────────────────────────────────────────────
    // 打开脚手架内部进度标记（`[harness] ...`）+ 本用例自身的 step 标记，把「10 分钟
    // 挂死点」窄化到某个具体 `await`：**CI 日志里最后一条 `step=N` 即为停住的位置**。
    // 本用例的每一步 await 都打了标记；配合 `harnessTrace` 可区分"挂在 pumpApp 内"
    // 还是"挂在本用例体内"。
    // 严禁用更短 test timeout 掩盖：标记只为**定位**，不改变任何断言强度。
    harnessTrace = true;
    debugPrint('[LOCALE-REFRESH-2] step=0 start');

    final FakeEngine engine = FakeEngine(
      constants: const <ConstantInfo>[
        ConstantInfo(symbol: 'π', name: 'Pi', value: '3.141592653589793'),
      ],
    );
    debugPrint('[LOCALE-REFRESH-2] step=1 engine built');
    final AppHarness h = await pumpApp(
      tester,
      size: const Size(411, 2400),
      engine: engine,
      loader: _enrichedLoader,
    );
    debugPrint('[LOCALE-REFRESH-2] step=2 pumpApp returned');

    // 说明：本用例涉及"在打开的抽屉上切语言"，全程使用有界泵帧 `_settle()`
    // （根因尚未定论，见文件头）；每一步 await 都打了 step 标记用于定位。

    // ── 常量面板（constants_panel 缺陷）──
    await tester.tap(find.text('Constants'));
    debugPrint('[LOCALE-REFRESH-2] step=3 tapped Constants');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=4 settled after Constants');
    expect(find.text('Pi (translated)'), findsWidgets);
    await h.locale.setLocale('zh-CN');
    debugPrint('[LOCALE-REFRESH-2] step=5 setLocale zh-CN');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=6 settled after zh-CN');
    expect(find.text('圆周率(译)'), findsWidgets,
        reason: '常量面板未随语言刷新（listen:false 缺陷）');
    expect(find.text('Pi (translated)'), findsNothing);
    await h.locale.setLocale('en');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=7 back to en');

    // ── 记忆面板（memory_sheet 缺陷）──
    await tester.tap(_keypadSemantics('Memory'));
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=8 memory sheet opened');
    expect(find.text('Memory'), findsWidgets); // 面板标题（en）
    await h.locale.setLocale('zh-CN');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=9 memory sheet zh-CN');
    expect(find.text('记忆寄存器'), findsWidgets,
        reason: '记忆面板未随语言刷新（listen:false 缺陷）');
    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=10 memory sheet closed');
    await h.locale.setLocale('en');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=11 back to en');

    // ── 历史抽屉（history_sheet 的 _HistoryTile 缺陷）──
    // `setText` 返回 void（不可 await）；`commit` 返回 Future<void>（应 await）。
    h.calculator.setText('1+1');
    debugPrint('[LOCALE-REFRESH-2] step=12 setText done');
    await h.calculator.commit();
    debugPrint('[LOCALE-REFRESH-2] step=13 commit done');
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.history).first);
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=14 history sheet opened');
    expect(find.byTooltip('Delete'), findsWidgets);
    await h.locale.setLocale('zh-CN');
    debugPrint('[LOCALE-REFRESH-2] step=15 setLocale zh-CN');
    await _settle(tester);
    debugPrint('[LOCALE-REFRESH-2] step=16 settled after zh-CN');
    expect(find.byTooltip('删除'), findsWidgets,
        reason: '历史条目未随语言刷新（listen:false 缺陷）');

    debugPrint('[LOCALE-REFRESH-2] step=17 body done');
    harnessTrace = false;
    h.dispose();
    debugPrint('[LOCALE-REFRESH-2] step=18 disposed');
  });
}
