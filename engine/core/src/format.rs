//! 数字格式化：科学计数法 / 定点 / 有效位 / 小数位 / 分数 / 千位分隔。
//!
//! 设计原则：
//! - **精确优先**：有理数若能写出有限十进制（分母只含 2 和 5 因子），且精度放得下，
//!   就显示精确串 —— 这是 `0.1+0.2` 显示 `0.3` 而不是 `0.30000000000000004` 的原因。
//! - **整数不受精度截断**：否则 `20!` 会被 10 位有效数字截成 `2.432902008×10¹⁸`。

use crate::error::{EngineError, ErrorKind, Result};
use crate::num::{Num, Special};

/// 记数法。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Notation {
    /// 自动：常规数量级用定点，极大/极小自动切科学计数法。
    Auto,
    /// 科学计数法。
    Scientific,
    /// 定点。
    Fixed,
}

impl Notation {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            Notation::Auto => "auto",
            Notation::Scientific => "scientific",
            Notation::Fixed => "fixed",
        }
    }

    /// 从标识解析；未知返回 `None`。
    pub fn from_id(s: &str) -> Option<Notation> {
        match s.trim().to_lowercase().as_str() {
            "auto" => Some(Notation::Auto),
            "scientific" => Some(Notation::Scientific),
            "fixed" => Some(Notation::Fixed),
            _ => None,
        }
    }
}

/// 精度模式（两者互斥）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrecisionMode {
    /// 有效位数。
    Significant,
    /// 小数位数。
    DecimalPlaces,
}

impl PrecisionMode {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            PrecisionMode::Significant => "significant",
            PrecisionMode::DecimalPlaces => "decimal_places",
        }
    }

    /// 从标识解析。
    pub fn from_id(s: &str) -> Option<PrecisionMode> {
        match s.trim().to_lowercase().as_str() {
            "significant" => Some(PrecisionMode::Significant),
            "decimal_places" | "decimals" => Some(PrecisionMode::DecimalPlaces),
            _ => None,
        }
    }
}

/// 分数显示模式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FractionMode {
    /// 关闭。
    Off,
    /// 假分数 `11/4`。
    Improper,
    /// 带分数 `2 3/4`。
    Mixed,
}

impl FractionMode {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            FractionMode::Off => "off",
            FractionMode::Improper => "improper",
            FractionMode::Mixed => "mixed",
        }
    }

    /// 从标识解析。
    pub fn from_id(s: &str) -> Option<FractionMode> {
        match s.trim().to_lowercase().as_str() {
            "off" => Some(FractionMode::Off),
            "improper" => Some(FractionMode::Improper),
            "mixed" => Some(FractionMode::Mixed),
            _ => None,
        }
    }
}

/// 格式化设置。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NumberFormatSettings {
    /// 记数法。
    pub notation: Notation,
    /// 精度模式。
    pub precision_mode: PrecisionMode,
    /// 精度值，合法区间 `1..=15`。
    pub precision: u8,
    /// 分数显示。
    pub fraction_mode: FractionMode,
    /// 千位分隔。
    pub grouping: bool,
}

impl Default for NumberFormatSettings {
    /// 默认：自动 / 有效位 / 10 位 / 不显示分数 / 开启千位分隔。
    fn default() -> Self {
        Self {
            notation: Notation::Auto,
            precision_mode: PrecisionMode::Significant,
            precision: 10,
            fraction_mode: FractionMode::Off,
            grouping: true,
        }
    }
}

/// 精度合法上界（与 `u8` 存储配合，15 位有效数字已覆盖 f64 全部可靠位数）。
pub const MAX_PRECISION: u8 = 15;
/// 精度合法下界。
pub const MIN_PRECISION: u8 = 1;
/// 分数显示允许的最大分母；超过则回退小数（避免 `0.333333` 显示成 `333333/1000000`）。
pub const MAX_FRACTION_DEN: i64 = 10_000;

/// 校验设置；`precision` 越界返回 `InvalidSettings`。
pub fn validate(s: &NumberFormatSettings) -> Result<()> {
    if s.precision < MIN_PRECISION || s.precision > MAX_PRECISION {
        return Err(EngineError::with_message(
            ErrorKind::InvalidSettings,
            format!("精度必须介于 {}~{}，实得 {}", MIN_PRECISION, MAX_PRECISION, s.precision),
        ));
    }
    Ok(())
}

// ── 内部工具 ────────────────────────────────────────────────

