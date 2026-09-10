//! 统一错误类型。

use crate::span::Span;

/// 本 crate 的统一 `Result` 别名。
pub type Result<T> = std::result::Result<T, EngineError>;

/// 引擎错误。
///
/// 设计要点：**错误必须携带 span**，因为 UI 要在表达式行里把出错字符标红。
#[derive(Debug, Clone, PartialEq)]
pub struct EngineError {
    /// 稳定错误分类，Dart 侧据此分支渲染。
    pub kind: ErrorKind,
    /// 出错区间（char 偏移）。词法/语法错误必有，求值错误通常没有。
    pub span: Option<Span>,
    /// 中文文案，可直接展示。
    pub message: String,
}

/// 错误分类。判别值即 JSON `error.code`，跨版本保持稳定。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKind {
    // ── 1xxx 词法 / 语法 ──
    /// 遇到无法识别的字符。
    UnexpectedCharacter = 1000,
    /// 运算符位置不对、多余记号等。
    UnexpectedToken = 1001,
    /// 表达式写到一半（最常见，UI 用灰色提示而非红色报错）。
    IncompleteExpression = 1002,
    /// 括号数量不匹配。
    MismatchedParen = 1003,
    /// 数字字面量非法（如 `0x` 后没有数字）。
    InvalidNumberLiteral = 1004,
    /// 调用了不存在的函数。
    UnknownFunction = 1005,
    /// 函数参数个数不对。
    WrongArity = 1006,
    // ── 2xxx 求值 / 数学 ──
    /// 除数为零。
    DivisionByZero = 2000,
    /// 数学定义域外（asin(2)、ln(-1)、(-1)! 等）。
    DomainError = 2001,
    /// 超出 i64 / 位宽可表示范围。
    Overflow = 2002,
    /// 需要整数却给了非整数（位运算、阶乘等）。
    NotAnInteger = 2003,
    // ── 3xxx 单位 ──
    /// 未知单位。
    UnknownUnit = 3000,
    /// 跨类别换算（如 inch → kg）。
    IncompatibleUnits = 3001,
    /// 低于绝对零度。
    BelowAbsoluteZero = 3002,
    // ── 4xxx 变量 ──
    /// 引用了未定义的变量。
    UndefinedVariable = 4000,
    /// 试图覆盖保留名（ans / 常量 / 函数名）。
    ReservedName = 4001,
    /// 变量名本身不合法。
    InvalidVariableName = 4002,
    // ── 5xxx 请求 / 内部 ──
    /// 请求体缺字段或 JSON 不合法。
    InvalidRequest = 5000,
    /// 设置项越界。
    InvalidSettings = 5001,
    /// 兜底错误（`catch_unwind` 捕获 panic 时用）。
    InternalError = 5002,
}

impl ErrorKind {
    /// 稳定 snake_case 名称，写入 JSON `error.kind`，Dart 侧 `switch` 用。
    pub fn stable_name(&self) -> &'static str {
        match self {
            ErrorKind::UnexpectedCharacter => "unexpected_character",
            ErrorKind::UnexpectedToken => "unexpected_token",
            ErrorKind::IncompleteExpression => "incomplete_expression",
            ErrorKind::MismatchedParen => "mismatched_paren",
            ErrorKind::InvalidNumberLiteral => "invalid_number_literal",
            ErrorKind::UnknownFunction => "unknown_function",
            ErrorKind::WrongArity => "wrong_arity",
            ErrorKind::DivisionByZero => "division_by_zero",
            ErrorKind::DomainError => "domain_error",
            ErrorKind::Overflow => "overflow",
            ErrorKind::NotAnInteger => "not_an_integer",
            ErrorKind::UnknownUnit => "unknown_unit",
            ErrorKind::IncompatibleUnits => "incompatible_units",
            ErrorKind::BelowAbsoluteZero => "below_absolute_zero",
            ErrorKind::UndefinedVariable => "undefined_variable",
            ErrorKind::ReservedName => "reserved_name",
            ErrorKind::InvalidVariableName => "invalid_variable_name",
            ErrorKind::InvalidRequest => "invalid_request",
            ErrorKind::InvalidSettings => "invalid_settings",
            ErrorKind::InternalError => "internal_error",
        }
    }

    /// 数字错误码，JSON `error.code`。
    pub fn code(&self) -> u16 {
        *self as u16
    }

    /// 默认中文文案（调用方未显式给出 message 时使用）。
    pub fn default_message(&self) -> &'static str {
        match self {
            ErrorKind::UnexpectedCharacter => "无法识别的字符",
            ErrorKind::UnexpectedToken => "运算符位置不正确",
            ErrorKind::IncompleteExpression => "表达式不完整",
            ErrorKind::MismatchedParen => "括号不匹配",
            ErrorKind::InvalidNumberLiteral => "数字格式不正确",
            ErrorKind::UnknownFunction => "未知函数",
            ErrorKind::WrongArity => "函数参数个数不正确",
            ErrorKind::DivisionByZero => "除数不能为零",
            ErrorKind::DomainError => "超出数学定义域",
            ErrorKind::Overflow => "数值超出可表示范围",
            ErrorKind::NotAnInteger => "需要整数",
            ErrorKind::UnknownUnit => "未知单位",
            ErrorKind::IncompatibleUnits => "单位类别不同，无法换算",
            ErrorKind::BelowAbsoluteZero => "温度低于绝对零度",
            ErrorKind::UndefinedVariable => "未定义的变量",
            ErrorKind::ReservedName => "该名称已保留，不能用作变量",
            ErrorKind::InvalidVariableName => "变量名不合法",
            ErrorKind::InvalidRequest => "请求格式不正确",
            ErrorKind::InvalidSettings => "设置项不合法",
            ErrorKind::InternalError => "引擎内部错误",
        }
    }
}

