//! [`Engine`] 领域门面。
//!
//! 所有 Dart 侧需要的领域能力都从这里出口；`api.rs` 只负责把它包成 JSON。

use crate::ast::Expr;
use crate::base::BaseRepr;
use crate::constants::{self, ConstantDef};
use crate::error::{EngineError, ErrorKind, Result};
use crate::eval::{self, EvalContext};
use crate::format;
use crate::num::Num;
use crate::parser::Parser;
use crate::session::{AngleMode, EngineSettings, Session, VariableInfo};
use crate::units::{self, CategoryInfo, UnitCategory, UnitDef, UnitInfo};

/// 求值结果（领域层）。
#[derive(Debug, Clone, PartialEq)]
pub struct EvalResult {
    /// 精确数值。
    pub value: Num,
    /// 已按格式设置渲染好的显示串。
    pub display: String,
    /// 分数模式下的表示；非分数模式为 `None`。
    pub fraction: Option<String>,
    /// 四种进制表示。
    pub base: BaseRepr,
    /// 本次执行产生的变量/ans 变更。
    pub assignments: Vec<VariableInfo>,
}

/// 单位换算结果。
#[derive(Debug, Clone, PartialEq)]
pub struct ConvertResult {
    /// 源单位。
    pub from: UnitInfo,
    /// 目标单位。
    pub to: UnitInfo,
    /// 输入数值。
    pub input_value: Num,
    /// 输出数值。
    pub output_value: Num,
    /// 输入显示串（含单位）。
    pub input_display: String,
    /// 输出显示串（含单位）。
    pub output_display: String,
}

/// 常量展示信息。
#[derive(Debug, Clone, PartialEq)]
pub struct ConstantInfo {
    /// 符号。
    pub symbol: String,
    /// 中文名。
    pub name: String,
    /// 单位。
    pub unit: String,
    /// 数值（f64）。
    pub value: f64,
    /// 分类。
    pub category: String,
    /// 别名。
    pub aliases: Vec<String>,
}

impl ConstantInfo {
    /// 由 [`ConstantDef`] 生成。
    pub fn of(c: &ConstantDef) -> Self {
        Self {
            symbol: c.symbol.to_string(),
            name: c.name.to_string(),
            unit: c.unit.to_string(),
            value: c.value,
            category: c.category.to_string(),
            aliases: c.aliases.iter().map(|a| a.to_string()).collect(),
        }
    }
}

/// 格式化后的值。
#[derive(Debug, Clone, PartialEq)]
pub struct FormattedValue {
    /// 显示串。
    pub display: String,
    /// 分数串。
    pub fraction: Option<String>,
    /// f64 近似值。
    pub approx: f64,
    /// 是否为整数。
    pub is_integer: bool,
}

/// 计算引擎门面。
#[derive(Debug, Clone)]
pub struct Engine {
    session: Session,
}

impl Default for Engine {
    fn default() -> Self {
        Self::new()
    }
}

impl Engine {
    /// 新建引擎。
    pub fn new() -> Self {
        Self {
            session: Session::new(),
        }
    }

    /// 当前设置。
    pub fn settings(&self) -> &EngineSettings {
        &self.session.settings
    }

    /// 可变会话引用（供测试与高级用法使用）。
    pub fn session_mut(&mut self) -> &mut Session {
        &mut self.session
    }

    /// 只读会话引用。
    pub fn session(&self) -> &Session {
        &self.session
    }

    /// 设置角度模式。
    pub fn set_angle_mode(&mut self, m: AngleMode) {
        self.session.settings.angle_mode = m;
    }

    /// 设置位宽（8/16/32/64）。
    pub fn set_word_size(&mut self, w: u8) -> Result<()> {
        self.session.set_word_size(w)
    }

    /// 应用一套完整设置（角度/位宽/格式化），逐项校验，任一项非法即整体拒绝。
    pub fn apply_settings(
        &mut self,
        angle_mode: Option<AngleMode>,
        word_size: Option<u8>,
        format: Option<crate::format::NumberFormatSettings>,
    ) -> Result<()> {
        if let Some(w) = word_size {
            crate::base::validate_word_size(w)?;
        }
        if let Some(f) = format {
            crate::format::validate(&f)?;
        }
        if let Some(a) = angle_mode {
            self.session.settings.angle_mode = a;
        }
        if let Some(w) = word_size {
            self.session.settings.word_size = w;
        }
        if let Some(f) = format {
            self.session.settings.format = f;
        }
        Ok(())
    }

