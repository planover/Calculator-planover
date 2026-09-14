/// 区域格式下发负载与控制器引擎联动测试（架构 §3.1 set_region_format 契约）。
///
/// 验证 Dart 侧把区域选择转成 Rust `set_region_format` 请求 JSON 的正确性
/// （de-DE 逗号、hi-IN 印度式分组 3;2;0、货币嵌套对象），以及
/// [RegionFormatController] 在 `setRegion` 时把请求透传给注入的引擎回调。
///
/// 全部不依赖设备 / FFI：引擎回调是一个内存记录器。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/models/region_format_request.dart';
import 'package:calculator_planover/src/state/region_format_controller.dart';
import 'package:calculator_planover/src/storage/region_format_store.dart';

void main() {
  group('RegionFormatWire.forRegion（set_region_format 契约 §3.1）', () {
    test('de-DE → 逗号小数、点分组、minus_plain', () {
      final Map<String, dynamic> json = RegionFormatWire.forRegion('de-DE').toJson();
      expect(json['decimal_separator'], ',');
      expect(json['group_separator'], '.');
      expect(json['group_pattern'], '3;0');
      expect(json['leading_zero'], true);
      expect(json['negative_format'], 'minus_plain');
    });

    test('hi-IN → 印度式分组 3;2;0（PRD §5.3 C8）', () {
      final Map<String, dynamic> json = RegionFormatWire.forRegion('hi-IN').toJson();
      expect(json['group_pattern'], '3;2;0');
      expect(json['decimal_separator'], '.');
    });

    test('zh-CN → 货币嵌套对象（符号 ¥ / 括号负数）', () {
      final Map<String, dynamic> json = RegionFormatWire.forRegion('zh-CN').toJson();
      final Object? currency = json['currency'];
      expect(currency, isA<Map<String, dynamic>>());
      final Map<String, dynamic> c = currency as Map<String, dynamic>;
      expect(c['symbol'], '¥');
      expect(c['positive_format'], 'before');
      expect(c['decimal_digits'], 2);
      final Map<String, dynamic> neg =
          c['negative_format'] as Map<String, dynamic>;
      expect(neg['sign'], 'paren');
      expect(neg['symbol'], 'before');
    });

    test('未知区域回落 en-US 风格', () {
      final Map<String, dynamic> json = RegionFormatWire.forRegion('xx-YY').toJson();
      expect(json['decimal_separator'], '.');
      expect(json['group_separator'], ',');
    });

    test('null 区域回落 en-US', () {
      final Map<String, dynamic> json = RegionFormatWire.forRegion(null).toJson();
      expect(json['group_pattern'], '3;0');
    });

    test('空字段（None）不出现在 JSON 中', () {
      const RegionFormatRequest r = RegionFormatRequest(decimalSeparator: ',');
      final Map<String, dynamic> json = r.toJson();
      expect(json.containsKey('group_separator'), isFalse);
      expect(json.containsKey('currency'), isFalse);
      expect(json['decimal_separator'], ',');
    });
  });

  group('RegionFormatController（LC-01 / A1 引擎下发）', () {
    test('setRegion 把请求透传给引擎回调', () async {
      RegionFormatRequest? captured;
      final RegionFormatController region = RegionFormatController(
        store: MemoryRegionFormatStore(),
        onRegionFormatChanged: (RegionFormatRequest r) => captured = r,
      );

      await region.setRegion('de-DE');
      expect(captured, isNotNull);
      expect(captured!.decimalSeparator, ',');

      await region.setRegion('hi-IN');
      expect(captured!.groupPattern, GroupPattern.indian);
    });

    test('load 首次下发引擎', () async {
      final MemoryRegionFormatStore store =
          MemoryRegionFormatStore(regionTag: 'fr-FR');
      RegionFormatRequest? captured;
      final RegionFormatController region = RegionFormatController(
        store: store,
        onRegionFormatChanged: (RegionFormatRequest r) => captured = r,
      );

      await region.load();
      expect(region.regionTag, 'fr-FR');
      expect(captured, isNotNull);
      expect(captured!.groupSeparator, ' ');
    });

    test('regionLanguage 与 config 随区域变化（RF-D-02）', () async {
      final RegionFormatController region = RegionFormatController();
      await region.setRegion('de-DE');
      expect(region.regionLanguage, 'de');
      await region.setRegion('zh-CN');
      expect(region.regionLanguage, 'zh');
    });
  });
}
