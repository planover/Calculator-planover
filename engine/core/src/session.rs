//! 会话状态：变量表 / `ans` / 引擎设置。
//!
//! `ans` 与历史**解耦**（Q9）：清空历史不重置 `ans`，`reset()` 也保留 `ans`。

use std::collections::HashMap;

use crate::base;
use crate::constants;
use crate::error::{EngineError, ErrorKind, Result};
use crate::format::NumberFormatSettings;
use crate::functions;
use crate::num::Num;

/// 角度模式。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AngleMode {
    /// 度。
    Deg,
    /// 弧度。
    Rad,
    /// 百分度（gon）。
    Grad,
}

impl AngleMode {
    /// 角度值 → 弧度。
    pub fn to_radians(&self, v: f64) -> f64 {
        match self {
            AngleMode::Deg => v * std::f64::consts::PI / 180.0,
            AngleMode::Rad => v,
            AngleMode::Grad => v * std::f64::consts::PI / 200.0,
        }
    }

    /// 弧度 → 当前角度单位下的值。
    pub fn from_radians(&self, v: f64) -> f64 {
        match self {
            AngleMode::Deg => v * 180.0 / std::f64::consts::PI,
            AngleMode::Rad => v,
            AngleMode::Grad => v * 200.0 / std::f64::consts::PI,
        }
    }

    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            AngleMode::Deg => "deg",
            AngleMode::Rad => "rad",
            AngleMode::Grad => "grad",
        }
    }

    /// 从标识解析。
    pub fn from_id(s: &str) -> Option<AngleMode> {
        match s.trim().to_lowercase().as_str() {
            "deg" | "degree" => Some(AngleMode::Deg),
            "rad" | "radian" => Some(AngleMode::Rad),
            "grad" | "gon" => Some(AngleMode::Grad),
            _ => None,
        }
    }
}

/// 引擎设置。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EngineSettings {
    /// 角度模式。
    pub angle_mode: AngleMode,
    /// 位宽 8/16/32/64。
    pub word_size: u8,
    /// 数字格式化设置。
    pub format: NumberFormatSettings,
}

impl Default for EngineSettings {
    fn default() -> Self {
        Self {
            angle_mode: AngleMode::Deg,
            word_size: 64,
            format: NumberFormatSettings::default(),
        }
    }
}

/// 变量展示信息。
#[derive(Debug, Clone, PartialEq)]
pub struct VariableInfo {
    /// 名字。
    pub name: String,
    /// 已按当前格式设置渲染好的值。
    pub display: String,
    /// 是否只读（`ans` 为 true）。
    pub readonly: bool,
}

/// 会话。
#[derive(Debug, Clone, PartialEq)]
pub struct Session {
    /// 用户自定义变量。
    pub variables: HashMap<String, Num>,
    /// 上一次提交的结果；与历史解耦。
    pub ans: Option<Num>,
    /// 当前设置。
    pub settings: EngineSettings,
}

impl Default for Session {
    fn default() -> Self {
        Self::new()
    }
}

impl Session {
    /// 新建空会话。
    pub fn new() -> Self {
        Self {
            variables: HashMap::new(),
            ans: None,
            settings: EngineSettings::default(),
        }
    }

    /// 取变量值。查找顺序：`ans` → 常量表 → 用户变量。
    pub fn get_var(&self, name: &str) -> Result<Num> {
        if name.eq_ignore_ascii_case("ans") {
            return self.ans.ok_or_else(|| {
                EngineError::with_message(ErrorKind::UndefinedVariable, "ans 还没有值，先按一次 =")
            });
        }
        if let Some(c) = constants::lookup(name) {
            return Ok(Num::float(c.value));
        }
        self.variables.get(name).copied().ok_or_else(|| {
            EngineError::with_message(ErrorKind::UndefinedVariable, format!("未定义的变量 {}", name))
        })
    }

    /// 写变量；保留名与非法名一律拒绝。
    pub fn set_var(&mut self, name: &str, v: Num) -> Result<()> {
        validate_variable_name(name)?;
        if is_reserved(name) {
            return Err(EngineError::with_message(
                ErrorKind::ReservedName,
                format!("“{}” 是保留名，不能作为变量", name),
            ));
        }
        self.variables.insert(name.to_string(), v);
        Ok(())
    }

    /// 删除变量；`ans` 不可删除。
    pub fn delete_var(&mut self, name: &str) -> Result<()> {
        if name.eq_ignore_ascii_case("ans") {
            return Err(EngineError::with_message(
                ErrorKind::ReservedName,
                "ans 由引擎维护，不能删除",
            ));
        }
        match self.variables.remove(name) {
            Some(_) => Ok(()),
            None => Err(EngineError::with_message(
                ErrorKind::UndefinedVariable,
                format!("变量 {} 不存在", name),
            )),
        }
    }

    /// 列出全部变量（`ans` 在最前且标记为只读）。
    pub fn list_vars(&self) -> Vec<VariableInfo> {
        let mut out = Vec::new();
        if let Some(a) = self.ans {
            out.push(VariableInfo {
                name: "ans".to_string(),
                display: crate::format::plain_decimal(&a),
                readonly: true,
            });
        }
        let mut names: Vec<&String> = self.variables.keys().collect();
        names.sort();
        for n in names {
            let v = self.variables[n.as_str()];
            out.push(VariableInfo {
                name: n.clone(),
                display: crate::format::plain_decimal(&v),
                readonly: false,
            });
        }
        out
    }

