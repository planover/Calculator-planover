/// 区域格式预设表 —— 按 BCP-47 标签给出**时间/日期**默认规则（PRD §6.3 / §6.4）。
///
/// 与 [RegionRegistry.supported]（"有哪些区域"的清单）**分开放置**：
/// 清单文件由既有的 UI 增量提交锁定（[RegionRegistry.supported] 的 21 档不可改），
/// 而本文件只负责"给定区域标签 → 时间/日期预设"，两者解耦、各自演进。
///
/// 数字/货币预设**不在此处**：它们由 Rust `set_region_format` 决定（架构 A1），
/// Dart 侧只镜像选择并透传标签。
///
/// 未列出的区域一律回落到 [RegionFormatPresets.fallback]（en-US 风格），
/// 保证"任意标签都有可用配置"，绝不抛异常。
library;

import '../models/region_format_config.dart';

/// 区域格式预设表与查询。
abstract final class RegionFormatPresets {
  /// 未知区域回落到的默认预设。
  static const RegionFormatConfig fallback = RegionFormatConfig(
    tag: 'en-US',
    timePattern: TimePattern.hmm12,
    datePattern: DatePattern.mdy,
    weekStart: WeekStart.sunday,
    regionLanguage: 'en',
  );

  /// 显式预设表：键为 BCP-47 标签，值为该区域的时间/日期规则。
  ///
  /// 覆盖 [RegionRegistry.supported] 全部 21 档 + 若干常见变体；其余回落 [fallback]。
  static const Map<String, RegionFormatConfig> presets =
      <String, RegionFormatConfig>{
    // ── 中文 ──
    'zh-CN': RegionFormatConfig(
      tag: 'zh-CN',
      timePattern: TimePattern.hmm24,
      datePattern: DatePattern.mdy,
      weekStart: WeekStart.monday,
      amSymbol: '上午',
      pmSymbol: '下午',
      regionLanguage: 'zh',
    ),
    'zh-TW': RegionFormatConfig(
      tag: 'zh-TW',
      timePattern: TimePattern.hmm24,
      datePattern: DatePattern.mdy,
      weekStart: WeekStart.sunday,
      amSymbol: '上午',
      pmSymbol: '下午',
      regionLanguage: 'zh',
    ),
    // ── 英语 ──
    'en-US': fallback,
    'en-GB': RegionFormatConfig(
      tag: 'en-GB',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'en',
    ),
    // ── 欧洲（24 小时制、日.月.年，周一为一周第一天）──
    'de-DE': RegionFormatConfig(
      tag: 'de-DE',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'de',
    ),
    'fr-FR': RegionFormatConfig(
      tag: 'fr-FR',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'fr',
    ),
    'es-ES': RegionFormatConfig(
      tag: 'es-ES',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'es',
    ),
    'it-IT': RegionFormatConfig(
      tag: 'it-IT',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'it',
    ),
    'pt-BR': RegionFormatConfig(
      tag: 'pt-BR',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.sunday,
      regionLanguage: 'pt',
    ),
    'nl-NL': RegionFormatConfig(
      tag: 'nl-NL',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'nl',
    ),
    'sv-SE': RegionFormatConfig(
      tag: 'sv-SE',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.ymd,
      weekStart: WeekStart.monday,
      regionLanguage: 'sv',
    ),
    'pl-PL': RegionFormatConfig(
      tag: 'pl-PL',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'pl',
    ),
    'el-GR': RegionFormatConfig(
      tag: 'el-GR',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      amSymbol: 'πμ',
      pmSymbol: 'μμ',
      regionLanguage: 'el',
    ),
    'ru-RU': RegionFormatConfig(
      tag: 'ru-RU',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'ru',
    ),
    // ── 亚洲 ──
    'ja-JP': RegionFormatConfig(
      tag: 'ja-JP',
      timePattern: TimePattern.hmm24,
      datePattern: DatePattern.ymd,
      weekStart: WeekStart.sunday,
      amSymbol: '午前',
      pmSymbol: '午後',
      regionLanguage: 'ja',
    ),
    'ko-KR': RegionFormatConfig(
      tag: 'ko-KR',
      timePattern: TimePattern.hmm24,
      datePattern: DatePattern.ymd,
      weekStart: WeekStart.sunday,
      amSymbol: '오전',
      pmSymbol: '오후',
      regionLanguage: 'ko',
    ),
    'hi-IN': RegionFormatConfig(
      tag: 'hi-IN',
      timePattern: TimePattern.hmm12,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.sunday,
      amSymbol: 'am',
      pmSymbol: 'pm',
      regionLanguage: 'hi',
    ),
    'th-TH': RegionFormatConfig(
      tag: 'th-TH',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.sunday,
      regionLanguage: 'th',
    ),
    'tr-TR': RegionFormatConfig(
      tag: 'tr-TR',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'tr',
    ),
    'ar-SA': RegionFormatConfig(
      tag: 'ar-SA',
      timePattern: TimePattern.hmm12,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.sunday,
      amSymbol: 'ص',
      pmSymbol: 'م',
      regionLanguage: 'ar',
    ),
    // ── ISO 风格变体 ──
    'en-CA': RegionFormatConfig(
      tag: 'en-CA',
      timePattern: TimePattern.hhmm24,
      datePattern: DatePattern.ymd,
      weekStart: WeekStart.sunday,
      regionLanguage: 'en',
    ),
    'en-AU': RegionFormatConfig(
      tag: 'en-AU',
      timePattern: TimePattern.hmm12,
      datePattern: DatePattern.dmy,
      weekStart: WeekStart.monday,
      regionLanguage: 'en',
    ),
  };

  /// 按标签解析预设（大小写不敏感、`_` 与 `-` 等价）；未命中回落 [fallback]。
  static RegionFormatConfig resolve(String? tag) {
    if (tag == null || tag.isEmpty) {
      return fallback;
    }
    final String needle = tag.replaceAll('_', '-');
    for (final MapEntry<String, RegionFormatConfig> e in presets.entries) {
      if (e.key.replaceAll('_', '-').toLowerCase() == needle.toLowerCase()) {
        return e.value;
      }
    }
    // 语言级回落（如 `de-LI` → `de-DE` 的语言规则）。
    final String language = needle.split('-').first.toLowerCase();
    for (final MapEntry<String, RegionFormatConfig> e in presets.entries) {
      if (e.key.split('-').first.toLowerCase() == language) {
        return e.value.copyWith(tag: needle);
      }
    }
    return fallback.copyWith(tag: needle);
  }
}