impl EngineError {
    /// 只给 kind，用默认文案。
    pub fn new(kind: ErrorKind) -> Self {
        Self {
            kind,
            span: None,
            message: kind.default_message().to_string(),
        }
    }

    /// 给 kind + span，用默认文案。
    pub fn with_span(kind: ErrorKind, span: Span) -> Self {
        Self {
            kind,
            span: Some(span),
            message: kind.default_message().to_string(),
        }
    }

    /// 给 kind + 自定义文案。
    pub fn with_message(kind: ErrorKind, msg: impl Into<String>) -> Self {
        Self {
            kind,
            span: None,
            message: msg.into(),
        }
    }

    /// 给 kind + span + 自定义文案（解析阶段最常用）。
    pub fn full(kind: ErrorKind, span: Span, msg: impl Into<String>) -> Self {
        Self {
            kind,
            span: Some(span),
            message: msg.into(),
        }
    }

    /// 若尚缺 span 则补上（保留已有 span，避免被外层粗粒度区间覆盖掉精确位置）。
    pub fn with_span_if_none(self, span: Span) -> Self {
        if self.span.is_none() {
            Self {
                span: Some(span),
                ..self
            }
        } else {
            self
        }
    }
}

impl std::fmt::Display for EngineError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self.span {
            Some(s) => write!(f, "{}（{}…{}）", self.message, s.start, s.end),
            None => write!(f, "{}", self.message),
        }
    }
}

impl std::error::Error for EngineError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn codes_are_stable() {
        assert_eq!(ErrorKind::UnexpectedCharacter.code(), 1000);
        assert_eq!(ErrorKind::WrongArity.code(), 1006);
        assert_eq!(ErrorKind::DivisionByZero.code(), 2000);
        assert_eq!(ErrorKind::NotAnInteger.code(), 2003);
        assert_eq!(ErrorKind::UnknownUnit.code(), 3000);
        assert_eq!(ErrorKind::BelowAbsoluteZero.code(), 3002);
        assert_eq!(ErrorKind::UndefinedVariable.code(), 4000);
        assert_eq!(ErrorKind::ReservedName.code(), 4001);
        assert_eq!(ErrorKind::InvalidRequest.code(), 5000);
        assert_eq!(ErrorKind::InternalError.code(), 5002);
    }

    #[test]
    fn stable_names_are_snake_case() {
        assert_eq!(ErrorKind::DivisionByZero.stable_name(), "division_by_zero");
        assert_eq!(
            ErrorKind::IncompleteExpression.stable_name(),
            "incomplete_expression"
        );
        assert_eq!(ErrorKind::BelowAbsoluteZero.stable_name(), "below_absolute_zero");
    }

    #[test]
    fn default_message_not_empty() {
        let all = [
            ErrorKind::UnexpectedCharacter,
            ErrorKind::UnexpectedToken,
            ErrorKind::IncompleteExpression,
            ErrorKind::MismatchedParen,
            ErrorKind::InvalidNumberLiteral,
            ErrorKind::UnknownFunction,
            ErrorKind::WrongArity,
            ErrorKind::DivisionByZero,
            ErrorKind::DomainError,
            ErrorKind::Overflow,
            ErrorKind::NotAnInteger,
            ErrorKind::UnknownUnit,
            ErrorKind::IncompatibleUnits,
            ErrorKind::BelowAbsoluteZero,
            ErrorKind::UndefinedVariable,
            ErrorKind::ReservedName,
            ErrorKind::InvalidVariableName,
            ErrorKind::InvalidRequest,
            ErrorKind::InvalidSettings,
            ErrorKind::InternalError,
        ];
        for k in all {
            assert!(!k.default_message().is_empty());
            assert!(!k.stable_name().is_empty());
        }
    }

    #[test]
    fn with_span_if_none_keeps_precise_span() {
        let e = EngineError::with_span(ErrorKind::UnexpectedToken, Span::new(2, 3));
        let e2 = e.with_span_if_none(Span::new(0, 10));
        assert_eq!(e2.span, Some(Span::new(2, 3)));
        let e3 = EngineError::new(ErrorKind::DomainError).with_span_if_none(Span::new(1, 2));
        assert_eq!(e3.span, Some(Span::new(1, 2)));
    }
}
