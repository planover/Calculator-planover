//! 集成测试的公共工具。
//!
//! 刻意放在 `common/mod.rs`（而不是 `common.rs`），这样 cargo 不会把它当作
//! 一个独立的测试目标去编译执行。

#![allow(dead_code)]

use calculator_core::engine::Engine;
use calculator_core::error::EngineError;
use calculator_core::eval::eval_simple;
use calculator_core::format;
use calculator_core::num::Num;
use calculator_core::session::{AngleMode, EngineSettings, Session};
use calculator_core::units;

/// 测试基线设置：**关闭千位分隔**，避免断言里到处写逗号。
pub fn settings() -> EngineSettings {
    EngineSettings {
        angle_mode: AngleMode::Deg,
        word_size: 64,
        format: format::NumberFormatSettings {
            notation: format::Notation::Auto,
            precision_mode: format::PrecisionMode::Significant,
            precision: 10,
            fraction_mode: format::FractionMode::Off,
            grouping: false,
        },
    }
}

/// 带千位分隔的设置（专供分组测试使用）。
pub fn settings_grouped() -> EngineSettings {
    let mut s = settings();
    s.format.grouping = true;
    s
}

/// 求值并格式化，失败直接 panic（用于"必须算对"的正向断言）。
pub fn calc(src: &str) -> String {
    let st = settings();
    eval_simple(src, &st)
        .and_then(|n| format::format_number(&n, &st.format))
        .unwrap_or_else(|e| panic!("表达式 “{}” 求值失败：{:?}", src, e))
}

/// 用指定设置求值并格式化。
pub fn calc_with(src: &str, st: &EngineSettings) -> String {
    eval_simple(src, st)
        .and_then(|n| format::format_number(&n, &st.format))
        .unwrap_or_else(|e| panic!("表达式 “{}” 求值失败：{:?}", src, e))
}

/// 求值但不格式化，返回 [`Num`]。
pub fn num(src: &str) -> Num {
    eval_simple(src, &settings())
        .unwrap_or_else(|e| panic!("表达式 “{}” 求值失败：{:?}", src, e))
}

/// 求值取 f64，用于带容差的比较。
pub fn approx(src: &str) -> f64 {
    num(src).to_f64()
}

/// 求值但允许失败，返回错误。
pub fn try_calc(src: &str) -> Result<Num, EngineError> {
    eval_simple(src, &settings())
}

/// 断言 f64 在 `tol` 容差内相等。
pub fn assert_close(actual: f64, expected: f64, tol: f64, what: &str) {
    assert!(
        (actual - expected).abs() <= tol,
        "{}：期望 {}，实际 {}（差 {}）",
        what,
        expected,
        actual,
        (actual - expected).abs()
    );
}

/// 新建引擎。
pub fn engine() -> Engine {
    Engine::new()
}

/// 新建会话。
pub fn session() -> Session {
    Session::new()
}

/// 单位换算便捷封装：返回输出值的 f64。
pub fn convert(value: &str, from: &str, to: &str) -> f64 {
    let v = calculator_core::lexer::parse_number_literal(value).unwrap();
    let f = units::lookup_unit(from).unwrap_or_else(|| panic!("未知单位 {}", from));
    let t = units::lookup_unit(to).unwrap_or_else(|| panic!("未知单位 {}", to));
    units::convert(&v, f, t).unwrap().to_f64()
}
