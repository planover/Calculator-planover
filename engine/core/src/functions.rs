//! 函数表。
//!
//! 约定：
//! - 所有函数都是**纯函数**（`rand` 除外，它用确定性 PRNG，见下）。
//! - 三角函数入参按当前 [`AngleMode`] 从角度值换算到弧度；反三角函数返回值
//!   再换算回当前角度单位（DEG 下 `asin(0.5) = 30`）。
//! - 定义域外一律返回 [`ErrorKind::DomainError`]。

use std::sync::atomic::{AtomicU64, Ordering};

use crate::error::{EngineError, ErrorKind, Result};
use crate::eval::EvalContext;
use crate::num::Num;
use crate::session::AngleMode;

/// 参数个数约束。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Arity {
    /// 固定个数。
    Fixed(u8),
    /// 闭区间个数，如 `log(b, x)` 允许 1~2 个。
    Range(u8, u8),
}

impl Arity {
    /// 校验实参个数。
    pub fn accepts(&self, n: usize) -> bool {
        match self {
            Arity::Fixed(k) => n == *k as usize,
            Arity::Range(lo, hi) => n >= *lo as usize && n <= *hi as usize,
        }
    }

    /// 人类可读描述，用于 `WrongArity` 文案。
    pub fn describe(&self) -> String {
        match self {
            Arity::Fixed(k) => format!("{} 个", k),
            Arity::Range(lo, hi) => format!("{}~{} 个", lo, hi),
        }
    }
}

/// 函数分类（键盘分栏用）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FuncCategory {
    /// 三角。
    Trig,
    /// 对数 / 指数。
    Log,
    /// 幂 / 根。
    Power,
    /// 取整。
    Rounding,
    /// 位运算。
    Bits,
    /// 统计 / 数论。
    Stats,
    /// 常量与其它。
    Misc,
}

impl FuncCategory {
    /// 稳定标识，写入 JSON。
    pub fn id(&self) -> &'static str {
        match self {
            FuncCategory::Trig => "trig",
            FuncCategory::Log => "log",
            FuncCategory::Power => "power",
            FuncCategory::Rounding => "rounding",
            FuncCategory::Bits => "bits",
            FuncCategory::Stats => "stats",
            FuncCategory::Misc => "misc",
        }
    }
}

/// 一个函数定义。
pub struct FunctionDef {
    /// 规范名（小写）。
    pub name: &'static str,
    /// 参数个数。
    pub arity: Arity,
    /// 分类。
    pub category: FuncCategory,
    /// 键盘插入模板，光标停在末尾。
    pub insert_template: &'static str,
    /// 别名（如 `arctan`、`lg`）。
    pub aliases: &'static [&'static str],
    /// 实现。
    pub eval: fn(&[Num], &EvalContext) -> Result<Num>,
}

// ── 实现函数 ────────────────────────────────────────────────

/// 该 PRNG 状态。`rand()` 刻意**不读系统时间**（架构 §1.2 要求领域层不依赖时间），
/// 而是用确定性 xorshift；同一进程内序列不同、跨进程可复现，便于测试。
static RAND_STATE: AtomicU64 = AtomicU64::new(0x2545F4914F6CDD1D);

fn next_random() -> f64 {
    let mut s = RAND_STATE.load(Ordering::Relaxed);
    s ^= s << 13;
    s ^= s >> 7;
    s ^= s << 17;
    RAND_STATE.store(s, Ordering::Relaxed);
    ((s >> 11) as f64) / ((1u64 << 53) as f64)
}

fn domain_err(what: &str) -> EngineError {
    EngineError::with_message(ErrorKind::DomainError, format!("{} 超出定义域", what))
}

fn need(args: &[Num], i: usize) -> f64 {
    args[i].to_f64()
}

fn f_sin(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(
        ctx.session.settings.angle_mode.to_radians(need(args, 0)).sin(),
    ))
}

fn f_cos(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(
        ctx.session.settings.angle_mode.to_radians(need(args, 0)).cos(),
    ))
}

fn f_tan(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(
        ctx.session.settings.angle_mode.to_radians(need(args, 0)).tan(),
    ))
}

fn f_asin(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if !(-1.0..=1.0).contains(&x) {
        return Err(domain_err("asin"));
    }
    Ok(Num::float(
        ctx.session.settings.angle_mode.from_radians(x.asin()),
    ))
}

