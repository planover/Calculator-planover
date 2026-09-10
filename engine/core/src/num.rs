//! 数值类型：精确有理数（i64/i64）∪ f64 ∪ 非有限值。
//!
//! 选型理由（对应架构 §0-D4 / PRD-Q1）：
//! - 有理数用 **i64 分子 / i64 分母** 自实现，避免引入 `num-rational` 之外的
//!   任意精度库（GMP/MPFR 需要外部 C 库，交叉编译到 Android 风险不可控）。
//! - 超越函数（sin/ln/…）天然无理，退化到 `f64`；一旦混入浮点，结果即"浮点传染"。
//! - `f64` 的 NaN/Inf 无法被 JSON 表达，故单列 [`Special`]。

use std::cmp::Ordering;

use crate::error::{EngineError, ErrorKind, Result};

/// 阶乘走精确 i64 的最大值：`20!` = 2432902008176640000 仍落在 i64 内，`21!` 溢出。
pub const MAX_FACTORIAL_EXACT: i64 = 20;

/// 有理数中间计算的 i128 上限（约 4.6e18 量级的安全平方区间）。
const I128_SAFE: i128 = 1i128 << 62;

/// 非有限浮点值。serde 无法表达 f64 的 NaN/Inf，故单列一个枚举。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Special {
    /// 非数值。
    Nan,
    /// 正无穷。
    Infinity,
    /// 负无穷。
    NegInfinity,
}

/// 引擎的数值类型。
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Num {
    /// 精确有理数：永远约分、分母恒正。
    Rational {
        /// 分子。
        num: i64,
        /// 分母，恒 > 0。
        den: i64,
    },
    /// 浮点（超越函数结果、无理常量、有理溢出的降级结果）。
    Float(f64),
    /// 非有限值。
    Special(Special),
}

// ── 内部小工具 ────────────────────────────────────────────────

/// 求最大公约数（对 `i64::MIN` 也安全）。
fn gcd_i64(a: i64, b: i64) -> i64 {
    let mut a = a.unsigned_abs();
    let mut b = b.unsigned_abs();
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    if a == 0 {
        1
    } else {
        a as i64
    }
}

/// 求最大公约数（i128 版，供中间计算用）。
fn gcd_i128(a: i128, b: i128) -> i128 {
    let mut a = a.unsigned_abs();
    let mut b = b.unsigned_abs();
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    if a == 0 {
        1
    } else {
        a as i128
    }
}

/// 把 i128 分子/分母约分并收窄回 `Num::Rational`；越界返回 `None` 由调用方降级。
fn rational_from_i128(n: i128, d: i128) -> Option<Num> {
    if d == 0 {
        return None;
    }
    let (mut n, mut d) = (n, d);
    if d < 0 {
        n = -n;
        d = -d;
    }
    let g = gcd_i128(n, d);
    let n = n / g;
    let d = d / g;
    if n > i64::MAX as i128 || n < i64::MIN as i128 || d > i64::MAX as i128 {
        return None;
    }
    Num::rational(n as i64, d as i64).ok()
}

/// 快速整数幂（i128，溢出返回 `None`）。
fn ipow_i128(base: i128, exp: i128) -> Option<i128> {
    let mut base = base;
    let mut exp = exp;
    let mut res: i128 = 1;
    loop {
        if exp & 1 == 1 {
            res = res.checked_mul(base)?;
            if res.unsigned_abs() > I128_SAFE as u128 {
                return None;
            }
        }
        exp >>= 1;
        if exp == 0 {
            break;
        }
        base = base.checked_mul(base)?;
        if base.unsigned_abs() > I128_SAFE as u128 {
            return None;
        }
    }
    Some(res)
}

/// 整数平方根（精确；非完全平方数返回 `None`）。
fn isqrt(v: i64) -> Option<i64> {
    if v < 0 {
        return None;
    }
    let t = v as i128;
    let mut r = (v as f64).sqrt() as i128;
    if r < 0 {
        r = 0;
    }
    while (r + 1) * (r + 1) <= t {
        r += 1;
    }
    while r * r > t {
        r -= 1;
    }
    if r * r == t {
        Some(r as i64)
    } else {
        None
    }
}

/// 取整数部分（向零取整）。
fn as_i64_trunc(v: f64) -> i64 {
    v.trunc() as i64
}

// ── 公开 API ─────────────────────────────────────────────────