fn superscript(exp: i32) -> String {
    let s = exp.to_string();
    s.chars()
        .map(|c| match c {
            '0' => '⁰',
            '1' => '¹',
            '2' => '²',
            '3' => '³',
            '4' => '⁴',
            '5' => '⁵',
            '6' => '⁶',
            '7' => '⁷',
            '8' => '⁸',
            '9' => '⁹',
            '-' => '⁻',
            other => other,
        })
        .collect()
}

fn trim_zeros(s: &str) -> String {
    if !s.contains('.') {
        return s.to_string();
    }
    let mut out = s.trim_end_matches('0').to_string();
    if out.ends_with('.') {
        out.pop();
    }
    if out == "-0" || out.is_empty() {
        return "0".to_string();
    }
    out
}

/// 千位分隔（入参为**纯数字**整数部分，不含符号）。
pub fn group_digits(int_part: &str) -> String {
    let digits: String = int_part.chars().filter(|c| c.is_ascii_digit()).collect();
    if digits.len() <= 3 {
        return digits;
    }
    let mut out = String::new();
    let n = digits.len();
    for (i, c) in digits.chars().enumerate() {
        let from_right = n - i;
        if i > 0 && from_right % 3 == 0 {
            out.push(',');
        }
        out.push(c);
    }
    out
}

/// 对可能带负号与小数部分的数字串做千位分隔。
fn apply_group(s: &str, group: bool) -> String {
    if !group {
        return s.to_string();
    }
    let (sign, body) = match s.strip_prefix('-') {
        Some(b) => ("-", b),
        None => ("", s),
    };
    match body.split_once('.') {
        Some((i, f)) => format!("{}{}.{}", sign, group_digits(i), f),
        None => format!("{}{}", sign, group_digits(body)),
    }
}

/// 取 `v` 的 `sig` 位有效数字，返回 (数字串, 十进制指数, 是否负数)。
fn sig_parts(v: f64, sig: u8) -> (String, i32, bool) {
    let sig = sig.clamp(1, MAX_PRECISION);
    let s = format!("{:.*e}", (sig - 1) as usize, v);
    let mut it = s.splitn(2, 'e');
    let mant = it.next().unwrap_or("0");
    let exp: i32 = it.next().and_then(|e| e.parse().ok()).unwrap_or(0);
    let neg = mant.starts_with('-');
    let digits: String = mant.chars().filter(|c| c.is_ascii_digit()).collect();
    (digits, exp, neg)
}

fn decimal_exponent(v: f64) -> i32 {
    if v == 0.0 || !v.is_finite() {
        0
    } else {
        v.abs().log10().floor() as i32
    }
}

fn render_plain(digits: &str, exp: i32, neg: bool, group: bool) -> String {
    let point = exp + 1;
    let body = if point <= 0 {
        format!("0.{}{}", "0".repeat((-point) as usize), digits)
    } else if point as usize >= digits.len() {
        format!("{}{}", digits, "0".repeat(point as usize - digits.len()))
    } else {
        format!(
            "{}.{}",
            &digits[..point as usize],
            &digits[point as usize..]
        )
    };
    let all_zero = digits.chars().all(|c| c == '0');
    let mut out = trim_zeros(&body);
    if neg && !all_zero && out != "0" {
        out.insert(0, '-');
    }
    apply_group(&out, group)
}

/// 科学计数法渲染：`1.23456789×10⁸`；指数为 0 时省略 `×10⁰`。
fn render_sci(digits: &str, exp: i32, neg: bool) -> String {
    let mant = if digits.len() <= 1 {
        digits.to_string()
    } else {
        format!("{}.{}", &digits[..1], &digits[1..])
    };
    let mant = trim_zeros(&mant);
    let head = if neg && mant != "0" {
        format!("-{}", mant)
    } else {
        mant
    };
    if exp == 0 {
        head
    } else {
        format!("{}×10{}", head, superscript(exp))
    }
}