fn f_acos(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if !(-1.0..=1.0).contains(&x) {
        return Err(domain_err("acos"));
    }
    Ok(Num::float(
        ctx.session.settings.angle_mode.from_radians(x.acos()),
    ))
}

fn f_atan(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(
        ctx.session
            .settings
            .angle_mode
            .from_radians(need(args, 0).atan()),
    ))
}

fn f_ln(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if x <= 0.0 {
        return Err(domain_err("ln"));
    }
    Ok(Num::float(x.ln()))
}

/// `log(x)` = 常用对数；`log(b, x)` = 以 b 为底。
fn f_log(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, args.len() - 1);
    if x <= 0.0 {
        return Err(domain_err("log"));
    }
    if args.len() == 2 {
        let b = need(args, 0);
        if b <= 0.0 || b == 1.0 {
            return Err(domain_err("log 的底数"));
        }
        Ok(Num::float(x.ln() / b.ln()))
    } else {
        Ok(Num::float(x.log10()))
    }
}

fn f_log2(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if x <= 0.0 {
        return Err(domain_err("log2"));
    }
    Ok(Num::float(x.log2()))
}

fn f_log10(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if x <= 0.0 {
        return Err(domain_err("log10"));
    }
    Ok(Num::float(x.log10()))
}

fn f_exp(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).exp()))
}

fn f_exp10(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(10f64.powf(need(args, 0))))
}

fn f_pow(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].pow(&args[1])
}

fn f_sqrt(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].sqrt()
}

fn f_cbrt(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(args[0].cbrt())
}

/// `root(x, n)` = x 的 n 次根。
fn f_root(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    let n = need(args, 1);
    if n == 0.0 {
        return Err(domain_err("root 的次数"));
    }
    if x < 0.0 && n.rem_euclid(2.0) == 0.0 {
        return Err(domain_err("root"));
    }
    if x < 0.0 {
        Ok(Num::float(-((-x).powf(1.0 / n))))
    } else {
        Ok(Num::float(x.powf(1.0 / n)))
    }
}

fn f_sq(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].pow(&Num::int(2))
}

fn f_cube(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].pow(&Num::int(3))
}

fn f_abs(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(args[0].abs())
}

fn f_neg(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(args[0].neg())
}

fn f_inv(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    // 倒数：1 / x（注意顺序，写成 x/1 会退化成恒等变换）
    Num::one().div(&args[0])
}

fn f_fact(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].factorial()
}

fn f_mod(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    args[0].rem(&args[1])
}

fn f_min(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let mut best = args[0];
    for a in &args[1..] {
        if a < &best {
            best = *a;
        }
    }
    Ok(best)
}

fn f_max(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let mut best = args[0];
    for a in &args[1..] {
        if a > &best {
            best = *a;
        }
    }
    Ok(best)
}

fn f_floor(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).floor()))
}

fn f_ceil(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).ceil()))
}

fn f_round(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).round()))
}

fn f_trunc(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).trunc()))
}

fn f_gcd(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let mut a = args[0].try_as_i64()?.unsigned_abs();
    let mut b = args[1].try_as_i64()?.unsigned_abs();
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    Ok(Num::int(a as i64))
}

fn f_lcm(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let a = args[0].try_as_i64()?.unsigned_abs();
    let b = args[1].try_as_i64()?.unsigned_abs();
    if a == 0 || b == 0 {
        return Ok(Num::int(0));
    }
    let g = {
        let (mut x, mut y) = (a, b);
        while y != 0 {
            let t = x % y;
            x = y;
            y = t;
        }
        x
    };
    Ok(Num::int((a / g * b) as i64))
}

fn f_and(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::bitwise(
        crate::base::BitOp::And,
        args[0].try_as_i64()?,
        args[1].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_or(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::bitwise(
        crate::base::BitOp::Or,
        args[0].try_as_i64()?,
        args[1].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_xor(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::bitwise(
        crate::base::BitOp::Xor,
        args[0].try_as_i64()?,
        args[1].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_not(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::mask_to_width(
        !args[0].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_shl(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::bitwise(
        crate::base::BitOp::Shl,
        args[0].try_as_i64()?,
        args[1].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_shr(args: &[Num], ctx: &EvalContext) -> Result<Num> {
    Ok(Num::int(crate::base::bitwise(
        crate::base::BitOp::Shr,
        args[0].try_as_i64()?,
        args[1].try_as_i64()?,
        ctx.session.settings.word_size,
    )))
}

fn f_sinh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).sinh()))
}

fn f_cosh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).cosh()))
}

fn f_tanh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).tanh()))
}

