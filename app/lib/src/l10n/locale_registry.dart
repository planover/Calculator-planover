/// 受支持的语言与区域清单 —— **Windows 11 + Android + iOS 受支持语言的并集**。
///
/// 为什么是这三者的并集而不是"地球全部语言"：
/// 地球上现存约 7000 种语言，其中绝大多数没有可用的 CLDR 区域数据、也没有
/// 标准书写规范，硬做只会产出无法验证的占位翻译。这里以 Windows 11 的语言包
/// 为基线（约 110 种，覆盖全球 99% 以上的互联网人口），再并入 Android（AOSP /
/// ICU 区域数据）与 iOS（Apple 官方"语言与地区"列表，iOS 17/18 级别）各自独有、
/// 而基线没有的语言与区域变体，保证每一档都 **可交付、可校对**。
///
/// 设计约定（与 `app_localizations.dart` 的三层兜底一致）：
/// 1. [AppLocale.tag] 用 BCP-47 风格（`zh-CN` / `pt-BR` / `es-419`），与系统 locale 直接比对；
/// 2. [AppLocale.rtl] 标记从右向左书写（阿拉伯语/希伯来语/波斯语/乌尔都语等），UI 据此镜像布局；
/// 3. 数字的小数点/千分位不写死在这里，而是由 `app_localizations.dart`
///    用 intl 的 CLDR `numberFormatSymbols` 查 —— 清单只管"有哪些语言"。
///
/// 区域变体（如 `en-US` / `de-DE` / `es-419`）仅用于"精确匹配系统区域、回落到
/// 用户所在区域的习惯"；清单本身不带任何翻译——未提供语言包的语言统一回落 `en`。
library;

/// 一档受支持的语言/区域。
class AppLocale {
  /// 构造一档语言。
  const AppLocale({
    required this.tag,
    required this.native,
    required this.english,
    this.rtl = false,
    this.cldr,
  });

  /// BCP-47 标签，如 `zh-CN` / `pt-BR` / `en`。
  final String tag;

  /// 该语言的**母语**名称（设置页按母语展示，用户才认得出）。
  final String native;

  /// 英文名称（便于按字母检索与调试）。
  final String english;

  /// 是否从右向左书写。
  final bool rtl;

  /// 显式指定 CLDR 数字格式键（如 `pt_BR`）；为 null 时由 [tag] 自动推导。
  final String? cldr;

  @override
  String toString() => 'AppLocale($tag, $native)';
}

