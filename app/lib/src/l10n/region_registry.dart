/// 区域格式清单 —— 与语言解耦的独立设置项（PRD §5 I3 / LC-01）。
///
/// 区域格式只决定**数字、货币、时间、日期的显示规则**，不影响界面文案
/// （界面文案由语言决定）。本清单是"区域格式"选项的来源，元素取自 Windows 11
/// 「区域格式」里最常见的一组，作为可选项呈现；`null` 表示"跟随系统区域"。
///
/// 数字的小数点/千分位由 [RegionFormatController] 经 `AppLocalizations` 的 CLDR
/// 数据驱动（见 `app_localizations.dart` 的 `number` 重映射），本清单只列"有哪些区域"。
library;

/// 一档区域格式。
class RegionFormat {
  /// 构造一档区域格式。
  const RegionFormat({
    required this.tag,
    required this.native,
    required this.english,
  });

  /// BCP-47 标签，如 `zh-CN` / `en-US` / `de-DE`。
  final String tag;

  /// 母语名称（设置页按母语展示）。
  final String native;

  /// 英文名称（便于检索与调试）。
  final String english;

  @override
  String toString() => 'RegionFormat($tag, $native)';
}

/// 区域格式清单与查询（与 [LocaleRegistry] 平级，但职责不同）。
abstract final class RegionRegistry {
  /// 全部受支持的区域格式（按英文名字母序，便于设置页列表稳定）。
  ///
  /// 首项 `system` 是占位（代表"跟随系统区域"），真正的区域选项从第二项开始。
  static const List<RegionFormat> supported = <RegionFormat>[
    RegionFormat(tag: 'zh-CN', native: '中文（中国）', english: 'Chinese (China)'),
    RegionFormat(tag: 'zh-TW', native: '中文（台湾）', english: 'Chinese (Taiwan)'),
    RegionFormat(tag: 'en-US', native: 'English (United States)', english: 'English (United States)'),
    RegionFormat(tag: 'en-GB', native: 'English (United Kingdom)', english: 'English (United Kingdom)'),
    RegionFormat(tag: 'de-DE', native: 'Deutsch (Deutschland)', english: 'German (Germany)'),
    RegionFormat(tag: 'fr-FR', native: 'Français (France)', english: 'French (France)'),
    RegionFormat(tag: 'es-ES', native: 'Español (España)', english: 'Spanish (Spain)'),
    RegionFormat(tag: 'it-IT', native: 'Italiano (Italia)', english: 'Italian (Italy)'),
    RegionFormat(tag: 'pt-BR', native: 'Português (Brasil)', english: 'Portuguese (Brazil)'),
    RegionFormat(tag: 'nl-NL', native: 'Nederlands (Nederland)', english: 'Dutch (Netherlands)'),
    RegionFormat(tag: 'ja-JP', native: '日本語（日本）', english: 'Japanese (Japan)'),
    RegionFormat(tag: 'ko-KR', native: '한국어（대한민국）', english: 'Korean (South Korea)'),
    RegionFormat(tag: 'ru-RU', native: 'Русский (Россия)', english: 'Russian (Russia)'),
    RegionFormat(tag: 'ar-SA', native: 'العربية (السعودية)', english: 'Arabic (Saudi Arabia)'),
    RegionFormat(tag: 'hi-IN', native: 'हिन्दी (भारत)', english: 'Hindi (India)'),
    RegionFormat(tag: 'th-TH', native: 'ไทย (ไทย)', english: 'Thai (Thailand)'),
    RegionFormat(tag: 'sv-SE', native: 'Svenska (Sverige)', english: 'Swedish (Sweden)'),
    RegionFormat(tag: 'pl-PL', native: 'Polski (Polska)', english: 'Polish (Poland)'),
    RegionFormat(tag: 'tr-TR', native: 'Türkçe (Türkiye)', english: 'Turkish (Turkey)'),
    RegionFormat(tag: 'el-GR', native: 'Ελληνικά (Ελλάδα)', english: 'Greek (Greece)'),
  ];

  /// 全部选项（含系统占位）用于设置页下拉框。
  static List<RegionFormat?> get options => <RegionFormat?>[null, ...supported];

  /// 按 tag 精确查找；未命中返回 null。
  static RegionFormat? find(String? tag) {
    if (tag == null || tag.isEmpty) {
      return null;
    }
    for (final RegionFormat r in supported) {
      if (r.tag == tag) {
        return r;
      }
    }
    return null;
  }
}
