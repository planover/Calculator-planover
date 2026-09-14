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
    /// 工程记数法：指数对齐到 3 的倍数（`1234.5` → `1.2345×10³`）。
    Engineering,
    /// 定点。
    Fixed,
}

impl Notation {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            Notation::Auto => "auto",
            Notation::Scientific => "scientific",
            Notation::Engineering => "engineering",
            Notation::Fixed => "fixed",
        }
    }

    /// 从标识解析；未知返回 `None`。
    pub fn from_id(s: &str) -> Option<Notation> {
        match s.trim().to_lowercase().as_str() {
            "auto" => Some(Notation::Auto),
            "scientific" => Some(Notation::Scientific),
            "engineering" | "eng" => Some(Notation::Engineering),
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

// ── 区域格式（A1：RF-N/RF-C，PRD-INCREMENT-v2 §6）───────────────────────────
//
// 契约见 `docs/ARCHITECTURE-INCREMENT-v2.md` §3.1：全部字段 `Option`，
// 缺省 = 现状行为（`.` 小数点 / `,` 千分位 / `3;0` / 显示前导零 / `-1.1`），
// 因此不传 `RegionFormatConfig` 时既有 238 个测试逐字节不变。

/// 分组方式（RF-N-04）：标准 `3;0`（123,456,789）或印度式 `3;2;0`（12,34,56,789）。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub enum GroupPattern {
    /// `3;0` —— 每三位一组。
    #[serde(rename = "3;0")]
    Standard,
    /// `3;2;0` —— 印度式：末组三位、其余每两位一组。
    #[serde(rename = "3;2;0")]
    Indian,
}

impl Default for GroupPattern {
    fn default() -> Self {
        GroupPattern::Standard
    }
}

/// 负数格式 5 种（RF-N-06，对齐 Win11「负数格式」）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum NegativeNumberFormat {
    /// `-1.1`（现状默认）。
    #[default]
    MinusPlain,
    /// `- 1.1`。
    MinusSpace,
    /// `(1.1)`。
    MinusParen,
    /// `1.1-`。
    TrailingMinus,
    /// `1.1 -`。
    TrailingMinusSpace,
}

/// 货币符号相对金额的位置 4 种（RF-C-02）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CurrencyPositiveFormat {
    /// `$1.1`。
    #[default]
    Before,
    /// `1.1$`。
    After,
    /// `$ 1.1`。
    BeforeSpace,
    /// `1.1 $`。
    AfterSpace,
}

/// 货币负数符号位 4 种（RF-C-03 的"符号"维度）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CurrencyNegativeSign {
    /// `($1.1)`。
    #[default]
    Paren,
    /// `-$1.1`。
    Before,
    /// `- $1.1`。
    BeforeSpace,
    /// `$1.1-`。
    Trailing,
}

/// 货币负数格式 = 符号位(4) × 货币位置(4) = **16 种**（RF-C-03）。
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, serde::Deserialize, serde::Serialize)]
pub struct CurrencyNegativeFormat {
    /// 负号/括号的位置。
    #[serde(default)]
    pub sign: CurrencyNegativeSign,
    /// 货币符号相对金额的位置。
    #[serde(default)]
    pub symbol: CurrencyPositiveFormat,
}

/// 货币格式配置（RF-C-01~07）；全部可选 → 缺省沿用各自默认。
#[derive(Debug, Clone, Default, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct CurrencyFormatConfig {
    /// 货币符号或 ISO 4217 代码（RF-C-01），默认 `¥`。
    #[serde(default)]
    pub symbol: Option<String>,
    /// 正数格式（RF-C-02），默认 `before`。
    #[serde(default)]
    pub positive_format: Option<CurrencyPositiveFormat>,
    /// 负数格式（RF-C-03），默认 `{sign: paren, symbol: before}`。
    #[serde(default)]
    pub negative_format: Option<CurrencyNegativeFormat>,
    /// 货币小数分隔符（RF-C-04），独立于普通小数分隔符。
    #[serde(default)]
    pub decimal_separator: Option<String>,
    /// 货币小数位数 0~9（RF-C-05，如 JPY=0、CNY=2），默认 2。
    #[serde(default)]
    pub decimal_digits: Option<u8>,
    /// 货币千分位（RF-C-06），独立于普通千分位。
    #[serde(default)]
    pub group_separator: Option<String>,
    /// 货币分组方式（RF-C-06）。
    #[serde(default)]
    pub group_pattern: Option<GroupPattern>,
}

