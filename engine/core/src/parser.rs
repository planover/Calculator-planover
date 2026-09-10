//! Pratt 解析器。
//!
//! 优先级（数字越大越紧，对应架构 §3.5）：
//! ```text
//!  1  = :=        右结合
//!  2  | ⊕         左
//!  3  &           左
//!  4  << >>       左
//!  5  + -         左
//!  6  * / mod 及隐式乘法   左
//!  7  一元 - + ~  右   ← 关键：低于 ^，故 -3^2 = -9
//!  8  ^           右结合
//!  9  后缀 % !
//! 10  函数调用 / 括号 / 常量
//! ```
//! 实现上用 `(lbp, rbp)` 二元组：左结合取 `(n, n+1)`，右结合取 `(n+1, n)`，
//! 前缀一元用 `parse_expr(BP_UNARY)`，其中 `BP_UNARY` 小于 `^` 的 lbp 从而让
//! `-(3^2)` 成立。

use crate::ast::{BinaryOp, Expr, UnaryOp};
use crate::constants;
use crate::error::{EngineError, ErrorKind, Result};
use crate::functions;
use crate::lexer::parse_number_literal;
use crate::span::Span;
use crate::token::{Token, TokenKind};

const BP_ASSIGN: (u32, u32) = (2, 1);
const BP_OR: (u32, u32) = (4, 5);
const BP_AND: (u32, u32) = (6, 7);
const BP_SHIFT: (u32, u32) = (8, 9);
const BP_ADD: (u32, u32) = (10, 11);
const BP_MUL: (u32, u32) = (12, 13);
/// 一元前缀的结合力。必须 **小于** `BP_POW.0`，否则 `-3^2` 会变成 `(-3)^2`。
const BP_UNARY: u32 = 14;
const BP_POW: (u32, u32) = (16, 15);

/// 递归深度上限，防表达式炸弹。
const MAX_DEPTH: u32 = 64;

/// Pratt 解析器。
pub struct Parser<'a> {
    tokens: &'a [Token],
    src: &'a str,
    pos: usize,
    depth: u32,
}

impl<'a> Parser<'a> {
    /// 构造。`src` 仅用于兜底构造 EOF 区间。
    pub fn new(tokens: &'a [Token], src: &'a str) -> Self {
        Self {
            tokens,
            src,
            pos: 0,
            depth: 0,
        }
    }

    /// 严格解析：记号必须全部消费完，否则报错。
    pub fn parse(&mut self) -> Result<Expr> {
        self.depth = 0;
        let e = self.parse_expr(0)?;
        match self.peek() {
            Some(t) if t.kind == TokenKind::EOF => Ok(e),
            Some(t) if t.kind == TokenKind::RParen => Err(EngineError::with_span(
                ErrorKind::MismatchedParen,
                t.span,
            )),
            Some(t) => Err(EngineError::full(
                ErrorKind::UnexpectedToken,
                t.span,
                format!("多余的记号 “{}”", t.text),
            )),
            None => Err(EngineError::with_span(
                ErrorKind::IncompleteExpression,
                self.eof_span(),
            )),
        }
    }

    /// 宽容解析：先按严格模式来；失败且存在未闭合左括号时，自动补 `)` 重试。
    ///
    /// 这样 `sin(30` 也能给出结果而不是硬报错，用于输入过程中的"尽力预览"。
    pub fn parse_lenient(&mut self) -> Result<Expr> {
        let snapshot = self.pos;
        match self.parse() {
            Ok(e) => Ok(e),
            Err(err) => {
                self.pos = snapshot;
                let extra = self.count_unclosed_parens();
                if extra == 0 {
                    return Err(err);
                }
                let mut toks: Vec<Token> = self.tokens.to_vec();
                let end = self.eof_span().start;
                for _ in 0..extra {
                    // 把原本的 EOF 顶掉，补上等量的右括号
                    toks.pop();
                    toks.push(Token::new(TokenKind::RParen, ")", Span::new(end, end)));
                }
                toks.push(Token::new(TokenKind::EOF, "", Span::new(end, end)));
                let mut p = Parser::new(&toks, self.src);
                p.parse().map_err(|_| err)
            }
        }
    }

    fn count_unclosed_parens(&self) -> usize {
        let mut open = 0usize;
        for t in self.tokens.iter() {
            match t.kind {
                TokenKind::LParen => open += 1,
                TokenKind::RParen => open = open.saturating_sub(1),
                _ => {}
            }
        }
        open
    }