    /// 重置会话（清变量，**保留 ans**）。
    pub fn reset_session(&mut self) {
        self.session.reset();
    }

    /// 预览求值。
    ///
    /// 语义：**不改 ans**；唯一的例外是表达式本身是赋值语句（`a=3+4`），
    /// 此时会写入变量并把变更放进 `assignments`，否则用户还得再按一次 `=` 才能引用。
    pub fn evaluate_preview(&mut self, expr: &str) -> Result<EvalResult> {
        self.run(expr, false)
    }

    /// 提交求值：更新 `ans`，并（若是赋值语句）写入变量。
    pub fn evaluate_commit(&mut self, expr: &str) -> Result<EvalResult> {
        self.run(expr, true)
    }

    fn run(&mut self, src: &str, commit: bool) -> Result<EvalResult> {
        let toks = crate::lexer::tokenize(src)?;
        let ast = Parser::new(&toks, src).parse()?;
        let is_assign = matches!(ast, Expr::Assign { .. });

        let value = if commit || is_assign {
            let mut ctx = EvalContext {
                session: &mut self.session,
                depth: 0,
            };
            eval::eval(&ast, &mut ctx)?
        } else {
            // 预览在会话副本上求值，保证不污染 ans / 变量
            let mut shadow = self.session.clone();
            let mut ctx = EvalContext {
                session: &mut shadow,
                depth: 0,
            };
            eval::eval(&ast, &mut ctx)?
        };

        let fmt = self.session.settings.format;
        let display = format::format_number(&value, &fmt)?;
        let fraction = format::format_fraction(&value, fmt.fraction_mode);
        let base = crate::base::repr_of(&value, self.session.settings.word_size);

        let mut assignments = Vec::new();
        if let Expr::Assign { name, .. } = &ast {
            assignments.push(VariableInfo {
                name: name.clone(),
                display: display.clone(),
                readonly: false,
            });
        }
        if commit {
            self.session.ans = Some(value);
            assignments.push(VariableInfo {
                name: "ans".to_string(),
                display: display.clone(),
                readonly: true,
            });
        }
        Ok(EvalResult {
            value,
            display,
            fraction,
            base,
            assignments,
        })
    }

    /// 单位换算（显式单位 id）。
    pub fn convert(&self, value: &Num, from: &str, to: &str) -> Result<ConvertResult> {
        let f = units::lookup_unit(from).ok_or_else(|| {
            EngineError::with_message(ErrorKind::UnknownUnit, format!("未知单位 {}", from))
        })?;
        let t = units::lookup_unit(to).ok_or_else(|| {
            EngineError::with_message(ErrorKind::UnknownUnit, format!("未知单位 {}", to))
        })?;
        let out = units::convert(value, f, t)?;
        self.build_convert_result(value, out, f, t)
    }

    /// 单位换算（自然语言查询，如 `12.7 inch in mm`）。
    pub fn convert_query(&self, q: &str) -> Result<ConvertResult> {
        let (value, f, t) = units::parse_convert_query(q)?;
        let out = units::convert(&value, f, t)?;
        self.build_convert_result(&value, out, f, t)
    }

    fn build_convert_result(
        &self,
        input: &Num,
        output: Num,
        f: &'static UnitDef,
        t: &'static UnitDef,
    ) -> Result<ConvertResult> {
        let fmt = self.session.settings.format;
        let iv = format::format_number(input, &fmt)?;
        let ov = format::format_number(&output, &fmt)?;
        Ok(ConvertResult {
            from: UnitInfo::of(f),
            to: UnitInfo::of(t),
            input_value: *input,
            output_value: output,
            input_display: format!("{} {}", iv, f.symbol),
            output_display: format!("{} {}", ov, t.symbol),
        })
    }

    /// 常量列表。
    pub fn list_constants(&self) -> Vec<ConstantInfo> {
        constants::all().iter().map(ConstantInfo::of).collect()
    }

    /// 单位类别列表；`None` 返回全部 10 类。
    pub fn list_units(&self, category: Option<UnitCategory>) -> Vec<CategoryInfo> {
        match category {
            Some(c) => vec![CategoryInfo::of(c)],
            None => units::all_categories(),
        }
    }

    /// 变量列表（含只读的 `ans`）。
    pub fn list_variables(&self) -> Vec<VariableInfo> {
        self.session.list_vars()
    }

