/// 区域格式状态控制器 —— L2 状态层，与 [LocaleController] 平级。
///
/// 区域格式只决定数字/货币/时间/日期的显示规则，与界面文案（语言）彻底解耦
/// （PRD §5 I3 / LC-01）。本控制器持有"当前区域格式"及其来源（自动/手动），
/// 通过 [RegionFormatStore] 持久化，并广播给依赖它的 Widget。
///
/// 职责边界（架构 A1/A2/A3）：
/// - **不碰 `dart:ffi`**：只和 [RegionFormatStore] 与可注入的引擎回调打交道；
/// - **数字/货币**格式化下发给 Rust（[pushToEngine] → `set_region_format`）；
/// - **时间/日期**由本控制器暴露 [config]（`RegionFormatConfig`），供
///   `utils/region_date_format.dart` 纯函数使用（A2：时间/日期不进 Rust）；
/// - 绝不使用 `Intl.defaultLocale`（A3）。
///
/// **回退可观测**：未注入 [RegionFormatStore] 时（测试/预览）默认"跟随系统"，不抛异常。
library;

import 'package:flutter/foundation.dart';
import 'package:intl/number_symbols.dart' show NumberSymbols;
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

import '../l10n/locale_registry.dart';
import '../l10n/region_format_presets.dart';
import '../l10n/region_registry.dart';
import '../models/region_format_config.dart';
import '../models/region_format_request.dart';
import '../storage/region_format_store.dart';

/// 区域格式状态。
class RegionFormatController extends ChangeNotifier {
  /// [store] 可空：为空时手动区域不会落盘（测试用）。
  ///
  /// [onRegionFormatChanged] 为可注入的引擎下发回调（真机接 `EngineGateway`；
  /// 测试可注入一个记录器）——控制器**本身不 import `dart:ffi`**（架构 R3）。
  RegionFormatController({
    RegionFormatStore? store,
    void Function(RegionFormatRequest request)? onRegionFormatChanged,
  })  : _store = store,
        _onChanged = onRegionFormatChanged;

  final RegionFormatStore? _store;
  final void Function(RegionFormatRequest request)? _onChanged;

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

  /// 是否已载入。
  bool get isLoaded => _loaded;

  /// 当前生效的区域标签（手动优先；"跟随系统"时回落 `zh-CN` 之外的 en-US 风格）。
  ///
  /// 注意：这里是**区域格式**标签，与界面语言无关（A3）。
  String get effectiveTag => _manualTag ?? RegionRegistry.supported.first.tag;

  /// 当前区域的时间/日期配置（RF-T/RF-D，A2）。
  ///
  /// "跟随系统区域"时用 [effectiveTag] 解析；未命中预设时回落 en-US 风格。
  RegionFormatConfig get config => RegionFormatPresets.resolve(_manualTag);

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

  /// 该区域的**语言**子段（月份/星期名所用，RF-D-02），如 `de-DE` → `de`。
  String get regionLanguage => config.regionLanguage;

  /// 解析某区域标签对应的数字/货币请求负载（供引擎下发，架构 A1）。
  RegionFormatRequest get request => RegionFormatWire.forRegion(effectiveTag);

  /// 从存储恢复手动区域并首次下发引擎。
  Future<void> load() async {
    _manualTag = await _store?.loadRegionTag();
    _loaded = true;
    _pushToEngine();
    notifyListeners();
  }

  /// 设定/清除手动区域：传 `null` 即恢复"跟随系统区域"。
  Future<void> setRegion(String? tag) async {
    _manualTag = tag;
    await _store?.saveRegionTag(tag);
    _pushToEngine();
    notifyListeners();
  }

  /// 把当前区域格式（数字/货币部分）下发引擎（架构 A1 / `set_region_format`）。
  ///
  /// 引擎回调为 null（测试/预览）时静默跳过，不抛异常。
  void _pushToEngine() {
    _onChanged?.call(request);
  }

  /// 手动触发一次引擎下发（例如引擎初始化晚于控制器构造时）。
  void pushToEngine() => _pushToEngine();
}
