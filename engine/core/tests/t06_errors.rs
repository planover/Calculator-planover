//! T06：错误处理（不完整表达式 / 括号不匹配 / 定义域错误 / 未知函数 / 参数个数 /
//! 非整数 / 除零 / 未定义变量 / 非法数字字面量）。
//!
//! 覆盖 PRD P0-03 / P0-07 / P0-08 / P0-11。

mod common;

use calculator_core::error::ErrorKind;
use common::try_calc;

/// 取表达式的报错类型；失败（返回 Ok）时直接 panic。
fn kind(src: &str) -> ErrorKind {
    try_calc(src).unwrap_err().kind
}

#[test]
fn incomplete_expression() {
    // 写到一半的表达式：UI 用灰色提示而不是红色报错
    assert_eq!(kind("1+"), ErrorKind::IncompleteExpression);
    assert_eq!(kind("1+2*"), ErrorKind::IncompleteExpression);
    assert_eq!(kind("("), ErrorKind::IncompleteExpression);
    assert_eq!(kind("sin("), ErrorKind::IncompleteExpression);
    assert_eq!(kind("2^"), ErrorKind::IncompleteExpression);
}

#[test]
fn mismatched_paren() {
    // 多余的右括号
    assert_eq!(kind("(1+2))"), ErrorKind::MismatchedParen);
    assert_eq!(kind("1+2)"), ErrorKind::MismatchedParen);
    assert_eq!(kind(")"), ErrorKind::MismatchedParen);
}

#[test]
fn unexpected_token() {
    assert_eq!(kind("1+*2"), ErrorKind::UnexpectedToken);
}

#[test]
fn division_by_zero() {
    assert_eq!(kind("1/0"), ErrorKind::DivisionByZero);
    assert_eq!(kind("1 mod 0"), ErrorKind::DivisionByZero);
    assert_eq!(kind("5%0"), ErrorKind::DivisionByZero);
}

#[test]
fn domain_errors() {
    // 反三角函数定义域
    assert_eq!(kind("asin(2)"), ErrorKind::DomainError);
    assert_eq!(kind("acos(2)"), ErrorKind::DomainError);
    // 对数定义域
    assert_eq!(kind("ln(-1)"), ErrorKind::DomainError);
    assert_eq!(kind("log(-5)"), ErrorKind::DomainError);
    assert_eq!(kind("ln(0)"), ErrorKind::DomainError);
    // 平方根定义域
    assert_eq!(kind("sqrt(-1)"), ErrorKind::DomainError);
    // 负数分数次幂
    assert_eq!(kind("(-2)^0.5"), ErrorKind::DomainError);
    // 阶乘只接受非负整数
    assert_eq!(kind("(-5)!"), ErrorKind::DomainError);
    assert_eq!(kind("0.5!"), ErrorKind::DomainError);
}

#[test]
fn unknown_function() {
    assert_eq!(kind("foo(1)"), ErrorKind::UnknownFunction);
    assert_eq!(kind("nope(2,3)"), ErrorKind::UnknownFunction);
}

#[test]
fn wrong_arity() {
    // sin 只需 1 个参数
    assert_eq!(kind("sin(1,2)"), ErrorKind::WrongArity);
    // pow 需 2 个参数
    assert_eq!(kind("pow(2)"), ErrorKind::WrongArity);
    assert_eq!(kind("pow(1,2,3)"), ErrorKind::WrongArity);
    // gcd 需 2 个参数
    assert_eq!(kind("gcd(2)"), ErrorKind::WrongArity);
}

#[test]
fn not_an_integer() {
    // 位运算要求整数操作数
    assert_eq!(kind("1.5 & 1"), ErrorKind::NotAnInteger);
    assert_eq!(kind("1.5 | 1"), ErrorKind::NotAnInteger);
    assert_eq!(kind("xor(1.5, 1)"), ErrorKind::NotAnInteger);
    assert_eq!(kind("1.5 << 2"), ErrorKind::NotAnInteger);
    assert_eq!(kind("~1.5"), ErrorKind::NotAnInteger);
}

#[test]
fn undefined_variable() {
    assert_eq!(kind("x"), ErrorKind::UndefinedVariable);
    assert_eq!(kind("undefined_var + 1"), ErrorKind::UndefinedVariable);
}

#[test]
fn invalid_number_literal() {
    // 前缀后无数字
    assert_eq!(kind("0x"), ErrorKind::InvalidNumberLiteral);
    // 非法的十六进制字符
    assert_eq!(kind("0xZZ"), ErrorKind::InvalidNumberLiteral);
}
