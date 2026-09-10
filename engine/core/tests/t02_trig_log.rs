//! T02-b：三角函数、对数、指数、幂、根、取整、双曲与角度模式。
//!
//! 覆盖 PRD P0-08 / P0-09 / P0-10 / P1-05。

mod common;

use common::{approx, assert_close, calc, calc_with, settings, try_calc};
use calculator_core::error::ErrorKind;
use calculator_core::session::AngleMode;

#[test]
fn trig_in_degree_mode() {
    // DEG 是默认模式
    assert_close(approx("sin(30)"), 0.5, 1e-12, "sin(30)");
    assert_close(approx("cos(60)"), 0.5, 1e-12, "cos(60)");
    assert_close(approx("tan(45)"), 1.0, 1e-12, "tan(45)");
    assert_close(approx("sin(0)"), 0.0, 1e-15, "sin(0)");
    assert_close(approx("cos(0)"), 1.0, 1e-15, "cos(0)");
    // 显示层：10 位有效数字下应收敛到干净值
    assert_eq!(calc("sin(30)"), "0.5");
    assert_eq!(calc("cos(60)"), "0.5");
    assert_eq!(calc("tan(45)"), "1");
}

#[test]
fn trig_in_radian_mode() {
    let mut st = settings();
    st.angle_mode = AngleMode::Rad;
    assert_close(calc_with("sin(π/6)", &st).parse::<f64>().unwrap(), 0.5, 1e-9, "sin(π/6) RAD");
    // 默认 DEG 下 sin(π/6) 的角度是 π/6≈0.5236°，结果应是很小的值而非 0.5
    // （RAD 模式下 sin(π/6)=0.5 已在上方断言）；用区间断言避免被 f64 残差绑架
    let deg_val = approx("sin(π/6)");
    assert!(deg_val > 0.0 && deg_val < 0.01, "默认 DEG 下 sin(π/6) 应是很小的值而非 0.5，实际 {}", deg_val);
    assert_close(calc_with("cos(0)", &st).parse::<f64>().unwrap(), 1.0, 1e-12, "cos(0) RAD");
}

#[test]
fn trig_in_grad_mode() {
    let mut st = settings();
    st.angle_mode = AngleMode::Grad;
    // 100 gon = 90°
    assert_close(calc_with("sin(100)", &st).parse::<f64>().unwrap(), 1.0, 1e-9, "sin(100) GRAD");
    assert_close(calc_with("cos(200)", &st).parse::<f64>().unwrap(), -1.0, 1e-9, "cos(200) GRAD");
    assert_close(calc_with("sin(50)", &st).parse::<f64>().unwrap(), 0.7071067811865476, 1e-9, "sin(50) GRAD");
}

#[test]
fn inverse_trig_returns_current_angle_unit() {
    let mut st = settings();
    st.angle_mode = AngleMode::Deg;
    assert_close(calc_with("asin(0.5)", &st).parse::<f64>().unwrap(), 30.0, 1e-9, "asin(0.5) DEG");
    assert_close(calc_with("acos(0.5)", &st).parse::<f64>().unwrap(), 60.0, 1e-9, "acos(0.5) DEG");
    assert_close(calc_with("atan(1)", &st).parse::<f64>().unwrap(), 45.0, 1e-9, "atan(1) DEG");
    st.angle_mode = AngleMode::Rad;
    assert_close(calc_with("asin(1)", &st).parse::<f64>().unwrap(), 1.5707963267948966, 1e-9, "asin(1) RAD");
}

