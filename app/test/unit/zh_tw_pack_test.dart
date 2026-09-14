/// 语言包 key 一致性测试（PRD §7 LG-07 / LG-08），聚焦本轮新增的 zh-TW。
///
/// 断言 `zh-TW.json` 与基准包（`zh-CN.json` / `en.json`）**key 集合完全一致**，
/// 且占位符（`{n}` 类）集合一致 —— 防止传统中文包漏键或漏占位符。
///
/// 经 `rootBundle` 读真实资源，故先 `TestWidgetsFlutterBinding.ensureInitialized()`。
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// 递归收集 JSON 里的所有叶子 key 路径（如 `ui.settings.title`）。
Set<String> _leafPaths(Object? node, [String prefix = '']) {
  final Set<String> out = <String>{};
  if (node is Map) {
    node.forEach((Object? k, Object? v) {
      final String path = prefix.isEmpty ? '$k' : '$prefix.$k';
      if (v is Map) {
        out.addAll(_leafPaths(v, path));
      } else {
        out.add(path);
      }
    });
  }
  return out;
}

/// 递归收集全部字符串叶子值里的占位符 token（形如 `{name}`）。
Set<String> _placeholders(Object? node) {
  final Set<String> out = <String>{};
  if (node is Map) {
    for (final Object? v in node.values) {
      out.addAll(_placeholders(v));
    }
  } else if (node is List) {
    for (final Object? v in node) {
      out.addAll(_placeholders(v));
    }
  } else if (node is String) {
    out.addAll(RegExp(r'\{[^}]+\}').allMatches(node).map((RegExpMatch m) => m.group(0)!));
  }
  return out;
}

Future<Map<String, dynamic>> _load(String tag) async {
  final String text = await rootBundle.loadString('assets/i18n/$tag.json');
  return Map<String, dynamic>.from(jsonDecode(text) as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('zh-TW 语言包完整性（LG-07 / LG-08）', () {
    test('zh-TW key 集合 == zh-CN key 集合', () async {
      final Map<String, dynamic> zhTw = await _load('zh-TW');
      final Map<String, dynamic> zhCn = await _load('zh-CN');
      expect(_leafPaths(zhTw), equals(_leafPaths(zhCn)));
    });

    test('zh-TW key 集合 == en key 集合', () async {
      final Map<String, dynamic> zhTw = await _load('zh-TW');
      final Map<String, dynamic> en = await _load('en');
      expect(_leafPaths(zhTw), equals(_leafPaths(en)));
    });

    test('zh-TW 占位符集合 == en 占位符集合', () async {
      final Map<String, dynamic> zhTw = await _load('zh-TW');
      final Map<String, dynamic> en = await _load('en');
      expect(_placeholders(zhTw), equals(_placeholders(en)));
    });

    test('zh-TW 关键文案为繁体中文', () async {
      final Map<String, dynamic> zhTw = await _load('zh-TW');
      expect(_leafPaths(zhTw).contains('ui.settings.title'), isTrue);
      final Map<String, dynamic> ui = zhTw['ui'] as Map<String, dynamic>;
      final Map<String, dynamic> settings =
          ui['settings'] as Map<String, dynamic>;
      expect(settings['title'], '設定');
      expect(settings['region'], '區域格式');
    });
  });
}