    /// 清空用户变量，**保留 ans**（Q9）。
    pub fn reset(&mut self) {
        self.variables.clear();
    }

    /// 设置位宽（8/16/32/64）。
    pub fn set_word_size(&mut self, w: u8) -> Result<()> {
        base::validate_word_size(w)?;
        self.settings.word_size = w;
        Ok(())
    }
}

/// 变量名合法性：首字符为字母或下划线，其余为字母/数字/下划线。
pub fn validate_variable_name(name: &str) -> Result<()> {
    let mut chars = name.chars();
    let first = chars
        .next()
        .ok_or_else(|| EngineError::new(ErrorKind::InvalidVariableName))?;
    if !(first.is_alphabetic() || first == '_') {
        return Err(EngineError::with_message(
            ErrorKind::InvalidVariableName,
            format!("变量名 “{}” 必须以字母或下划线开头", name),
        ));
    }
    if !chars.all(|c| c.is_alphanumeric() || c == '_') {
        return Err(EngineError::with_message(
            ErrorKind::InvalidVariableName,
            format!("变量名 “{}” 只能包含字母、数字和下划线", name),
        ));
    }
    Ok(())
}

/// 是否为保留名（`ans` / 常量 / 函数名）。
pub fn is_reserved(name: &str) -> bool {
    name.eq_ignore_ascii_case("ans")
        || constants::is_constant_name(name)
        || functions::is_function_name(name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn angle_mode_conversion() {
        assert!((AngleMode::Deg.to_radians(180.0) - std::f64::consts::PI).abs() < 1e-12);
        assert!((AngleMode::Grad.to_radians(200.0) - std::f64::consts::PI).abs() < 1e-12);
        assert_eq!(AngleMode::Rad.to_radians(2.0), 2.0);
        assert!((AngleMode::Deg.from_radians(std::f64::consts::PI) - 180.0).abs() < 1e-9);
        assert_eq!(AngleMode::from_id("RAD"), Some(AngleMode::Rad));
        assert_eq!(AngleMode::Deg.id(), "deg");
    }

    #[test]
    fn constants_are_readable() {
        let s = Session::new();
        assert_eq!(s.get_var("c").unwrap().to_f64(), 299792458.0);
        assert_eq!(s.get_var("pi").unwrap().to_f64(), std::f64::consts::PI);
    }

    #[test]
    fn ans_is_undefined_until_commit() {
        let s = Session::new();
        assert_eq!(s.get_var("ans").unwrap_err().kind, ErrorKind::UndefinedVariable);
    }

    #[test]
    fn set_get_delete_variable() {
        let mut s = Session::new();
        s.set_var("a", Num::int(7)).unwrap();
        assert_eq!(s.get_var("a").unwrap(), Num::int(7));
        s.delete_var("a").unwrap();
        assert_eq!(s.get_var("a").unwrap_err().kind, ErrorKind::UndefinedVariable);
        assert_eq!(s.delete_var("a").unwrap_err().kind, ErrorKind::UndefinedVariable);
    }

    #[test]
    fn reserved_names_rejected() {
        let mut s = Session::new();
        assert_eq!(s.set_var("ans", Num::int(1)).unwrap_err().kind, ErrorKind::ReservedName);
        assert_eq!(s.set_var("π", Num::int(1)).unwrap_err().kind, ErrorKind::ReservedName);
        assert_eq!(s.set_var("sin", Num::int(1)).unwrap_err().kind, ErrorKind::ReservedName);
    }

    #[test]
    fn invalid_names_rejected() {
        let mut s = Session::new();
        assert_eq!(s.set_var("1a", Num::int(1)).unwrap_err().kind, ErrorKind::InvalidVariableName);
        assert_eq!(s.set_var("a b", Num::int(1)).unwrap_err().kind, ErrorKind::InvalidVariableName);
        assert_eq!(s.set_var("", Num::int(1)).unwrap_err().kind, ErrorKind::InvalidVariableName);
    }

    #[test]
    fn reset_keeps_ans() {
        let mut s = Session::new();
        s.ans = Some(Num::int(42));
        s.set_var("x", Num::int(1)).unwrap();
        s.reset();
        assert!(s.variables.is_empty());
        assert_eq!(s.ans, Some(Num::int(42)));
        assert_eq!(s.get_var("ans").unwrap(), Num::int(42));
    }

    #[test]
    fn list_vars_puts_ans_first_and_readonly() {
        let mut s = Session::new();
        s.ans = Some(Num::int(3));
        s.set_var("b", Num::int(2)).unwrap();
        s.set_var("a", Num::int(1)).unwrap();
        let v = s.list_vars();
        assert_eq!(v[0].name, "ans");
        assert!(v[0].readonly);
        assert_eq!(v[1].name, "a");
        assert_eq!(v[2].name, "b");
    }

    #[test]
    fn word_size_setting() {
        let mut s = Session::new();
        assert!(s.set_word_size(32).is_ok());
        assert_eq!(s.settings.word_size, 32);
        assert_eq!(s.set_word_size(12).unwrap_err().kind, ErrorKind::InvalidSettings);
    }
}
