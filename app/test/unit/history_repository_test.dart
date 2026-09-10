/// 历史仓库测试 —— 走 [MemoryHistoryRepository]，**不加载 sqflite 插件**（架构风险 R3）。
///
/// 重点验证 Q7：**历史上限 500，超出即裁剪**。裁剪逻辑在真机上由 SQL 子查询完成，
/// 这里验证的是"行为契约"，内存实现刻意复刻同款行为，故测试通过即代表契约成立。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/models/history_entry.dart';
import 'package:calculator_planover/src/storage/history_repository.dart';
import 'package:calculator_planover/src/storage/memory_history_repository.dart';

void main() {
  late MemoryHistoryRepository repo;

  setUp(() {
    repo = MemoryHistoryRepository();
  });

  HistoryEntry entry(int i) => HistoryEntry(
        expr: 'expr$i',
        result: '$i',
        ts: 1000 + i,
      );

  test('add 回填自增 id', () async {
    final HistoryEntry stored = await repo.add(entry(1));
    expect(stored.id, isNotNull);
    expect(stored.expr, 'expr1');
  });

  test('all 按时间倒序返回', () async {
    await repo.add(entry(1));
    await repo.add(entry(2));
    await repo.add(entry(3));

    final List<HistoryEntry> all = await repo.all();
    expect(all.map((HistoryEntry e) => e.expr).toList(),
        <String>['expr3', 'expr2', 'expr1']);
  });

  test('all 受 limit 限制', () async {
    for (int i = 1; i <= 5; i++) {
      await repo.add(entry(i));
    }
    expect((await repo.all(limit: 2)), hasLength(2));
  });

  test('delete 只删指定一条', () async {
    final HistoryEntry a = await repo.add(entry(1));
    await repo.add(entry(2));

    await repo.delete(a.id!);
    final List<HistoryEntry> all = await repo.all();
    expect(all, hasLength(1));
    expect(all.single.expr, 'expr2');
  });

  test('clear 清空全部', () async {
    await repo.add(entry(1));
    await repo.add(entry(2));
    await repo.clear();
    expect(await repo.all(), isEmpty);
  });

  test('Q7：超过 500 条自动裁剪，只保留最近 500', () async {
    for (int i = 1; i <= historyCapacity + 10; i++) {
      await repo.add(entry(i));
    }
    final List<HistoryEntry> all = await repo.all();
    expect(all, hasLength(historyCapacity));
    // 保留的是最新的：expr510 排在最前
    expect(all.first.expr, 'expr${historyCapacity + 10}');
  });
}
