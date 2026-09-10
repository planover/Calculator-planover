/// 语言状态控制器 —— L2 状态层，持有并广播"当前语言"及其来源（自动/手动）。
///
/// 为什么单独做一档控制器（而不是塞进 [SettingsController]）：
/// - 语言切换需要**同时**回写持久化（[SettingsStore]）与重建本地化对象
///   （[AppLocalizations]），它与"求值/格式化设置"是完全不同的生命周期，
///   拆开能让两边各自演进、互不污染；
/// - **可注入 loader**：[load] 默认走 `AppLocalizations.load`（会读 `rootBundle`
///   里的 JSON 语言包），但单测里可以注入一个内存 loader，**彻底不碰
///   `rootBundle`、也不碰 `dart:ffi` / `native_engine`**（架构 R3 同款思路：
///   测试不加载任何原生依赖），从而让本控制器可在纯 Dart 环境下被测。
///
/// 职责边界：
/// - **不碰 `dart:ffi`**：只和 [SettingsStore] 与（可注入的）[AppLocalizations.loader] 打交道；
/// - **回退可观测**：未注入 [SettingsStore] 时（测试/预览）直接用 `en` 占位，不抛异常。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale, WidgetsBinding;

import '../l10n/app_localizations.dart';
import '../storage/settings_store.dart';

/// 语言状态。
///
/// 镜像 [SettingsController] 的 `ChangeNotifier` 风格：持有当前 [AppLocalizations]，
/// 并在语言变化后 [notifyListeners]，让依赖 `l10n` 的 Widget 自动重建。
class LocaleController extends ChangeNotifier {
  /// [store] 可空：为空时手动语言不会落盘（测试用）；
  /// [loader] 可注入：默认 `AppLocalizations.load`，测试里换成内存实现即可脱离 assets。
  LocaleController({
    SettingsStore? store,
    Future<AppLocalizations> Function(String?) loader = AppLocalizations.load,
  })  : _store = store,
        _loader = loader;

  final SettingsStore? _store;
  final Future<AppLocalizations> Function(String?) _loader;

  /// 当前本地化对象（占位 `en`，[load] 后被真实语言替换）。
  AppLocalizations _l10n = AppLocalizations('en');

  /// 手动指定的语言标签；`null` 表示"跟随系统"。
  String? _manualTag;

  /// 系统语言（从 [WidgetsBinding] 读取；纯单测里 binding 可能为 null）。
  Locale? _systemLocale;

  /// 是否已从存储/系统载入过（避免 UI 在载入前用占位值闪一下）。
  bool _loaded = false;

  /// 当前本地化对象。
  AppLocalizations get l10n => _l10n;

  /// 手动语言标签；`null` ⇒ 跟随系统。
  String? get manualTag => _manualTag;

  /// 是否处于"跟随系统"模式。
  bool get isAuto => _manualTag == null;

  /// 是否已载入（首次 [load]/[setLocale] 之后为 true）。
  bool get isLoaded => _loaded;

  /// 系统语言（可能为 null，例如无 Flutter 绑定的纯单测环境）。
  Locale? get systemLocale => _systemLocale;

  /// 从存储恢复手动语言，并探测系统语言，最后加载对应本地化。
  Future<void> load() async {
    _manualTag = await _store?.loadLocaleTag();
    // 纯单测里 WidgetsBinding.instance 可能为 null，这里用 ?. 安全降级。
    final WidgetsBinding? b = WidgetsBinding.instance;
    _systemLocale = b?.platformDispatcher.locale;
    await _apply();
  }

  /// 设定/清除手动语言：传 `null` 即恢复"跟随系统"。
  Future<void> setLocale(String? tag) async {
    _manualTag = tag;
    await _store?.saveLocaleTag(tag);
    await _apply();
  }

  /// 把系统 [Locale] 规整成清单可用的 BCP-47 标签（无地区时只取语言码）。
  String _systemTag() {
    final Locale? s = _systemLocale;
    if (s == null) {
      return '';
    }
    return s.countryCode == null ? s.languageCode : '${s.languageCode}-${s.countryCode}';
  }

  /// 计算"有效语言"（手动优先、否则系统），加载本地化并广播。
  Future<void> _apply() async {
    final String effective = _manualTag ?? _systemTag();
    _l10n = await _loader(effective);
    _loaded = true;
    notifyListeners();
  }
}
