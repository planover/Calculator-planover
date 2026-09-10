/// 真机历史仓库 —— SQLite 落地。
///
/// Q7 的"历史上限 500"裁剪逻辑**只在本文件一处**实现：
/// 每次插入后立刻删掉超出最近 500 条的行，避免历史无限增长拖慢冷启动。
/// 内存版（供测试注入）在 `memory_history_repository.dart` 里复刻同款行为。
library;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_entry.dart';
import 'history_repository.dart';

/// 基于 sqflite 的历史实现。
class SqfliteHistoryRepository implements HistoryRepository {
  /// [database] 允许外部注入已打开的数据库（便于迁移到同一 DB 或测试）。
  SqfliteHistoryRepository({String? fileName, Database? database})
      : _fileName = fileName ?? defaultFileName,
        _db = database;

  /// 数据库文件名。
  static const String defaultFileName = 'calculator.db';

  /// 表名。
  static const String tableName = 'history';

  final String _fileName;
  Database? _db;

  Future<Database> _open() async {
    final Database? existing = _db;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final String dir = await getDatabasesPath();
    final String path = join(dir, _fileName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE $tableName (
  id INTEGER PRIMARY KEY,
  expr TEXT NOT NULL,
  result TEXT NOT NULL,
  ts INTEGER NOT NULL,
  kind INTEGER NOT NULL
)
''');
      },
    );
    return _db!;
  }

  @override
  Future<HistoryEntry> add(HistoryEntry entry) async {
    final Database db = await _open();
    final int id = await db.insert(tableName, entry.toMap());
    await _trim(db);
    return entry.copyWith(id: id);
  }

  @override
  Future<List<HistoryEntry>> all({int limit = historyCapacity}) async {
    final Database db = await _open();
    final List<Map<String, dynamic>> rows = await db.query(
      tableName,
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map(HistoryEntry.fromMap).toList(growable: false);
  }

  @override
  Future<void> delete(int id) async {
    final Database db = await _open();
    await db.delete(tableName, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<void> clear() async {
    final Database db = await _open();
    await db.delete(tableName);
  }

  @override
  Future<void> close() async {
    final Database? db = _db;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _db = null;
  }

  /// 保留最近 [historyCapacity] 条，其余删除。
  Future<void> _trim(Database db) async {
    await db.delete(
      tableName,
      where: 'id NOT IN (SELECT id FROM $tableName ORDER BY ts DESC LIMIT $historyCapacity)',
    );
  }
}