impl Num {
    /// 构造有理数并约分；`den == 0` 返回 `DivisionByZero`。
    pub fn rational(num: i64, den: i64) -> Result<Num> {
        if den == 0 {
            return Err(EngineError::new(ErrorKind::DivisionByZero));
        }
        let (mut n, mut d) = (num, den);
        if d < 0 {
            n = n.wrapping_neg();
            d = d.wrapping_neg();
        }
        let g = gcd_i64(n, d);
        Ok(Num::Rational {
            num: n / g,
            den: d / g,
        })
    }

    /// 构造整数（分母为 1 的有理数）。
    pub fn int(v: i64) -> Num {
        Num::Rational { num: v, den: 1 }
    }

    /// 构造浮点；非有限值自动转成 [`Num::Special`]。
    pub fn float(v: f64) -> Num {
        if v.is_nan() {
            Num::Special(Special::Nan)
        } else if v.is_infinite() {
            if v > 0.0 {
                Num::Special(Special::Infinity)
            } else {
                Num::Special(Special::NegInfinity)
            }
        } else {
            Num::Float(v)
        }
    }

    /// 0。
    pub fn zero() -> Num {
        Num::Rational { num: 0, den: 1 }
    }

    /// 1。
    pub fn one() -> Num {
        Num::Rational { num: 1, den: 1 }
    }

    /// 是否为 0（含 -0.0 与浮点 0.0）。
    pub fn is_zero(&self) -> bool {
        match self {
            Num::Rational { num, .. } => *num == 0,
            Num::Float(f) => *f == 0.0,
            Num::Special(_) => false,
        }
    }

    /// 是否为整数值（浮点 3.0 也算整数）。
    pub fn is_int(&self) -> bool {
        match self {
            Num::Rational { den, .. } => *den == 1,
            Num::Float(f) => f.is_finite() && f.fract() == 0.0,
            Num::Special(_) => false,
        }
    }

    /// 转成 f64（有理数做除法，非有限值映射为 NaN/±Inf）。
    pub fn to_f64(&self) -> f64 {
        match self {
            Num::Rational { num, den } => *num as f64 / *den as f64,
            Num::Float(f) => *f,
            Num::Special(Special::Nan) => f64::NAN,
            Num::Special(Special::Infinity) => f64::INFINITY,
            Num::Special(Special::NegInfinity) => f64::NEG_INFINITY,
        }
    }

    /// 取整数值；非整数返回 `NotAnInteger`，越界返回 `Overflow`。
    pub fn try_as_i64(&self) -> Result<i64> {
        match self {
            Num::Rational { num, den } => {
                if *den == 1 {
                    Ok(*num)
                } else {
                    Err(EngineError::with_message(
                        ErrorKind::NotAnInteger,
                        format!("{} 不是整数", self.to_f64()),
                    ))
                }
            }
            Num::Float(f) => {
                if !f.is_finite() {
                    return Err(EngineError::new(ErrorKind::Overflow));
                }
                if f.fract() == 0.0 && *f >= i64::MIN as f64 && *f <= i64::MAX as f64 {
                    Ok(*f as i64)
                } else {
                    Err(EngineError::with_message(
                        ErrorKind::NotAnInteger,
                        format!("{} 不是整数", f),
                    ))
                }
            }
            Num::Special(_) => Err(EngineError::new(ErrorKind::NotAnInteger)),
        }
    }

    /// 绝对值。
    pub fn abs(&self) -> Num {
        match self {
            Num::Rational { num, den } => Num::Rational {
                num: num.wrapping_abs(),
                den: *den,
            },
            Num::Float(f) => Num::float(f.abs()),
            Num::Special(Special::NegInfinity) => Num::Special(Special::Infinity),
            Num::Special(s) => Num::Special(*s),
        }
    }

    /// 取负；`i64::MIN` 溢出时降级为浮点。
    pub fn neg(&self) -> Num {
        match self {
            Num::Rational { num, den } => match num.checked_neg() {
                Some(n) => Num::Rational { num: n, den: *den },
                None => Num::Float(-(*num as f64) / (*den as f64)),
            },
            Num::Float(f) => Num::float(-*f),
            Num::Special(Special::Infinity) => Num::Special(Special::NegInfinity),
            Num::Special(Special::NegInfinity) => Num::Special(Special::Infinity),
            Num::Special(s) => Num::Special(*s),
        }
    }

