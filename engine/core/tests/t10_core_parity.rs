//! T10：U5 引擎核心对齐（`docs/PRD-INCREMENT-v2.md` §13）。
//!
//! 覆盖 **CP-01~CP-15** 中可本机 `cargo test` 真实验证的 `[R]` 断言，
//! 外加：
//! - **Turns 角度**（§3 UI-22，原版有的第 4 种角度单位）；
//! - **CP-19 的可验证部分**：输入 `i` 返回明确的 `UndefinedVariable`。
//!
//! 纯 `[D]` / `[M]` 的界面项（CP-06/07/16/17）不在本文件的验证范围内。

mod common;

use common::{assert_close, settings};
use calculator_core::api::dispatch;
use calculator_core::engine::Engine;
use calculator_core::error::ErrorKind;
use calculator_core::eval::eval_simple;
use calculator_core::format::{self, Notation, PrecisionMode};
use calculator_core::num::Num;
use calculator_core::session::{AngleMode, EngineSettings};
use serde_json::Value;

// ── 工具 ────────────────────────────────────────────────────

/// 在基线设置上换角度模式。
fn st_angle(m: AngleMode) -> EngineSettings {
    let mut s = settings();
    s.angle_mode = m;
    s
}

/// 用给定设置求值，取 f64（失败即 panic）。
fn f(src: &str, st: &EngineSettings) -> f64 {
    eval_simple(src, st)
        .unwrap_or_else(|e| panic!("表达式 “{}” 求值失败：{:?}", src, e))
        .to_f64()
}

/// 用给定设置求值，断言失败并返回错误分类。
fn f_err(src: &str, st: &EngineSettings) -> ErrorKind {
    match eval_simple(src, st) {
        Ok(v) => panic!("表达式 “{}” 本应失败，却得到 {:?}", src, v),
        Err(e) => e.kind,
    }
}

/// 工程记数法设置。
fn eng_settings(precision: u8, grouping: bool) -> EngineSettings {
    let mut s = settings();
    s.format.notation = Notation::Engineering;
    s.format.precision_mode = PrecisionMode::Significant;
    s.format.precision = precision;
    s.format.grouping = grouping;
    s
}

/// 求值 + 按设置格式化。
fn eng(src: &str, st: &EngineSettings) -> String {
    let n = eval_simple(src, st).unwrap_or_else(|e| panic!("表达式 “{}” 求值失败：{:?}", src, e));
    format::format_number(&n, &st.format).unwrap()
}

/// 从 `…×10ᴱ` 里解析出上标指数（无 `×10` 视为 0）。
fn superscript_exp(s: &str) -> i32 {
    let idx = match s.find("×10") {
        Some(i) => i + "×10".len(),
        None => return 0,
    };
    let mut neg = false;
    let mut val: i64 = 0;
    let mut any = false;
    for c in s[idx..].chars() {
        let d = match c {
            '⁻' => {
                neg = true;
                continue;
            }
            '⁰' => 0,
            '¹' => 1,
            '²' => 2,
            '³' => 3,
            '⁴' => 4,
            '⁵' => 5,
            '⁶' => 6,
            '⁷' => 7,
            '⁸' => 8,
            '⁹' => 9,
            _ => break,
        };
        val = val * 10 + d;
        any = true;
    }
    if !any {
        return 0;
    }
    if neg {
        -(val as i32)
    } else {
        val as i32
    }
}

/// 调 dispatch 并解析 JSON（必须是合法 JSON）。
fn call(e: &mut Engine, method: &str, json: &str) -> Value {
    let out = dispatch(method, json, e);
    serde_json::from_str(&out).expect("dispatch 必须返回合法 JSON")
}

// ── §13.1 记忆寄存器（CP-01~CP-05）────────────────────────────

