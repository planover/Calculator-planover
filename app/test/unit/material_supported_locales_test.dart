/// UX-02 守护：`MaterialSupportedLocales.tags` == `LocaleRegistry.supported` 中
/// **真正有 `GlobalMaterialLocalizations` 数据**的交集，且交集大小 `< 216`。
///
/// 双重作用：
/// 1. **校准**：静态表初值由本测试在 CI 首次运行打印的"期望列表"填入
///    （本机无 Flutter SDK，无法在本地算真交集 —— 见 `material_supported_locales.dart`）；
/// 2. **防漂移**：一旦 `LocaleRegistry` 或 Flutter 的 Material 支持集变化，断言立刻红，
///    永不静默让"无 Material 数据的语言"混进 `supportedLocales`（那正是卡死根因之一）。
///
/// 断言 B（`length < 216`）直接裁决"卡死根因 (a)"：若交集 == 216，说明所有 locale 都有
/// Material 数据，(a) 不是根因；否则 (a) 成立。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/l10n/locale_registry.dart';
import 'package:calculator_planover/src/l10n/material_supported_locales.dart';
import 'package:calculator_planover/src/theme/app_theme.dart';

void main() {
  test('supportedLocales == CLDR∩GlobalMaterialLocalizations 且 != 216（UX-02）', () {
    // 真交集（按 `LocaleRegistry.supported` 顺序过滤）。
    final List<AppLocale> expectedAppLocales = LocaleRegistry.supported
        .where(
          (AppLocale a) =>
              GlobalMaterialLocalizations.delegate.isSupported(toFlutterLocale(a.tag)),
        )
        .toList(growable: false);

    final List<String> expectedTags = expectedAppLocales
        .map((AppLocale a) => a.tag)
        .toList(growable: false);

    // 打印期望列表（供 CI 日志直接反推 `MaterialSupportedLocales.tags` 的校准值）。
    // ignore: avoid_print
    print('MATERIAL_INTERSECTION(${expectedTags.length}) = $expectedTags');

    final List<Locale> actual = MaterialSupportedLocales.tags
        .map(toFlutterLocale)
        .toList(growable: false);
    final List<Locale> expected =
        expectedTags.map(toFlutterLocale).toList(growable: false);

    // 断言 A：静态表已与真交集同步（不一致时把期望列表打印在 reason 里）。
    expect(
      actual,
      expected,
      reason: '静态表漂移。期望列表（可直接替换 MaterialSupportedLocales.tags）= $expectedTags',
    );

    // 断言 B：收敛后**必须**小于 216（证明确实做了收敛）。
    expect(expected.length, lessThan(216));
  });
}
