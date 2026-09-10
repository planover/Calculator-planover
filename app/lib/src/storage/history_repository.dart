/// 历史仓库抽象 —— 定义"历史记录"这一 Dart 侧能力（Rust 不碰文件 IO，架构 §1.2 不变量 4）。
///
/// 为什么抽象：
/// - 真机走 SQLite（[SqfliteHistoryRepository]）；
/// - 测试注入 [MemoryHistoryRepository]，`flutter test` 不必加载 sqflite 插件通道
///   （与 FakeEngine 同一套思路，见架构风险 R3）。
///
/// 接口一律 `Future`：SQLite 天然异步，同步接口会逼着调用方在真机上卡顿。
library;

import '../models/history_entry.dart';

/// 历史上限（Q7）。裁剪逻辑**只在 SQLite 实现里一处**，内存实现保持同款行为以便测试。
const int historyCapacity = 500;

/// 历史仓库。
abstract class HistoryRepository {
  /// 追加一条记录；返回已回填自增 id 的条目。
  Future<HistoryEntry> add(HistoryEntry entry);

  /// 取最近的记录（按时间倒序），最多 [limit] 条。
  Future<List<HistoryEntry>> all({int limit = historyCapacity});

  /// 删除单条。
  Future<void> delete(int id);

  /// 清空全部。
  Future<void> clear();

  /// 关闭底层资源；内存实现是 no-op。
  Future<void> close();
}
