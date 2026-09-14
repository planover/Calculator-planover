//! 用户自定义模式串（RF-X，PRD-INCREMENT-v2 §6.5）。
//!
//! 职责：**校验**用户手输的数字/日期时间模式串并给出明确错误码（RF-X-03），
//! 以及按已校验的日期时间模式渲染（RF-X-02）。纯自包含实现——不引入
//! chrono/ICU 等依赖（架构 C7 内核精简；A2 裁决下完整时间/日期本地化在 Dart 侧）。

use crate::error::{EngineError, ErrorKind, Result};

/// 模式串校验错误（RF-X-03 要求逐类给出明确错误码）。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PatternError {
    /// 出现不允许的字符。
    IllegalChar,
    /// 出现未知占位符（如 `YYYY`——大小写敏感）。
    UnknownPlaceholder,
    /// 括号/方括号不配对。
    UnbalancedBracket,
    /// 模式串超长（> 64 字符）。
    TooLong,
}

impl PatternError {
    /// 稳定错误码（对外契约，勿改动既有取值）。
    pub fn code(&self) -> &'static str {
        match self {
            PatternError::IllegalChar => "illegal_char",
            PatternError::UnknownPlaceholder => "unknown_placeholder",
            PatternError::UnbalancedBracket => "unbalanced_bracket",
            PatternError::TooLong => "too_long",
        }
    }

    /// 中文错误说明。
    pub fn message(&self) -> &'static str {
        match self {
            PatternError::IllegalChar => "模式串含有非法字符",
            PatternError::UnknownPlaceholder => "模式串含有未知占位符（大小写敏感）",
            PatternError::UnbalancedBracket => "模式串括号不配对",
            PatternError::TooLong => "模式串超过 64 字符上限",
        }
    }
}

/// 模式串长度上限。
pub const MAX_PATTERN_LEN: usize = 64;

/// 日期时间模式允许的占位符字母。
const DT_PLACEHOLDERS: [char; 6] = ['y', 'M', 'd', 'H', 'm', 's'];
/// 日期时间模式允许的字面分隔字符。
const DT_SEPARATORS: [char; 7] = ['-', '/', ':', '.', ',', ' ', '_'];

/// 校验**数字**模式串（RF-X-01）。允许数字、`#`、常见分隔符与括号（须配对）。
pub fn validate_number_pattern(s: &str) -> std::result::Result<(), PatternError> {
    if s.chars().count() > MAX_PATTERN_LEN {
        return Err(PatternError::TooLong);
    }
    let mut paren_depth = 0i32;
    let mut bracket_depth = 0i32;
    for c in s.chars() {
        match c {
            '(' => paren_depth += 1,
            ')' => {
                paren_depth -= 1;
                if paren_depth < 0 {
                    return Err(PatternError::UnbalancedBracket);
                }
            }
            '[' => bracket_depth += 1,
            ']' => {
                bracket_depth -= 1;
                if bracket_depth < 0 {
                    return Err(PatternError::UnbalancedBracket);
                }
            }
            '0'..='9' | '#' | '.' | ',' | '-' | '+' | ' ' | '\'' | '\u{066C}' | '\u{066B}'
            | '\u{00A0}' | '%' | '‰' => {}
            c if c.is_alphabetic() => return Err(PatternError::IllegalChar),
            _ => return Err(PatternError::IllegalChar),
        }
    }
    if paren_depth != 0 || bracket_depth != 0 {
        return Err(PatternError::UnbalancedBracket);
    }
    Ok(())
}