/// 把有理数写成有限十进制串；分母含 2/5 以外的因子则返回 `None`。
pub fn exact_decimal_string(num: i64, den: i64) -> Option<String> {
    if den == 0 {
        return None;
    }
    let (mut n, mut d) = (num, den);
    if d < 0 {
        n = -n;
        d = -d;
    }
    let g = gcd(n, d);
    n /= g;
    d /= g;
    let mut dd = d;
    let mut twos = 0u32;
    let mut fives = 0u32;
    while dd % 2 == 0 {
        dd /= 2;
        twos += 1;
    }
    while dd % 5 == 0 {
        dd /= 5;
        fives += 1;
    }
    if dd != 1 {
        return None;
    }
    let k = twos.max(fives);
    if k > 24 {
        return None;
    }
    // 把分母 2^twos·5^fives 凑成 10^k：分子相应乘 2^(k-twos)·5^(k-fives)，
    // 得到"缩放后的整数" value，使得 value/10^k == n/d 且 value 本身为整数。
    // （旧实现误写成 n·10^k，得到的是 n 而非 n/d，导致 3/10 显示成 "3"。）
    let f2: u32 = k - twos;
    let f5: u32 = k - fives;
    // 分子相应补 2^(k-twos)·5^(k-fives)，把分母凑成 10^k：
    // value = n·2^(k-twos)·5^(k-fives)，于是 value/10^k == n/d 且 value 为整数。
    let value = (n as i128)
        .checked_mul(1i128 << f2)?
        .checked_mul(5i128.pow(f5))?;
    if value > i64::MAX as i128 || value < i64::MIN as i128 {
        return None;
    }
    let value = value as i64;
    let den10 = 10i64.pow(k);
    let int_part = value / den10;
    let frac_part = (value % den10).abs();
    let neg = value < 0 && (int_part != 0 || frac_part != 0);
    let sign = if neg { "-" } else { "" };
    if k == 0 {
        return Some(format!("{}{}", sign, int_part.abs()));
    }
    let fs = format!("{:0width$}", frac_part, width = k as usize);
    let fs = fs.trim_end_matches('0').to_string();
    if fs.is_empty() {
        Some(format!("{}{}", sign, int_part.abs()))
    } else {
        Some(format!("{}{}.{}", sign, int_part.abs(), fs))
    }
}

fn gcd(mut a: i64, mut b: i64) -> i64 {
    while b != 0 {
        let t = a % b;
        a = b;
        b = t;
    }
    a.abs()
}

/// 统计十进制串的有效数字位数（忽略符号、前导 0 与小数点）。
fn count_significant(s: &str) -> usize {
    let body = s.trim_start_matches('-');
    let digits: String = body.chars().filter(|c| c.is_ascii_digit()).collect();
    let t = digits.trim_start_matches('0');
    if t.is_empty() {
        1
    } else {
        t.len()
    }
}

fn decimal_places_of(s: &str) -> usize {
    match s.split_once('.') {
        Some((_, f)) => f.len(),
        None => 0,
    }
}

/// 精确串是否在给定精度内放得下。
fn precision_fits(exact: &str, s: &NumberFormatSettings) -> bool {
    match s.precision_mode {
        PrecisionMode::Significant => count_significant(exact) <= s.precision as usize,
        PrecisionMode::DecimalPlaces => decimal_places_of(exact) <= s.precision as usize,
    }
}

// ── 公开 API ────────────────────────────────────────────────

/// 按设置格式化数值。
pub fn format_number(n: &Num, s: &NumberFormatSettings) -> Result<String> {
    validate(s)?;
    match n {
        Num::Special(Special::Nan) => return Ok("非数值".to_string()),
        Num::Special(Special::Infinity) => return Ok("∞".to_string()),
        Num::Special(Special::NegInfinity) => return Ok("-∞".to_string()),
        _ => {}
    }

    if s.fraction_mode != FractionMode::Off {
        if let Some(f) = format_fraction(n, s.fraction_mode) {
            return Ok(f);
        }
    }

    // 整数：不受精度截断（否则 20! 会被有效位砍掉）。
    // 显式 Scientific：用科学计数法展示，但仍是全精度、不被截断；
    // Auto/Fixed：始终以完整整数展示，不做科学计数法切换（保证大整数如 20! 直接显示）。
    if let Ok(i) = n.try_as_i64() {
        if matches!(s.notation, Notation::Scientific) {
            let t = i.to_string();
            let neg = i < 0;
            let digits: String = t.chars().filter(|c| c.is_ascii_digit()).collect();
            let exp = (digits.len() as i32) - 1;
            return Ok(render_sci(&digits, exp, neg));
        }
        let t = i.to_string();
        return Ok(apply_group(&t, s.grouping));
    }

    // 有限十进制的有理数：精度放得下就用精确串
    if let Num::Rational { num, den } = n {
        if let Some(exact) = exact_decimal_string(*num, *den) {
            if precision_fits(&exact, s) {
                return Ok(apply_group(&exact, s.grouping));
            }
        }
    }

    let v = n.to_f64();
    match s.precision_mode {
        PrecisionMode::Significant => {
            let (digits, exp, neg) = sig_parts(v, s.precision);
            let use_sci = matches!(s.notation, Notation::Scientific)
                || (matches!(s.notation, Notation::Auto) && (exp >= 12 || exp <= -9));
            Ok(if use_sci {
                render_sci(&digits, exp, neg)
            } else {
                render_plain(&digits, exp, neg, s.grouping)
            })
        }
        PrecisionMode::DecimalPlaces => {
            if matches!(s.notation, Notation::Scientific) {
                let e = decimal_exponent(v);
                let sig = (e + 1 + s.precision as i32).clamp(1, MAX_PRECISION as i32) as u8;
                let (d, e2, neg) = sig_parts(v, sig);
                Ok(render_sci(&d, e2, neg))
            } else {
                let t = format!("{:.*}", s.precision as usize, v);
                Ok(apply_group(&trim_zeros(&t), s.grouping))
            }
        }
    }
}

