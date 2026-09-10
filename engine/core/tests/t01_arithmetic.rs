//! T02-a：四则运算、优先级、隐式乘法、百分号、阶乘、精度基线。
//!
//! 覆盖 PRD P0-04 / P0-06 / P0-11 / P0-31。

mod common;

use common::{approx, assert_close, calc, calc_with, num, settings, settings_grouped, try_calc};
use calculator_core::format::{FractionMode, Notation, NumberFormatSettings, PrecisionMode};
use calculator_core::num::Num;

/// 表驱动：表达式 → 期望显示串。
fn table(cases: &[(&str, &str)]) {
    for (src, want) in cases {
        assert_eq!(calc(src), *want, "表达式：{}", src);
    }
}

#[test]
fn basic_arithmetic() {
    table(&[
        ("1+2", "3"),
        ("1+2*3", "7"),
        ("(1+2)*3", "9"),
        ("10-3-2", "5"),
        ("100/4", "25"),
        ("2*3*4", "24"),
        ("1-2+3", "2"),
        ("8/4/2", "1"),
        ("0.5+0.25", "0.75"),
        ("1_000+1", "1001"),
        (".5*4", "2"),
        ("1e3+1", "1001"),
        ("1.5e2", "150"),
        ("7/2", "3.5"),
        ("-5+2", "-3"),
        ("-(5+2)", "-7"),
        ("+7", "7"),
        ("10-(-3)", "13"),
        ("2*(3+4)-5", "9"),
        ("(1+2)*(3+4)", "21"),
        ("3-(-2)*(-4)", "-5"),
    ]);
}

#[test]
fn precedence_and_associativity() {
    // Q2：一元负号优先级低于幂运算
    table(&[
        ("-3^2", "-9"),
        ("(-3)^2", "9"),
        ("2^3^2", "512"),
        ("2^2^3", "256"),
        ("-2^2", "-4"),
        ("2^-1", "0.5"),
        ("2*3^2", "18"),
        ("(2*3)^2", "36"),
        ("1+2^3*2", "17"),
        ("100/2^2", "25"),
        ("-3^2+1", "-8"),
        ("2^-2", "0.25"),
    ]);
}

#[test]
fn implicit_multiplication() {
    table(&[
        ("2(3+4)", "14"),
        ("(1+2)(3+4)", "21"),
        ("2(3)(4)", "24"),
        ("3(2+1)^2", "27"),
        ("2(3+4)-1", "13"),
    ]);
    // 2π ≈ 6.283185307
    assert_close(approx("2π"), 6.283185307179586, 1e-12, "2π");
    assert_close(approx("2pi"), 6.283185307179586, 1e-12, "2pi");
    // 3sin(30) 视为 3*sin(30)
    assert_close(approx("3sin(30)"), 1.5, 1e-12, "3sin(30)");
}

#[test]
fn percent_semantics() {
    // Q4：a% == a/100，故 200*10% = 20
    table(&[
        ("50%", "0.5"),
        ("200*10%", "20"),
        ("200+10%", "200.1"),
        ("10%*10%", "0.01"),
        ("100-50%", "99.5"),
    ]);
}

#[test]
fn factorial_and_modulo() {
    table(&[
        ("0!", "1"),
        ("1!", "1"),
        ("5!", "120"),
        ("20!", "2432902008176640000"),
        ("7%3", "1"),
        ("7 mod 3", "1"),
        ("(-7)%3", "-1"),
        ("10 mod 4", "2"),
    ]);
    assert_eq!(num("21!").to_f64(), 51090942171709440000.0);
}

#[test]
fn precision_baseline_from_prd() {
    // PRD P0-31 五项基线
    assert_eq!(calc("20!"), "2432902008176640000");
    assert_eq!(calc("0.1+0.2"), "0.3");
    assert_eq!(calc("1/3*3"), "1");
    assert_close(approx("2^0.5"), 1.4142135623730951, 1e-15, "2^0.5");
    assert_close(
        calculator_core::units::convert(
            &Num::int(1),
            calculator_core::units::lookup_unit("inch").unwrap(),
            calculator_core::units::lookup_unit("mm").unwrap(),
        )
        .unwrap()
        .to_f64(),
        25.4,
        1e-9,
        "1 inch → mm",
    );
}

#[test]
fn exact_rational_beats_float_noise() {
    assert_eq!(calc("0.1+0.2"), "0.3");
    assert_eq!(calc("0.1*3"), "0.3");
    assert_eq!(calc("1/3*3"), "1");
    assert_eq!(calc("(1/7)*7"), "1");
    assert_eq!(calc("1/2+1/3"), "0.8333333333");
    assert_eq!(calc("2/4"), "0.5");
    assert_eq!(calc("6/3"), "2");
}

#[test]
fn grouping_setting() {
    let g = settings_grouped();
    assert_eq!(calc_with("1234567.89", &g), "1,234,567.89");
    assert_eq!(calc_with("1234567.89", &settings()), "1234567.89");
    assert_eq!(calc_with("20!", &g), "2,432,902,008,176,640,000");
}

#[test]
fn overflow_degrades_gracefully() {
    // i64 溢出 → 自动降级浮点，仍然给出数值而不是报错
    let v = approx("9223372036854775807+1");
    assert!(v.is_finite());
    assert!(v > 9.2e18);
}

#[test]
fn integer_literals_in_other_bases() {
    table(&[
        ("0xFF", "255"),
        ("0b1010", "10"),
        ("0o17", "15"),
        ("0xFF+1", "256"),
        ("0b1111*2", "30"),
    ]);
}

#[test]
fn fraction_mode_display() {
    let mut st = settings();
    st.format.fraction_mode = FractionMode::Improper;
    assert_eq!(calc_with("1/3+1/6", &st), "1/2");
    assert_eq!(calc_with("0.5", &st), "1/2");
    st.format.fraction_mode = FractionMode::Mixed;
    assert_eq!(calc_with("2.75", &st), "2 3/4");
    assert_eq!(calc_with("1/3+1/6", &st), "1/2");
    assert_eq!(calc_with("7", &st), "7");
}

#[test]
fn scientific_and_fixed_notation() {
    let mut st = settings();
    st.format.notation = Notation::Scientific;
    assert_eq!(calc_with("123456789", &st), "1.23456789×10⁸");
    st.format.notation = Notation::Fixed;
    st.format.precision_mode = PrecisionMode::DecimalPlaces;
    st.format.precision = 2;
    assert_eq!(calc_with("123456789", &st), "123456789");
    assert_eq!(calc_with("1/3", &st), "0.33");
}

#[test]
fn errors_on_division_by_zero() {
    assert_eq!(
        try_calc("1/0").unwrap_err().kind,
        calculator_core::error::ErrorKind::DivisionByZero
    );
    assert_eq!(
        try_calc("1/0.0").unwrap_err().kind,
        calculator_core::error::ErrorKind::DivisionByZero
    );
    assert_eq!(
        try_calc("1 mod 0").unwrap_err().kind,
        calculator_core::error::ErrorKind::DivisionByZero
    );
}

#[test]
fn format_settings_defaults_are_documented() {
    let d = NumberFormatSettings::default();
    assert_eq!(d.notation, Notation::Auto);
    assert_eq!(d.precision_mode, PrecisionMode::Significant);
    assert_eq!(d.precision, 10);
    assert_eq!(d.fraction_mode, FractionMode::Off);
    assert!(d.grouping);
}
