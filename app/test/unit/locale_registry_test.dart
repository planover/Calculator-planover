/// 语言清单单元测试。
///
/// 纯 Dart：只依赖 `flutter_test` 与 [LocaleRegistry]，不引入 `dart:ffi` /
/// `rootBundle` —— [LocaleRegistry] 本身没有任何 Flutter 依赖，因此可以在
/// 不拉起 Flutter 绑定（也不碰原生引擎）的前提下独立校验清单正确性。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/l10n/locale_registry.dart';

void main() {
  group('LocaleRegistry.supported', () {
    test('所有 tag 唯一（合并 Win11+Android+iOS 后无重复）', () {
      final List<String> tags =
          LocaleRegistry.supported.map((AppLocale l) => l.tag).toList();
      final int unique = tags.toSet().length;
      expect(unique, tags.length,
          reason: '存在重复 tag：${_duplicates(tags)}');
    });

    test('RTL 语言被正确标记', () {
      // 既有 RTL 语言
      for (final String t in <String>[
        'ar',
        'he',
        'fa',
        'ur',
        'ps',
        'sd',
        'ug',
        'ku',
        'ckb',
        'prs',
      ]) {
        expect(LocaleRegistry.isRtl(t), isTrue, reason: '$t 应为 RTL');
      }
      // 新增的 RTL 区域/变体
      expect(LocaleRegistry.isRtl('ar-EG'), isTrue);
      expect(LocaleRegistry.isRtl('fa-IR'), isTrue);
      expect(LocaleRegistry.isRtl('ur-PK'), isTrue);
      expect(LocaleRegistry.isRtl('pa-PK'), isTrue);
      // LTR 语言不应误判
      expect(LocaleRegistry.isRtl('en'), isFalse);
      expect(LocaleRegistry.isRtl('zh-CN'), isFalse);
      expect(LocaleRegistry.isRtl('de-DE'), isFalse);
    });
  });

  group('LocaleRegistry.canonicalize', () {
    test('null / 空 / 未知语言回落 en', () {
      expect(LocaleRegistry.canonicalize(null), 'en');
      expect(LocaleRegistry.canonicalize(''), 'en');
      expect(LocaleRegistry.canonicalize('xx-XX'), 'en');
    });

    test('精确标签原样返回', () {
      expect(LocaleRegistry.canonicalize('zh-Hans'), 'zh-Hans');
      expect(LocaleRegistry.canonicalize('de-AT'), 'de-AT');
    });

    test('未收录的区域变体回落到基础语言', () {
      // de-LI 不在清单中，但属于德语，应回落到基础档 de
      expect(LocaleRegistry.canonicalize('de-LI'), 'de');
      // fr-RE 不在清单中，回落到 fr
      expect(LocaleRegistry.canonicalize('fr-RE'), 'fr');
    });
  });

  group('LocaleRegistry.find', () {
    test('按 tag 精确查找，含母语名', () {
      final AppLocale? zh = LocaleRegistry.find('zh-CN');
      expect(zh, isNotNull);
      expect(zh!.native, '简体中文');
      expect(zh.english, 'Chinese (Simplified)');
    });

    test('下划线写法与连字符等价', () {
      final AppLocale? zh = LocaleRegistry.find('zh_CN');
      expect(zh, isNotNull);
      expect(zh!.tag, 'zh-CN');
    });

    test('新增的脚本/区域条目可被查到', () {
      expect(LocaleRegistry.find('zh-Hant'), isNotNull);
      expect(LocaleRegistry.find('es-419'), isNotNull);
      expect(LocaleRegistry.find('en-US'), isNotNull);
    });
  });
}

/// 找出列表里的重复项，便于测试失败时定位。
List<String> _duplicates(List<String> tags) {
  final Set<String> seen = <String>{};
  final List<String> dup = <String>[];
  for (final String t in tags) {
    if (!seen.add(t)) {
      dup.add(t);
    }
  }
  return dup;
}
