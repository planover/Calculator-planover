/// 区域格式状态控制器 —— L2 状态层，与 [LocaleController] 平级。
///
/// 区域格式只决定数字/货币/时间/日期的显示规则，与界面文案（语言）彻底解耦
/// （PRD §5 I3 / LC-01）。本控制器持有"当前区域格式"及其来源（自动/手动），
/// 通过 [RegionFormatStore] 持久化，并广播给依赖它的 Widget。
///
/// 职责边界：
/// - **不碰 `dart:ffi`**；只和 [RegionFormatStore] 打交道；
/// - **回退可观测**：未注入 [RegionFormatStore] 时（测试/预览）默认"跟随系统"，不抛异常。
library;

import 'package:flutter/foundation.dart';
import 'package:intl/number_symbols.dart' show NumberSymbols;
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

import '../l10n/locale_registry.dart';
import '../l10n/region_registry.dart';
import '../storage/region_format_store.dart';

/// 区域格式状态。
class RegionFormatController extends ChangeNotifier {
  /// [store] 可空：为空时手动区域不会落盘（测试用）。
  RegionFormatController({RegionFormatStore? store}) : _store = store;

  final RegionFormatStore? _store;

  /// 手动指定的区域标签；`null` 表示"跟随系统区域"。
  String? _manualTag;

  /// 是否已从存储载入过（避免 UI 在载入前用默认值闪一下）。
  bool _loaded = false;

  /// 当前区域标签（手动优先，否则 null = 跟随系统）。
  String? get regionTag => _manualTag;

  /// 是否处于"跟随系统"模式。
  bool get isAuto => _manualTag == null;

  /// 当前区域（手动命中清单时返回；否则 null = 跟随系统）。
  RegionFormat? get region => RegionRegistry.find(_manualTag);

  /// 区域格式的小数点符号（CLDR，LC-09）。
  ///
  /// 手动指定区域时按该区域的 CLDR 数字符号返回；`跟随系统区域` 时返回 `null`，
  /// 由调用方回落到语言（[AppLocalizations.decimalSeparator]）。查不到则回落 `null`。
  String? get decimalSeparator {
    final RegionFormat? r = region;
    if (r == null) {
      return null;
    }
    for (final String key in LocaleRegistry.cldrCandidates(r.tag)) {
      final NumberSymbols? s = numberFormatSymbols[key];
      if (s != null) {
        return s.DECIMAL_SEP;
      }
    }
    return null;
  }

  /// 是否已载入。
  bool get isLoaded => _loaded;

  /// 从存储恢复手动区域。
  Future<void> load() async {
    _manualTag = await _store?.loadRegionTag();
    _loaded = true;
    notifyListeners();
  }

  /// 设定/清除手动区域：传 `null` 即恢复"跟随系统区域"。
  Future<void> setRegion(String? tag) async {
    _manualTag = tag;
    await _store?.saveRegionTag(tag);
    notifyListeners();
  }
}
