//! AST 求值器。

use crate::ast::{BinaryOp, Expr, UnaryOp};
use crate::base::{self, BitOp};
use crate::error::{EngineError, ErrorKind, Result};
use crate::functions;
use crate::num::Num;
use crate::session::{EngineSettings, Session};

/// 递归深度上限，防表达式炸弹（架构 §3.12）。
pub const MAX_DEPTH: u32 = 64;

/// 求值上下文。
pub struct EvalContext<'a> {
    /// 可变会话（变量读写、读取设置）。
    pub session: &'a mut Session,
    /// 当前递归深度。
    pub depth: u32,
}

/// 求值一个 AST 节点。
pub fn eval(expr: &Expr, ctx: &mut EvalContext) -> Result<Num> {
    if ctx.depth > MAX_DEPTH {
        return Err(EngineError::with_message(
            ErrorKind::InternalError,
            "表达式嵌套过深",
        ));
    }
    ctx.depth += 1;
    let out = eval_inner(expr, ctx);
    ctx.depth -= 1;
    out
}

fn eval_inner(expr: &Expr, ctx: &mut EvalContext) -> Result<Num> {
    match expr {
        Expr::Number(n, _) => Ok(*n),
        Expr::Const(name, span) => ctx
            .session
            .get_var(name)
            .map_err(|e: EngineError| e.with_span_if_none(*span)),
        Expr::Var(name, span) => ctx
            .session
            .get_var(name)
            .map_err(|e: EngineError| e.with_span_if_none(*span)),
        Expr::Unary { op, operand, span } => {
            let v = eval(operand, ctx)?;
            match op {
                UnaryOp::Neg => Ok(v.neg()),
                UnaryOp::Pos => Ok(v),
                UnaryOp::Not => {
                    let i = v
                        .try_as_i64()
                        .map_err(|e: EngineError| e.with_span_if_none(*span))?;
                    let ws = ctx.session.settings.word_size;
                    Ok(Num::int(base::mask_to_width(!i, ws)))
                }
                UnaryOp::Percent => v
                    .div(&Num::int(100))
                    .map_err(|e: EngineError| e.with_span_if_none(*span)),
            }
        }
        Expr::Binary { op, lhs, rhs, span } => {
            let a = eval(lhs, ctx)?;
            let b = eval(rhs, ctx)?;
            match op {
                BinaryOp::Add => Ok(a.add(&b)),
                BinaryOp::Sub => Ok(a.sub(&b)),
                BinaryOp::Mul => Ok(a.mul(&b)),
                BinaryOp::Pow => a.pow(&b).map_err(|e: EngineError| e.with_span_if_none(*span)),
                BinaryOp::Div => a.div(&b).map_err(|e: EngineError| e.with_span_if_none(*span)),
                BinaryOp::Mod => a.rem(&b).map_err(|e: EngineError| e.with_span_if_none(*span)),
                BinaryOp::BitAnd | BinaryOp::BitOr | BinaryOp::BitXor
                | BinaryOp::Shl | BinaryOp::Shr => {
                    let ws = ctx.session.settings.word_size;
                    let x = a
                        .try_as_i64()
                        .map_err(|e: EngineError| e.with_span_if_none(*span))?;
                    let y = b
                        .try_as_i64()
                        .map_err(|e: EngineError| e.with_span_if_none(*span))?;
                    let op = match op {
                        BinaryOp::BitAnd => BitOp::And,
                        BinaryOp::BitOr => BitOp::Or,
                        BinaryOp::BitXor => BitOp::Xor,
                        BinaryOp::Shl => BitOp::Shl,
                        _ => BitOp::Shr,
                    };
                    Ok(Num::int(base::bitwise(op, x, y, ws)))
                }
            }
        }
        Expr::Call { name, args, span } => {
            let mut vals = Vec::with_capacity(args.len());
            for a in args {
                vals.push(eval(a, ctx)?);
            }
            functions::call(name, &vals, ctx)
                .map_err(|e: EngineError| e.with_span_if_none(*span))
        }
        Expr::Factorial(inner, span) => {
            let v = eval(inner, ctx)?;
            v.factorial()
                .map_err(|e: EngineError| e.with_span_if_none(*span))
        }
        Expr::Assign { name, value, span } => {
            let v = eval(value, ctx)?;
            ctx.session
                .set_var(name, v)
                .map_err(|e: EngineError| e.with_span_if_none(*span))?;
            Ok(v)
        }
    }
}

/// 一次性求值：内部开一个临时会话，不保留任何副作用。
pub fn eval_simple(src: &str, settings: &EngineSettings) -> Result<Num> {
    let toks = crate::lexer::tokenize(src)?;
    let ast = crate::parser::Parser::new(&toks, src).parse()?;
    let mut session = Session::new();
    session.settings = *settings;
    let mut ctx = EvalContext {
        session: &mut session,
        depth: 0,
    };
    eval(&ast, &mut ctx)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn calc(src: &str) -> Result<Num> {
        eval_simple(src, &EngineSettings::default())
    }

    #[test]
    fn basics() {
        assert_eq!(calc("1+2*3").unwrap(), Num::int(7));
        assert_eq!(calc("(1+2)*3").unwrap(), Num::int(9));
        assert_eq!(calc("-3^2").unwrap(), Num::int(-9));
        assert_eq!(calc("2^3^2").unwrap(), Num::int(512));
        assert_eq!(calc("2(3+4)").unwrap(), Num::int(14));
        assert_eq!(calc("200*10%").unwrap(), Num::int(20));
        assert_eq!(calc("50%").unwrap(), Num::rational(1, 2).unwrap());
        assert_eq!(calc("10-(-3)").unwrap(), Num::int(13));
        assert_eq!(calc("7%3").unwrap(), Num::int(1));
        assert_eq!(calc("7 mod 3").unwrap(), Num::int(1));
        assert_eq!(calc("5!").unwrap(), Num::int(120));
    }

    #[test]
    fn division_by_zero_is_error() {
        assert_eq!(calc("1/0").unwrap_err().kind, ErrorKind::DivisionByZero);
    }

    #[test]
    fn depth_limit_protects_against_bombs() {
        let src = "(".repeat(200) + "1" + &")".repeat(200);
        assert_eq!(calc(&src).unwrap_err().kind, ErrorKind::InternalError);
    }

    #[test]
    fn assignment_writes_variable() {
        let mut s = Session::new();
        let toks = crate::lexer::tokenize("a=3+4").unwrap();
        let ast = crate::parser::Parser::new(&toks, "a=3+4").parse().unwrap();
        let mut ctx = EvalContext {
            session: &mut s,
            depth: 0,
        };
        assert_eq!(eval(&ast, &mut ctx).unwrap(), Num::int(7));
        assert_eq!(s.get_var("a").unwrap(), Num::int(7));
    }

    #[test]
    fn bitwise_uses_word_size() {
        let mut st = EngineSettings::default();
        st.word_size = 64;
        assert_eq!(eval_simple("~0", &st).unwrap(), Num::int(-1));
        assert_eq!(eval_simple("0b1010 & 0b1100", &st).unwrap(), Num::int(8));
        st.word_size = 8;
        assert_eq!(eval_simple("0xFF & 0x0F", &st).unwrap(), Num::int(15));
    }
}
