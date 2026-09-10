//! T05：数字格式化（科学 / 定点 / 有效位 / 小数位 / 分数 / 分组 / 精确小数 / 整数不截断）。
//!
//! 覆盖 PRD P0-16 / P0-17 / P0-18 / P0-19。

mod common;

use calculator_core::format::{
    format_fraction, format_number, format_scientific, FractionMode, Notation,
    NumberFormatSettings, PrecisionMode,
};
use calculator_core::num::{Num, Special};
use common::{calc, calc_with, settings, settings_grouped};

/// 便捷封装：按设置格式化一个 [`Num`]。
fn fmt(n: Num, s: NumberFormatSettings) -> String {
    format_number(&n, &s).unwrap()
}

#[test]
fn significant_digits_rounding() {
    // 默认有效位 10，精度放得下直接用有效数字
    let s4 = NumberFormatSettings {
        precision: 4,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::float(std::f64::consts::PI), s4), "3.142");
    let s10 = NumberFormatSettings {
        precision: 10,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::float(std::f64::consts::PI), s10), "3.141592654");
}

#[test]
fn decimal_places_mode() {
    let s = NumberFormatSettings {
        notation: Notation::Fixed,
        precision_mode: PrecisionMode::DecimalPlaces,
        precision: 2,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::float(std::f64::consts::PI), s), "3.14");
    assert_eq!(fmt(Num::rational(1, 3).unwrap(), s), "0.33");
}

#[test]
fn scientific_notation_uses_unicode_superscript() {
    // 直接渲染函数：始终给出科学计数法
    assert_eq!(format_scientific(123456789.0, 10), "1.23456789×10⁸");
    assert_eq!(format_scientific(0.000001, 3), "1×10⁻⁶");
    // 浮点输入走科学计数法分支（整数会走"不截断"分支，故此处用浮点）
    let s = NumberFormatSettings {
        notation: Notation::Scientific,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::float(123456789.0), s), "1.23456789×10⁸");
}

#[test]
fn auto_switches_to_scientific_for_extremes() {
    let s = NumberFormatSettings {
        precision: 10,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::float(1.5e20), s), "1.5×10²⁰");
    assert_eq!(fmt(Num::float(1.5e-12), s), "1.5×10⁻¹²");
}

#[test]
fn fraction_modes() {
    let improper = NumberFormatSettings {
        fraction_mode: FractionMode::Improper,
        ..NumberFormatSettings::default()
    };
    let mixed = NumberFormatSettings {
        fraction_mode: FractionMode::Mixed,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::rational(1, 2).unwrap(), improper), "1/2");
    assert_eq!(fmt(Num::rational(11, 4).unwrap(), improper), "11/4");
    assert_eq!(fmt(Num::rational(11, 4).unwrap(), mixed), "2 3/4");
    // 浮点也能化成分数（2.75 == 11/4）
    assert_eq!(
        format_fraction(&Num::float(2.75), FractionMode::Mixed),
        Some("2 3/4".to_string())
    );
}

#[test]
fn grouping_separators() {
    let g = settings_grouped();
    assert_eq!(calc_with("1234567.89", &g), "1,234,567.89");
    // 关闭分组时不加逗号
    assert_eq!(calc_with("1234567.89", &settings()), "1234567.89");
    // 整数也分组
    assert_eq!(calc_with("1234567890", &g), "1,234,567,890");
}

#[test]
fn exact_decimal_beats_float_noise() {
    // 精确有理数能写出有限十进制时就显示精确串，不被 f64 噪声污染
    let s = NumberFormatSettings::default();
    assert_eq!(fmt(Num::rational(3, 10).unwrap(), s), "0.3");
    assert_eq!(calc("0.1+0.2"), "0.3");
    assert_eq!(calc("1/3*3"), "1");
    assert_eq!(calc("2/4"), "0.5");
}

#[test]
fn integers_are_never_truncated() {
    // P0-31 基线：20! 整数不受有效位截断（关闭分组，专测"不被砍"语义）
    let s = NumberFormatSettings {
        grouping: false,
        ..NumberFormatSettings::default()
    };
    assert_eq!(fmt(Num::int(2432902008176640000), s), "2432902008176640000");
    assert_eq!(
        fmt(Num::int(9223372036854775807), s),
        "9223372036854775807"
    );
}

#[test]
fn non_finite_display() {
    let s = NumberFormatSettings::default();
    assert_eq!(fmt(Num::Special(Special::Nan), s), "非数值");
    assert_eq!(fmt(Num::Special(Special::Infinity), s), "∞");
    assert_eq!(fmt(Num::Special(Special::NegInfinity), s), "-∞");
}

#[test]
fn precision_bounds_validated() {
    use calculator_core::error::ErrorKind;
    use calculator_core::format::validate;
    assert!(validate(&NumberFormatSettings::default()).is_ok());
    assert_eq!(
        validate(&NumberFormatSettings {
            precision: 0,
            ..NumberFormatSettings::default()
        })
        .unwrap_err()
        .kind,
        ErrorKind::InvalidSettings
    );
    assert_eq!(
        validate(&NumberFormatSettings {
            precision: 16,
            ..NumberFormatSettings::default()
        })
        .unwrap_err()
        .kind,
        ErrorKind::InvalidSettings
    );
}