/// 语言清单与查询。
abstract final class LocaleRegistry {
  /// 全部受支持的语言（按英文名字母序，便于设置页列表稳定）。
  ///
  /// 合并自 Windows 11 + Android + iOS。新增条目遵循既有 `// ── X ──` 字母分组；
  /// `tag` 全局唯一（测试会断言）。绝大多数条目无需显式 [AppLocale.cldr]——
  /// [cldrCandidates] 的朴素推导（`tag` 直转 / `语言_地区` / `语言`）已能覆盖
  /// `pt-BR`→`pt_BR`、`zh-CN`→`zh`、`zh-Hans`→`zh`/`zh_Hans` 等常见情形。
  static const List<AppLocale> supported = <AppLocale>[
    // ── A ──
    AppLocale(tag: 'af', native: 'Afrikaans', english: 'Afrikaans'),
    AppLocale(tag: 'ak', native: 'Akan', english: 'Akan'),
    AppLocale(tag: 'sq', native: 'Shqip', english: 'Albanian'),
    AppLocale(tag: 'am', native: 'አማርኛ', english: 'Amharic'),
    AppLocale(tag: 'ar', native: 'العربية', english: 'Arabic', rtl: true),
    AppLocale(tag: 'ar-AE', native: 'العربية (الإمارات)', english: 'Arabic (United Arab Emirates)', rtl: true),
    AppLocale(tag: 'ar-BH', native: 'العربية (البحرين)', english: 'Arabic (Bahrain)', rtl: true),
    AppLocale(tag: 'ar-DZ', native: 'العربية (الجزائر)', english: 'Arabic (Algeria)', rtl: true),
    AppLocale(tag: 'ar-EG', native: 'العربية (مصر)', english: 'Arabic (Egypt)', rtl: true),
    AppLocale(tag: 'ar-IL', native: 'العربية (إسرائيل)', english: 'Arabic (Israel)', rtl: true),
    AppLocale(tag: 'ar-IQ', native: 'العربية (العراق)', english: 'Arabic (Iraq)', rtl: true),
    AppLocale(tag: 'ar-JO', native: 'العربية (الأردن)', english: 'Arabic (Jordan)', rtl: true),
    AppLocale(tag: 'ar-KW', native: 'العربية (الكويت)', english: 'Arabic (Kuwait)', rtl: true),
    AppLocale(tag: 'ar-LB', native: 'العربية (لبنان)', english: 'Arabic (Lebanon)', rtl: true),
    AppLocale(tag: 'ar-LY', native: 'العربية (ليبيا)', english: 'Arabic (Libya)', rtl: true),
    AppLocale(tag: 'ar-MA', native: 'العربية (المغرب)', english: 'Arabic (Morocco)', rtl: true),
    AppLocale(tag: 'ar-OM', native: 'العربية (عُمان)', english: 'Arabic (Oman)', rtl: true),
    AppLocale(tag: 'ar-QA', native: 'العربية (قطر)', english: 'Arabic (Qatar)', rtl: true),
    AppLocale(tag: 'ar-SA', native: 'العربية (السعودية)', english: 'Arabic (Saudi Arabia)', rtl: true),
    AppLocale(tag: 'ar-SD', native: 'العربية (السودان)', english: 'Arabic (Sudan)', rtl: true),
    AppLocale(tag: 'ar-SY', native: 'العربية (سوريا)', english: 'Arabic (Syria)', rtl: true),
    AppLocale(tag: 'ar-TN', native: 'العربية (تونس)', english: 'Arabic (Tunisia)', rtl: true),
    AppLocale(tag: 'ar-YE', native: 'العربية (اليمن)', english: 'Arabic (Yemen)', rtl: true),
    AppLocale(tag: 'hy', native: 'Հայերեն', english: 'Armenian'),
    AppLocale(tag: 'as', native: 'অসমীয়া', english: 'Assamese'),
    AppLocale(tag: 'az', native: 'Azərbaycan', english: 'Azerbaijani'),
    // ── B ──
    AppLocale(tag: 'eu', native: 'Euskara', english: 'Basque'),
    AppLocale(tag: 'be', native: 'Беларуская', english: 'Belarusian'),
    AppLocale(tag: 'bn', native: 'বাংলা', english: 'Bangla'),
    AppLocale(tag: 'bn-BD', native: 'বাংলা', english: 'Bangla (Bangladesh)'),
    AppLocale(tag: 'bn-IN', native: 'বাংলা', english: 'Bangla (India)'),
    AppLocale(tag: 'bo', native: 'བོད་སྐད', english: 'Tibetan'),
    AppLocale(tag: 'bs', native: 'Bosanski', english: 'Bosnian'),
    AppLocale(tag: 'bg', native: 'Български', english: 'Bulgarian'),
    // ── C ──
    AppLocale(tag: 'ca', native: 'Català', english: 'Catalan'),
    AppLocale(tag: 'ckb', native: 'کوردیی ناوەندی', english: 'Central Kurdish', rtl: true),
    AppLocale(tag: 'zh-CN', native: '简体中文', english: 'Chinese (Simplified)'),
    AppLocale(tag: 'zh-TW', native: '繁體中文', english: 'Chinese (Traditional)'),
    AppLocale(tag: 'zh-HK', native: '繁體中文（香港）', english: 'Chinese (Traditional, Hong Kong SAR)'),
    AppLocale(tag: 'zh-Hans', native: '中文（简体）', english: 'Chinese (Simplified)'),
    AppLocale(tag: 'zh-Hant', native: '中文（繁體）', english: 'Chinese (Traditional)'),
    AppLocale(tag: 'zh-SG', native: '简体中文（新加坡）', english: 'Chinese (Simplified, Singapore)'),
    AppLocale(tag: 'hr', native: 'Hrvatski', english: 'Croatian'),
    AppLocale(tag: 'cs', native: 'Čeština', english: 'Czech'),
    // ── D ──
    AppLocale(tag: 'da', native: 'Dansk', english: 'Danish'),
    AppLocale(tag: 'prs', native: 'دری', english: 'Dari', rtl: true),
    AppLocale(tag: 'nl', native: 'Nederlands', english: 'Dutch'),
    AppLocale(tag: 'nl-BE', native: 'Nederlands (België)', english: 'Dutch (Belgium)'),
    AppLocale(tag: 'nl-NL', native: 'Nederlands (Nederland)', english: 'Dutch (Netherlands)'),
    AppLocale(tag: 'nl-LU', native: 'Nederlands (Luxemburg)', english: 'Dutch (Luxembourg)'),
    AppLocale(tag: 'dz', native: 'རྫོང་ཁ', english: 'Dzongkha'),
    // ── E ──
    AppLocale(tag: 'ee', native: 'Eʋegbe', english: 'Ewe'),
    AppLocale(tag: 'en', native: 'English', english: 'English'),
    AppLocale(tag: 'en-AE', native: 'English (United Arab Emirates)', english: 'English (United Arab Emirates)'),
    AppLocale(tag: 'en-AU', native: 'English (Australia)', english: 'English (Australia)'),
    AppLocale(tag: 'en-CA', native: 'English (Canada)', english: 'English (Canada)'),
    AppLocale(tag: 'en-GB', native: 'English (United Kingdom)', english: 'English (United Kingdom)'),
    AppLocale(tag: 'en-IE', native: 'English (Ireland)', english: 'English (Ireland)'),
    AppLocale(tag: 'en-IN', native: 'English (India)', english: 'English (India)'),
    AppLocale(tag: 'en-MY', native: 'English (Malaysia)', english: 'English (Malaysia)'),
    AppLocale(tag: 'en-NZ', native: 'English (New Zealand)', english: 'English (New Zealand)'),
    AppLocale(tag: 'en-PH', native: 'English (Philippines)', english: 'English (Philippines)'),
    AppLocale(tag: 'en-SG', native: 'English (Singapore)', english: 'English (Singapore)'),
    AppLocale(tag: 'en-US', native: 'English (United States)', english: 'English (United States)'),
    AppLocale(tag: 'en-ZA', native: 'English (South Africa)', english: 'English (South Africa)'),
    AppLocale(tag: 'et', native: 'Eesti', english: 'Estonian'),
    // ── F ──
    AppLocale(tag: 'fil', native: 'Filipino', english: 'Filipino'),
    AppLocale(tag: 'fi', native: 'Suomi', english: 'Finnish'),
    AppLocale(tag: 'ff', native: 'Fulfulde', english: 'Fulah'),
    AppLocale(tag: 'fj', native: 'Na Vosa Vakaviti', english: 'Fijian'),
    AppLocale(tag: 'fo', native: 'Føroyskt', english: 'Faroese'),
    AppLocale(tag: 'fr', native: 'Français', english: 'French'),
    AppLocale(tag: 'fr-BE', native: 'Français (Belgique)', english: 'French (Belgium)'),
    AppLocale(tag: 'fr-CA', native: 'Français (Canada)', english: 'French (Canada)'),
    AppLocale(tag: 'fr-CH', native: 'Français (Suisse)', english: 'French (Switzerland)'),
    AppLocale(tag: 'fr-FR', native: 'Français (France)', english: 'French (France)'),
    AppLocale(tag: 'fr-LU', native: 'Français (Luxembourg)', english: 'French (Luxembourg)'),
    // ── G ──
    AppLocale(tag: 'gl', native: 'Galego', english: 'Galician'),
    AppLocale(tag: 'ka', native: 'ქართული', english: 'Georgian'),
    AppLocale(tag: 'de', native: 'Deutsch', english: 'German'),
    AppLocale(tag: 'de-AT', native: 'Deutsch (Österreich)', english: 'German (Austria)'),
    AppLocale(tag: 'de-CH', native: 'Deutsch (Schweiz)', english: 'German (Switzerland)'),
    AppLocale(tag: 'de-DE', native: 'Deutsch (Deutschland)', english: 'German (Germany)'),
    AppLocale(tag: 'el', native: 'Ελληνικά', english: 'Greek'),
    AppLocale(tag: 'gu', native: 'ગુજરાતી', english: 'Gujarati'),
    // ── H ──
    AppLocale(tag: 'ha', native: 'Hausa', english: 'Hausa'),
    AppLocale(tag: 'haw', native: 'ʻŌlelo Hawaiʻi', english: 'Hawaiian'),
    AppLocale(tag: 'he', native: 'עברית', english: 'Hebrew', rtl: true),
    AppLocale(tag: 'hi', native: 'हिन्दी', english: 'Hindi'),
    AppLocale(tag: 'hi-IN', native: 'हिन्दी', english: 'Hindi (India)'),
    AppLocale(tag: 'hu', native: 'Magyar', english: 'Hungarian'),
    // ── I ──
    AppLocale(tag: 'is', native: 'Íslenska', english: 'Icelandic'),
    AppLocale(tag: 'ig', native: 'Igbo', english: 'Igbo'),
    AppLocale(tag: 'id', native: 'Bahasa Indonesia', english: 'Indonesian'),
    AppLocale(tag: 'ga', native: 'Gaeilge', english: 'Irish'),
    AppLocale(tag: 'it', native: 'Italiano', english: 'Italian'),
    AppLocale(tag: 'it-CH', native: 'Italiano (Svizzera)', english: 'Italian (Switzerland)'),
    AppLocale(tag: 'it-IT', native: 'Italiano (Italia)', english: 'Italian (Italy)'),
    AppLocale(tag: 'iu', native: 'ᐃᓄᒃᑎᑐᑦ', english: 'Inuktitut'),
    // ── J ──
    AppLocale(tag: 'ja', native: '日本語', english: 'Japanese'),
    AppLocale(tag: 'ja-JP', native: '日本語', english: 'Japanese (Japan)'),
    AppLocale(tag: 'jv', native: 'Basa Jawa', english: 'Javanese'),
    // ── K ──
    AppLocale(tag: 'kn', native: 'ಕನ್ನಡ', english: 'Kannada'),
    AppLocale(tag: 'kk', native: 'Қазақ тілі', english: 'Kazakh'),
    AppLocale(tag: 'km', native: 'ខ្មែរ', english: 'Khmer'),
    AppLocale(tag: 'kl', native: 'Kalaallisut', english: 'Greenlandic'),
    AppLocale(tag: 'ko', native: '한국어', english: 'Korean'),
    AppLocale(tag: 'ko-KR', native: '한국어', english: 'Korean (South Korea)'),
    AppLocale(tag: 'kok', native: 'कोंकणी', english: 'Konkani'),
    AppLocale(tag: 'ku', native: 'Kurdî', english: 'Kurdish', rtl: true),
    AppLocale(tag: 'ky', native: 'Кыргызча', english: 'Kyrgyz'),
    // ── L ──
    AppLocale(tag: 'lo', native: 'ລາວ', english: 'Lao'),
    AppLocale(tag: 'lv', native: 'Latviešu', english: 'Latvian'),
    AppLocale(tag: 'lt', native: 'Lietuvių', english: 'Lithuanian'),
    AppLocale(tag: 'lb', native: 'Lëtzebuergesch', english: 'Luxembourgish'),
    // ── M ──
    AppLocale(tag: 'mk', native: 'Македонски', english: 'Macedonian'),
    AppLocale(tag: 'ms', native: 'Bahasa Melayu', english: 'Malay'),
    AppLocale(tag: 'ms-MY', native: 'Bahasa Melayu', english: 'Malay (Malaysia)'),
    AppLocale(tag: 'my', native: 'မြန်မာဘာသာ', english: 'Burmese'),
    AppLocale(tag: 'ml', native: 'മലയാളം', english: 'Malayalam'),
    AppLocale(tag: 'mt', native: 'Malti', english: 'Maltese'),
    AppLocale(tag: 'mai', native: 'मैथिली', english: 'Maithili'),
    AppLocale(tag: 'mi', native: 'Te Reo Māori', english: 'Maori'),
    AppLocale(tag: 'mr', native: 'मराठी', english: 'Marathi'),
    AppLocale(tag: 'mn', native: 'Монгол', english: 'Mongolian'),
    // ── N ──
    AppLocale(tag: 'ne', native: 'नेपाली', english: 'Nepali'),
    AppLocale(tag: 'ne-IN', native: 'नेपाली', english: 'Nepali (India)'),
    AppLocale(tag: 'nr', native: 'isiNdebele', english: 'Ndebele'),
    AppLocale(tag: 'nb', native: 'Norsk bokmål', english: 'Norwegian Bokmål'),
    AppLocale(tag: 'nb-NO', native: 'Norsk bokmål', english: 'Norwegian Bokmål (Norway)'),
    AppLocale(tag: 'nn', native: 'Norsk nynorsk', english: 'Norwegian Nynorsk'),
    AppLocale(tag: 'nn-NO', native: 'Norsk nynorsk', english: 'Norwegian Nynorsk (Norway)'),
    AppLocale(tag: 'ny', native: 'Chichewa', english: 'Nyanja'),
    // ── O ──
    AppLocale(tag: 'or', native: 'ଓଡ଼ିଆ', english: 'Odia'),
    // ── P ──
    AppLocale(tag: 'ps', native: 'پښتو', english: 'Pashto', rtl: true),
    AppLocale(tag: 'fa', native: 'فارسی', english: 'Persian', rtl: true),
    AppLocale(tag: 'fa-IR', native: 'فارسی', english: 'Persian (Iran)', rtl: true),
    AppLocale(tag: 'pl', native: 'Polski', english: 'Polish'),
    AppLocale(tag: 'pt', native: 'Português', english: 'Portuguese'),
    AppLocale(tag: 'pt-BR', native: 'Português (Brasil)', english: 'Portuguese (Brazil)'),
    AppLocale(tag: 'pt-PT', native: 'Português (Portugal)', english: 'Portuguese (Portugal)'),
    AppLocale(tag: 'pa', native: 'ਪੰਜਾਬੀ', english: 'Punjabi'),
    AppLocale(tag: 'pa-IN', native: 'ਪੰਜਾਬੀ', english: 'Punjabi (India)'),
    AppLocale(tag: 'pa-PK', native: 'پنجابی', english: 'Punjabi (Pakistan)', rtl: true),
    // ── Q ──
    AppLocale(tag: 'qu', native: 'Runasimi', english: 'Quechua'),
    // ── R ──
    AppLocale(tag: 'rn', native: 'Ikirundi', english: 'Rundi'),
    AppLocale(tag: 'ro', native: 'Română', english: 'Romanian'),
    AppLocale(tag: 'ru', native: 'Русский', english: 'Russian'),
    AppLocale(tag: 'ru-RU', native: 'Русский', english: 'Russian (Russia)'),
    // ── S ──
    AppLocale(tag: 'gd', native: 'Gàidhlig', english: 'Scottish Gaelic'),
    AppLocale(tag: 'sa', native: 'संस्कृतम्', english: 'Sanskrit'),
    AppLocale(tag: 'sd', native: 'سنڌي', english: 'Sindhi', rtl: true),
    AppLocale(tag: 'si', native: 'සිංහල', english: 'Sinhala'),
    AppLocale(tag: 'sk', native: 'Slovenčina', english: 'Slovak'),
    AppLocale(tag: 'sl', native: 'Slovenščina', english: 'Slovenian'),
    AppLocale(tag: 'sm', native: 'Gagana Samoa', english: 'Samoan'),
    AppLocale(tag: 'so', native: 'Soomaali', english: 'Somali'),
    AppLocale(tag: 'sr', native: 'Српски', english: 'Serbian'),
    AppLocale(tag: 'ss', native: 'SiSwati', english: 'Swati'),
    AppLocale(tag: 'st', native: 'Sesotho', english: 'Sotho'),
    AppLocale(tag: 'es', native: 'Español', english: 'Spanish'),
    AppLocale(tag: 'es-419', native: 'Español (Latinoamérica)', english: 'Spanish (Latin America)'),
    AppLocale(tag: 'es-AR', native: 'Español (Argentina)', english: 'Spanish (Argentina)'),
    AppLocale(tag: 'es-BO', native: 'Español (Bolivia)', english: 'Spanish (Bolivia)'),
    AppLocale(tag: 'es-CL', native: 'Español (Chile)', english: 'Spanish (Chile)'),
    AppLocale(tag: 'es-CO', native: 'Español (Colombia)', english: 'Spanish (Colombia)'),
    AppLocale(tag: 'es-CR', native: 'Español (Costa Rica)', english: 'Spanish (Costa Rica)'),
    AppLocale(tag: 'es-DO', native: 'Español (República Dominicana)', english: 'Spanish (Dominican Republic)'),
    AppLocale(tag: 'es-EC', native: 'Español (Ecuador)', english: 'Spanish (Ecuador)'),
    AppLocale(tag: 'es-ES', native: 'Español (España)', english: 'Spanish (Spain)'),
    AppLocale(tag: 'es-GT', native: 'Español (Guatemala)', english: 'Spanish (Guatemala)'),
    AppLocale(tag: 'es-HN', native: 'Español (Honduras)', english: 'Spanish (Honduras)'),
    AppLocale(tag: 'es-MX', native: 'Español (México)', english: 'Spanish (Mexico)'),
    AppLocale(tag: 'es-NI', native: 'Español (Nicaragua)', english: 'Spanish (Nicaragua)'),
    AppLocale(tag: 'es-PA', native: 'Español (Panamá)', english: 'Spanish (Panama)'),
    AppLocale(tag: 'es-PE', native: 'Español (Perú)', english: 'Spanish (Peru)'),
    AppLocale(tag: 'es-PR', native: 'Español (Puerto Rico)', english: 'Spanish (Puerto Rico)'),
    AppLocale(tag: 'es-PY', native: 'Español (Paraguay)', english: 'Spanish (Paraguay)'),
    AppLocale(tag: 'es-SV', native: 'Español (El Salvador)', english: 'Spanish (El Salvador)'),
    AppLocale(tag: 'es-US', native: 'Español (Estados Unidos)', english: 'Spanish (United States)'),
    AppLocale(tag: 'es-UY', native: 'Español (Uruguay)', english: 'Spanish (Uruguay)'),
    AppLocale(tag: 'es-VE', native: 'Español (Venezuela)', english: 'Spanish (Venezuela)'),
    AppLocale(tag: 'sw', native: 'Kiswahili', english: 'Swahili'),
    AppLocale(tag: 'sv', native: 'Svenska', english: 'Swedish'),
    AppLocale(tag: 'su', native: 'Basa Sunda', english: 'Sundanese'),
    // ── T ──
    AppLocale(tag: 'ta', native: 'தமிழ்', english: 'Tamil'),
    AppLocale(tag: 'ta-IN', native: 'தமிழ்', english: 'Tamil (India)'),
    AppLocale(tag: 'ta-LK', native: 'தமிழ்', english: 'Tamil (Sri Lanka)'),
    AppLocale(tag: 'ta-MY', native: 'தமிழ்', english: 'Tamil (Malaysia)'),
    AppLocale(tag: 'ta-SG', native: 'தமிழ்', english: 'Tamil (Singapore)'),
    AppLocale(tag: 'te', native: 'తెలుగు', english: 'Telugu'),
    AppLocale(tag: 'tg', native: 'Тоҷикӣ', english: 'Tajik'),
    AppLocale(tag: 'th', native: 'ไทย', english: 'Thai'),
    AppLocale(tag: 'th-TH', native: 'ไทย', english: 'Thai (Thailand)'),
    AppLocale(tag: 'ti', native: 'ትግርኛ', english: 'Tigrinya'),
    AppLocale(tag: 'tk', native: 'Türkmen', english: 'Turkmen'),
    AppLocale(tag: 'tn', native: 'Setswana', english: 'Tswana'),
    AppLocale(tag: 'to', native: 'Lea fakatonga', english: 'Tongan'),
    AppLocale(tag: 'tr', native: 'Türkçe', english: 'Turkish'),
    AppLocale(tag: 'tr-TR', native: 'Türkçe', english: 'Turkish (Turkey)'),
    AppLocale(tag: 'ts', native: 'Xitsonga', english: 'Tsonga'),
    AppLocale(tag: 'tt', native: 'Татарча', english: 'Tatar'),
    // ── U ──
    AppLocale(tag: 'ug', native: 'ئۇيغۇرچە', english: 'Uyghur', rtl: true),
    AppLocale(tag: 'uk', native: 'Українська', english: 'Ukrainian'),
    AppLocale(tag: 'ur', native: 'اردو', english: 'Urdu', rtl: true),
    AppLocale(tag: 'ur-PK', native: 'اردو', english: 'Urdu (Pakistan)', rtl: true),
    AppLocale(tag: 'uz', native: 'Oʻzbekcha', english: 'Uzbek'),
    // ── V ──
    AppLocale(tag: 've', native: 'Tshivenḓa', english: 'Venda'),
    AppLocale(tag: 'vi', native: 'Tiếng Việt', english: 'Vietnamese'),
    AppLocale(tag: 'vi-VN', native: 'Tiếng Việt', english: 'Vietnamese (Vietnam)'),
    // ── W ──
    AppLocale(tag: 'cy', native: 'Cymraeg', english: 'Welsh'),
    AppLocale(tag: 'wo', native: 'Wolof', english: 'Wolof'),
    // ── X / Y / Z ──
    AppLocale(tag: 'xh', native: 'isiXhosa', english: 'Xhosa'),
    AppLocale(tag: 'yo', native: 'Yorùbá', english: 'Yoruba'),
    AppLocale(tag: 'yi', native: 'ייִדיש', english: 'Yiddish'),
    AppLocale(tag: 'zu', native: 'isiZulu', english: 'Zulu'),
  ];