#[test]
fn memory_dispatch_contract() {
    let mut e = Engine::new();

    // 初值为 0（CP-01）
    let r = call(&mut e, "memory_recall", "{}");
    assert_eq!(r["ok"], true);
    assert_eq!(r["data"]["is_zero"], true);
    assert_eq!(r["data"]["text"], "0");
    assert_eq!(r["data"]["value"]["num"], 0);

    // M+ 5 → 5（CP-02）
    let r = call(&mut e, "memory_add", r#"{"value":"5"}"#);
    assert_eq!(r["data"]["is_zero"], false);
    assert_eq!(r["data"]["value"]["num"], 5);
    assert_eq!(r["data"]["text"], "5");

    // M+ 5（结果仍 5）→ 10（CP-02）
    let r = call(&mut e, "memory_add", r#"{"value":"5"}"#);
    assert_eq!(r["data"]["value"]["num"], 10);

    // M- 5 → 5（CP-03）
    let r = call(&mut e, "memory_sub", r#"{"value":"5"}"#);
    assert_eq!(r["data"]["value"]["num"], 5);

    // 别名 memory_subtract 语义一致（CP-01 契约里两个名字都暴露）
    let r = call(&mut e, "memory_subtract", r#"{"value":"5"}"#);
    assert_eq!(r["data"]["value"]["num"], 0);

    // 允许负值：再减 5 → -5（CP-03）
    let r = call(&mut e, "memory_sub", r#"{"value":"5"}"#);
    assert_eq!(r["data"]["value"]["num"], -5);
    assert_eq!(r["data"]["text"], "(-5)");

    // MC → 0，幂等（CP-04）
    let r = call(&mut e, "memory_clear", "{}");
    assert_eq!(r["data"]["is_zero"], true);
    assert_eq!(r["data"]["value"]["num"], 0);
    // 再 MC 一次（对已为 0 执行无副作用）
    let r = call(&mut e, "memory_clear", "{}");
    assert_eq!(r["data"]["value"]["num"], 0);
}

#[test]
fn memory_independent_of_ans_via_dispatch() {
    let mut e = Engine::new();
    // ans = 5
    dispatch("evaluate_commit", r#"{"expr":"5"}"#, &mut e);
    // 把“当前结果”用 ans 作为表达式喂给 M+
    dispatch("memory_add", r#"{"value":"ans"}"#, &mut e);

    // M+ 不改 ans
    let a = call(&mut e, "evaluate_preview", r#"{"expr":"ans"}"#);
    assert_eq!(a["data"]["display"], "5");
    let m = call(&mut e, "memory_recall", "{}");
    assert_eq!(m["data"]["value"]["num"], 5);

    // 改 ans 不改 memory
    dispatch("evaluate_commit", r#"{"expr":"99"}"#, &mut e);
    let a2 = call(&mut e, "evaluate_preview", r#"{"expr":"ans"}"#);
    assert_eq!(a2["data"]["display"], "99");
    let m2 = call(&mut e, "memory_recall", "{}");
    assert_eq!(m2["data"]["value"]["num"], 5);
}

#[test]
fn memory_cleared_by_reset_session() {
    let mut e = Engine::new();
    dispatch("memory_add", r#"{"value":"8"}"#, &mut e);
    assert_eq!(call(&mut e, "memory_recall", "{}")["data"]["is_zero"], false);
    // Q13-1：memory 随 reset_session 清零
    dispatch("reset_session", r#"{"keep_ans":true}"#, &mut e);
    let m = call(&mut e, "memory_recall", "{}");
    assert_eq!(m["data"]["is_zero"], true);
    assert_eq!(m["data"]["value"]["num"], 0);
}

#[test]
fn mr_inserts_recall_text_at_cursor() {
    // memory == 5（CP-05）
    let mut e = Engine::new();
    dispatch("memory_add", r#"{"value":"5"}"#, &mut e);
    let text = call(&mut e, "memory_recall", "{}")["data"]["text"]
        .as_str()
        .unwrap()
        .to_string();
    assert_eq!(text, "5");

    // 表达式 "2+"、光标在末尾(index 2) → "2+5"，光标 index 3
    let out = dispatch(
        "apply_edit",
        &format!(
            r#"{{"text":"2+","cursor":2,"action":"insert","payload":"{}"}}"#,
            text
        ),
        &mut e,
    );
    let v: Value = serde_json::from_str(&out).unwrap();
    assert_eq!(v["data"]["text"], "2+5");
    assert_eq!(v["data"]["cursor"], 3);

    // 光标在 "2+" 的 index 1 → "25+"，光标 index 2
    let out2 = dispatch(
        "apply_edit",
        &format!(
            r#"{{"text":"2+","cursor":1,"action":"insert","payload":"{}"}}"#,
            text
        ),
        &mut e,
    );
    let v2: Value = serde_json::from_str(&out2).unwrap();
    assert_eq!(v2["data"]["text"], "25+");
    assert_eq!(v2["data"]["cursor"], 2);

    // memory == 0 → 插入 "0"（不插空串）
    let mut e0 = Engine::new();
    let m0 = call(&mut e0, "memory_recall", "{}");
    assert_eq!(m0["data"]["text"], "0");

    // 负值 → "(-5)"（保证语法正确）
    let mut eneg = Engine::new();
    dispatch("memory_sub", r#"{"value":"5"}"#, &mut eneg);
    let mn = call(&mut eneg, "memory_recall", "{}");
    assert_eq!(mn["data"]["text"], "(-5)");
}

// ── §13.2 Engineering 记数法（CP-08、CP-09）──────────────────

#[test]
fn engineering_notation_is_a_valid_option() {
    assert_eq!(Notation::from_id("engineering"), Some(Notation::Engineering));
    assert_eq!(Notation::from_id("eng"), Some(Notation::Engineering));
    assert_eq!(Notation::Engineering.id(), "engineering");
}

#[test]
fn engineering_notation_examples() {
    let st = eng_settings(10, false);
    // CP-08 已裁决样例
    assert_eq!(eng("1234.5", &st), "1.2345×10³");
    assert_eq!(eng("0.0123", &st), "12.3×10⁻³");
    assert_eq!(eng("12345678901", &st), "12.345678901×10⁹");
    // 指数对齐到 3 的倍数：0 → 省略 ×10⁰
    assert_eq!(eng("1", &st), "1");
    assert_eq!(eng("1000", &st), "1×10³");
    assert_eq!(eng("0.001", &st), "1×10⁻³");
    // 负值
    assert_eq!(eng("-1234.5", &st), "-1.2345×10³");
}

#[test]
fn engineering_respects_significant_precision() {
    // CP-09：与有效位数协同
    assert_eq!(eng("1/3", &eng_settings(10, false)), "333.3333333×10⁻³");
    assert_eq!(eng("1/3", &eng_settings(5, false)), "333.33×10⁻³");
}

#[test]
fn engineering_grouping_is_noop_on_mantissa() {
    // 工程记数法尾数的整数部分恒 ≤ 3 位（指数对齐 3 的倍数），
    // 故千位分隔对其无影响；两种设置必须得到同一结果（CP-09 协同，不破坏）。
    let a = eng("12345678901", &eng_settings(10, false));
    let b = eng("12345678901", &eng_settings(10, true));
    assert_eq!(a, b);
    assert_eq!(b, "12.345678901×10⁹");
}

#[test]
fn engineering_exponent_is_multiple_of_three() {
    // CP-08 属性测试：随机 1000 个数值，指数必须为 3 的倍数。
    let st = eng_settings(10, false);
    let mut seed: u64 = 0x9E37_79B9_7F4A_7C15;
    for _ in 0..1000 {
        seed = seed
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        let mant = ((seed >> 11) % 1_000_000_000) as f64 + 1.0;
        let scale = (seed % 13) as i32 - 6; // -6..=6
        let v = mant * 10f64.powi(scale);

        let s = format::format_number(&Num::float(v), &st.format).unwrap();
        assert_eq!(
            superscript_exp(&s) % 3,
            0,
            "v={:e} → {} （指数不是 3 的倍数）",
            v,
            s
        );

        let sn = format::format_number(&Num::float(-v), &st.format).unwrap();
        assert_eq!(superscript_exp(&sn) % 3, 0, "v=-{:e} → {}", v, sn);
    }
}

// ── §3 UI-22 Turns 角度 ─────────────────────────────────────

#[test]
fn angle_mode_turns() {
    assert_eq!(AngleMode::from_id("turns"), Some(AngleMode::Turns));
    assert_eq!(AngleMode::from_id("turn"), Some(AngleMode::Turns));
    assert_eq!(AngleMode::Turns.id(), "turns");

    let st = st_angle(AngleMode::Turns);
    // 1 turn = 2π rad：0.25 turn = 90°，0.5 turn = 180°
    assert_close(f("sin(0.25)", &st), 1.0, 1e-9, "sin(0.25 turn)");
    assert_close(f("cos(0.5)", &st), -1.0, 1e-9, "cos(0.5 turn)");
    assert_close(f("sin(0)", &st), 0.0, 1e-12, "sin(0 turn)");
}

// ── §13.3 函数补全（CP-10~CP-15）────────────────────────────

#[test]
fn cp10_cot() {
    let rad = st_angle(AngleMode::Rad);
    let deg = st_angle(AngleMode::Deg);
    assert_close(f("cot(π/4)", &rad), 1.0, 1e-12, "cot(π/4)");
    assert_close(f("cot(45)", &deg), 1.0, 1e-12, "cot(45) DEG");
    // Q13-2：极点返回 DomainError
    assert_eq!(f_err("cot(0)", &deg), ErrorKind::DomainError);
    assert_close(f("cot(π/2)", &rad), 0.0, 1e-9, "cot(π/2)");
}

#[test]
fn cp11_acot() {
    let rad = st_angle(AngleMode::Rad);
    let deg = st_angle(AngleMode::Deg);
    // Q13-3：acot(x) = π/2 − atan(x)，值域 (0, π)
    assert_close(f("acot(0)", &rad), std::f64::consts::FRAC_PI_2, 1e-12, "acot(0)");
    assert_close(f("acot(1)", &rad), std::f64::consts::FRAC_PI_4, 1e-12, "acot(1)");
    assert_close(
        f("acot(-1)", &rad),
        3.0 * std::f64::consts::FRAC_PI_4,
        1e-12,
        "acot(-1)",
    );
    for x in [-100.0_f64, -1.0, 0.0, 1.0, 100.0] {
        let v = f(&format!("acot({})", x), &rad);
        assert!(
            v > 0.0 && v < std::f64::consts::PI,
            "acot({}) 值域越界：{}",
            x,
            v
        );
    }
    // 按当前角度单位换算
    assert_close(f("acot(0)", &deg), 90.0, 1e-9, "acot(0) DEG");
}

#[test]
fn cp12_coth() {
    let deg = st_angle(AngleMode::Deg);
    assert_close(f("coth(1)", &deg), 1.3130352854993315, 1e-9, "coth(1)");
    assert_eq!(f_err("coth(0)", &deg), ErrorKind::DomainError);
    // 大参数不溢出、不返回 NaN
    assert_close(f("coth(100)", &deg), 1.0, 1e-9, "coth(100)");
}

#[test]
fn cp13_acoth() {
    let deg = st_angle(AngleMode::Deg);
    assert_close(f("acoth(2)", &deg), 0.5493061443340549, 1e-9, "acoth(2)");
    // 定义域 |x| > 1
    assert_eq!(f_err("acoth(1)", &deg), ErrorKind::DomainError);
    assert_eq!(f_err("acoth(0.5)", &deg), ErrorKind::DomainError);
    assert_close(f("acoth(-2)", &deg), -0.5493061443340549, 1e-9, "acoth(-2)");
}

#[test]
fn cp14_sgn() {
    let deg = st_angle(AngleMode::Deg);
    assert_close(f("sgn(-3)", &deg), -1.0, 0.0, "sgn(-3)");
    // Q13-4：sgn(0) = 0
    assert_close(f("sgn(0)", &deg), 0.0, 0.0, "sgn(0)");
    assert_close(f("sgn(3)", &deg), 1.0, 0.0, "sgn(3)");
    assert_close(f("sgn(-0.0001)", &deg), -1.0, 0.0, "sgn(-0.0001)");
    assert_close(f("sgn(π)", &deg), 1.0, 0.0, "sgn(π)");
    // 值域断言
    for x in [-5.0_f64, -0.5, 0.0, 0.5, 42.0] {
        let v = f(&format!("sgn({})", x), &deg);
        assert!(v == -1.0 || v == 0.0 || v == 1.0, "sgn({}) = {} 越界", x, v);
    }
}

#[test]
fn cp15_frac() {
    let deg = st_angle(AngleMode::Deg);
    assert_close(f("frac(3.25)", &deg), 0.25, 1e-12, "frac(3.25)");
    // Q13-5：frac(-3.25) = -0.25（保留符号，不是 +0.75）
    assert_close(f("frac(-3.25)", &deg), -0.25, 1e-12, "frac(-3.25)");
    assert_close(f("frac(2)", &deg), 0.0, 1e-12, "frac(2)");
    assert_close(f("frac(-0.5)", &deg), -0.5, 1e-12, "frac(-0.5)");
    // 不变式：x == trunc(x) + frac(x)，且 |frac(x)| < 1
    for x in [3.25_f64, -3.25, 2.0, -0.5, 7.9, -7.9, 0.0] {
        let v = f(&format!("frac({})", x), &deg);
        assert_close(x.trunc() + v, x, 1e-9, "x == trunc + frac");
        assert!(v.abs() < 1.0, "|frac({})| = {} 不小于 1", x, v.abs());
    }
}

// ── CP-19 可验证部分：复数单位 `i` 不可用 ───────────────────

#[test]
fn imaginary_unit_is_undefined_variable() {
    let rad = st_angle(AngleMode::Rad);
    assert_eq!(f_err("i", &rad), ErrorKind::UndefinedVariable);
}
