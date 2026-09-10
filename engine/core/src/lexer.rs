//! 词法分析。
//!
//! 设计约定：
//! 1. **Span 一律是 char 偏移**（不是字节偏移），Dart 侧可直接 `substring`。
//! 2. 本层**不做隐式乘法**，只产出线性记号流；隐式乘法由 parser 判定。
//! 3. `1e9` 必须在这一层被识别成一个数字，否则会退化成 `1*e*9`（架构 §3.7 警告）。

use crate::error::{EngineError, ErrorKind, Result};
use crate::num::Num;
use crate::span::Span;
use crate::token::{Token, TokenKind};

/// 词法分析器。
pub struct Lexer<'a> {
    src: &'a str,
    chars: Vec<char>,
    pos: usize,
}

impl<'a> Lexer<'a> {
    /// 基于源码构造。
    pub fn new(src: &'a str) -> Self {
        Self {
            src,
            chars: src.chars().collect(),
            pos: 0,
        }
    }

    /// 扫描出完整记号流（末尾必带 [`TokenKind::EOF`]）。
    pub fn tokenize(&mut self) -> Result<Vec<Token>> {
        let mut out = Vec::new();
        loop {
            let t = self.next_token()?;
            let is_eof = t.kind == TokenKind::EOF;
            out.push(t);
            if is_eof {
                break;
            }
        }
        Ok(out)
    }