    /// 定义/覆盖一个变量：`expr` 先求值再存。
    pub fn set_variable(&mut self, name: &str, expr: &str) -> Result<VariableInfo> {
        let toks = crate::lexer::tokenize(expr)?;
        let ast = Parser::new(&toks, expr).parse()?;
        let mut ctx = EvalContext {
            session: &mut self.session,
            depth: 0,
        };
        let v = eval::eval(&ast, &mut ctx)?;
        self.session.set_var(name, v)?;
        Ok(VariableInfo {
            name: name.to_string(),
            display: format::plain_decimal(&v),
            readonly: false,
        })
    }

    /// 删除变量。
    pub fn delete_variable(&mut self, name: &str) -> Result<()> {
        self.session.delete_var(name)
    }

    /// 按当前设置格式化一个数值。
    pub fn format_number(&self, value: &Num) -> Result<FormattedValue> {
        let fmt = self.session.settings.format;
        Ok(FormattedValue {
            display: format::format_number(value, &fmt)?,
            fraction: format::format_fraction(value, fmt.fraction_mode),
            approx: value.to_f64(),
            is_integer: value.is_int(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preview_does_not_change_ans() {
        let mut e = Engine::new();
        let r = e.evaluate_preview("1+2").unwrap();
        assert_eq!(r.display, "3");
        assert!(r.assignments.is_empty());
        assert!(e.session.ans.is_none());
    }

    #[test]
    fn commit_updates_ans() {
        let mut e = Engine::new();
        let r = e.evaluate_commit("1+2").unwrap();
        assert_eq!(r.display, "3");
        assert_eq!(e.session.ans, Some(Num::int(3)));
        assert_eq!(r.assignments.len(), 1);
        assert_eq!(r.assignments[0].name, "ans");
        let r2 = e.evaluate_commit("ans*2").unwrap();
        assert_eq!(r2.display, "6");
    }

    #[test]
    fn assignment_in_preview_writes_variable() {
        let mut e = Engine::new();
        let r = e.evaluate_preview("a=3+4").unwrap();
        assert_eq!(r.display, "7");
        assert_eq!(r.assignments[0].name, "a");
        assert_eq!(e.session.get_var("a").unwrap(), Num::int(7));
    }

    #[test]
    fn reset_keeps_ans() {
        let mut e = Engine::new();
        e.evaluate_commit("5").unwrap();
        e.set_variable("x", "1").unwrap();
        e.reset_session();
        assert_eq!(e.session.get_var("ans").unwrap(), Num::int(5));
        assert!(e.session.get_var("x").is_err());
    }

    #[test]
    fn convert_and_query() {
        let e = Engine::new();
        let r = e
            .convert(&Num::rational(127, 10).unwrap(), "inch", "mm")
            .unwrap();
        assert_eq!(r.output_display, "322.58 mm");
        assert_eq!(r.from.id, "inch");
        let r2 = e.convert_query("12.7 inch in mm").unwrap();
        assert_eq!(r2.output_display, "322.58 mm");
    }

    #[test]
    fn lists() {
        let e = Engine::new();
        assert!(e.list_constants().len() >= 12);
        assert_eq!(e.list_units(None).len(), 10);
        assert_eq!(e.list_units(Some(UnitCategory::Length)).len(), 1);
        assert_eq!(e.list_units(Some(UnitCategory::Length))[0].units.len(), 12);
        assert!(e.list_variables().is_empty());
    }

    #[test]
    fn set_and_delete_variable() {
        let mut e = Engine::new();
        // 注意："k" 是玻尔兹曼常数 k_B 的保留别名，不能用作变量名，故改用 "kk"
        let v = e.set_variable("kk", "2*3").unwrap();
        assert_eq!(v.display, "6");
        assert_eq!(e.session.get_var("kk").unwrap(), Num::int(6));
        e.delete_variable("kk").unwrap();
        assert!(e.session.get_var("kk").is_err());
    }

    #[test]
    fn format_number_facade() {
        let e = Engine::new();
        let f = e.format_number(&Num::rational(1, 3).unwrap()).unwrap();
        assert_eq!(f.display, "0.3333333333");
        assert!(f.is_integer == false);
    }

    #[test]
    fn settings_roundtrip() {
        let mut e = Engine::new();
        e.set_angle_mode(AngleMode::Rad);
        assert_eq!(e.settings().angle_mode, AngleMode::Rad);
        e.set_word_size(16).unwrap();
        assert_eq!(e.settings().word_size, 16);
        assert!(e.set_word_size(24).is_err());
    }
}
