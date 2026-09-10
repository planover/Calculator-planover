/// 内存版历史仓库 —— `flutter test` 与预览环境注入用。
///
/// 行为刻意与 [SqfliteHistoryRepository] 保持一致（倒序返回、上限裁剪），
/// 这样测试里验证过的行为在真机上同样成立。
library;

import '../models/history_entry.dart';
import 'history_repository.dart';

/// 进程内历史。
class MemoryHistoryRepository implements HistoryRepository {
  /// 可预置初始数据。
  MemoryHistoryRepository({List<HistoryEntry>? seed})
      : _rows = List<HistoryEntry>.of(seed ?? const <HistoryEntry>[]) {
    _sort();
  }

  final List<HistoryEntry> _rows;
  int _nextId = 1;

  /// 当前全部记录（调试/测试用，按时间倒序）。
  List<HistoryEntry> get rows => List<HistoryEntry>.unmodifiable(_rows);

  @override
  Future<HistoryEntry> add(HistoryEntry entry) async {
    final HistoryEntry stored = entry.copyWith(id: entry.id ?? _nextId++);
    _rows.insert(0, stored);
    _trim();
    return stored;
  }

  @override
  Future<List<HistoryEntry>> all({int limit = historyCapacity}) async {
    _sort();
    if (_rows.length <= limit) {
      return List<HistoryEntry>.unmodifiable(_rows);
    }
    return List<HistoryEntry>.unmodifiable(_rows.take(limit));
  }

  @override
  Future<void> delete(int id) async {
    _rows.removeWhere((HistoryEntry e) => e.id == id);
  }

  @override
  Future<void> clear() async {
    _rows.clear();
  }

  @override
  Future<void> close() async {}

  void _sort() {
    _rows.sort((HistoryEntry a, HistoryEntry b) => b.ts.compareTo(a.ts));
  }

  void _trim() {
    if (_rows.length <= historyCapacity) {
      return;
    }
    _rows.removeRange(historyCapacity, _rows.length);
  }
}