/// 分数表示；化不出（分母过大 / 非有限值 / 关闭）返回 `None`。
pub fn format_fraction(n: &Num, mode: FractionMode) -> Option<String> {
    if mode == FractionMode::Off {
        return None;
    }
    let (num, den) = match n {
        Num::Rational { num, den } => (*num, *den),
        Num::Float(_) => match n.to_rational_approx(MAX_FRACTION_DEN)? {
            Num::Rational { num, den } => (num, den),
            _ => return None,
        },
        Num::Special(_) => return None,
    };
    if den == 0 || den.unsigned_abs() > MAX_FRACTION_DEN as u64 {
        return None;
    }
    let mut num = num;
    let mut den = den;
    if den < 0 {
        num = -num;
        den = -den;
    }
    let g = gcd(num, den);
    num /= g;
    den /= g;
    if den == 1 {
        return Some(num.to_string());
    }
    match mode {
        FractionMode::Off => None,
        FractionMode::Improper => Some(format!("{}/{}", num, den)),
        FractionMode::Mixed => {
            let sign = if num < 0 { "-" } else { "" };
            let a = num.unsigned_abs();
            let whole = a / den as u64;
            let rem = a % den as u64;
            if rem == 0 {
                Some(format!("{}{}", sign, whole))
            } else if whole == 0 {
                Some(format!("{}{}/{}", sign, rem, den))
            } else {
                Some(format!("{}{} {}/{}", sign, whole, rem, den))
            }
        }
    }
}

/// 科学计数法串，如 `1.23456789×10⁸`。
pub fn format_scientific(v: f64, sig: u8) -> String {
    if !v.is_finite() {
        return if v.is_nan() {
            "非数值".to_string()
        } else if v > 0.0 {
            "∞".to_string()
        } else {
            "-∞".to_string()
        };
    }
    let (d, e, neg) = sig_parts(v, sig.clamp(1, MAX_PRECISION));
    render_sci(&d, e, neg)
}