/// 区域格式配置（A1）。
///
/// **全部字段 `Option`**：缺省 = 现状行为（`RegionStyle::default()`），
/// 保证 `format_number` / `evaluate_*` 既有行为逐字节一致（架构 §3.4）。
#[derive(Debug, Clone, Default, PartialEq, serde::Deserialize, serde::Serialize)]
pub struct RegionFormatConfig {
    /// 小数分隔符（RF-N-01）：`.` / `,` / `٫` / 空格 / 自定义 1 字符。
    #[serde(default)]
    pub decimal_separator: Option<String>,
    /// 千分位分组符（RF-N-03）：`,` / `.` / `'` / 空格 / `٬` / 自定义；空串 = 不分组。
    #[serde(default)]
    pub group_separator: Option<String>,
    /// 分组方式（RF-N-04）：`3;0` / `3;2;0`。
    #[serde(default)]
    pub group_pattern: Option<GroupPattern>,
    /// 显示前导零（RF-N-07）：false 时 `0.5` 显示为 `.5`。
    #[serde(default)]
    pub leading_zero: Option<bool>,
    /// 负数格式（RF-N-06）5 选 1。
    #[serde(default)]
    pub negative_format: Option<NegativeNumberFormat>,
    /// 列表分隔符（RF-N-09，P2）。
    #[serde(default)]
    pub list_separator: Option<String>,
    /// 货币格式（RF-C-01~07）。
    #[serde(default)]
    pub currency: Option<CurrencyFormatConfig>,
}

impl RegionFormatConfig {
    /// 校验：分隔符长度 ≤ 1、货币小数位 0~9。非法返回 `InvalidSettings`。
    pub fn validate(&self) -> Result<()> {
        let check = |name: &str, v: &Option<String>| -> Result<()> {
            if let Some(s) = v {
                if s.chars().count() > 1 {
                    return Err(EngineError::with_message(
                        ErrorKind::InvalidSettings,
                        format!("非法区域格式：{} 长度必须 ≤ 1 字符", name),
                    ));
                }
            }
            Ok(())
        };
        check("decimal_separator", &self.decimal_separator)?;
        check("group_separator", &self.group_separator)?;
        check("list_separator", &self.list_separator)?;
        if let Some(c) = &self.currency {
            check("currency.decimal_separator", &c.decimal_separator)?;
            check("currency.group_separator", &c.group_separator)?;
            if let Some(d) = c.decimal_digits {
                if d > 9 {
                    return Err(EngineError::with_message(
                        ErrorKind::InvalidSettings,
                        format!("非法区域格式：currency.decimal_digits 必须介于 0~9，实得 {}", d),
                    ));
                }
            }
        }
        Ok(())
    }

    /// 解析为完整渲染风格；`grouping` 来自 `NumberFormatSettings.grouping`。
    pub fn resolve_with(&self, grouping: bool) -> RegionStyle {
        RegionStyle {
            grouping,
            decimal_separator: self
                .decimal_separator
                .clone()
                .unwrap_or_else(|| ".".to_string()),
            group_separator: self
                .group_separator
                .clone()
                .unwrap_or_else(|| ",".to_string()),
            group_pattern: self.group_pattern.unwrap_or(GroupPattern::Standard),
            leading_zero: self.leading_zero.unwrap_or(true),
            negative_format: self.negative_format.unwrap_or_default(),
        }
    }
}

/// 解析后的区域渲染风格（`None` 已落默认值）。
#[derive(Debug, Clone, PartialEq)]
pub struct RegionStyle {
    /// 是否启用千分位分组（继承自 `NumberFormatSettings.grouping`）。
    pub grouping: bool,
    /// 小数分隔符。
    pub decimal_separator: String,
    /// 千分位分组符；空串 = 不分组。
    pub group_separator: String,
    /// 分组方式。
    pub group_pattern: GroupPattern,
    /// 显示前导零。
    pub leading_zero: bool,
    /// 负数格式。
    pub negative_format: NegativeNumberFormat,
}

impl Default for RegionStyle {
    /// 与基线行为逐字节一致的默认：`.` / `,` / `3;0` / 前导零 / `-1.1`。
    fn default() -> Self {
        Self {
            grouping: true,
            decimal_separator: ".".to_string(),
            group_separator: ",".to_string(),
            group_pattern: GroupPattern::Standard,
            leading_zero: true,
            negative_format: NegativeNumberFormat::MinusPlain,
        }
    }
}