    /// 当前源码（保留给调用方做错误上下文回显）。
    pub fn src(&self) -> &'a str {
        self.src
    }

    fn peek_at(&self, i: usize) -> Option<char> {
        self.chars.get(i).copied()
    }

    fn next_token(&mut self) -> Result<Token> {
        // 空白
        while let Some(c) = self.peek_at(self.pos) {
            if c.is_whitespace() {
                self.pos += 1;
            } else {
                break;
            }
        }
        let start = self.pos;
        let c = match self.peek_at(self.pos) {
            Some(c) => c,
            None => {
                return Ok(Token::new(
                    TokenKind::EOF,
                    "",
                    Span::new(start, start),
                ))
            }
        };

        if c.is_ascii_digit() || (c == '.' && self.peek_at(start + 1).is_some_and(is_digit)) {
            return self.scan_number();
        }
        if c.is_alphabetic() || c == '_' {
            return Ok(self.scan_ident());
        }

        let kind = match c {
            '+' => TokenKind::Plus,
            '-' | '\u{2212}' => TokenKind::Minus,
            '*' | '\u{00D7}' | '\u{00B7}' | '\u{22C5}' => TokenKind::Star,
            '/' | '\u{00F7}' => TokenKind::Slash,
            '^' => TokenKind::Caret,
            '(' => TokenKind::LParen,
            ')' => TokenKind::RParen,
            ',' => TokenKind::Comma,
            '%' => TokenKind::Percent,
            '!' => TokenKind::Bang,
            '&' => TokenKind::And,
            '|' => TokenKind::Or,
            '~' => TokenKind::Not,
            '\u{2295}' => TokenKind::Xor,
            // 根号符号 √（U+221A）：作为单字符标识符流出，由 parser 按前缀函数（sqrt 别名）处理，
            // 与已支持的 `sin30` 同路径。后续数字/括号不并入标识符，保持运算符语义。
            '\u{221A}' => {
                self.pos += 1;
                return Ok(Token::new(
                    TokenKind::Ident,
                    "\u{221A}".to_string(),
                    Span::new(start, start + 1),
                ));
            }
            '=' => TokenKind::Assign,
            ':' if self.peek_at(start + 1) == Some('=') => {
                self.pos += 2;
                return Ok(Token::new(
                    TokenKind::Assign,
                    ":=",
                    Span::new(start, start + 2),
                ));
            }
            '<' if self.peek_at(start + 1) == Some('<') => {
                self.pos += 2;
                return Ok(Token::new(TokenKind::Shl, "<<", Span::new(start, start + 2)));
            }
            '>' if self.peek_at(start + 1) == Some('>') => {
                self.pos += 2;
                return Ok(Token::new(TokenKind::Shr, ">>", Span::new(start, start + 2)));
            }
            _ => {
                self.pos += 1;
                return Err(EngineError::full(
                    ErrorKind::UnexpectedCharacter,
                    Span::new(start, start + 1),
                    format!("无法识别的字符 “{}”", c),
                ));
            }
        };
        self.pos += 1;
        Ok(Token::new(
            kind,
            c.to_string(),
            Span::new(start, start + 1),
        ))
    }

    fn scan_ident(&mut self) -> Token {
        let start = self.pos;
        let mut i = start;
        // 首字符已确认是字母或 '_'
        i += 1;
        while let Some(c) = self.peek_at(i) {
            if c.is_alphanumeric() || c == '_' {
                i += 1;
            } else {
                break;
            }
        }
        self.pos = i;
        let text: String = self.chars[start..i].iter().collect();
        Token::new(TokenKind::Ident, text, Span::new(start, i))
    }

    fn scan_number(&mut self) -> Result<Token> {
        let start = self.pos;
        let n = self.chars.len();
        if self.chars[start] == '0' && start + 1 < n {
            match self.chars[start + 1] {
                'x' | 'X' => return self.scan_radix(start, 16),
                'b' | 'B' => return self.scan_radix(start, 2),
                'o' | 'O' => return self.scan_radix(start, 8),
                _ => {}
            }
        }
        let mut i = start;
        let mut seen_dot = false;
        while i < n {
            let c = self.chars[i];
            if c.is_ascii_digit() || c == '_' {
                i += 1;
            } else if c == '.' && !seen_dot {
                seen_dot = true;
                i += 1;
            } else {
                break;
            }
        }
        // 科学计数法：只有紧跟 e/E 且后面确实是 [+/-]数字 才吞掉，避免把 3e 拆成 3*e
        if i < n && (self.chars[i] == 'e' || self.chars[i] == 'E') {
            let mut j = i + 1;
            if j < n && (self.chars[j] == '+' || self.chars[j] == '-') {
                j += 1;
            }
            if j < n && self.chars[j].is_ascii_digit() {
                let mut k = j;
                while k < n && (self.chars[k].is_ascii_digit() || self.chars[k] == '_') {
                    k += 1;
                }
                i = k;
            }
        }
        self.pos = i;
        let text: String = self.chars[start..i].iter().collect();
        Ok(Token::new(TokenKind::Number, text, Span::new(start, i)))
    }

    fn scan_radix(&mut self, start: usize, radix: u32) -> Result<Token> {
        let n = self.chars.len();
        let mut i = start + 2;
        let mut digits = 0usize;
        while i < n {
            let c = self.chars[i];
            if c == '_' {
                i += 1;
                continue;
            }
            if c.is_digit(radix) {
                digits += 1;
                i += 1;
            } else {
                break;
            }
        }
        if digits == 0 {
            return Err(EngineError::full(
                ErrorKind::InvalidNumberLiteral,
                Span::new(start, i),
                "进制前缀后缺少数字",
            ));
        }
        self.pos = i;
        let text: String = self.chars[start..i].iter().collect();
        Ok(Token::new(TokenKind::Number, text, Span::new(start, i)))
    }
}

fn is_digit(c: char) -> bool {
    c.is_ascii_digit()
}

/// 便捷纯函数：源码 → 记号流。
pub fn tokenize(src: &str) -> Result<Vec<Token>> {
    Lexer::new(src).tokenize()
}