/// 不带分组、尽量保留信息的十进制串（供进制结果行等非主显示场景用）。
pub fn plain_decimal(n: &Num) -> String {
    match n {
        Num::Special(Special::Nan) => "非数值".to_string(),
        Num::Special(Special::Infinity) => "∞".to_string(),
        Num::Special(Special::NegInfinity) => "-∞".to_string(),
        _ => {
            if let Ok(i) = n.try_as_i64() {
                return i.to_string();
            }
            if let Num::Rational { num, den } = n {
                if let Some(s) = exact_decimal_string(*num, *den) {
                    return s;
                }
            }
            let v = n.to_f64();
            let (d, e, neg) = sig_parts(v, MAX_PRECISION);
            if e > 30 || e < -15 {
                render_sci(&d, e, neg)
            } else {
                render_plain(&d, e, neg, false)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fmt(n: Num, s: NumberFormatSettings) -> String {
        format_number(&n, &s).unwrap()
    }

    fn auto_sig(p: u8) -> NumberFormatSettings {
        NumberFormatSettings {
            precision: p,
            ..NumberFormatSettings::default()
        }
    }

    #[test]
    fn significant_digits() {
        let pi = Num::float(std::f64::consts::PI);
        assert_eq!(fmt(pi, auto_sig(4)), "3.142");
        assert_eq!(fmt(pi, auto_sig(10)), "3.141592654");
    }

    #[test]
    fn decimal_places() {
        let pi = Num::float(std::f64::consts::PI);
        let s = NumberFormatSettings {
            precision_mode: PrecisionMode::DecimalPlaces,
            precision: 2,
            ..NumberFormatSettings::default()
        };
        assert_eq!(fmt(pi, s), "3.14");
    }

    #[test]
    fn precision_bounds_validated() {
        assert!(validate(&NumberFormatSettings::default()).is_ok());
        assert_eq!(
            validate(&NumberFormatSettings { precision: 0, ..Default::default() })
                .unwrap_err()
                .kind,
            ErrorKind::InvalidSettings
        );
        assert_eq!(
            validate(&NumberFormatSettings { precision: 16, ..Default::default() })
                .unwrap_err()
                .kind,
            ErrorKind::InvalidSettings
        );
    }

    #[test]
    fn scientific_notation_uses_unicode_superscript() {
        assert_eq!(format_scientific(123456789.0, 10), "1.23456789×10⁸");
        assert_eq!(format_scientific(0.000001, 3), "1×10⁻⁶");
        let s = NumberFormatSettings {
            notation: Notation::Scientific,
            ..NumberFormatSettings::default()
        };
        assert_eq!(fmt(Num::int(123456789), s), "1.23456789×10⁸");
    }

    #[test]
    fn auto_switches_to_scientific_for_huge_values() {
        let v = Num::float(1.5e20);
        assert_eq!(fmt(v, auto_sig(10)), "1.5×10²⁰");
        let small = Num::float(1.5e-12);
        assert_eq!(fmt(small, auto_sig(10)), "1.5×10⁻¹²");
    }

    #[test]
    fn grouping() {
        let s = NumberFormatSettings::default();
        let off = NumberFormatSettings { grouping: false, ..s };
        assert_eq!(fmt(Num::int(1234567), s), "1,234,567");
        assert_eq!(fmt(Num::int(1234567), off), "1234567");
        assert_eq!(group_digits("1234567890"), "1,234,567,890");
        assert_eq!(group_digits("123"), "123");
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
        let half = Num::rational(1, 2).unwrap();
        assert_eq!(fmt(half, improper), "1/2");
        assert_eq!(fmt(half, mixed), "1/2");
        let eleven_fourths = Num::rational(11, 4).unwrap();
        assert_eq!(fmt(eleven_fourths, improper), "11/4");
        assert_eq!(fmt(eleven_fourths, mixed), "2 3/4");
        assert_eq!(fmt(Num::float(2.75), mixed), "2 3/4");
        assert_eq!(fmt(Num::int(7), mixed), "7");
    }

    #[test]
    fn fraction_falls_back_when_denominator_too_large() {
        assert_eq!(
            format_fraction(&Num::rational(1, 1_000_001).unwrap(), FractionMode::Improper),
            None
        );
        assert_eq!(format_fraction(&Num::Special(Special::Nan), FractionMode::Mixed), None);
    }

    #[test]
    fn exact_decimals_beat_float_noise() {
        let s = NumberFormatSettings::default();
        let sum = Num::rational(3, 10).unwrap();
        assert_eq!(fmt(sum, s), "0.3");
    }

    #[test]
    fn integers_are_never_truncated() {
        let s = NumberFormatSettings::default();
        assert_eq!(fmt(Num::int(2432902008176640000), s), "2,432,902,008,176,640,000");
    }

    #[test]
    fn non_finite_display() {
        let s = NumberFormatSettings::default();
        assert_eq!(fmt(Num::Special(Special::Nan), s), "非数值");
        assert_eq!(fmt(Num::Special(Special::Infinity), s), "∞");
        assert_eq!(fmt(Num::Special(Special::NegInfinity), s), "-∞");
    }

    #[test]
    fn enum_ids_roundtrip() {
        assert_eq!(Notation::from_id("scientific"), Some(Notation::Scientific));
        assert_eq!(Notation::from_id("nope"), None);
        assert_eq!(
            PrecisionMode::from_id("decimal_places"),
            Some(PrecisionMode::DecimalPlaces)
        );
        assert_eq!(FractionMode::from_id("mixed"), Some(FractionMode::Mixed));
        assert_eq!(FractionMode::Off.id(), "off");
    }
}