/// 校验**日期时间**模式串（RF-X-02/03）。
///
/// 合法占位符（大小写敏感）：`yyyy` `yy` `MM` `M` `dd` `d` `HH` `H` `mm` `m` `ss` `s` `tt`；
/// 其余字母一律 `UnknownPlaceholder`；括号不配对 → `UnbalancedBracket`；
/// 超过 64 字符 → `TooLong`；其它非法符号 → `IllegalChar`。
pub fn validate_datetime_pattern(s: &str) -> std::result::Result<(), PatternError> {
    if s.chars().count() > MAX_PATTERN_LEN {
        return Err(PatternError::TooLong);
    }
    let chars: Vec<char> = s.chars().collect();
    let mut i = 0usize;
    let mut paren_depth = 0i32;
    let mut bracket_depth = 0i32;
    while i < chars.len() {
        let c = chars[i];
        match c {
            '(' => paren_depth += 1,
            ')' => {
                paren_depth -= 1;
                if paren_depth < 0 {
                    return Err(PatternError::UnbalancedBracket);
                }
            }
            '[' => bracket_depth += 1,
            ']' => {
                bracket_depth -= 1;
                if bracket_depth < 0 {
                    return Err(PatternError::UnbalancedBracket);
                }
            }
            't' => {
                // 只接受 `tt`（AM/PM）；单个 `t` 视为未知占位符。
                if i + 1 < chars.len() && chars[i + 1] == 't' {
                    i += 2;
                    continue;
                }
                return Err(PatternError::UnknownPlaceholder);
            }
            c if DT_PLACEHOLDERS.contains(&c) => {
                // 连续同字母占位（yyyy / MM / dd / HH / mm / ss / 单字母）。
                let run = chars[i..].iter().take_while(|&&x| x == c).count();
                i += run;
                continue;
            }
            c if DT_SEPARATORS.contains(&c) || c.is_ascii_digit() => {}
            // ASCII 字母：合法占位符已在上面 `DT_PLACEHOLDERS` 分支放行，
            // 走到这里说明是**大小写不符或拼错的占位符**（如 `Y`/`D`/`q`），
            // 归类为 `UnknownPlaceholder` 以给出更准确的错误码（RF-X-03）。
            c if c.is_ascii_alphabetic() => return Err(PatternError::UnknownPlaceholder),
            // 非 ASCII 字面字符（如 `年`/`月`/`日`、本地化文本）放行。
            c if !c.is_ascii() => {}
            _ => return Err(PatternError::IllegalChar),
        }
        i += 1;
    }
    if paren_depth != 0 || bracket_depth != 0 {
        return Err(PatternError::UnbalancedBracket);
    }
    Ok(())
}

/// 把已校验的日期时间模式应用到 Unix 时间戳（秒，UTC）上（RF-X-02）。
///
/// 占位符：`yyyy` 四位年、`yy` 两年、`MM` 两位月、`M` 月、`dd`/`d` 日、
/// `HH`/`H` 时（24 制）、`mm`/`m` 分、`ss`/`s` 秒、`tt` AM/PM。
/// 模式串未校验时先行校验；`tt` 需要配 `am`/`pm` 文案。
pub fn format_datetime_with_pattern(
    unix_secs: i64,
    pattern: &str,
    am: &str,
    pm: &str,
) -> Result<String> {
    validate_datetime_pattern(pattern).map_err(|e| {
        EngineError::with_message(
            ErrorKind::InvalidSettings,
            format!("非法日期时间模式串（{}）：{}", e.code(), e.message()),
        )
    })?;
    let days = unix_secs.div_euclid(86_400);
    let secs_of_day = unix_secs.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);
    let (h, m, sec) = (
        secs_of_day / 3600,
        (secs_of_day % 3600) / 60,
        secs_of_day % 60,
    );
    let is_pm = h >= 12;

    let chars: Vec<char> = pattern.chars().collect();
    let mut out = String::new();
    let mut i = 0usize;
    while i < chars.len() {
        let c = chars[i];
        if c == 't' {
            // validate 已保证 `tt` 成对出现。
            out.push_str(if is_pm { pm } else { am });
            i += 2;
            continue;
        }
        if DT_PLACEHOLDERS.contains(&c) {
            let run = chars[i..].iter().take_while(|&&x| x == c).count();
            let token: String = chars[i..i + run].iter().collect();
            out.push_str(&expand_placeholder(&token, year, month, day, h, m, sec));
            i += run;
            continue;
        }
        out.push(c);
        i += 1;
    }
    Ok(out)
}

