/// 区域时间/日期格式化纯函数测试（PRD §6.3 RF-T / §6.4 RF-D，A2/Q4）。
///
/// 全部为**纯函数**断言 —— 不依赖设备、不依赖 `Intl.defaultLocale`（A3），
/// 因此可在 CI 的 `flutter test` 中确定性通过。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/l10n/region_format_presets.dart';
import 'package:calculator_planover/src/models/region_format_config.dart';
import 'package:calculator_planover/src/utils/region_date_format.dart';

void main() {
  // 2025-09-09 14:32 —— 与 PRD §5.3 组合矩阵的示例时刻对齐。
  final DateTime dt = DateTime(2025, 9, 9, 14, 32);

  group('formatTime（RF-T-02 / RF-T-05）', () {
    test('H:mm 24 制不补零 → 14:32', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hmm24,
      );
      expect(RegionDateFormatter.formatTime(dt, c), '14:32');
    });

    test('HH:mm 24 制补零 → 09:05', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hhmm24,
      );
      expect(
        RegionDateFormatter.formatTime(DateTime(2025, 1, 1, 9, 5), c),
        '09:05',
      );
    });

    test('h:mm tt 12 制 → 2:32 PM', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hmm12,
      );
      expect(RegionDateFormatter.formatTime(dt, c), '2:32 PM');
    });

    test('hh:mm tt 12 制补零 → 09:05 AM', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hhmm12,
      );
      expect(
        RegionDateFormatter.formatTime(DateTime(2025, 1, 1, 9, 5), c),
        '09:05 AM',
      );
    });

    test('午夜 0 点 → 12:00 AM（12 制）', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hmm12,
      );
      expect(
        RegionDateFormatter.formatTime(DateTime(2025, 1, 1, 0, 0), c),
        '12:00 AM',
      );
    });

    test('正午 12 点 → 12:00 PM（12 制）', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hmm12,
      );
      expect(
        RegionDateFormatter.formatTime(DateTime(2025, 1, 1, 12, 0), c),
        '12:00 PM',
      );
    });

    test('自定义时间分隔符（RF-T-01）', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hhmm24,
        timeSeparator: '.',
      );
      expect(RegionDateFormatter.formatTime(dt, c), '14.32');
    });

    test('自定义 AM/PM 符号（RF-T-04）', () {
      const RegionFormatConfig c = RegionFormatConfig(
        tag: 'x',
        timePattern: TimePattern.hmm12,
        amSymbol: '上午',
        pmSymbol: '下午',
      );
      expect(RegionDateFormatter.formatTime(dt, c), '2:32 下午');
    });
  });

  group('formatDate（RF-D-01）', () {
    test('M/d/yyyy → 9/9/2025', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'x', datePattern: DatePattern.mdy);
      expect(RegionDateFormatter.formatDate(dt, c), '9/9/2025');
    });

    test('yyyy-MM-dd → 2025-09-09', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'x', datePattern: DatePattern.ymd);
      expect(RegionDateFormatter.formatDate(dt, c), '2025-09-09');
    });

    test('dd/MM/yyyy → 09/09/2025', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'x', datePattern: DatePattern.dmy);
      expect(RegionDateFormatter.formatDate(dt, c), '09/09/2025');
    });

    test('M/d/yy → 9/9/25', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'x', datePattern: DatePattern.mdyy);
      expect(RegionDateFormatter.formatDate(dt, c), '9/9/25');
    });
  });

  group('formatPattern 月份/星期名（RF-D-02，随区域语言）', () {
    test('英文长日期 dddd, MMMM d, yyyy', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'en-US', regionLanguage: 'en');
      expect(
        RegionDateFormatter.formatPattern(dt, 'dddd, MMMM d, yyyy', c),
        'Tuesday, September 9, 2025',
      );
    });

    test('德文长日期（月份/星期名随区域语言，非界面语言）', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'de-DE', regionLanguage: 'de');
      expect(
        RegionDateFormatter.formatPattern(dt, 'dddd, d. MMMM yyyy', c),
        'Dienstag, 9. September 2025',
      );
    });

    test('中文长日期', () {
      const RegionFormatConfig c =
          RegionFormatConfig(tag: 'zh-CN', regionLanguage: 'zh');
      expect(
        RegionDateFormatter.formatPattern(dt, 'yyyy年M月d日 dddd', c),
        '2025年9月9日 星期二',
      );
    });
  });

  group('区域预设解析（RegionFormatPresets）', () {
    test('de-DE 短日期为日.月.年、24 制、周一为首日', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve('de-DE');
      expect(c.timePattern, TimePattern.hhmm24);
      expect(c.datePattern, DatePattern.dmy);
      expect(c.weekStart, WeekStart.monday);
      expect(RegionDateFormatter.formatTime(dt, c), '14:32');
    });

    test('en-US 短时间为 12 制 → 2:32 PM', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve('en-US');
      expect(RegionDateFormatter.formatTime(dt, c), '2:32 PM');
      expect(RegionDateFormatter.formatDate(dt, c), '9/9/2025');
    });

    test('zh-CN 短日期 → 9/9/2025、24 制', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve('zh-CN');
      expect(RegionDateFormatter.formatDate(dt, c), '9/9/2025');
      expect(RegionDateFormatter.formatTime(dt, c), '14:32');
    });

    test('未知区域回落 en-US 风格（不抛异常）', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve('xx-YY');
      expect(RegionDateFormatter.formatTime(dt, c), '2:32 PM');
    });

    test('null 区域返回默认预设', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve(null);
      expect(c.tag, 'en-US');
    });

    test('语言级回落 de-LI → 德式规则', () {
      final RegionFormatConfig c = RegionFormatPresets.resolve('de-LI');
      expect(c.datePattern, DatePattern.dmy);
    });

    test('firstDayOfWeek 映射（RF-D-03）', () {
      expect(
        RegionDateFormatter.firstDayOfWeek(RegionFormatPresets.resolve('en-US')),
        0,
      );
      expect(
        RegionDateFormatter.firstDayOfWeek(RegionFormatPresets.resolve('de-DE')),
        1,
      );
    });
  });
}
