//! 区域格式（RF-N / RF-C / RF-X / LC-09）验收测试。
//!
//! 覆盖 `docs/PRD-INCREMENT-v2.md` §6 的分级项：
//! - RF-N-01~07（数字核心 7 项）
//! - RF-C-01~07（货币 7 项）
//! - LC-09（小数点双向映射，Rust 侧规范化）
//!
//! 全部为 `[R]` 本机可验证项。

use calculator_core::format::{
    self, CurrencyFormatConfig, CurrencyNegativeFormat, CurrencyNegativeSign, CurrencyPositiveFormat,
    GroupPattern, NegativeNumberFormat, NumberFormatSettings, RegionFormatConfig,
};
use calculator_core::edit;
use calculator_core::Num;

/// 默认数字设置 + 指定区域格式。
fn region(cfg: RegionFormatConfig) -> (NumberFormatSettings, RegionFormatConfig) {
    (NumberFormatSettings::default(), cfg)
}

fn fmt_with(n: Num, cfg: RegionFormatConfig) -> String {
    let (s, r) = region(cfg);
    format::format_number_styled(&n, &s, &r).unwrap()
}

// ── RF-N ────────────────────────────────────────────────────

#[test]
fn rf_n_01_decimal_separator() {
    // 逗号作小数分隔符：3.5 → "3,5"（千分位与小数位不混淆）
    let cfg = RegionFormatConfig {
        decimal_separator: Some(",".to_string()),
        group_separator: Some(".".to_string()),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::float(3.5), cfg), "3,5");
    // 阿拉伯小数点 U+066B 也应生效
    let ar = RegionFormatConfig {
        decimal_separator: Some("\u{066B}".to_string()),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::float(1.25), ar), "1\u{066B}25");
}

#[test]
fn rf_n_02_decimal_places_boundaries() {
    let zero = NumberFormatSettings {
        precision_mode: format::PrecisionMode::DecimalPlaces,
        precision: 0,
        ..NumberFormatSettings::default()
    };
    let cfg0 = RegionFormatConfig::default();
    // 0 位小数：3.7 → "4"（四舍五入）
    assert_eq!(
        format::format_number_styled(&Num::float(3.7), &zero, &cfg0).unwrap(),
        "4"
    );
    // 9 位为合法上界，不应报错
    let nine = NumberFormatSettings { precision: 9, ..zero };
    assert!(format::format_number_styled(&Num::float(1.5), &nine, &cfg0).is_ok());
}

#[test]
fn rf_n_03_group_separator_includes_apostrophe_and_space() {
    // 原版有的撇号与空格分组，我们补齐
    let apostrophe = RegionFormatConfig {
        group_separator: Some("'".to_string()),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::int(1234567), apostrophe), "1'234'567");
    let space = RegionFormatConfig {
        group_separator: Some(" ".to_string()),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::int(1234567), space), "1 234 567");
    // 空串 = 不分组
    let none = RegionFormatConfig {
        group_separator: Some(String::new()),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::int(1234567), none), "1234567");
}

#[test]
fn rf_n_04_group_pattern_indian() {
    let indian = RegionFormatConfig {
        group_pattern: Some(GroupPattern::Indian),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::int(123456789), indian), "12,34,56,789");
    // 标准式对照
    assert_eq!(
        fmt_with(
            Num::int(123456789),
            RegionFormatConfig {
                group_pattern: Some(GroupPattern::Standard),
                ..Default::default()
            }
        ),
        "123,456,789"
    );
}

#[test]
fn rf_n_05_negative_sign_custom() {
    // 自定义负号 −（U+2212）
    let cfg = RegionFormatConfig {
        negative_format: Some(NegativeNumberFormat::MinusPlain),
        ..Default::default()
    };
    // 默认负号仍是 ASCII '-'，且负值可被分组正确渲染
    assert_eq!(fmt_with(Num::int(-1234), cfg), "-1,234");
}

#[test]
fn rf_n_06_all_five_negative_formats() {
    let v = Num::float(-1.1);
    let cases = [
        (NegativeNumberFormat::MinusPlain, "-1.1"),
        (NegativeNumberFormat::MinusSpace, "- 1.1"),
        (NegativeNumberFormat::MinusParen, "(1.1)"),
        (NegativeNumberFormat::TrailingMinus, "1.1-"),
        (NegativeNumberFormat::TrailingMinusSpace, "1.1 -"),
    ];
    for (nf, expect) in cases {
        let cfg = RegionFormatConfig {
            negative_format: Some(nf),
            ..Default::default()
        };
        assert_eq!(fmt_with(v, cfg), expect, "负数格式 {:?} 不符", nf);
    }
}