/// 展开单个占位符。
fn expand_placeholder(
    token: &str,
    year: i64,
    month: u32,
    day: u32,
    h: i64,
    m: i64,
    sec: i64,
) -> String {
    match token {
        "yyyy" => format!("{:04}", year),
        "yy" => format!("{:02}", year.rem_euclid(100)),
        "MM" => format!("{:02}", month),
        "M" => month.to_string(),
        "dd" => format!("{:02}", day),
        "d" => day.to_string(),
        "HH" => format!("{:02}", h),
        "H" => h.to_string(),
        "mm" => format!("{:02}", m),
        "m" => m.to_string(),
        "ss" => format!("{:02}", sec),
        "s" => sec.to_string(),
        other => other.to_string(),
    }
}

/// 天数（自 1970-01-01 起）→ (年, 月, 日)，Howard Hinnant 民用历算法（公有领域）。
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as i64; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365; // [0, 399]
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; // [1, 31]
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32; // [1, 12]
    (if m <= 2 { y + 1 } else { y }, m, d)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn datetime_valid_patterns_pass() {
        assert!(validate_datetime_pattern("yyyy-MM-dd").is_ok());
        assert!(validate_datetime_pattern("HH:mm:ss").is_ok());
        assert!(validate_datetime_pattern("yyyy/MM/dd HH:mm tt").is_ok());
        assert!(validate_datetime_pattern("yyyy年MM月dd日").is_ok()); // 非 ASCII 字面字符放行
    }

    #[test]
    fn datetime_illegal_patterns_return_expected_codes() {
        // RF-X-03：≥ 8 条非法串，逐条断言错误码。
        assert_eq!(
            validate_datetime_pattern("YYYY-MM-dd"),
            Err(PatternError::UnknownPlaceholder)
        );
        assert_eq!(
            validate_datetime_pattern("yyyy-MM-ddq"),
            Err(PatternError::UnknownPlaceholder)
        );
        assert_eq!(
            validate_datetime_pattern("yyyy-MM-dd("),
            Err(PatternError::UnbalancedBracket)
        );
        assert_eq!(
            validate_datetime_pattern("yyyy]dd"),
            Err(PatternError::UnbalancedBracket)
        );
        assert_eq!(
            validate_datetime_pattern("yyyy-MM-dd$"),
            Err(PatternError::IllegalChar)
        );
        assert_eq!(
            validate_datetime_pattern("HH;mm"),
            Err(PatternError::IllegalChar)
        );
        assert_eq!(
            validate_datetime_pattern("yyyy-MM-dd t"),
            Err(PatternError::UnknownPlaceholder)
        );
        let long = "y".repeat(MAX_PATTERN_LEN + 1);
        assert_eq!(
            validate_datetime_pattern(&long),
            Err(PatternError::TooLong)
        );
    }

    #[test]
    fn number_pattern_validation() {
        assert!(validate_number_pattern("0.00").is_ok());
        assert!(validate_number_pattern("#,##0.00").is_ok());
        assert_eq!(
            validate_number_pattern("0.0a"),
            Err(PatternError::IllegalChar)
        );
        assert_eq!(
            validate_number_pattern("(0.0"),
            Err(PatternError::UnbalancedBracket)
        );
    }

    #[test]
    fn datetime_rendering() {
        // 2026-09-11 09:00:05 UTC
        let t = 1_789_117_205i64;
        assert_eq!(
            format_datetime_with_pattern(t, "yyyy-MM-dd", "AM", "PM").unwrap(),
            "2026-09-11"
        );
        assert_eq!(
            format_datetime_with_pattern(t, "HH:mm:ss", "AM", "PM").unwrap(),
            "09:00:05"
        );
        assert_eq!(
            format_datetime_with_pattern(t, "yyyy/MM/dd HH:mm tt", "上午", "下午").unwrap(),
            "2026/09/11 09:00 上午"
        );
        assert_eq!(
            format_datetime_with_pattern(t, "dd.MM.yy", "AM", "PM").unwrap(),
            "11.09.26"
        );
        // 非法模式串 → InvalidSettings
        assert!(format_datetime_with_pattern(t, "YYYY", "AM", "PM").is_err());
    }
}