    fn eof_span(&self) -> Span {
        let n = self.src.chars().count();
        Span::new(n, n)
    }

    fn peek(&self) -> Option<&'a Token> {
        self.tokens.get(self.pos)
    }

    fn peek_at(&self, k: usize) -> Option<&'a Token> {
        self.tokens.get(self.pos + k)
    }

    fn bump(&mut self) -> Option<&'a Token> {
        let t = self.tokens.get(self.pos);
        if t.is_some() {
            self.pos += 1;
        }
        t
    }

    /// 下一个记号能否开启一个"值"（数字 / 标识符 / 左括号）。
    ///
    /// 注意：不含一元负号——否则 `2-3` 会被误判成隐式乘法 `2*(-3)`。
    /// 下一个记号能否开启一个"值"（数字 / 标识符 / 左括号）。
    ///
    /// 注意：不含一元负号——否则 `2-3` 会被误判成隐式乘法 `2*(-3)`。
    /// 另外 `mod` 是中缀取模关键字，不能开启一个值；否则 `7 mod 3` 会被误判成
    /// 隐式乘法 `7 * mod(...)`，进而把 `mod` 当成未定义变量去查而报错。
    fn starts_value(&self) -> bool {
        match self.peek() {
            Some(t) => match t.kind {
                TokenKind::Number | TokenKind::LParen => true,
                TokenKind::Ident => !is_mod_keyword(&t.text),
                _ => false,
            },
            None => false,
        }
    }

    fn starts_value_at(&self, k: usize) -> bool {
        match self.peek_at(k) {
            Some(t) => match t.kind {
                TokenKind::Number | TokenKind::LParen => true,
                TokenKind::Ident => !is_mod_keyword(&t.text),
                _ => false,
            },
            None => false,
        }
    }

    fn parse_expr(&mut self, min_bp: u32) -> Result<Expr> {
        self.depth += 1;
        if self.depth > MAX_DEPTH {
            self.depth -= 1;
            return Err(EngineError::new(ErrorKind::InternalError));
        }
        let mut lhs = self.prefix()?;
        self.postfix(&mut lhs)?;

        loop {
            // 隐式乘法：值后面紧跟另一个值 → 插入 `*`
            if self.starts_value() {
                if BP_MUL.0 < min_bp {
                    break;
                }
                let rhs = self.parse_expr(BP_MUL.1)?;
                let span = lhs.span().merge(rhs.span());
                lhs = Expr::Binary {
                    op: BinaryOp::Mul,
                    lhs: Box::new(lhs),
                    rhs: Box::new(rhs),
                    span,
                };
                continue;
            }

            let t = match self.peek() {
                Some(t) => t,
                None => break,
            };
            if t.kind == TokenKind::Assign {
                if BP_ASSIGN.0 < min_bp {
                    break;
                }
                let assign_span = t.span;
                let name = match &lhs {
                    Expr::Var(n, _) => n.clone(),
                    Expr::Const(n, _) => n.clone(),
                    other => {
                        return Err(EngineError::with_span(
                            ErrorKind::InvalidVariableName,
                            other.span(),
                        ))
                    }
                };
                self.bump();
                let value = self.parse_expr(BP_ASSIGN.1)?;
                let span = lhs.span().merge(value.span()).merge(assign_span);
                lhs = Expr::Assign {
                    name,
                    value: Box::new(value),
                    span,
                };
                continue;
            }

            let (lbp, rbp) = match self.infix_bp(t) {
                Some(v) => v,
                None => break,
            };
            if lbp < min_bp {
                break;
            }
            let op = self.infix_op(t)?;
            let op_span = t.span;
            self.bump();
            let rhs = self.parse_expr(rbp)?;
            let span = lhs.span().merge(rhs.span()).merge(op_span);
            lhs = Expr::Binary {
                op,
                lhs: Box::new(lhs),
                rhs: Box::new(rhs),
                span,
            };
        }
        self.depth -= 1;
        Ok(lhs)
    }

    fn infix_bp(&self, t: &Token) -> Option<(u32, u32)> {
        match t.kind {
            TokenKind::Assign => Some(BP_ASSIGN),
            TokenKind::Or => Some(BP_OR),
            TokenKind::Xor => Some(BP_OR),
            TokenKind::And => Some(BP_AND),
            TokenKind::Shl | TokenKind::Shr => Some(BP_SHIFT),
            TokenKind::Plus | TokenKind::Minus => Some(BP_ADD),
            TokenKind::Star | TokenKind::Slash => Some(BP_MUL),
            TokenKind::Caret => Some(BP_POW),
            // 中缀 `%`：只有后面确实还有值时才当取模，否则留给后缀百分号
            TokenKind::Percent if self.starts_value_at(1) => Some(BP_MUL),
            TokenKind::Ident if is_mod_keyword(&t.text) => Some(BP_MUL),
            _ => None,
        }
    }

    fn infix_op(&self, t: &Token) -> Result<BinaryOp> {
        Ok(match t.kind {
            TokenKind::Or => BinaryOp::BitOr,
            TokenKind::Xor => BinaryOp::BitXor,
            TokenKind::And => BinaryOp::BitAnd,
            TokenKind::Shl => BinaryOp::Shl,
            TokenKind::Shr => BinaryOp::Shr,
            TokenKind::Plus => BinaryOp::Add,
            TokenKind::Minus => BinaryOp::Sub,
            TokenKind::Star => BinaryOp::Mul,
            TokenKind::Slash => BinaryOp::Div,
            TokenKind::Caret => BinaryOp::Pow,
            TokenKind::Percent => BinaryOp::Mod,
            TokenKind::Ident if is_mod_keyword(&t.text) => BinaryOp::Mod,
            other => {
                return Err(EngineError::full(
                    ErrorKind::UnexpectedToken,
                    t.span,
                    format!("记号 “{}” 不能用作中缀运算符（{:?}）", t.text, other),
                ))
            }
        })
    }

    fn prefix(&mut self) -> Result<Expr> {
        let t = match self.peek() {
            Some(t) => t,
            None => {
                return Err(EngineError::with_span(
                    ErrorKind::IncompleteExpression,
                    self.eof_span(),
                ))
            }
        };
        match t.kind {
            TokenKind::Minus | TokenKind::Plus | TokenKind::Not => {
                let op = match t.kind {
                    TokenKind::Minus => UnaryOp::Neg,
                    TokenKind::Plus => UnaryOp::Pos,
                    _ => UnaryOp::Not,
                };
                let op_span = t.span;
                self.bump();
                let operand = self.parse_expr(BP_UNARY)?;
                let span = op_span.merge(operand.span());
                Ok(Expr::Unary {
                    op,
                    operand: Box::new(operand),
                    span,
                })
            }
            _ => self.primary(),
        }
    }

    fn postfix(&mut self, lhs: &mut Expr) -> Result<()> {
        loop {
            let t = match self.peek() {
                Some(t) => t,
                None => break,
            };
            match t.kind {
                TokenKind::Bang => {
                    let sp = t.span;
                    self.bump();
                    let inner = lhs.clone();
                    let span = inner.span().merge(sp);
                    *lhs = Expr::Factorial(Box::new(inner), span);
                }
                // 后缀百分号：后面没有值时才是 `a/100`
                TokenKind::Percent if !self.starts_value_at(1) => {
                    let sp = t.span;
                    self.bump();
                    let inner = lhs.clone();
                    let span = inner.span().merge(sp);
                    *lhs = Expr::Unary {
                        op: UnaryOp::Percent,
                        operand: Box::new(inner),
                        span,
                    };
                }
                _ => break,
            }
        }
        Ok(())
    }

    fn primary(&mut self) -> Result<Expr> {
        let t = match self.peek() {
            Some(t) => t,
            None => {
                return Err(EngineError::with_span(
                    ErrorKind::IncompleteExpression,
                    self.eof_span(),
                ))
            }
        };
        match t.kind {
            TokenKind::Number => {
                let n = parse_number_literal(&t.text).map_err(|e| {
                    EngineError::full(ErrorKind::InvalidNumberLiteral, t.span, e.message)
                })?;
                let sp = t.span;
                self.bump();
                Ok(Expr::Number(n, sp))
            }
            TokenKind::Ident => {
                let name = t.text.clone();
                let sp = t.span;
                // 1) 标识符紧跟左括号 → 一律视为函数调用（即便未注册，
                //    求值层也会给出 UnknownFunction，比把它当未定义变量更贴近用户意图）。
                if self.peek_at(1).map(|x| x.kind) == Some(TokenKind::LParen) {
                    self.bump();
                    self.bump();
                    let args = self.parse_args()?;
                    let end = self
                        .tokens
                        .get(self.pos.saturating_sub(1))
                        .map(|x| x.span)
                        .unwrap_or(sp);
                    return Ok(Expr::Call {
                        name,
                        args,
                        span: sp.merge(end),
                    });
                }
                // 2) `sin30` 这类函数名 + 数字连写
                if let Some((fname, lit)) = split_func_number(&name) {
                    self.bump();
                    let n = parse_number_literal(&lit).map_err(|e| {
                        EngineError::full(ErrorKind::InvalidNumberLiteral, sp, e.message)
                    })?;
                    return Ok(Expr::Call {
                        name: fname.to_string(),
                        args: vec![Expr::Number(n, sp)],
                        span: sp,
                    });
                }
                // 3) 已知函数名或别名，但后面不是 `(` → 把紧随的 primary 当作唯一实参（隐式函数调用）
                if let Some(canon) = functions::resolve_function_name(&name) {
                    self.bump();
                    let arg = self.primary()?;
                    let span = sp.merge(arg.span());
                    return Ok(Expr::Call {
                        name: canon.to_string(),
                        args: vec![arg],
                        span,
                    });
                }
                self.bump();
                if constants::lookup(&name).is_some() {
                    Ok(Expr::Const(name, sp))
                } else {
                    Ok(Expr::Var(name, sp))
                }
            }
            TokenKind::LParen => {
                let open = t.span;
                self.bump();
                let inner = self.parse_expr(0)?;
                match self.peek() {
                    Some(x) if x.kind == TokenKind::RParen => {
                        let close = x.span;
                        self.bump();
                        // 保留原始区间以便错误定位
                        let _ = (open, close);
                        Ok(inner)
                    }
                    Some(x) if x.kind == TokenKind::EOF => Err(EngineError::with_span(
                        ErrorKind::IncompleteExpression,
                        x.span,
                    )),
                    Some(x) => Err(EngineError::with_span(ErrorKind::MismatchedParen, x.span)),
                    None => Err(EngineError::with_span(
                        ErrorKind::IncompleteExpression,
                        self.eof_span(),
                    )),
                }
            }
            TokenKind::EOF => Err(EngineError::with_span(
                ErrorKind::IncompleteExpression,
                t.span,
            )),
            TokenKind::RParen => Err(EngineError::with_span(ErrorKind::MismatchedParen, t.span)),
            _ => Err(EngineError::full(
                ErrorKind::UnexpectedToken,
                t.span,
                format!("意外的记号 “{}”", t.text),
            )),
        }
    }

    /// 解析函数调用实参表；`f()` 视为 0 个实参。
    fn parse_args(&mut self) -> Result<Vec<Expr>> {
        let mut args = Vec::new();
        if let Some(t) = self.peek() {
            if t.kind == TokenKind::RParen {
                self.bump();
                return Ok(args);
            }
        }
        loop {
            args.push(self.parse_expr(0)?);
            match self.peek() {
                Some(t) if t.kind == TokenKind::Comma => {
                    self.bump();
                }
                Some(t) if t.kind == TokenKind::RParen => {
                    self.bump();
                    return Ok(args);
                }
                Some(t) if t.kind == TokenKind::EOF => {
                    return Err(EngineError::with_span(
                        ErrorKind::IncompleteExpression,
                        t.span,
                    ))
                }
                Some(t) => {
                    return Err(EngineError::with_span(ErrorKind::UnexpectedToken, t.span))
                }
                None => {
                    return Err(EngineError::with_span(
                        ErrorKind::IncompleteExpression,
                        self.eof_span(),
                    ))
                }
            }
        }
    }
}