/// 从 `src` 开头尽量长地扫出一个数字字面量，返回结束下标（字符偏移）。
///
/// 供 [`crate::units::parse_convert_query`] 拆解 "12.7 inch in mm" 这类查询串使用，
/// 避免单位换算再手写一套数字识别。扫不出数字返回 `None`。
pub fn scan_number_prefix(src: &str) -> Option<usize> {
    let chars: Vec<char> = src.chars().collect();
    let n = chars.len();
    let mut i = 0usize;
    if i < n && (chars[i] == '+' || chars[i] == '-' || chars[i] == '\u{2212}') {
        i += 1;
    }
    if chars.get(i).is_some_and(|c| *c == '0') {
        if let Some(c) = chars.get(i + 1) {
            match c {
                'x' | 'X' => return scan_radix_prefix(&chars, 16),
                'b' | 'B' => return scan_radix_prefix(&chars, 2),
                'o' | 'O' => return scan_radix_prefix(&chars, 8),
                _ => {}
            }
        }
    }
    let start_digits = i;
    let mut seen_dot = false;
    while i < n {
        let c = chars[i];
        if c.is_ascii_digit() || c == '_' {
            i += 1;
        } else if c == '.' && !seen_dot {
            seen_dot = true;
            i += 1;
        } else {
            break;
        }
    }
    if i == start_digits {
        return None;
    }
    if i < n && (chars[i] == 'e' || chars[i] == 'E') {
        let mut j = i + 1;
        if j < n && (chars[j] == '+' || chars[j] == '-') {
            j += 1;
        }
        if j < n && chars[j].is_ascii_digit() {
            let mut k = j;
            while k < n && (chars[k].is_ascii_digit() || chars[k] == '_') {
                k += 1;
            }
            i = k;
        }
    }
    Some(i)
}

fn scan_radix_prefix(chars: &[char], radix: u32) -> Option<usize> {
    let n = chars.len();
    let mut i = 2usize;
    let mut digits = 0usize;
    while i < n {
        let c = chars[i];
        if c == '_' {
            i += 1;
            continue;
        }
        if c.is_digit(radix) {
            digits += 1;
            i += 1;
        } else {
            break;
        }
    }
    if digits == 0 {
        None
    } else {
        Some(i)
    }
}

