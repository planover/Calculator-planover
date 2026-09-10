//! T07：变量赋值 / ans 解耦 / 重置保留 ans（Q9）/ 保留名拒绝 / 删除变量 / 列表顺序。
//!
//! 覆盖 PRD P0-05 / P0-13 与架构 Q9。

mod common;

use calculator_core::engine::Engine;
use calculator_core::error::ErrorKind;
use calculator_core::num::Num;

#[test]
fn variable_assignment_and_read() {
    let mut e = Engine::new();
    let v = e.set_variable("a", "3+4").unwrap();
    assert_eq!(v.display, "7");
    // 提交后变量可被后续表达式引用
    let r = e.evaluate_commit("a*2").unwrap();
    assert_eq!(r.display, "14");
    // 列出变量包含 a
    let list = e.list_variables();
    assert!(list.iter().any(|x| x.name == "a" && x.display == "7"));
}

#[test]
fn ans_updates_only_on_commit_and_is_independent() {
    let mut e = Engine::new();
    // 预览不更新 ans
    let _ = e.evaluate_preview("10+20").unwrap();
    assert!(e.session().ans.is_none());
    // 提交更新 ans
    let _ = e.evaluate_commit("10+20").unwrap();
    assert_eq!(e.session().ans, Some(Num::int(30)));
    // 再次提交覆盖 ans（与历史无关，不会把前面结果也累加进去）
    let _ = e.evaluate_commit("1+1").unwrap();
    assert_eq!(e.session().ans, Some(Num::int(2)));
    // 用 ans 继续计算
    let r = e.evaluate_commit("ans*3").unwrap();
    assert_eq!(r.display, "6");
}

#[test]
fn reset_keeps_ans_q9() {
    let mut e = Engine::new();
    e.evaluate_commit("5").unwrap();
    e.set_variable("x", "1").unwrap();
    e.reset_session();
    // ans 保留（Q9：清空历史不重置 ans）
    assert_eq!(e.session().ans, Some(Num::int(5)));
    // 用户变量被清掉
    assert!(e.session().get_var("x").is_err());
    // ans 仍可用
    let r = e.evaluate_preview("ans*2").unwrap();
    assert_eq!(r.display, "10");
}

#[test]
fn reserved_names_rejected_at_engine_level() {
    let mut e = Engine::new();
    assert_eq!(
        e.set_variable("ans", "1").unwrap_err().kind,
        ErrorKind::ReservedName
    );
    assert_eq!(
        e.set_variable("pi", "1").unwrap_err().kind,
        ErrorKind::ReservedName
    );
    assert_eq!(
        e.set_variable("sin", "1").unwrap_err().kind,
        ErrorKind::ReservedName
    );
    // 变量名本身不合法
    assert_eq!(
        e.set_variable("1a", "1").unwrap_err().kind,
        ErrorKind::InvalidVariableName
    );
}

#[test]
fn delete_variable_roundtrip() {
    let mut e = Engine::new();
    e.set_variable("kk", "2*3").unwrap();
    assert_eq!(e.session().get_var("kk").unwrap(), Num::int(6));
    e.delete_variable("kk").unwrap();
    assert!(e.session().get_var("kk").is_err());
    // 删除不存在的变量：明确报错而不是静默成功
    assert_eq!(
        e.delete_variable("kk").unwrap_err().kind,
        ErrorKind::UndefinedVariable
    );
}

#[test]
fn list_variables_puts_ans_first_and_sorted() {
    let mut e = Engine::new();
    e.evaluate_commit("3").unwrap();
    e.set_variable("b", "2").unwrap();
    e.set_variable("a", "1").unwrap();
    let list = e.list_variables();
    // ans 排在最前且只读
    assert_eq!(list[0].name, "ans");
    assert!(list[0].readonly);
    // 用户变量按字母序
    let names: Vec<&str> = list[1..].iter().map(|v| v.name.as_str()).collect();
    assert_eq!(names, vec!["a", "b"]);
}

#[test]
fn constants_are_readable_through_session() {
    let mut e = Engine::new();
    // 常量可当作只读变量读取
    let r = e.evaluate_preview("e").unwrap();
    assert!((r.value.to_f64() - std::f64::consts::E).abs() < 1e-12);
    let r2 = e.evaluate_preview("pi*2").unwrap();
    assert!((r2.value.to_f64() - 2.0 * std::f64::consts::PI).abs() < 1e-12);
}