fn is_mod_keyword(text: &str) -> bool {
    text.eq_ignore_ascii_case("mod")
}

/// 把 `sin30` 拆成 `("sin", "30")`；取**最长**函数名匹配。
pub fn split_func_number(text: &str) -> Option<(&'static str, String)> {
    let mut best: Option<(&'static str, String)> = None;
    for f in functions::all() {
        if text.len() <= f.name.len() || !text.starts_with(f.name) {
            continue;
        }
        let rest = &text[f.name.len()..];
        if rest.is_empty() || !rest.chars().all(|c| c.is_ascii_digit() || c == '.') {
            continue;
        }
        if !rest.chars().any(|c| c.is_ascii_digit()) {
            continue;
        }
        match &best {
            Some((b, _)) if b.len() >= f.name.len() => {}
            _ => best = Some((f.name, rest.to_string())),
        }
    }
    best
}

/// 便捷纯函数：源码 → AST。
pub fn parse(src: &str) -> Result<Expr> {
    let toks = crate::lexer::tokenize(src)?;
    Parser::new(&toks, src).parse()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::num::Num;

    fn eval_shape(src: &str) -> Expr {
        parse(src).unwrap()
    }

    #[test]
    fn unary_minus_binds_looser_than_power() {
        // -3^2 必须是 -(3^2)
        match eval_shape("-3^2") {
            Expr::Unary { op: UnaryOp::Neg, operand, .. } => match *operand {
                Expr::Binary { op: BinaryOp::Pow, .. } => {}
                other => panic!("期望幂在内层，实际 {:?}", other),
            },
            other => panic!("期望一元负号在外层，实际 {:?}", other),
        }
    }

    #[test]
    fn power_is_right_associative() {
        match eval_shape("2^3^2") {
            Expr::Binary { op: BinaryOp::Pow, rhs, .. } => match *rhs {
                Expr::Binary { op: BinaryOp::Pow, .. } => {}
                other => panic!("^ 应右结合，实际 {:?}", other),
            },
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn implicit_multiplication() {
        match eval_shape("2(3+4)") {
            Expr::Binary { op: BinaryOp::Mul, .. } => {}
            other => panic!("{:?}", other),
        }
        match eval_shape("2π") {
            Expr::Binary { op: BinaryOp::Mul, .. } => {}
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn percent_is_postfix_when_no_following_value() {
        match eval_shape("200*10%") {
            Expr::Binary { op: BinaryOp::Mul, rhs, .. } => match *rhs {
                Expr::Unary { op: UnaryOp::Percent, .. } => {}
                other => panic!("{:?}", other),
            },
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn percent_is_infix_when_value_follows() {
        match eval_shape("7%3") {
            Expr::Binary { op: BinaryOp::Mod, .. } => {}
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn function_call_and_omitted_paren_number() {
        match eval_shape("sin(30)") {
            Expr::Call { name, args, .. } => {
                assert_eq!(name, "sin");
                assert_eq!(args.len(), 1);
            }
            other => panic!("{:?}", other),
        }
        match eval_shape("sin30") {
            Expr::Call { name, args, .. } => {
                assert_eq!(name, "sin");
                assert_eq!(args[0], Expr::Number(Num::int(30), Span::new(0, 5)));
            }
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn assignment_parses() {
        match eval_shape("a=3+4") {
            Expr::Assign { name, .. } => assert_eq!(name, "a"),
            other => panic!("{:?}", other),
        }
        match eval_shape("x:=5") {
            Expr::Assign { name, .. } => assert_eq!(name, "x"),
            other => panic!("{:?}", other),
        }
    }

    #[test]
    fn incomplete_expression_has_span() {
        let e = parse("1+").unwrap_err();
        assert_eq!(e.kind, ErrorKind::IncompleteExpression);
        let e2 = parse("1+2*").unwrap_err();
        assert_eq!(e2.kind, ErrorKind::IncompleteExpression);
    }

    #[test]
    fn unexpected_token_span_is_exact() {
        let e = parse("1+*2").unwrap_err();
        assert_eq!(e.kind, ErrorKind::UnexpectedToken);
        assert_eq!(e.span, Some(Span::new(2, 3)));
    }

    #[test]
    fn mismatched_paren_variants() {
        assert_eq!(parse("(1+2").unwrap_err().kind, ErrorKind::IncompleteExpression);
        assert_eq!(parse("(1+2))").unwrap_err().kind, ErrorKind::MismatchedParen);
    }

    #[test]
    fn parse_lenient_closes_missing_parens() {
        let toks = crate::lexer::tokenize("sin(30").unwrap();
        let e = Parser::new(&toks, "sin(30").parse_lenient().unwrap();
        match e {
            Expr::Call { name, .. } => assert_eq!(name, "sin"),
            other => panic!("{:?}", other),
        }
        let toks2 = crate::lexer::tokenize("1+2*").unwrap();
        assert!(Parser::new(&toks2, "1+2*").parse_lenient().is_err());
    }
}
