/// 历史控制器（架构 §T05 要点 2 / §5）。
///
/// 封装 [HistoryRepository]，把"记录列表"作为状态广播给 UI。
/// 真机注入 [SqfliteHistoryRepository]，测试注入 [MemoryHistoryRepository]。
library;

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../storage/history_repository.dart';

/// 历史状态。
class HistoryController extends ChangeNotifier {
  /// 注入仓库；[load] 之后列表才可用。
  HistoryController(this._repo);

  final HistoryRepository _repo;

  List<HistoryEntry> _entries = const <HistoryEntry>[];
  bool _loaded = false;

  /// 当前记录（倒序，最新在前）。
  List<HistoryEntry> get entries => _entries;

  /// 是否已从仓库载入。
  bool get isLoaded => _loaded;

  /// 从仓库载入全部记录。
  Future<void> load() async {
    _entries = await _repo.all();
    _loaded = true;
    notifyListeners();
  }

  /// 追加一条并刷新列表（保持最新在前）。
  Future<void> add(HistoryEntry entry) async {
    final HistoryEntry stored = await _repo.add(entry);
    _entries = <HistoryEntry>[stored, ..._entries];
    notifyListeners();
  }

  /// 删除单条。
  Future<void> delete(int id) async {
    await _repo.delete(id);
    _entries = _entries.where((HistoryEntry e) => e.id != id).toList();
    notifyListeners();
  }

  /// 清空全部。
  Future<void> clear() async {
    await _repo.clear();
    _entries = const <HistoryEntry>[];
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.close();
    super.dispose();
  }
}
