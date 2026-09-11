/// 区域格式测试（PRD §5 I3 / LC-09）。
///
/// 验证 [RegionFormatController] 的小数点符号随区域变化（驱动键盘小数点键面），
/// 且"跟随系统区域"时返回 null（由语言 CLDR 回落）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/state/region_format_controller.dart';

void main() {
  group('RegionFormatController 小数点符号（LC-09）', () {
    test('跟随系统区域 → null（回落语言）', () {
      final RegionFormatController region = RegionFormatController();
      expect(region.isAuto, isTrue);
      expect(region.region, isNull);
      expect(region.decimalSeparator, isNull);
    });

    test('de-DE → 逗号，en-US → 点', () async {
      final RegionFormatController region = RegionFormatController();
      await region.setRegion('de-DE');
      expect(region.decimalSeparator, ',');

      await region.setRegion('en-US');
      expect(region.decimalSeparator, '.');

      // 恢复跟随系统。
      await region.setRegion(null);
      expect(region.decimalSeparator, isNull);
    });
  });
}
