/// 历史条目模型测试 —— 验证 `usedMemory` 字段的往返（PRD §13.1 CP-16）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/models/history_entry.dart';

void main() {
  group('HistoryEntry.usedMemory 往返', () {
    test('默认 false；toMap / fromMap 保留', () {
      const HistoryEntry e = HistoryEntry(expr: '1+2', result: '3', ts: 100);
      expect(e.usedMemory, isFalse);
      expect(e.toMap()['used_memory'], 0);

      final HistoryEntry fromMap =
          HistoryEntry.fromMap(<String, dynamic>{...e.toMap()});
      expect(fromMap.usedMemory, isFalse);
    });

    test('usedMemory=true 经 toMap / fromMap 保留', () {
      const HistoryEntry e = HistoryEntry(
        expr: 'MR',
        result: '5',
        ts: 200,
        usedMemory: true,
      );
      expect(e.toMap()['used_memory'], 1);

      final HistoryEntry fromMap =
          HistoryEntry.fromMap(<String, dynamic>{...e.toMap()});
      expect(fromMap.usedMemory, isTrue);
    });

    test('fromJson 解析 used_memory 整数', () {
      final HistoryEntry e = HistoryEntry.fromJson(<String, dynamic>{
        'expr': 'MR',
        'result': '5',
        'ts': 200,
        'used_memory': 1,
      });
      expect(e.usedMemory, isTrue);

      final HistoryEntry none = HistoryEntry.fromJson(<String, dynamic>{
        'expr': '1',
        'result': '1',
        'ts': 1,
      });
      expect(none.usedMemory, isFalse);
    });
  });
}