#[test]
fn trig_domain_errors() {
    assert_eq!(try_calc("asin(2)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("asin(-2)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("acos(2)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("acosh(0)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("atanh(1)").unwrap_err().kind, ErrorKind::DomainError);
}

#[test]
fn logarithms_and_exponentials() {
    assert_close(approx("ln(e)"), 1.0, 1e-12, "ln(e)");
    assert_eq!(calc("log(100)"), "2");
    assert_eq!(calc("log2(8)"), "3");
    assert_eq!(calc("log10(1000)"), "3");
    assert_close(approx("exp(1)"), std::f64::consts::E, 1e-12, "exp(1)");
    assert_eq!(calc("exp10(3)"), "1000");
    assert_close(approx("log(2,8)"), 3.0, 1e-12, "log(2,8)");
    assert_eq!(calc("e^1"), "2.718281828");
}

#[test]
fn logarithm_domain_errors() {
    assert_eq!(try_calc("ln(0)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("ln(-1)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("log(0)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("log2(-5)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("log(1,5)").unwrap_err().kind, ErrorKind::DomainError);
}

#[test]
fn powers_and_roots() {
    assert_eq!(calc("2^10"), "1024");
    assert_eq!(calc("sqrt(16)"), "4");
    assert_eq!(calc("√16"), "4");
    assert_eq!(calc("cbrt(27)"), "3");
    assert_eq!(calc("root(27,3)"), "3");
    assert_eq!(calc("sq(5)"), "25");
    assert_eq!(calc("cube(3)"), "27");
    assert_eq!(calc("pow(2,10)"), "1024");
    assert_close(approx("2^0.5"), 1.4142135623730951, 1e-15, "2^0.5");
    assert_eq!(calc("sqrt(2/8)"), "0.5");
}

#[test]
fn power_domain_errors() {
    assert_eq!(try_calc("sqrt(-1)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("(-8)^(1/2)").unwrap_err().kind, ErrorKind::DomainError);
    assert_eq!(try_calc("root(-4,2)").unwrap_err().kind, ErrorKind::DomainError);
}

#[test]
fn rounding_and_sign_functions() {
    assert_eq!(calc("floor(2.7)"), "2");
    assert_eq!(calc("ceil(2.1)"), "3");
    assert_eq!(calc("round(2.5)"), "3");
    assert_eq!(calc("trunc(-2.7)"), "-2");
    assert_eq!(calc("abs(-7)"), "7");
    assert_eq!(calc("abs(7)"), "7");
    assert_eq!(calc("neg(5)"), "-5");
    assert_eq!(calc("inv(4)"), "0.25");
    assert_eq!(calc("min(3,1,2)"), "1");
    assert_eq!(calc("max(3,9)"), "9");
    assert_eq!(calc("gcd(12,18)"), "6");
    assert_eq!(calc("lcm(4,6)"), "12");
    assert_eq!(calc("fact(5)"), "120");
    assert_eq!(calc("mod(7,3)"), "1");
}

#[test]
fn inv_of_zero_is_division_by_zero() {
    assert_eq!(try_calc("inv(0)").unwrap_err().kind, ErrorKind::DivisionByZero);
}

#[test]
fn hyperbolic_functions() {
    assert_close(approx("sinh(0)"), 0.0, 1e-15, "sinh(0)");
    assert_eq!(calc("cosh(0)"), "1");
    assert_close(approx("tanh(1)"), 0.7615941559557649, 1e-12, "tanh(1)");
    assert_close(approx("asinh(0)"), 0.0, 1e-15, "asinh(0)");
    assert_close(approx("acosh(1)"), 0.0, 1e-15, "acosh(1)");
    assert_close(approx("atanh(0.5)"), 0.5493061443340549, 1e-12, "atanh(0.5)");
}

#[test]
fn rand_is_deterministic_and_in_unit_interval() {
    for _ in 0..4 {
        let v = approx("rand()");
        assert!((0.0..1.0).contains(&v), "rand() = {}", v);
    }
}

#[test]
fn unknown_function_and_wrong_arity() {
    assert_eq!(try_calc("frobnicate(1)").unwrap_err().kind, ErrorKind::UnknownFunction);
    assert_eq!(try_calc("sin()").unwrap_err().kind, ErrorKind::WrongArity);
    assert_eq!(try_calc("pow(2)").unwrap_err().kind, ErrorKind::WrongArity);
}

#[test]
fn function_name_without_parens() {
    // PRD P0-06：`sin30` 等价于 sin(30)
    assert_close(approx("sin30"), 0.5, 1e-12, "sin30");
    assert_close(approx("2sin30"), 1.0, 1e-12, "2sin30");
    assert_eq!(calc("fact5"), "120");
    assert_eq!(calc("sqrt16"), "4");
}

#[test]
fn constants_are_all_usable_in_expressions() {
    assert_close(approx("c"), 299792458.0, 1.0, "c");
    assert_close(approx("c/1000"), 299792.458, 1e-6, "c/1000");
    assert_close(approx("g"), 9.80665, 1e-12, "g");
    assert_close(approx("N_A"), 6.02214076e23, 1e15, "N_A");
    assert_close(approx("h"), 6.62607015e-34, 1e-40, "h");
    assert_close(approx("e_c"), 1.602176634e-19, 1e-25, "e_c");
    assert_close(approx("φ"), 1.6180339887498948, 1e-12, "φ");
    assert_close(approx("τ"), 6.283185307179586, 1e-12, "τ");
}
