/// `MaterialApp.supportedLocales` 的**权威取值**：`LocaleRegistry.supported` 中
/// **真正有 `GlobalMaterialLocalizations` 数据**的子集（v3 UX-02 / IC-3）。
///
/// 为什么要收敛：把 216 条全塞进 `MaterialApp.supportedLocales`，一旦用户选中
/// 一门 **没有 `MaterialLocalizations` 数据**的语言，`GlobalMaterialLocalizations`
/// 解析会失败 / 抛异常，表现为"切语言卡死"（UX-02 的候选根因之一）。
///
/// 为什么是静态表而不是运行时 216 次探测：
/// 1. 本机无 Flutter SDK，运行时探测的**结果无法在本地复核**，只能盲信；
/// 2. 静态表是"可 review 的 artifact"，且由 `material_supported_locales_test` 在
///    CI 里**重算真交集并断言相等** —— 一旦漂移立刻红，永不静默出错；
/// 3. 运行期零探测、零 `Future`、零抖动。
///
/// ⚠️ 维护方式：只允许通过 CI 失败信息里打印的"期望列表"整体替换 [tags]。
///
/// ⚠️ **初值状态（T01）**：本机无 Flutter SDK，**无法在本地算出真交集**。
/// [tags] 为按对 `kMaterialSupportedLanguages` 的了解填入的**尽力初值**，
/// **待 CI 首轮运行 `material_supported_locales_test` 打印的期望列表校准**。
/// 该测试断言 `tags` 与真交集逐项相等 —— 未校准时即为红灯（防止"忘了收敛"直接发布）。
library;

/// `MaterialApp.supportedLocales` 的静态交集表。
abstract final class MaterialSupportedLocales {
  /// 交集（BCP-47，与 `AppLocale.tag` 同形，且与 `LocaleRegistry.supported` 的
  /// **相对顺序一致**，便于守护测试逐项比较）。
  ///
  /// 口径：`LocaleRegistry.supported` 中语言码 ∈ Flutter `kMaterialSupportedLanguages`
  /// 的条目（含地区变体，如 `ar-SA` / `es-419` / `pt-BR`）。
  ///
  /// **初值待 CI 校准**（见文件头说明）。
  static const List<String> tags = <String>[
    'af',
    'sq',
    'am',
    'ar', 'ar-AE', 'ar-BH', 'ar-DZ', 'ar-EG', 'ar-IL', 'ar-IQ', 'ar-JO',
    'ar-KW', 'ar-LB', 'ar-LY', 'ar-MA', 'ar-OM', 'ar-QA', 'ar-SA', 'ar-SD',
    'ar-SY', 'ar-TN', 'ar-YE',
    'hy',
    'as',
    'az',
    'eu',
    'be',
    'bn', 'bn-BD', 'bn-IN',
    'bs',
    'bg',
    'ca',
    'zh-CN', 'zh-TW', 'zh-HK', 'zh-Hans', 'zh-Hant', 'zh-SG',
    'hr',
    'cs',
    'da',
    'nl', 'nl-BE', 'nl-NL', 'nl-LU',
    'en', 'en-AE', 'en-AU', 'en-CA', 'en-GB', 'en-IE', 'en-IN', 'en-MY',
    'en-NZ', 'en-PH', 'en-SG', 'en-US', 'en-ZA',
    'et',
    'fil',
    'fi',
    'fr', 'fr-BE', 'fr-CA', 'fr-CH', 'fr-FR', 'fr-LU',
    'gl',
    'ka',
    'de', 'de-AT', 'de-CH', 'de-DE',
    'el',
    'gu',
    'he',
    'hi', 'hi-IN',
    'hu',
    'is',
    'id',
    'ga',
    'it', 'it-CH', 'it-IT',
    'ja', 'ja-JP',
    'kn',
    'kk',
    'km',
    'ko', 'ko-KR',
    'ky',
    'lo',
    'lv',
    'lt',
    'mk',
    'ms', 'ms-MY',
    'my',
    'ml',
    'mr',
    'mn',
    'ne', 'ne-IN',
    'nb', 'nb-NO',
    'nn', 'nn-NO',
    'or',
    'ps',
    'fa', 'fa-IR',
    'pl',
    'pt', 'pt-BR', 'pt-PT',
    'pa', 'pa-IN', 'pa-PK',
    'ro',
    'ru', 'ru-RU',
    'si',
    'sk',
    'sl',
    'sr',
    'es', 'es-419', 'es-AR', 'es-BO', 'es-CL', 'es-CO', 'es-CR', 'es-DO',
    'es-EC', 'es-ES', 'es-GT', 'es-HN', 'es-MX', 'es-NI', 'es-PA', 'es-PE',
    'es-PR', 'es-PY', 'es-SV', 'es-US', 'es-UY', 'es-VE',
    'sw',
    'sv',
    'ta', 'ta-IN', 'ta-LK', 'ta-MY', 'ta-SG',
    'te',
    'th', 'th-TH',
    'tr', 'tr-TR',
    'uk',
    'ur', 'ur-PK',
    'uz',
    'vi', 'vi-VN',
    'cy',
  ];
}
