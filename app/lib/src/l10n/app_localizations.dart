/// 运行时本地化 —— **自研 JSON 语言包**，不用 `gen-l10n` 代码生成。
///
/// 为什么不用官方 gen-l10n：
/// 1. 它是**构建期代码生成**，而本机没有 Flutter/Dart SDK，生成的 Dart 代码
///    我无法在本地编译验证 —— 与当初"手写 FFI 而不用 flutter_rust_bridge"是同一个理由；
/// 2. 运行时 JSON 包意味着**新增一门语言不用重新发版代码**，且与"引擎零改动、
///    翻译全在 Dart 侧"的整体决策一致（引擎 238 个测试断言的是中文文案，不能动）。
///
/// 三层兜底（永不白屏）：
/// `精确语言包` → `en 语言包` → `调用方传入的原文`（引擎文案 / 单位 id / 常量符号）。
///
/// 区域习惯：小数点与千分位来自 intl 的 CLDR `numberFormatSymbols`，
/// 由 [number] 对引擎返回的**规范串**（小数点是 `.`、千分位是 `,`）做安全重映射，
/// 这样既保留引擎里已经过 238 个测试验证的精度/记数法逻辑，又符合当地书写习惯。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/number_symbols.dart' show NumberSymbols;
import 'package:intl/number_symbols_data.dart' show numberFormatSymbols;

import 'locale_registry.dart';

/// 一份已加载的语言环境。
class AppLocalizations {
  /// [bundle] 为当前语言包，[fallback] 为兜底（en）语言包；两者都可注入（便于测试）。
  AppLocalizations(
    this.tag, {
    Map<String, dynamic>? bundle,
    Map<String, dynamic>? fallback,
  })  : _bundle = bundle ?? const <String, dynamic>{},
        _fallback = fallback ?? const <String, dynamic>{} {
    _resolveSeparators();
  }

  /// 语言标签（已规整成清单里的形式）。
  final String tag;

  final Map<String, dynamic> _bundle;
  final Map<String, dynamic> _fallback;

  /// 小数点符号（CLDR）。
  String decimalSeparator = '.';

  /// 千分位符号（CLDR）。
  String groupSeparator = ',';

  /// 语言包资源目录。
  static const String assetPath = 'assets/i18n';

  static final Map<String, Map<String, dynamic>> _cache =
      <String, Map<String, dynamic>>{};

  /// 从 assets 加载指定语言（失败逐级兜底）。依赖 Flutter 绑定（[rootBundle]）；
  /// 在测试中调用需先 `TestWidgetsFlutterBinding.ensureInitialized()`。
  static Future<AppLocalizations> load(String? tag) async {
    final String resolved = LocaleRegistry.canonicalize(tag);
    final Map<String, dynamic> bundle = await _loadBundle(resolved);
    final Map<String, dynamic> fallback = resolved == LocaleRegistry.fallbackTag
        ? const <String, dynamic>{}
        : await _loadBundle(LocaleRegistry.fallbackTag);
    return AppLocalizations(resolved, bundle: bundle, fallback: fallback);
  }

  static const Map<String, dynamic> _empty = <String, dynamic>{};

  static Future<Map<String, dynamic>> _loadBundle(String tag) async {
    final Map<String, dynamic>? hit = _cache[tag];
    if (hit != null) {
      return hit;
    }
    try {
      final String text = await rootBundle.loadString('$assetPath/$tag.json');
      final Object? decoded = jsonDecode(text);
      if (decoded is Map) {
        final Map<String, dynamic> m =
            Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(decoded));
        _cache[tag] = m;
        return m;
      }
    } catch (e, st) {
      // 语言包缺失是**预期内**的（110 档语言不可能一次性全部翻译完），
      // 这里保留三级降级行为，但把真实失败原因打到日志，便于真机定位。
      debugPrint('[i18n] 语言包加载失败: $tag -> $e\n$st');
    }
    return _empty;
  }

  /// 清空缓存（测试或热切换语言时用）。
  static void clearCache() => _cache.clear();

  void _resolveSeparators() {
    for (final String key in LocaleRegistry.cldrCandidates(tag)) {
      final NumberSymbols? s = numberFormatSymbols[key];
      if (s != null) {
        decimalSeparator = s.DECIMAL_SEP;
        groupSeparator = s.GROUP_SEP;
        return;
      }
    }
    // 查不到就沿用规范写法
    decimalSeparator = '.';
    groupSeparator = ',';
  }

  /// 是否从右向左书写。
  bool get isRtl => LocaleRegistry.isRtl(tag);

  /// 转成 Flutter 的 [Locale]。
  Locale get locale {
    final List<String> parts = tag.split('-');
    return parts.length >= 2
        ? Locale(parts[0], parts[1])
        : Locale(parts[0]);
  }

  /// 查一条文案；[path] 支持点号分层（如 `ui.common.cancel`）。
  ///
  /// 未命中时依次退回：兜底语言包 → [fallback] → 键名本身。
  String tr(String path, {String? fallback}) {
    final Object? v = _lookup(_bundle, path);
    if (v is String && v.isNotEmpty) {
      return v;
    }
    final Object? f = _lookup(_fallback, path);
    if (f is String && f.isNotEmpty) {
      return f;
    }
    return fallback ?? path;
  }

  static Object? _lookup(Map<String, dynamic> map, String path) {
    Object? cur = map;
    for (final String seg in path.split('.')) {
      if (cur is Map) {
        cur = cur[seg];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// 错误文案：按引擎返回的稳定 `kind`（snake_case）翻译。
  ///
  /// [engineMessage] 是引擎给的中文原文，翻译缺失时原样展示（总比空白好）。
  String errorText(String kind, String engineMessage) =>
      tr('errors.$kind', fallback: engineMessage);

  /// 单位显示名：按单位 id 翻译，缺失时用引擎给的中文名。
  String unitName(String id, String engineName) =>
      tr('units.$id', fallback: engineName);

  /// 常量显示名：按常量符号翻译，缺失时用引擎给的中文名。
  String constantName(String symbol, String engineName) =>
      tr('constants.$symbol', fallback: engineName);

  /// 把引擎返回的**规范数字串**改写成当前区域习惯。
  ///
  /// 规范串约定：小数点是 `.`、千分位是 `,`（Rust 侧固定）。
  /// 科学记数法只改写尾数部分，指数保持不动。
  String number(String canonical) {
    if (decimalSeparator == '.' && groupSeparator == ',') {
      return canonical;
    }
    final int eIndex = canonical.indexOf('e');
    final int upperIndex = canonical.indexOf('E');
    final int cut = eIndex >= 0 ? eIndex : upperIndex;
    if (cut < 0) {
      return _remap(canonical);
    }
    return _remap(canonical.substring(0, cut)) + canonical.substring(cut);
  }

  String _remap(String s) => s
      .replaceAll(',', '\u0001')
      .replaceAll('.', decimalSeparator)
      .replaceAll('\u0001', groupSeparator);
}