    /// 加法。有理 × 有理保持精确，溢出降级浮点。
    pub fn add(&self, r: &Num) -> Num {
        match (self, r) {
            (
                Num::Rational { num: a, den: b },
                Num::Rational {
                    num: c,
                    den: d,
                },
            ) => {
                let n = *a as i128 * *d as i128 + *c as i128 * *b as i128;
                let den = *b as i128 * *d as i128;
                rational_from_i128(n, den)
                    .unwrap_or_else(|| Num::float(self.to_f64() + r.to_f64()))
            }
            _ => Num::float(self.to_f64() + r.to_f64()),
        }
    }

    /// 减法。
    pub fn sub(&self, r: &Num) -> Num {
        match (self, r) {
            (
                Num::Rational { num: a, den: b },
                Num::Rational {
                    num: c,
                    den: d,
                },
            ) => {
                let n = *a as i128 * *d as i128 - *c as i128 * *b as i128;
                let den = *b as i128 * *d as i128;
                rational_from_i128(n, den)
                    .unwrap_or_else(|| Num::float(self.to_f64() - r.to_f64()))
            }
            _ => Num::float(self.to_f64() - r.to_f64()),
        }
    }

    /// 乘法。
    pub fn mul(&self, r: &Num) -> Num {
        match (self, r) {
            (
                Num::Rational { num: a, den: b },
                Num::Rational {
                    num: c,
                    den: d,
                },
            ) => {
                let n = *a as i128 * *c as i128;
                let den = *b as i128 * *d as i128;
                rational_from_i128(n, den)
                    .unwrap_or_else(|| Num::float(self.to_f64() * r.to_f64()))
            }
            _ => Num::float(self.to_f64() * r.to_f64()),
        }
    }

    /// 除法；除数为 0 返回 `DivisionByZero`。
    pub fn div(&self, r: &Num) -> Result<Num> {
        if r.is_zero() {
            return Err(EngineError::new(ErrorKind::DivisionByZero));
        }
        match (self, r) {
            (
                Num::Rational { num: a, den: b },
                Num::Rational {
                    num: c,
                    den: d,
                },
            ) => {
                let n = *a as i128 * *d as i128;
                let den = *b as i128 * *c as i128;
                Ok(rational_from_i128(n, den)
                    .unwrap_or_else(|| Num::float(self.to_f64() / r.to_f64())))
            }
            _ => Ok(Num::float(self.to_f64() / r.to_f64())),
        }
    }

    /// 取模，**结果符号跟随被除数**：`7 % 3 = 1`、`(-7) % 3 = -1`。
    pub fn rem(&self, r: &Num) -> Result<Num> {
        if r.is_zero() {
            return Err(EngineError::new(ErrorKind::DivisionByZero));
        }
        match (self, r) {
            (
                Num::Rational { num: a, den: b },
                Num::Rational {
                    num: c,
                    den: d,
                },
            ) => {
                // q = trunc(a/b ÷ c/d) = trunc(a·d / (b·c))；i128 除法天然向零取整
                let num = *a as i128 * *d as i128;
                let den = *b as i128 * *c as i128;
                let q = num / den;
                let n = num - *c as i128 * *b as i128 * q;
                let dd = *b as i128 * *d as i128;
                Ok(rational_from_i128(n, dd)
                    .unwrap_or_else(|| Num::float(self.to_f64() % r.to_f64())))
            }
            _ => Ok(Num::float(self.to_f64() % r.to_f64())),
        }
    }

    /// 幂运算。`0^0` 按工程惯例返回 1；负底数 + 分数指数返回 `DomainError`。
    pub fn pow(&self, r: &Num) -> Result<Num> {
        if self.is_zero() && r.is_zero() {
            return Ok(Num::one());
        }
        if let Num::Rational { num: e, den: ed } = r {
            if *ed == 1 {
                let e = *e;
                if self.is_zero() && e < 0 {
                    return Err(EngineError::new(ErrorKind::DivisionByZero));
                }
                if let Num::Rational { num: a, den: b } = self {
                    let (bn, bd, exp) = if e >= 0 {
                        (*a as i128, *b as i128, e as i128)
                    } else {
                        (*b as i128, *a as i128, -(e as i128))
                    };
                    if let (Some(pn), Some(pd)) = (ipow_i128(bn, exp), ipow_i128(bd, exp)) {
                        if let Some(v) = rational_from_i128(pn, pd) {
                            return Ok(v);
                        }
                    }
                }
                let base = self.to_f64();
                let ei = e.clamp(i32::MIN as i64, i32::MAX as i64) as i32;
                return Ok(Num::float(base.powi(ei)));
            }
        }
        // 分数指数：负底数无实数解
        let base = self.to_f64();
        let exp = r.to_f64();
        if base < 0.0 {
            return Err(EngineError::with_message(
                ErrorKind::DomainError,
                "负数的分数次幂无实数解",
            ));
        }
        Ok(Num::float(base.powf(exp)))
    }

