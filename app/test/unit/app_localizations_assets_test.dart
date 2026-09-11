/// `AppLocalizations` 资源加载回归测试。
///
/// 目的有二：
/// 1. **资源可用性**：证明 `flutter test` 下能经 `rootBundle` 读到 pubspec 中
///    声明的真实语言包 `assets/i18n/*.json`（这正是真机上"设置页整屏裸 key"
///    所依赖的那条链路）；
/// 2. **兜底语义**：锁死"精确语言包缺失 → 回落 `en`"的行为。修复前
///    `load()` 在精确包缺失时会把 fallback 置空（与注释宣称的三层兜底相反），
///    导致未翻译语言整屏显示裸 key。
///
/// `rootBundle` 依赖 Flutter 绑定，故先 `TestWidgetsFlutterBinding.ensureInitialized()`。
/// 另附一组**纯逻辑**用例（构造函数注入内存包），不依赖资源，作为兜底语义的补充锁定。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/l10n/app_localizations.dart';

void main() {
  // 若不加这一句，`rootBundle` 未绑定会抛异常。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('资源加载链路（经 rootBundle，锁死真机资源可用性）', () {
    test('zh-CN 包能加载并翻译静态键', () async {
      final AppLocalizations l = await AppLocalizations.load('zh-CN');
      expect(l.tag, 'zh-CN');
      expect(l.tr('ui.settings.title'), '设置');
      expect(l.tr('ui.keypad.equal'), '=');
    });

    test('en 兜底：未翻译语言回落英文，绝不回退成裸 key', () async {
      final AppLocalizations l = await AppLocalizations.load('fr');
      expect(l.tag, 'fr');
      // 回归点：修复前 fr.json 缺失会把 fallback 置空 → 此处会得到裸 key 'ui.settings.title'。
      expect(l.tr('ui.settings.title'), 'Settings');
      // 两层都没有的键，才退回 key 本身。
      expect(l.tr('ui.__missing_key__'), 'ui.__missing_key__');
    });
  });

  group('tr() 三层兜底语义（纯逻辑，注入内存包，不依赖资源）', () {
    const Map<String, dynamic> zh = <String, dynamic>{
      'ui': <String, dynamic>{
        'settings': <String, dynamic>{'title': '设置'},
      },
    };
    const Map<String, dynamic> en = <String, dynamic>{
      'ui': <String, dynamic>{
        'settings': <String, dynamic>{'title': 'Settings'},
      },
    };

    test('精确包命中优先于兜底', () {
      final AppLocalizations l =
          AppLocalizations('zh-CN', bundle: zh, fallback: en);
      expect(l.tr('ui.settings.title'), '设置');
    });

    test('精确包缺失时命中 en 兜底', () {
      final AppLocalizations l = AppLocalizations('fr', fallback: en);
      expect(l.tr('ui.settings.title'), 'Settings');
    });

    test('两层都缺失：退回 key 本身 / 调用方原文', () {
      final AppLocalizations l = AppLocalizations('fr');
      expect(l.tr('ui.settings.title'), 'ui.settings.title');
      expect(l.tr('ui.settings.title', fallback: '原文'), '原文');
    });
  });
}