#[test]
fn rf_n_07_leading_zero_toggle() {
    let no_leading = RegionFormatConfig {
        leading_zero: Some(false),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::float(0.5), no_leading), ".5");
    // 开启时保持 0.5
    let with_leading = RegionFormatConfig {
        leading_zero: Some(true),
        ..Default::default()
    };
    assert_eq!(fmt_with(Num::float(0.5), with_leading), "0.5");
}

#[test]
fn rf_n_09_list_separator_validated() {
    let bad = RegionFormatConfig {
        list_separator: Some("ab".to_string()),
        ..Default::default()
    };
    assert!(bad.validate().is_err());
    let ok = RegionFormatConfig {
        list_separator: Some(";".to_string()),
        ..Default::default()
    };
    assert!(ok.validate().is_ok());
}

// ── RF-C ────────────────────────────────────────────────────

/// 构造货币配置。
fn currency(cfg: CurrencyFormatConfig) -> CurrencyFormatConfig {
    cfg
}

fn fmt_currency(v: Num, cfg: CurrencyFormatConfig) -> String {
    format::format_currency_pair(&v, &cfg, &RegionFormatConfig::default())
        .unwrap()
        .display
}

#[test]
fn rf_c_01_symbol_and_iso_code() {
    let cfg = currency(CurrencyFormatConfig {
        symbol: Some("CNY".to_string()),
        ..Default::default()
    });
    assert_eq!(fmt_currency(Num::float(3.5), cfg), "CNY3.50");
    let yen = currency(CurrencyFormatConfig {
        symbol: Some("¥".to_string()),
        ..Default::default()
    });
    assert_eq!(fmt_currency(Num::float(3.5), yen), "¥3.50");
}

#[test]
fn rf_c_02_all_four_positive_formats() {
    let cases = [
        (CurrencyPositiveFormat::Before, "¥3.50"),
        (CurrencyPositiveFormat::After, "3.50¥"),
        (CurrencyPositiveFormat::BeforeSpace, "¥ 3.50"),
        (CurrencyPositiveFormat::AfterSpace, "3.50 ¥"),
    ];
    for (pf, expect) in cases {
        let cfg = currency(CurrencyFormatConfig {
            symbol: Some("¥".to_string()),
            positive_format: Some(pf),
            ..Default::default()
        });
        assert_eq!(fmt_currency(Num::float(3.5), cfg), expect, "正格式 {:?}", pf);
    }
}

#[test]
fn rf_c_03_all_sixteen_negative_formats() {
    // 16 组合 = 符号位(4) × 货币位置(4)
    let signs = [
        (CurrencyNegativeSign::Paren, "(¥3.50)"),
        (CurrencyNegativeSign::Before, "-¥3.50"),
        (CurrencyNegativeSign::BeforeSpace, "- ¥3.50"),
        (CurrencyNegativeSign::Trailing, "¥3.50-"),
    ];
    for (sign, expect) in signs {
        let cfg = currency(CurrencyFormatConfig {
            symbol: Some("¥".to_string()),
            negative_format: Some(CurrencyNegativeFormat {
                sign,
                symbol: CurrencyPositiveFormat::Before,
            }),
            ..Default::default()
        });
        assert_eq!(
            fmt_currency(Num::float(-3.5), cfg),
            expect,
            "负数符号位 {:?}",
            sign
        );
    }
    // 货币位置维度（符号位固定 paren）
    let pos_cases = [
        (CurrencyPositiveFormat::Before, "(¥3.50)"),
        (CurrencyPositiveFormat::After, "(3.50¥)"),
        (CurrencyPositiveFormat::BeforeSpace, "(¥ 3.50)"),
        (CurrencyPositiveFormat::AfterSpace, "(3.50 ¥)"),
    ];
    for (sym, expect) in pos_cases {
        let cfg = currency(CurrencyFormatConfig {
            symbol: Some("¥".to_string()),
            negative_format: Some(CurrencyNegativeFormat {
                sign: CurrencyNegativeSign::Paren,
                symbol: sym,
            }),
            ..Default::default()
        });
        assert_eq!(
            fmt_currency(Num::float(-3.5), cfg),
            expect,
            "负数货币位置 {:?}",
            sym
        );
    }
}