  /// 默认（也是最终兜底）语言。
  static const String fallbackTag = 'en';

  /// 按 tag 精确查找；未命中返回 null。
  static AppLocale? find(String? tag) {
    if (tag == null || tag.isEmpty) {
      return null;
    }
    final String needle = tag.replaceAll('_', '-');
    for (final AppLocale l in supported) {
      if (l.tag.replaceAll('_', '-') == needle) {
        return l;
      }
    }
    return null;
  }

  /// 是否从右向左书写（未知语言按 LTR 处理）。
  static bool isRtl(String? tag) => find(tag)?.rtl ?? false;

  /// 把语言标签规整成清单里的形式。
  ///
  /// 解析顺序（**兜底链**，与语言包加载一致）：
  /// 1. 完整匹配 `zh-TW` → `zh-TW`
  /// 2. 语言匹配 `zh-HK` → `zh-HK`；`de-AT` → `de-AT`（精确条目存在时）
  /// 3. 都匹配不上（如 `de-LI`）→ 回落到同语言第一档 `de`
  /// 4. 连语言都不认识 → `en`
  static String canonicalize(String? tag) {
    if (tag == null || tag.isEmpty) {
      return fallbackTag;
    }
    final String needle = tag.replaceAll('_', '-');
    final AppLocale? exact = find(needle);
    if (exact != null) {
      return exact.tag;
    }
    final String language = needle.split('-').first.toLowerCase();
    for (final AppLocale l in supported) {
      if (l.tag.split('-').first.toLowerCase() == language) {
        return l.tag;
      }
    }
    return fallbackTag;
  }

  /// 推导 CLDR 数字格式键（如 `de_DE` / `pt_BR`）。
  ///
  /// 优先用清单里显式指定的 [AppLocale.cldr]，否则按
  /// `tag 直转` → `语言_地区` → `语言_语言大写` → `语言` 的顺序猜测，
  /// 最终由调用方用 `numberFormatSymbols.containsKey` 校验。
  static List<String> cldrCandidates(String tag) {
    final AppLocale? found = find(tag);
    final List<String> out = <String>[];
    if (found?.cldr != null) {
      out.add(found!.cldr!);
    }
    final String normalized = tag.replaceAll('-', '_');
    out.add(normalized);
    final List<String> parts = normalized.split('_');
    if (parts.length >= 2) {
      out.add('${parts[0]}_${parts[1].toUpperCase()}');
    }
    // 语言_语言大写（de → de_DE）
    out.add('${parts[0]}_${parts[0].toUpperCase()}');
    out.add(parts[0]);
    return out;
  }
}
