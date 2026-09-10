//! 抽象语法树。

use crate::num::Num;
use crate::span::Span;

/// 一元运算符。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnaryOp {
    /// 负号 `-`（优先级低于 `^`）
    Neg,
    /// 正号 `+`
    Pos,
    /// 按位取反 `~`
    Not,
    /// 百分号 `%`：语义为 `a/100`
    Percent,
}

/// 二元运算符。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinaryOp {
    /// `+`
    Add,
    /// `-`
    Sub,
    /// `*`（含隐式乘法）
    Mul,
    /// `/`
    Div,
    /// `^`
    Pow,
    /// `mod` / 中缀 `%`
    Mod,
    /// `&`
    BitAnd,
    /// `|`
    BitOr,
    /// `xor`
    BitXor,
    /// `<<`
    Shl,
    /// `>>`
    Shr,
}

/// 表达式节点。
#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    /// 数字字面量。
    Number(Num, Span),
    /// 常量引用（π / e / c …），名字在求值期查表。
    Const(String, Span),
    /// 变量引用（含 `ans`）。
    Var(String, Span),
    /// 一元运算。
    Unary {
        /// 运算符。
        op: UnaryOp,
        /// 操作数。
        operand: Box<Expr>,
        /// 整体区间。
        span: Span,
    },
    /// 二元运算。
    Binary {
        /// 运算符。
        op: BinaryOp,
        /// 左操作数。
        lhs: Box<Expr>,
        /// 右操作数。
        rhs: Box<Expr>,
        /// 整体区间。
        span: Span,
    },
    /// 函数调用。
    Call {
        /// 函数名。
        name: String,
        /// 实参。
        args: Vec<Expr>,
        /// 整体区间。
        span: Span,
    },
    /// 后缀阶乘。
    Factorial(Box<Expr>, Span),
    /// 赋值 `a=3+4` / `x:=5`。
    Assign {
        /// 变量名。
        name: String,
        /// 右值。
        value: Box<Expr>,
        /// 整体区间。
        span: Span,
    },
}

impl Expr {
    /// 该节点的源码区间。
    pub fn span(&self) -> Span {
        match self {
            Expr::Number(_, s)
            | Expr::Const(_, s)
            | Expr::Var(_, s)
            | Expr::Unary { span: s, .. }
            | Expr::Binary { span: s, .. }
            | Expr::Call { span: s, .. }
            | Expr::Factorial(_, s)
            | Expr::Assign { span: s, .. } => *s,
        }
    }
}