fn f_asinh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(need(args, 0).asinh()))
}

fn f_acosh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if x < 1.0 {
        return Err(domain_err("acosh"));
    }
    Ok(Num::float(x.acosh()))
}

fn f_atanh(args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    let x = need(args, 0);
    if x <= -1.0 || x >= 1.0 {
        return Err(domain_err("atanh"));
    }
    Ok(Num::float(x.atanh()))
}

fn f_rand(_args: &[Num], _ctx: &EvalContext) -> Result<Num> {
    Ok(Num::float(next_random()))
}

// ── 表 ─────────────────────────────────────────────────────

/// 全部函数。
pub static FUNCTIONS: &[FunctionDef] = &[
    // 三角
    FunctionDef { name: "sin", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "sin(", aliases: &[], eval: f_sin },
    FunctionDef { name: "cos", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "cos(", aliases: &[], eval: f_cos },
    FunctionDef { name: "tan", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "tan(", aliases: &[], eval: f_tan },
    FunctionDef { name: "asin", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "asin(", aliases: &["arcsin"], eval: f_asin },
    FunctionDef { name: "acos", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "acos(", aliases: &["arccos"], eval: f_acos },
    FunctionDef { name: "atan", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "atan(", aliases: &["arctan"], eval: f_atan },
    // 双曲
    FunctionDef { name: "sinh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "sinh(", aliases: &[], eval: f_sinh },
    FunctionDef { name: "cosh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "cosh(", aliases: &[], eval: f_cosh },
    FunctionDef { name: "tanh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "tanh(", aliases: &[], eval: f_tanh },
    FunctionDef { name: "asinh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "asinh(", aliases: &[], eval: f_asinh },
    FunctionDef { name: "acosh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "acosh(", aliases: &[], eval: f_acosh },
    FunctionDef { name: "atanh", arity: Arity::Fixed(1), category: FuncCategory::Trig, insert_template: "atanh(", aliases: &[], eval: f_atanh },
    // 对数 / 指数
    FunctionDef { name: "ln", arity: Arity::Fixed(1), category: FuncCategory::Log, insert_template: "ln(", aliases: &[], eval: f_ln },
    FunctionDef { name: "log", arity: Arity::Range(1, 2), category: FuncCategory::Log, insert_template: "log(", aliases: &["lg"], eval: f_log },
    FunctionDef { name: "log2", arity: Arity::Fixed(1), category: FuncCategory::Log, insert_template: "log2(", aliases: &[], eval: f_log2 },
    FunctionDef { name: "log10", arity: Arity::Fixed(1), category: FuncCategory::Log, insert_template: "log10(", aliases: &[], eval: f_log10 },
    FunctionDef { name: "exp", arity: Arity::Fixed(1), category: FuncCategory::Log, insert_template: "exp(", aliases: &[], eval: f_exp },
    FunctionDef { name: "exp10", arity: Arity::Fixed(1), category: FuncCategory::Log, insert_template: "exp10(", aliases: &[], eval: f_exp10 },
    // 幂 / 根
    FunctionDef { name: "pow", arity: Arity::Fixed(2), category: FuncCategory::Power, insert_template: "pow(,)", aliases: &[], eval: f_pow },
    FunctionDef { name: "sqrt", arity: Arity::Fixed(1), category: FuncCategory::Power, insert_template: "sqrt(", aliases: &["√"], eval: f_sqrt },
    FunctionDef { name: "cbrt", arity: Arity::Fixed(1), category: FuncCategory::Power, insert_template: "cbrt(", aliases: &[], eval: f_cbrt },
    FunctionDef { name: "root", arity: Arity::Fixed(2), category: FuncCategory::Power, insert_template: "root(,)", aliases: &[], eval: f_root },
    FunctionDef { name: "sq", arity: Arity::Fixed(1), category: FuncCategory::Power, insert_template: "sq(", aliases: &[], eval: f_sq },
    FunctionDef { name: "cube", arity: Arity::Fixed(1), category: FuncCategory::Power, insert_template: "cube(", aliases: &[], eval: f_cube },
    // 符号 / 倒数
    FunctionDef { name: "abs", arity: Arity::Fixed(1), category: FuncCategory::Misc, insert_template: "abs(", aliases: &[], eval: f_abs },
    FunctionDef { name: "neg", arity: Arity::Fixed(1), category: FuncCategory::Misc, insert_template: "neg(", aliases: &[], eval: f_neg },
    FunctionDef { name: "inv", arity: Arity::Fixed(1), category: FuncCategory::Misc, insert_template: "inv(", aliases: &[], eval: f_inv },
    // 数论 / 统计
    FunctionDef { name: "fact", arity: Arity::Fixed(1), category: FuncCategory::Stats, insert_template: "fact(", aliases: &[], eval: f_fact },
    FunctionDef { name: "mod", arity: Arity::Fixed(2), category: FuncCategory::Stats, insert_template: "mod(,)", aliases: &[], eval: f_mod },
    FunctionDef { name: "min", arity: Arity::Range(2, 8), category: FuncCategory::Stats, insert_template: "min(,)", aliases: &[], eval: f_min },
    FunctionDef { name: "max", arity: Arity::Range(2, 8), category: FuncCategory::Stats, insert_template: "max(,)", aliases: &[], eval: f_max },
    FunctionDef { name: "gcd", arity: Arity::Fixed(2), category: FuncCategory::Stats, insert_template: "gcd(,)", aliases: &[], eval: f_gcd },
    FunctionDef { name: "lcm", arity: Arity::Fixed(2), category: FuncCategory::Stats, insert_template: "lcm(,)", aliases: &[], eval: f_lcm },
    // 取整
    FunctionDef { name: "floor", arity: Arity::Fixed(1), category: FuncCategory::Rounding, insert_template: "floor(", aliases: &[], eval: f_floor },
    FunctionDef { name: "ceil", arity: Arity::Fixed(1), category: FuncCategory::Rounding, insert_template: "ceil(", aliases: &[], eval: f_ceil },
    FunctionDef { name: "round", arity: Arity::Fixed(1), category: FuncCategory::Rounding, insert_template: "round(", aliases: &[], eval: f_round },
    FunctionDef { name: "trunc", arity: Arity::Fixed(1), category: FuncCategory::Rounding, insert_template: "trunc(", aliases: &[], eval: f_trunc },
    // 位运算
    FunctionDef { name: "and", arity: Arity::Fixed(2), category: FuncCategory::Bits, insert_template: "and(,)", aliases: &[], eval: f_and },
    FunctionDef { name: "or", arity: Arity::Fixed(2), category: FuncCategory::Bits, insert_template: "or(,)", aliases: &[], eval: f_or },
    FunctionDef { name: "xor", arity: Arity::Fixed(2), category: FuncCategory::Bits, insert_template: "xor(,)", aliases: &[], eval: f_xor },
    FunctionDef { name: "not", arity: Arity::Fixed(1), category: FuncCategory::Bits, insert_template: "not(", aliases: &[], eval: f_not },
    FunctionDef { name: "shl", arity: Arity::Fixed(2), category: FuncCategory::Bits, insert_template: "shl(,)", aliases: &[], eval: f_shl },
    FunctionDef { name: "shr", arity: Arity::Fixed(2), category: FuncCategory::Bits, insert_template: "shr(,)", aliases: &[], eval: f_shr },
    // 随机
    FunctionDef { name: "rand", arity: Arity::Fixed(0), category: FuncCategory::Misc, insert_template: "rand()", aliases: &[], eval: f_rand },
];

/// 全部函数。
pub fn all() -> &'static [FunctionDef] {
    FUNCTIONS
}

/// 按名字或别名查找。
pub fn lookup(name: &str) -> Option<&'static FunctionDef> {
    if let Some(f) = FUNCTIONS.iter().find(|f| f.name == name) {
        return Some(f);
    }
    if let Some(f) = FUNCTIONS.iter().find(|f| f.aliases.contains(&name)) {
        return Some(f);
    }
    let needle = name.to_lowercase();
    FUNCTIONS.iter().find(|f| {
        f.name.to_lowercase() == needle || f.aliases.iter().any(|a| a.to_lowercase() == needle)
    })
}

/// 是否为已注册函数名（parser 用它区分"函数调用"和"隐式乘法"）。
pub fn is_function_name(name: &str) -> bool {
    lookup(name).is_some()
}

/// 把函数名或别名解析为规范函数名；非函数返回 None。
pub fn resolve_function_name(name: &str) -> Option<&'static str> {
    lookup(name).map(|f| f.name)
}

/// 按名字取实现，供 eval 调用前做存在性判断。
pub fn call(name: &str, args: &[Num], ctx: &EvalContext) -> Result<Num> {
    let def = lookup(name)
        .ok_or_else(|| EngineError::with_message(ErrorKind::UnknownFunction, format!("未知函数 {}", name)))?;
    if !def.arity.accepts(args.len()) {
        return Err(EngineError::with_message(
            ErrorKind::WrongArity,
            format!("{} 需要{}参数，实得 {} 个", def.name, def.arity.describe(), args.len()),
        ));
    }
    (def.eval)(args, ctx)
}

/// 角度模式转弧度/反算的便捷封装（供测试与 UI 复用）。
pub fn angle_mode_factors(m: AngleMode) -> (f64, f64) {
    match m {
        AngleMode::Deg => (std::f64::consts::PI / 180.0, 180.0 / std::f64::consts::PI),
        AngleMode::Rad => (1.0, 1.0),
        AngleMode::Grad => (std::f64::consts::PI / 200.0, 200.0 / std::f64::consts::PI),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::session::Session;

    fn call_with(angle: AngleMode, word: u8, name: &str, args: &[Num]) -> Result<Num> {
        let mut session = Session::new();
        session.settings.angle_mode = angle;
        session.settings.word_size = word;
        let ctx = EvalContext {
            session: &mut session,
            depth: 0,
        };
        call(name, args, &ctx)
    }

    #[test]
    fn trig_honours_angle_mode() {
        let v = call_with(AngleMode::Deg, 64, "sin", &[Num::int(30)]).unwrap();
        assert!((v.to_f64() - 0.5).abs() < 1e-12);
        let v = call_with(AngleMode::Deg, 64, "cos", &[Num::int(60)]).unwrap();
        assert!((v.to_f64() - 0.5).abs() < 1e-12);
        let v = call_with(AngleMode::Deg, 64, "tan", &[Num::int(45)]).unwrap();
        assert!((v.to_f64() - 1.0).abs() < 1e-12);
        let v = call_with(AngleMode::Grad, 64, "sin", &[Num::int(100)]).unwrap();
        assert!((v.to_f64() - 1.0).abs() < 1e-12);
        let rad = call_with(AngleMode::Rad, 64, "sin", &[Num::float(std::f64::consts::PI / 6.0)]).unwrap();
        assert!((rad.to_f64() - 0.5).abs() < 1e-12);
    }

    #[test]
    fn inverse_trig_returns_current_angle_unit() {
        let v = call_with(AngleMode::Deg, 64, "asin", &[Num::float(0.5)]).unwrap();
        assert!((v.to_f64() - 30.0).abs() < 1e-9);
        let v = call_with(AngleMode::Rad, 64, "asin", &[Num::float(0.5)]).unwrap();
        assert!((v.to_f64() - 0.5235987755982988).abs() < 1e-12);
    }

    #[test]
    fn domain_errors() {
        assert_eq!(
            call_with(AngleMode::Deg, 64, "asin", &[Num::int(2)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "ln", &[Num::int(0)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "ln", &[Num::int(-1)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "sqrt", &[Num::int(-4)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "acosh", &[Num::int(0)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "atanh", &[Num::int(1)]).unwrap_err().kind,
            ErrorKind::DomainError
        );
    }

    #[test]
    fn log_and_exp() {
        assert!((call_with(AngleMode::Deg, 64, "ln", &[Num::float(std::f64::consts::E)]).unwrap().to_f64() - 1.0).abs() < 1e-12);
        assert_eq!(call_with(AngleMode::Deg, 64, "log", &[Num::int(100)]).unwrap().to_f64(), 2.0);
        assert_eq!(call_with(AngleMode::Deg, 64, "log2", &[Num::int(8)]).unwrap().to_f64(), 3.0);
        assert!((call_with(AngleMode::Deg, 64, "log", &[Num::int(2), Num::int(8)]).unwrap().to_f64() - 3.0).abs() < 1e-12);
    }

    #[test]
    fn rounding_and_number_theory() {
        assert_eq!(call_with(AngleMode::Deg, 64, "floor", &[Num::float(2.7)]).unwrap(), Num::float(2.0));
        assert_eq!(call_with(AngleMode::Deg, 64, "ceil", &[Num::float(2.1)]).unwrap(), Num::float(3.0));
        assert_eq!(call_with(AngleMode::Deg, 64, "round", &[Num::float(2.5)]).unwrap(), Num::float(3.0));
        assert_eq!(call_with(AngleMode::Deg, 64, "trunc", &[Num::float(-2.7)]).unwrap(), Num::float(-2.0));
        assert_eq!(call_with(AngleMode::Deg, 64, "gcd", &[Num::int(12), Num::int(18)]).unwrap(), Num::int(6));
        assert_eq!(call_with(AngleMode::Deg, 64, "lcm", &[Num::int(4), Num::int(6)]).unwrap(), Num::int(12));
        assert_eq!(call_with(AngleMode::Deg, 64, "min", &[Num::int(3), Num::int(1), Num::int(2)]).unwrap(), Num::int(1));
        assert_eq!(call_with(AngleMode::Deg, 64, "max", &[Num::int(3), Num::int(9)]).unwrap(), Num::int(9));
    }

    #[test]
    fn bitwise_helpers() {
        assert_eq!(call_with(AngleMode::Deg, 64, "and", &[Num::int(0b1010), Num::int(0b1100)]).unwrap(), Num::int(0b1000));
        assert_eq!(call_with(AngleMode::Deg, 64, "or", &[Num::int(0b1010), Num::int(0b0101)]).unwrap(), Num::int(0b1111));
        assert_eq!(call_with(AngleMode::Deg, 64, "xor", &[Num::int(0b1010), Num::int(0b0110)]).unwrap(), Num::int(0b1100));
        assert_eq!(call_with(AngleMode::Deg, 64, "not", &[Num::int(0)]).unwrap(), Num::int(-1));
        assert_eq!(call_with(AngleMode::Deg, 32, "shl", &[Num::int(0xFF), Num::int(8)]).unwrap(), Num::int(65280));
    }

    #[test]
    fn hyperbolic() {
        assert!((call_with(AngleMode::Deg, 64, "sinh", &[Num::int(0)]).unwrap().to_f64()).abs() < 1e-15);
        assert_eq!(call_with(AngleMode::Deg, 64, "cosh", &[Num::int(0)]).unwrap().to_f64(), 1.0);
        assert!((call_with(AngleMode::Deg, 64, "tanh", &[Num::int(1)]).unwrap().to_f64() - 0.7615941559557649).abs() < 1e-12);
    }

    #[test]
    fn rand_is_in_unit_interval() {
        for _ in 0..8 {
            let v = call_with(AngleMode::Deg, 64, "rand", &[]).unwrap().to_f64();
            assert!((0.0..1.0).contains(&v));
        }
    }

    #[test]
    fn arity_is_enforced() {
        assert_eq!(
            call_with(AngleMode::Deg, 64, "sin", &[]).unwrap_err().kind,
            ErrorKind::WrongArity
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "pow", &[Num::int(2)]).unwrap_err().kind,
            ErrorKind::WrongArity
        );
        assert_eq!(
            call_with(AngleMode::Deg, 64, "nope", &[Num::int(1)]).unwrap_err().kind,
            ErrorKind::UnknownFunction
        );
    }

    #[test]
    fn function_table_integrity() {
        assert!(all().len() >= 30);
        let mut names = std::collections::HashSet::new();
        for f in all() {
            assert!(names.insert(f.name), "重复函数名 {}", f.name);
            assert!(!f.insert_template.is_empty());
        }
        for n in ["sin", "cos", "tan", "asin", "acos", "atan", "ln", "log", "log2", "log10",
                  "exp", "sqrt", "cbrt", "abs", "fact", "mod", "min", "max", "floor", "ceil",
                  "round", "trunc", "gcd", "lcm", "and", "or", "xor", "not", "shl", "shr",
                  "sinh", "cosh", "tanh", "asinh", "acosh", "atanh", "rand", "pow", "root", "sq", "cube", "inv", "neg", "exp10"] {
            assert!(is_function_name(n), "缺少函数 {}", n);
        }
    }
}
