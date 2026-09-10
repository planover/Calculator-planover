//! 词法记号定义。

use serde::{Deserialize, Serialize};

use crate::span::Span;

/// 记号类别。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TokenKind {
    /// 数字字面量：十进制 / `0x` / `0b` / `0o` / 科学计数法 `1e-9`。
    Number,
    /// 标识符：变量名 / 常量名 / 函数名（含 `π` `φ` `ε₀` 等 Unicode 符号）。
    Ident,
    /// `+`
    Plus,
    /// `-`（含 Unicode 减号 `−`）
    Minus,
    /// `*`（含 `×` `·`）
    Star,
    /// `/`（含 `÷`）
    Slash,
    /// `^` —— 幂运算（**不是异或**）
    Caret,
    /// `(`
    LParen,
    /// `)`
    RParen,
    /// `,`
    Comma,
    /// `%` —— 后缀百分号 / 中缀取模（由 parser 依据后继记号判定）
    Percent,
    /// `!` —— 后缀阶乘
    Bang,
    /// `=` 或 `:=`
    Assign,
    /// `&` —— 按位与
    And,
    /// `|` —— 按位或
    Or,
    /// `⊕` —— 按位异或（保留给符号输入；表达式里用 `xor(a,b)`）
    Xor,
    /// `~` —— 按位取反
    Not,
    /// `<<`
    Shl,
    /// `>>`
    Shr,
    /// 输入结束。
    EOF,
}

/// 一个词法记号。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Token {
    /// 类别。
    pub kind: TokenKind,
    /// 原始切片（未归一化，便于错误提示原样回显）。
    pub text: String,
    /// 字符偏移区间。
    pub span: Span,
}

impl Token {
    /// 便捷构造。
    pub fn new(kind: TokenKind, text: impl Into<String>, span: Span) -> Self {
        Self {
            kind,
            text: text.into(),
            span,
        }
    }
}