    /// 平方根；负数返回 `DomainError`；完全平方数保持精确有理。
    pub fn sqrt(&self) -> Result<Num> {
        match self {
            Num::Rational { num, den } => {
                if *num < 0 {
                    return Err(EngineError::with_message(
                        ErrorKind::DomainError,
                        "负数不能开平方",
                    ));
                }
                if let (Some(a), Some(b)) = (isqrt(*num), isqrt(*den)) {
                    if let Ok(v) = Num::rational(a, b) {
                        return Ok(v);
                    }
                }
                Ok(Num::float(self.to_f64().sqrt()))
            }
            Num::Float(f) => {
                if *f < 0.0 {
                    return Err(EngineError::with_message(
                        ErrorKind::DomainError,
                        "负数不能开平方",
                    ));
                }
                Ok(Num::float(f.sqrt()))
            }
            Num::Special(s) => Ok(Num::Special(*s)),
        }
    }

    /// 立方根（负数有定义）。
    pub fn cbrt(&self) -> Num {
        Num::float(self.to_f64().cbrt())
    }

    /// 阶乘：仅非负整数；`n > 20` 用浮点近似；非整数/负数返回 `DomainError`。
    pub fn factorial(&self) -> Result<Num> {
        let n = match self.try_as_i64() {
            Ok(n) => n,
            Err(_) => {
                // 非整数（或 NaN/Inf）统一按定义域错误上报，与 Q5 裁决一致
                return Err(EngineError::with_message(
                    ErrorKind::DomainError,
                    "阶乘只接受非负整数",
                ));
            }
        };
        if n < 0 {
            return Err(EngineError::with_message(
                ErrorKind::DomainError,
                "负数没有阶乘",
            ));
        }
        if n <= MAX_FACTORIAL_EXACT {
            let mut acc: i64 = 1;
            for i in 2..=n {
                acc = acc
                    .checked_mul(i)
                    .ok_or_else(|| EngineError::new(ErrorKind::Overflow))?;
            }
            return Ok(Num::int(acc));
        }
        let mut acc: f64 = 1.0;
        for i in 2..=n {
            acc *= i as f64;
            if !acc.is_finite() {
                return Ok(Num::Special(Special::Infinity));
            }
        }
        Ok(Num::float(acc))
    }

    /// 用连分数把 f64 逼近为最简分数，供分数显示用；分母超过 `max_den` 则停止。
    pub fn to_rational_approx(&self, max_den: i64) -> Option<Num> {
        let x = self.to_f64();
        if !x.is_finite() {
            return None;
        }
        let neg = x < 0.0;
        let x = x.abs();
        let mut p_prev: i128 = 1;
        let mut q_prev: i128 = 0;
        let mut p: i128 = x.floor() as i128;
        let mut q: i128 = 1;
        let mut frac = x - x.floor();
        let mut best = (p, q);
        let mut i = 0;
        while frac > 1e-15 && i < 64 {
            i += 1;
            let inv = 1.0 / frac;
            let a = inv.floor();
            frac = inv - a;
            let pn = a as i128 * p + p_prev;
            let qn = a as i128 * q + q_prev;
            p_prev = p;
            q_prev = q;
            p = pn;
            q = qn;
            if q <= 0 || q > max_den as i128 {
                break;
            }
            best = (p, q);
        }
        let (n, d) = best;
        if d == 0 || d > i64::MAX as i128 {
            return None;
        }
        let n = if neg { -n } else { n };
        if n > i64::MAX as i128 || n < i64::MIN as i128 {
            return None;
        }
        Num::rational(n as i64, d as i64).ok()
    }
}

impl PartialOrd for Num {
    /// 统一转 f64 比较；任一侧为 NaN 时不可比较（与 IEEE 语义一致）。
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        let a = self.to_f64();
        let b = other.to_f64();
        if a.is_nan() || b.is_nan() {
            None
        } else {
            a.partial_cmp(&b)
        }
    }
}