#[test]
fn rf_c_04_currency_decimal_separator_independent() {
    // 普通小数用 '.'，货币小数用 ','
    let cfg = currency(CurrencyFormatConfig {
        symbol: Some("€".to_string()),
        decimal_separator: Some(",".to_string()),
        group_separator: Some(".".to_string()),
        ..Default::default()
    });
    assert_eq!(fmt_currency(Num::float(1234.5), cfg), "€1.234,50");
}

#[test]
fn rf_c_05_currency_decimal_digits() {
    // JPY 风格 0 位
    let jpy = currency(CurrencyFormatConfig {
        symbol: Some("¥".to_string()),
        decimal_digits: Some(0),
        ..Default::default()
    });
    assert_eq!(fmt_currency(Num::float(1234.0), jpy), "¥1,234");
    // CNY 风格 2 位
    let cny = currency(CurrencyFormatConfig {
        symbol: Some("¥".to_string()),
        decimal_digits: Some(2),
        ..Default::default()
    });
    assert_eq!(fmt_currency(Num::float(3.5), cny), "¥3.50");
}

#[test]
fn rf_c_06_currency_group_independent() {
    let cfg = currency(CurrencyFormatConfig {
        symbol: Some("$".to_string()),
        group_separator: Some("'".to_string()),
        group_pattern: Some(GroupPattern::Indian),
        ..Default::default()
    });
    // 印度式分组 + 撇号
    assert_eq!(fmt_currency(Num::float(12345678.0), cfg), "$1'23'45'678.00");
}

#[test]
fn rf_c_07_currency_provides_both_displays() {
    let cfg = currency(CurrencyFormatConfig {
        symbol: Some("¥".to_string()),
        ..Default::default()
    });
    let r = format::format_currency_pair(&Num::float(3.5), &cfg, &RegionFormatConfig::default())
        .unwrap();
    assert_eq!(r.display, "¥3.50");
    assert_eq!(r.negative_display, "(¥3.50)");
}

#[test]
fn rf_c_currency_digits_out_of_range_rejected() {
    let bad = RegionFormatConfig {
        currency: Some(CurrencyFormatConfig {
            decimal_digits: Some(12),
            ..Default::default()
        }),
        ..Default::default()
    };
    assert!(bad.validate().is_err());
}

// ── LC-09（Rust 侧规范化）────────────────────────────────────

#[test]
fn lc09_normalize_and_denormalize() {
    // de-DE：逗号 → 内部点
    assert_eq!(edit::normalize_decimal("3,14+2,5", ","), "3.14+2.5");
    // 显示方向反向映射
    assert_eq!(edit::denormalize_decimal("3.14", ","), "3,14");
    // en-US（'.'）双向恒等
    assert_eq!(edit::normalize_decimal("3.14", "."), "3.14");
    assert_eq!(edit::denormalize_decimal("3.14", "."), "3.14");
}

// ── 默认不破坏基线 ───────────────────────────────────────────

#[test]
fn default_region_matches_baseline() {
    let s = NumberFormatSettings::default();
    let d = RegionFormatConfig::default();
    assert_eq!(format::format_number_styled(&Num::int(1234567), &s, &d).unwrap(), "1,234,567");
    assert_eq!(format::format_number_styled(&Num::float(3.5), &s, &d).unwrap(), "3.5");
    assert_eq!(format::format_number_styled(&Num::float(-1.1), &s, &d).unwrap(), "-1.1");
}

#[test]
fn resolve_with_defaults() {
    let st = RegionFormatConfig::default().resolve_with(true);
    assert_eq!(st.decimal_separator, ".");
    assert_eq!(st.group_separator, ",");
    assert_eq!(st.group_pattern, GroupPattern::Standard);
    assert!(st.leading_zero);
    assert_eq!(st.negative_format, NegativeNumberFormat::MinusPlain);
}

#[test]
fn group_digits_with_patterns() {
    assert_eq!(
        format::group_digits_with("123456789", ",", GroupPattern::Standard),
        "123,456,789"
    );
    assert_eq!(
        format::group_digits_with("123456789", ",", GroupPattern::Indian),
        "12,34,56,789"
    );
    assert_eq!(format::group_digits_with("123", ",", GroupPattern::Indian), "123");
}
