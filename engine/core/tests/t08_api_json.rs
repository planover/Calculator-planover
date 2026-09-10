//! T08：api::dispatch 的 JSON 契约（每个 method 至少 2 个用例）。
//!
//! 覆盖架构 §5.2 全部方法；验证返回**永远是一段合法 JSON**，
//! 成功用 `ok:true` + `data`，失败用 `ok:false` + `error{code,kind,message}`。

mod common;

use calculator_core::api::dispatch;
use calculator_core::engine::Engine;
use serde_json::Value;

/// 调用 dispatch 并解析返回的 JSON（必须是合法 JSON，否则直接 panic）。
fn call(method: &str, json: &str) -> Value {
    let out = dispatch(method, json, &mut Engine::new());
    serde_json::from_str(&out).expect("dispatch 必须返回合法 JSON")
}

#[test]
fn version_contract() {
    let v = call("version", "{}");
    assert_eq!(v["ok"], true);
    assert_eq!(v["data"]["engine"], "calculator_core");
    assert!(!v["data"]["version"].as_str().unwrap().is_empty());
    assert_eq!(v["data"]["abi"], 1);
    // 别名
    let v2 = call("calc_version", "{}");
    assert_eq!(v2["data"]["engine"], "calculator_core");
}

#[test]
fn evaluate_preview_success_and_error() {
    let ok = call("evaluate_preview", r#"{"expr":"2+3*4"}"#);
    assert_eq!(ok["ok"], true);
    assert_eq!(ok["data"]["display"], "14");
    assert_eq!(ok["data"]["is_integer"], true);
    assert!(ok["data"]["base"]["hex"].is_string());
    assert!(ok["data"]["base"]["is_integer"].as_bool().unwrap());

    let err = call("evaluate_preview", r#"{"expr":"1/0"}"#);
    assert_eq!(err["ok"], false);
    assert_eq!(err["error"]["code"], 2000);
    assert_eq!(err["error"]["kind"], "division_by_zero");
    assert!(err["error"]["message"].as_str().unwrap().len() > 0);
}

#[test]
fn evaluate_commit_updates_ans() {
    let mut e = Engine::new();
    let _ = dispatch("evaluate_commit", r#"{"expr":"6"}"#, &mut e);
    let out = dispatch("evaluate_preview", r#"{"expr":"ans*7"}"#, &mut e);
    let v: Value = serde_json::from_str(&out).unwrap();
    assert_eq!(v["ok"], true);
    assert_eq!(v["data"]["display"], "42");
}

#[test]
fn convert_value_and_query() {
    let v = call("convert", r#"{"value":"12.7","from":"inch","to":"mm"}"#);
    assert_eq!(v["ok"], true);
    assert_eq!(v["data"]["output_display"], "322.58 mm");
    assert_eq!(v["data"]["from"]["id"], "inch");
    assert_eq!(v["data"]["to"]["category"], "length");

    let q = call("convert", r#"{"query":"1 inch in kg"}"#);
    assert_eq!(q["ok"], false);
    assert_eq!(q["error"]["code"], 3001); // IncompatibleUnits
}

#[test]
fn list_constants_and_units() {
    let c = call("list_constants", "{}");
    let arr = c["data"]["constants"].as_array().unwrap();
    assert!(arr.len() >= 12, "常量数量应 >= 12，实际 {}", arr.len());
    assert_eq!(arr[0]["symbol"], "π");

    let u = call("list_units", "{}");
    let cats = u["data"]["categories"].as_array().unwrap();
    assert_eq!(cats.len(), 10, "应有 10 个类别，实际 {}", cats.len());
    let t = call("list_units", r#"{"category":"temperature"}"#);
    assert_eq!(t["data"]["categories"][0]["units"][0]["kind"], "affine");

    let bad = call("list_units", r#"{"category":"nope"}"#);
    assert_eq!(bad["ok"], false);
    assert_eq!(bad["error"]["code"], 5000);
}

#[test]
fn variables_contract() {
    let mut e = Engine::new();
    let set: Value =
        serde_json::from_str(&dispatch("set_variable", r#"{"name":"a","expr":"3+4"}"#, &mut e))
            .unwrap();
    assert_eq!(set["ok"], true);
    assert_eq!(set["data"]["name"], "a");
    assert_eq!(set["data"]["display"], "7");

    let list: Value =
        serde_json::from_str(&dispatch("list_variables", "{}", &mut e)).unwrap();
    let arr = list["data"]["variables"].as_array().unwrap();
    assert!(arr.iter().any(|x| x["name"] == "a"));

    let del: Value =
        serde_json::from_str(&dispatch("delete_variable", r#"{"name":"a"}"#, &mut e)).unwrap();
    assert_eq!(del["data"]["name"], "a");
}

#[test]
fn angle_mode_and_word_size() {
    let m = call("set_angle_mode", r#"{"angle_mode":"rad"}"#);
    assert_eq!(m["data"]["angle_mode"], "rad");
    let bad = call("set_angle_mode", r#"{"angle_mode":"xxx"}"#);
    assert_eq!(bad["ok"], false);
    assert_eq!(bad["error"]["code"], 5001);

    let w = call("set_word_size", r#"{"word_size":32}"#);
    assert_eq!(w["data"]["word_size"], 32);
    let badw = call("set_word_size", r#"{"word_size":24}"#);
    assert_eq!(badw["ok"], false);
    assert_eq!(badw["error"]["code"], 5001);
}

#[test]
fn reset_session_contract() {
    let mut e = Engine::new();
    let _ = dispatch("evaluate_commit", r#"{"expr":"5"}"#, &mut e);
    // keep_ans=true：保留 ans
    let keep = dispatch("reset_session", r#"{"keep_ans":true}"#, &mut e);
    let kv: Value = serde_json::from_str(&keep).unwrap();
    assert_eq!(kv["data"]["ok"], true);
    let after = dispatch("evaluate_preview", r#"{"expr":"ans*2"}"#, &mut e);
    let av: Value = serde_json::from_str(&after).unwrap();
    assert_eq!(av["data"]["display"], "10");

    // keep_ans=false：丢弃 ans
    let _ = dispatch("evaluate_commit", r#"{"expr":"9"}"#, &mut e);
    let _ = dispatch("reset_session", r#"{"keep_ans":false}"#, &mut e);
    let gone = dispatch("evaluate_preview", r#"{"expr":"ans"}"#, &mut e);
    let gv: Value = serde_json::from_str(&gone).unwrap();
    assert_eq!(gv["ok"], false);
    assert_eq!(gv["error"]["code"], 4000);
}

#[test]
fn format_number_contract() {
    let f = call("format_number", r#"{"value":"1/3"}"#);
    assert_eq!(f["data"]["display"], "0.3333333333");
    assert_eq!(f["data"]["is_integer"], false);
    let f2 = call(
        "format_number",
        r#"{"value":"1/3+1/6","settings":{"fraction_mode":"improper"}}"#,
    );
    assert_eq!(f2["data"]["display"], "1/2");
}

#[test]
fn apply_edit_contract() {
    let a = call(
        "apply_edit",
        r#"{"text":"(","cursor":1,"action":"insert","payload":")"}"#,
    );
    assert_eq!(a["data"]["text"], "()");
    assert_eq!(a["data"]["cursor"], 1);
    assert_eq!(a["data"]["changed"], true);

    let b = call(
        "apply_edit",
        r#"{"text":"1+2","cursor":3,"action":"backspace","payload":""}"#,
    );
    assert_eq!(b["data"]["text"], "1+");
    assert_eq!(b["data"]["cursor"], 2);
}

#[test]
fn invalid_request_contract() {
    let unknown = call("no_such_method", "{}");
    assert_eq!(unknown["ok"], false);
    assert_eq!(unknown["error"]["code"], 5000);
    assert_eq!(unknown["error"]["kind"], "invalid_request");

    let bad_json = call("evaluate_preview", "{oops");
    assert_eq!(bad_json["ok"], false);
    assert_eq!(bad_json["error"]["code"], 5000);
}

#[test]
fn dispatch_never_returns_empty_or_non_json() {
    let mut e = Engine::new();
    for m in [
        "version",
        "evaluate_preview",
        "convert",
        "list_constants",
        "list_units",
        "list_variables",
        "apply_edit",
        "set_angle_mode",
        "no",
    ] {
        let out = dispatch(m, "{}", &mut e);
        assert!(!out.is_empty(), "方法 {} 返回了空串", m);
        serde_json::from_str::<Value>(&out).expect("必须是合法 JSON");
    }
}
