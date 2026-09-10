//! `calculator_core` —— Calculator-planover 的计算内核。
//!
//! 本 crate **只产出 rlib**，承载全部计算逻辑与全部测试，可在任意桌面环境
//! `cargo test -p calculator_core` 验证，不依赖 Android / Flutter / IO / 系统时间。
//!
//! 分层（自底向上）：
//! - [`span`] / [`error`]：错误定位与错误分类
//! - [`num`]：数值类型（精确有理数 ∪ f64 ∪ 非有限值）
//! - [`token`] / [`lexer`] / [`ast`] / [`parser`]：表达式前端
//! - [`functions`] / [`constants`] / [`units`] / [`base`] / [`format`]：领域能力
//! - [`session`] / [`eval`] / [`engine`]：运行时与门面
//! - [`api`]：JSON DTO 与 `dispatch` 统一入口（FFI 层只做转发）
//! - [`edit`]：输入编辑纯函数

pub mod api;
pub mod ast;
pub mod base;
pub mod constants;
pub mod edit;
pub mod engine;
pub mod error;
pub mod eval;
pub mod format;
pub mod functions;
pub mod lexer;
pub mod num;
pub mod parser;
pub mod session;
pub mod span;
pub mod token;
pub mod units;

pub use engine::Engine;
pub use error::{EngineError, ErrorKind, Result};
pub use num::Num;
pub use span::Span;

/// 引擎语义版本号，写入 `calc_version()` 响应的 `engine` 字段。
pub const ENGINE_NAME: &str = "calculator_core";
/// 引擎版本号。
pub const ENGINE_VERSION: &str = "1.0.0";
/// C ABI 版本号。结构体字段发生不兼容变更时必须 +1，Dart 启动自检用。
pub const ABI_VERSION: u32 = 1;