/// 把数字字面量文本解析成 [`Num`]。
///
/// 十进制走**精确有理路径**（`0.1` → `1/10`），这是 `0.1+0.2 == 0.3` 得以成立的前提；
/// 只有超长/超大小数才降级 f64。
pub fn parse_number_literal(text: &str) -> Result<Num> {
    let t = text.replace('_', "");
    let lower = t.to_ascii_lowercase();
    if let Some(body) = lower.strip_prefix("0x") {
        let v = i64::from_str_radix(body, 16)
            .map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral))?;
        return Ok(Num::int(v));
    }
    if let Some(body) = lower.strip_prefix("0b") {
        let v = i64::from_str_radix(body, 2)
            .map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral))?;
        return Ok(Num::int(v));
    }
    if let Some(body) = lower.strip_prefix("0o") {
        let v = i64::from_str_radix(body, 8)
            .map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral))?;
        return Ok(Num::int(v));
    }

    let (mant, exp) = match t.find(['e', 'E']) {
        Some(p) => (&t[..p], t[p + 1..].parse::<i32>().unwrap_or(0)),
        None => (t.as_str(), 0i32),
    };
    let (int_part, frac_part) = match mant.find('.') {
        Some(p) => (&mant[..p], &mant[p + 1..]),
        None => (mant, ""),
    };
    if int_part.is_empty() && frac_part.is_empty() {
        return Err(EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    let mut digits = String::new();
    digits.push_str(int_part);
    digits.push_str(frac_part);
    if digits.is_empty() {
        return Err(EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    let scale = exp - frac_part.len() as i32;

    let parsed = digits.parse::<i128>().ok();
    match (parsed, scale) {
        (Some(d), s) if s >= 0 => match pow10_i128(s as u32).and_then(|p| d.checked_mul(p)) {
            Some(v) if v >= i64::MIN as i128 && v <= i64::MAX as i128 => Ok(Num::int(v as i64)),
            _ => Ok(Num::float(t.parse::<f64>().unwrap_or(f64::NAN))),
        },
        (Some(d), s) => {
            let k = (-s) as u32;
            match pow10_i128(k) {
                Some(p) if p <= i64::MAX as i128 && d <= i64::MAX as i128 => {
                    Num::rational(d as i64, p as i64)
                }
                _ => Ok(Num::float(t.parse::<f64>().unwrap_or(f64::NAN))),
            }
        }
        (None, _) => Ok(Num::float(t.parse::<f64>().unwrap_or(f64::NAN))),
    }
}

fn pow10_i128(e: u32) -> Option<i128> {
    let mut r: i128 = 1;
    for _ in 0..e {
        r = r.checked_mul(10)?;
    }
    Some(r)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn kinds(src: &str) -> Vec<TokenKind> {
        tokenize(src).unwrap().iter().map(|t| t.kind).collect()
    }

    #[test]
    fn scientific_notation_is_one_number() {
        assert_eq!(
            kinds("1e9"),
            vec![TokenKind::Number, TokenKind::EOF]
        );
        assert_eq!(parse_number_literal("1e9").unwrap(), Num::int(1_000_000_000));
    }

    #[test]
    fn three_e_is_implicit_multiply() {
        // 3e 后面没有数字 → 不吞 e，交给 parser 做 3*e
        assert_eq!(
            kinds("3e"),
            vec![TokenKind::Number, TokenKind::Ident, TokenKind::EOF]
        );
    }

    #[test]
    fn radix_literals() {
        assert_eq!(parse_number_literal("0x1F").unwrap(), Num::int(31));
        assert_eq!(parse_number_literal("0b1010").unwrap(), Num::int(10));
        assert_eq!(parse_number_literal("0o17").unwrap(), Num::int(15));
        assert!(parse_number_literal("0x").is_err());
    }

    #[test]
    fn decimals_become_exact_rationals() {
        assert_eq!(
            parse_number_literal("0.1").unwrap(),
            Num::rational(1, 10).unwrap()
        );
        assert_eq!(
            parse_number_literal(".5").unwrap(),
            Num::rational(1, 2).unwrap()
        );
        assert_eq!(parse_number_literal("1_000").unwrap(), Num::int(1000));
        assert_eq!(
            parse_number_literal("1.5e-9").unwrap(),
            Num::rational(15, 10_000_000_000).unwrap()
        );
    }

    #[test]
    fn spans_are_char_offsets() {
        let toks = tokenize("2π+1").unwrap();
        assert_eq!(toks[0].span, Span::new(0, 1));
        assert_eq!(toks[1].span, Span::new(1, 2)); // π 是 1 个 char
        assert_eq!(toks[2].span, Span::new(2, 3));
        assert_eq!(toks[3].span, Span::new(3, 4));
    }

    #[test]
    fn unicode_operator_aliases() {
        assert_eq!(kinds("2×3"), vec![TokenKind::Number, TokenKind::Star, TokenKind::Number, TokenKind::EOF]);
        assert_eq!(kinds("6÷2"), vec![TokenKind::Number, TokenKind::Slash, TokenKind::Number, TokenKind::EOF]);
        assert_eq!(kinds("5−1"), vec![TokenKind::Number, TokenKind::Minus, TokenKind::Number, TokenKind::EOF]);
    }

    #[test]
    fn epsilon_subscript_is_single_ident() {
        let toks = tokenize("ε₀").unwrap();
        assert_eq!(toks[0].kind, TokenKind::Ident);
        assert_eq!(toks[0].text, "ε₀");
        assert_eq!(toks[0].span, Span::new(0, 2));
    }

    #[test]
    fn unknown_character_reports_span() {
        let e = tokenize("1 # 2").unwrap_err();
        assert_eq!(e.kind, ErrorKind::UnexpectedCharacter);
        assert_eq!(e.span, Some(Span::new(2, 3)));
    }

    #[test]
    fn scan_number_prefix_for_unit_query() {
        assert_eq!(scan_number_prefix("12.7 inch in mm"), Some(4));
        assert_eq!(scan_number_prefix("-3.5 kg"), Some(4));
        assert_eq!(scan_number_prefix("0x1F"), Some(4));
        assert_eq!(scan_number_prefix("inch"), None);
    }
}