/// 校验设置；`precision` 越界返回 `InvalidSettings`。
///
/// 小数位模式下 `0` 合法（RF-N-02：小数位数取值 0~9，`0` 表示取整）；
/// 有效位模式下仍要求 `1~=15`（0 位有效数字无意义）。
pub fn validate(s: &NumberFormatSettings) -> Result<()> {
    let lo = match s.precision_mode {
        PrecisionMode::DecimalPlaces => 0,
        PrecisionMode::Significant => MIN_PRECISION,
    };
    if s.precision < lo || s.precision > MAX_PRECISION {
        return Err(EngineError::with_message(
            ErrorKind::InvalidSettings,
            format!(
                "精度必须介于 {}~{}，实得 {}",
                lo, MAX_PRECISION, s.precision
            ),
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

/// 千位分隔（自定义分隔符与分组方式；入参为**纯数字**整数部分，不含符号）。
///
/// `sep` 为空串时不分组。印度式（`3;2;0`）末组三位、其余每两位一组。
pub fn group_digits_with(int_part: &str, sep: &str, pattern: GroupPattern) -> String {
    let digits: String = int_part.chars().filter(|c| c.is_ascii_digit()).collect();
    if digits.len() <= 3 || sep.is_empty() {
        return digits;
    }
    let n = digits.len();
    let mut out = String::new();
    match pattern {
        GroupPattern::Standard => {
            for (i, c) in digits.chars().enumerate() {
                let from_right = n - i;
                if i > 0 && from_right % 3 == 0 {
                    out.push_str(sep);
                }
                out.push(c);
            }
        }
        GroupPattern::Indian => {
            // 123456789 → 12,34,56,789：末组 3 位，之前每 2 位一组。
            let head = n - 3;
            for (i, c) in digits.chars().enumerate() {
                if i > 0 {
                    let need_sep = if i < head {
                        (head - i) % 2 == 0
                    } else {
                        i == head
                    };
                    if need_sep {
                        out.push_str(sep);
                    }
                }
                out.push(c);
            }
        }
    }
    out
}

/// 千位分隔（默认 `,` + `3;0`；保留旧签名供既有调用与测试使用）。
pub fn group_digits(int_part: &str) -> String {
    group_digits_with(int_part, ",", GroupPattern::Standard)
}

/// 对可能带负号与小数部分的数字串应用区域风格：
/// 千分位分组（自定义分隔符/方式）+ 小数分隔符替换 + 前导零开关（RF-N-01/03/04/07）。
fn apply_group_styled(s: &str, st: &RegionStyle) -> String {
    let (sign, body) = match s.strip_prefix('-') {
        Some(b) => ("-", b),
        None => ("", s),
    };
    // RF-N-07：关闭前导零时 `0.5` → `.5`（仅整数部分恰为 0 的小数）。
    let body = if !st.leading_zero && body.starts_with("0.") {
        &body[1..]
    } else {
        body
    };
    let out = match body.split_once('.') {
        Some((i, f)) => {
            let gi = if st.grouping && !st.group_separator.is_empty() {
                group_digits_with(i, &st.group_separator, st.group_pattern)
            } else {
                i.to_string()
            };
            format!("{}{}{}", gi, st.decimal_separator, f)
        }
        None => {
            if st.grouping && !st.group_separator.is_empty() {
                group_digits_with(body, &st.group_separator, st.group_pattern)
            } else {
                body.to_string()
            }
        }
    };
    format!("{}{}", sign, out)
}

/// RF-N-06：把带 `-` 前缀的渲染结果改写为选定负数格式（`minus_plain` 恒等）。
fn apply_negative_format(rendered: &str, st: &RegionStyle) -> String {
    if st.negative_format == NegativeNumberFormat::MinusPlain || !rendered.starts_with('-') {
        return rendered.to_string();
    }
    let body = &rendered[1..];
    match st.negative_format {
        NegativeNumberFormat::MinusPlain => rendered.to_string(),
        NegativeNumberFormat::MinusSpace => format!("- {}", body),
        NegativeNumberFormat::MinusParen => format!("({})", body),
        NegativeNumberFormat::TrailingMinus => format!("{}-", body),
        NegativeNumberFormat::TrailingMinusSpace => format!("{} -", body),
    }
}

/// 把串中**第一个** `.` 换成区域小数分隔符（科学/工程记数法尾数专用——
/// 其余路径在 `apply_group_styled` 里按 int/frac 分割后直接拼接，避免歧义）。
fn swap_decimal(s: &str, sep: &str) -> String {
    if sep == "." {
        return s.to_string();
    }
    match s.find('.') {
        Some(i) => format!("{}{}{}", &s[..i], sep, &s[i + 1..]),
        None => s.to_string(),
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

fn render_plain(digits: &str, exp: i32, neg: bool, st: &RegionStyle) -> String {
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
    apply_group_styled(&out, st)
}

/// 科学计数法渲染：`1.23456789×10⁸`；指数为 0 时省略 `×10⁰`。
fn render_sci(digits: &str, exp: i32, neg: bool, st: &RegionStyle) -> String {
    let mant = if digits.len() <= 1 {
        digits.to_string()
    } else {
        format!("{}.{}", &digits[..1], &digits[1..])
    };
    let mant = trim_zeros(&mant);
    // RF-N-01：尾数里唯一的 `.` 换成区域小数分隔符。
    let mant = swap_decimal(&mant, &st.decimal_separator);
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

/// 工程记数法渲染：**指数对齐到 3 的倍数**，如 `1.2345×10³`、`12.3×10⁻³`。
///
/// `digits` 为有效数字串（不含小数点与符号），`exp` 为首位的十进制指数
/// （即 `值 = d.ddd… × 10^exp`）。对齐后的指数为 0 时省略 `×10⁰`。
fn render_engineering(digits: &str, exp: i32, neg: bool, st: &RegionStyle) -> String {
    // 把指数下调到 3 的倍数：mant_exp ∈ {0,1,2}，mantissa_exp 为 3 的倍数。
    let mant_exp = ((exp % 3) + 3) % 3;
    let mantissa_exp = exp - mant_exp;
    let point = (mant_exp + 1) as usize;
    let body = if digits.len() <= point {
        format!("{}{}", digits, "0".repeat(point - digits.len()))
    } else {
        format!("{}.{}", &digits[..point], &digits[point..])
    };
    let all_zero = digits.chars().all(|c| c == '0');
    let mut mant = trim_zeros(&body);
    if neg && !all_zero && mant != "0" {
        mant.insert(0, '-');
    }
    let mant = apply_group_styled(&mant, st);
    if mantissa_exp == 0 {
        mant
    } else {
        format!("{}×10{}", mant, superscript(mantissa_exp))
    }
}

/// 工程记数法的完整渲染：整数走全精度，其余走当前有效位数。
fn engineering_number(n: &Num, s: &NumberFormatSettings, st: &RegionStyle) -> String {
    if let Ok(i) = n.try_as_i64() {
        let digits = i.unsigned_abs().to_string();
        let exp = digits.len() as i32 - 1;
        return render_engineering(&digits, exp, i < 0, st);
    }
    let v = n.to_f64();
    let (digits, exp, neg) = sig_parts(v, s.precision);
    render_engineering(&digits, exp, neg, st)
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

/// 按设置格式化数值（默认区域风格，与既有行为逐字节一致）。
pub fn format_number(n: &Num, s: &NumberFormatSettings) -> Result<String> {
    format_number_styled(n, s, &RegionFormatConfig::default())
}

/// 按设置 + 区域格式格式化数值（A1：区域配置经 `set_region_format` 落会话）。
pub fn format_number_styled(
    n: &Num,
    s: &NumberFormatSettings,
    region: &RegionFormatConfig,
) -> Result<String> {
    let st = region.resolve_with(s.grouping);
    let rendered = format_number_inner(n, s, &st)?;
    Ok(apply_negative_format(&rendered, &st))
}

fn format_number_inner(n: &Num, s: &NumberFormatSettings, st: &RegionStyle) -> Result<String> {
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

    // 工程记数法：整数与小数统一处理，且**优先于**精确十进制捷径
    // （CP-08 要求 `0.0123` 显示为 `12.3×10⁻³` 而非精确串 `0.0123`）。
    if matches!(s.notation, Notation::Engineering) {
        return Ok(engineering_number(n, s, st));
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
            return Ok(render_sci(&digits, exp, neg, st));
        }
        let t = i.to_string();
        return Ok(apply_group_styled(&t, st));
    }

    // 有限十进制的有理数：精度放得下就用精确串
    if let Num::Rational { num, den } = n {
        if let Some(exact) = exact_decimal_string(*num, *den) {
            if precision_fits(&exact, s) {
                return Ok(apply_group_styled(&exact, st));
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
                render_sci(&digits, exp, neg, st)
            } else {
                render_plain(&digits, exp, neg, st)
            })
        }
        PrecisionMode::DecimalPlaces => {
            if matches!(s.notation, Notation::Scientific) {
                let e = decimal_exponent(v);
                let sig = (e + 1 + s.precision as i32).clamp(1, MAX_PRECISION as i32) as u8;
                let (d, e2, neg) = sig_parts(v, sig);
                Ok(render_sci(&d, e2, neg, st))
            } else {
                let t = format!("{:.*}", s.precision as usize, v);
                Ok(apply_group_styled(&trim_zeros(&t), st))
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
    render_sci(&d, e, neg, &RegionStyle::default())
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
                render_sci(&d, e, neg, &RegionStyle::default())
            } else {
                render_plain(&d, e, neg, &RegionStyle { grouping: false, ..RegionStyle::default() })
            }
        }
    }
}

// ── 货币格式化（RF-C-01~07，A1/Q8）─────────────────────────────────────────

/// 货币渲染结果：`display` 为该值本身的渲染，`negative_display` 为取负后的渲染
/// （RF-C-03 的 16 种组合）。
#[derive(Debug, Clone, PartialEq)]
pub struct CurrencyRender {
    /// 正值渲染，如 `¥3.50`。
    pub display: String,
    /// 取负后的渲染，如 `(¥3.50)`。
    pub negative_display: String,
}

/// 按货币符号位置摆放符号（RF-C-02 的 4 种）。
fn place_symbol(amount: &str, symbol: &str, fmt: CurrencyPositiveFormat) -> String {
    match fmt {
        CurrencyPositiveFormat::Before => format!("{}{}", symbol, amount),
        CurrencyPositiveFormat::After => format!("{}{}", amount, symbol),
        CurrencyPositiveFormat::BeforeSpace => format!("{} {}", symbol, amount),
        CurrencyPositiveFormat::AfterSpace => format!("{} {}", amount, symbol),
    }
}

/// 按 RF-C-03 的符号位包裹负数金额（金额须为**无符号**串）。
fn wrap_negative(signed: String, sign: CurrencyNegativeSign) -> String {
    match sign {
        CurrencyNegativeSign::Paren => format!("({})", signed),
        CurrencyNegativeSign::Before => format!("-{}", signed),
        CurrencyNegativeSign::BeforeSpace => format!("- {}", signed),
        CurrencyNegativeSign::Trailing => format!("{}-", signed),
    }
}

/// 货币金额：按货币小数位**定点**渲染（保留尾零，`3.5` → `3.50`），
/// 使用货币自己的分隔符/分组方式（RF-C-04/05/06）。
fn currency_amount(abs: f64, digits: u8, st: &RegionStyle) -> String {
    let s = format!("{:.*}", digits as usize, abs);
    let (int_part, frac) = match s.split_once('.') {
        Some((i, f)) => (i, Some(f)),
        None => (s.as_str(), None),
    };
    let gi = if st.grouping && !st.group_separator.is_empty() {
        group_digits_with(int_part, &st.group_separator, st.group_pattern)
    } else {
        int_part.to_string()
    };
    match frac {
        Some(f) => format!("{}{}{}", gi, st.decimal_separator, f),
        None => gi,
    }
}

/// 货币格式化（RF-C-01~07）。
///
/// 金额取绝对值渲染、再按正/负格式摆放符号；特殊值（非有限）返回 `InvalidSettings`。
pub fn format_currency_pair(
    v: &Num,
    cfg: &CurrencyFormatConfig,
    _region: &RegionFormatConfig,
) -> Result<CurrencyRender> {
    let f = v.to_f64();
    if !f.is_finite() {
        return Err(EngineError::with_message(
            ErrorKind::InvalidSettings,
            "货币格式化需要有限数值".to_string(),
        ));
    }
    let symbol = cfg.symbol.clone().unwrap_or_else(|| "¥".to_string());
    let pos_fmt = cfg.positive_format.unwrap_or_default();
    let neg_fmt = cfg.negative_format.unwrap_or_default();
    let digits = cfg.decimal_digits.unwrap_or(2).min(9);
    let st = RegionStyle {
        grouping: true,
        decimal_separator: cfg
            .decimal_separator
            .clone()
            .unwrap_or_else(|| ".".to_string()),
        group_separator: cfg
            .group_separator
            .clone()
            .unwrap_or_else(|| ",".to_string()),
        group_pattern: cfg.group_pattern.unwrap_or(GroupPattern::Standard),
        leading_zero: true,
        negative_format: NegativeNumberFormat::MinusPlain,
    };

    let amount = currency_amount(f, digits, &st);
    let display = if f < 0.0 {
        wrap_negative(place_symbol(&amount, &symbol, neg_fmt.symbol), neg_fmt.sign)
    } else {
        place_symbol(&amount, &symbol, pos_fmt)
    };
    let neg_amount = currency_amount(-f, digits, &st);
    let negative_display =
        wrap_negative(place_symbol(&neg_amount, &symbol, neg_fmt.symbol), neg_fmt.sign);
    Ok(CurrencyRender {
        display,
        negative_display,
    })
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