/// 把 `Num` 截断成 i64（位运算、位宽掩码用；不用于错误上报）。
pub fn trunc_to_i64(n: &Num) -> i64 {
    as_i64_trunc(n.to_f64())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn r(n: i64, d: i64) -> Num {
        Num::rational(n, d).unwrap()
    }

    #[test]
    fn rational_is_reduced_and_sign_normalized() {
        assert_eq!(r(4, 8), Num::Rational { num: 1, den: 2 });
        assert_eq!(r(-2, 4), Num::Rational { num: -1, den: 2 });
        assert_eq!(r(2, -4), Num::Rational { num: -1, den: 2 });
        assert!(Num::rational(1, 0).is_err());
    }

    #[test]
    fn float_routes_non_finite_to_special() {
        assert_eq!(Num::float(f64::NAN), Num::Special(Special::Nan));
        assert_eq!(Num::float(f64::INFINITY), Num::Special(Special::Infinity));
        assert_eq!(
            Num::float(f64::NEG_INFINITY),
            Num::Special(Special::NegInfinity)
        );
        assert_eq!(Num::float(1.5), Num::Float(1.5));
    }

    #[test]
    fn exact_rational_arithmetic() {
        assert_eq!(r(1, 10).add(&r(2, 10)), r(3, 10));
        assert_eq!(r(1, 3).mul(&Num::int(3)), Num::int(1));
        assert_eq!(Num::int(1).div(&Num::int(3)).unwrap(), r(1, 3));
    }

    #[test]
    fn overflow_degrades_to_float() {
        let big = Num::int(i64::MAX);
        let v = big.add(&Num::int(1));
        assert!(matches!(v, Num::Float(_)));
        assert_eq!(v.to_f64(), i64::MAX as f64 + 1.0);
    }

    #[test]
    fn remainder_follows_dividend_sign() {
        assert_eq!(Num::int(7).rem(&Num::int(3)).unwrap(), Num::int(1));
        assert_eq!(Num::int(-7).rem(&Num::int(3)).unwrap(), Num::int(-1));
        assert_eq!(Num::int(7).rem(&Num::int(-3)).unwrap(), Num::int(1));
        assert_eq!(Num::int(-7).rem(&Num::int(-3)).unwrap(), Num::int(-1));
    }

    #[test]
    fn pow_semantics() {
        assert_eq!(Num::int(2).pow(&Num::int(10)).unwrap(), Num::int(1024));
        assert_eq!(
            Num::int(2).pow(&Num::rational(1, 2).unwrap()).unwrap().to_f64(),
            2f64.sqrt()
        );
        assert_eq!(Num::int(0).pow(&Num::int(0)).unwrap(), Num::one());
        assert_eq!(Num::int(2).pow(&Num::int(-1)).unwrap(), r(1, 2));
        assert!(Num::int(-2)
            .pow(&Num::rational(1, 2).unwrap())
            .is_err());
    }

    #[test]
    fn sqrt_exact_when_perfect_square() {
        assert_eq!(Num::int(16).sqrt().unwrap(), Num::int(4));
        assert_eq!(r(9, 16).sqrt().unwrap(), r(3, 4));
        assert!(Num::int(-1).sqrt().is_err());
        assert!((Num::int(2).sqrt().unwrap().to_f64() - 2f64.sqrt()).abs() < 1e-15);
    }

    #[test]
    fn factorial_baseline() {
        assert_eq!(Num::int(0).factorial().unwrap(), Num::int(1));
        assert_eq!(Num::int(5).factorial().unwrap(), Num::int(120));
        assert_eq!(
            Num::int(20).factorial().unwrap(),
            Num::int(2432902008176640000)
        );
        assert_eq!(
            Num::int(21).factorial().unwrap().to_f64(),
            51090942171709440000.0
        );
        assert!(Num::int(-1).factorial().is_err());
        assert!(Num::float(2.5).factorial().is_err());
    }

    #[test]
    fn rational_approx_recovers_simple_fractions() {
        assert_eq!(
            Num::float(2.75).to_rational_approx(1_000_000_000),
            Some(r(11, 4))
        );
        assert_eq!(
            Num::float(1.0 / 3.0).to_rational_approx(1_000_000_000),
            Some(r(1, 3))
        );
        assert_eq!(
            Num::float(0.5).to_rational_approx(1_000_000_000),
            Some(r(1, 2))
        );
        assert_eq!(Num::Special(Special::Nan).to_rational_approx(1000), None);
    }

    #[test]
    fn ordering_and_abs() {
        assert!(Num::int(2) > Num::int(1));
        assert!(r(1, 3) < r(1, 2));
        assert_eq!(Num::int(-7).abs(), Num::int(7));
        assert_eq!(r(-1, 2).abs(), r(1, 2));
    }
}
