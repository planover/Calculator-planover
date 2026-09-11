/// 区域格式持久化 —— 与 [SettingsStore] 平级，独立负责"区域格式"偏好。
///
/// 为什么单独做一个 store（而不是塞进 [SettingsStore]）：区域格式是与语言
/// 完全解耦的独立设置项（PRD §5 I3 / LC-01），单独的文件让 T05（UI）与
/// T04（数据/存储层）各自演进、互不污染，也避免两人改同一文件产生冲突。
///
/// 不依赖 `material`（与 [SettingsStore] 一致的约定：存储层不引入 UI 依赖）。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 区域格式存储。
abstract class RegionFormatStore {
  /// 读取手动指定的区域标签；`null` 表示"跟随系统区域"。
  Future<String?> loadRegionTag();

  /// 写入区域标签；传 `null` 表示恢复"跟随系统区域"。
  Future<void> saveRegionTag(String? tag);
}

/// 基于 SharedPreferences 的实现（真机用）。
class SharedPreferencesRegionFormatStore implements RegionFormatStore {
  /// 构造（测试里用 `SharedPreferences.setMockInitialValues` 注入即可）。
  const SharedPreferencesRegionFormatStore();

  static const String _kRegionTag = 'settings.region_tag';

  @override
  Future<String?> loadRegionTag() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRegionTag);
  }

  @override
  Future<void> saveRegionTag(String? tag) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (tag == null) {
      await prefs.remove(_kRegionTag);
      return;
    }
    await prefs.setString(_kRegionTag, tag);
  }
}

/// 纯内存实现：测试注入用，行为与 SharedPreferences 版一致但不落盘。
class MemoryRegionFormatStore implements RegionFormatStore {
  /// 初始为空表示"从未存过"，读时回落"跟随系统"。
  MemoryRegionFormatStore({this.regionTag});

  /// 当前区域标签（内存版直接暴露字段，便于测试断言）。
  String? regionTag;

  @override
  Future<String?> loadRegionTag() async => regionTag;

  @override
  Future<void> saveRegionTag(String? tag) async => regionTag = tag;
}
