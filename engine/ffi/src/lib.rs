//! `calculator_ffi` —— C ABI 胶水层。
//!
//! 职责边界（架构 §1.2-L4）：**只做 `*const c_char` ↔ `String` 与 JSON 转发，
//! 不放任何计算逻辑**。所有语义都在 `calculator_core::api::dispatch` 里，
//! 因此可以在本机用 `cargo test -p calculator_core` 完整覆盖。
//!
//! 内存契约：
//! - 入参是 UTF-8、以 `\0` 结尾的 C 字符串；`NULL` 视作 `{}`。
//! - 返回值由本库用 `CString::into_raw()` 分配，**永不返回 NULL**；
//!   Dart 必须在 `finally` 里调 [`calc_string_free`]，且同一指针只能释放一次。
//! - panic 一律被 [`catch_unwind`] 兜住，转成 `code=5002`，绝不跨越 FFI 边界。

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{self, AssertUnwindSafe};
use std::sync::{LazyLock, Mutex};

use calculator_core::api;
use calculator_core::Engine;

/// 进程级会话单例。用 `Mutex` 串行化，可从任意 Dart isolate 调用。
static ENGINE: LazyLock<Mutex<Engine>> = LazyLock::new(|| Mutex::new(Engine::new()));

/// 序列化彻底失败时的兜底 JSON；保证调用方永远拿到合法字符串。
const FALLBACK_JSON: &str =
    r#"{"ok":false,"error":{"code":5002,"kind":"internal_error","message":"引擎内部错误"}}"#;

/// 把 `*const c_char` 安全地转成 `&str`；`NULL` 或非法 UTF-8 时返回空串。
///
/// 返回空串意味着"空请求"，`dispatch` 会用 `{}` 处理，从而缺字段的请求
/// 得到的是 `InvalidRequest` 而不是崩溃。
fn read_input(req: *const c_char) -> String {
    if req.is_null() {
        return String::new();
    }
    // SAFETY: 调用方保证传入以 '\0' 结尾的合法 C 字符串。
    let cstr = unsafe { CStr::from_ptr(req) };
    cstr.to_str().unwrap_or("").to_string()
}

/// 把 Rust 字符串交给 Dart：用 `CString::into_raw()` 转移所有权。
fn into_raw(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        // 字符串里出现内嵌 NUL（理论上不应发生）时截断处理，绝不返回 NULL
        Err(_) => CString::new(FALLBACK_JSON)
            .unwrap_or_else(|_| CString::new("").unwrap())
            .into_raw(),
    }
}

/// 统一的调用包装：加锁 → 分发 → catch_unwind。
fn call(method: &str, req: *const c_char) -> *mut c_char {
    let input = read_input(req);
    let result = panic::catch_unwind(AssertUnwindSafe(|| {
        // 锁被 Poison 时不 unwrap（那会 panic），直接降级成新会话继续使用。
        // 计算引擎的状态是纯内存的，重建一个不会造成数据损坏。
        let mut guard = match ENGINE.lock() {
            Ok(g) => g,
            Err(poisoned) => poisoned.into_inner(),
        };
        api::dispatch(method, &input, &mut guard)
    }));
    into_raw(result.unwrap_or_else(|_| FALLBACK_JSON.to_string()))
}

/// 引擎版本自检；Dart 启动时调用，版本号不匹配直接报错。
///
/// 请求：忽略（可传 NULL）。响应 `data`：
/// `{"version":"1.0.0","engine":"calculator_core","abi":1}`
#[no_mangle]
pub extern "C" fn calc_version() -> *mut c_char {
    call("version", std::ptr::null())
}

/// 预览求值（**无副作用**：不改 ans，不写变量）。
#[no_mangle]
pub extern "C" fn calc_evaluate_preview(req: *const c_char) -> *mut c_char {
    call("evaluate_preview", req)
}

/// 提交求值（更新 ans；赋值语句写入变量）。
#[no_mangle]
pub extern "C" fn calc_evaluate_commit(req: *const c_char) -> *mut c_char {
    call("evaluate_commit", req)
}

/// 单位换算。
#[no_mangle]
pub extern "C" fn calc_convert(req: *const c_char) -> *mut c_char {
    call("convert", req)
}

/// 常量列表。
#[no_mangle]
pub extern "C" fn calc_list_constants(req: *const c_char) -> *mut c_char {
    call("list_constants", req)
}

/// 单位列表；`{}` 返回全部 10 类。
#[no_mangle]
pub extern "C" fn calc_list_units(req: *const c_char) -> *mut c_char {
    call("list_units", req)
}

/// 变量列表（含只读的 ans）。
#[no_mangle]
pub extern "C" fn calc_list_variables(req: *const c_char) -> *mut c_char {
    call("list_variables", req)
}

/// 按设置格式化一个数值表达式。
#[no_mangle]
pub extern "C" fn calc_format_number(req: *const c_char) -> *mut c_char {
    call("format_number", req)
}

/// 定义变量（右值先求值再存）。
#[no_mangle]
pub extern "C" fn calc_set_variable(req: *const c_char) -> *mut c_char {
    call("set_variable", req)
}

/// 删除变量。
#[no_mangle]
pub extern "C" fn calc_delete_variable(req: *const c_char) -> *mut c_char {
    call("delete_variable", req)
}

/// 设置角度模式。
#[no_mangle]
pub extern "C" fn calc_set_angle_mode(req: *const c_char) -> *mut c_char {
    call("set_angle_mode", req)
}

/// 设置位宽（8/16/32/64）。
#[no_mangle]
pub extern "C" fn calc_set_word_size(req: *const c_char) -> *mut c_char {
    call("set_word_size", req)
}

/// 重置会话（默认保留 ans）。
#[no_mangle]
pub extern "C" fn calc_reset_session(req: *const c_char) -> *mut c_char {
    call("reset_session", req)
}

/// 输入编辑纯函数（括号自动配对等）。
#[no_mangle]
pub extern "C" fn calc_apply_edit(req: *const c_char) -> *mut c_char {
    call("apply_edit", req)
}

/// 释放本库分配的 C 字符串。
///
/// 对 `nullptr` 调用是安全的 no-op；**同一指针禁止释放两次**。
#[no_mangle]
pub extern "C" fn calc_string_free(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    // SAFETY: 指针来自 CString::into_raw，且调用方遵守"只释放一次"约定。
    drop(unsafe { CString::from_raw(s) });
}
