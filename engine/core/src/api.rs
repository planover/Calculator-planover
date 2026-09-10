//! JSON DTO 与统一分发入口。
//!
//! **这里不含任何 FFI 代码**：`dispatch` 是纯粹的
//! `(方法名, JSON 串, &mut Engine) -> JSON 串` 函数，
//! 因此 FFI 的语义 100% 落在本机 `cargo test` 的覆盖范围内（架构 §3.15）。

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::base::BaseRepr;
use crate::edit::{self, EditAction, EditRequest, EditResult};
use crate::engine::{ConstantInfo, ConvertResult, Engine, EvalResult, FormattedValue};
use crate::error::{EngineError, ErrorKind, Result};
use crate::format::{
    FractionMode, Notation, NumberFormatSettings, PrecisionMode, MAX_PRECISION, MIN_PRECISION,
};
use crate::num::{Num, Special};
use crate::session::{AngleMode, VariableInfo};
use crate::span::Span;
use crate::units::{CategoryInfo, UnitCategory};

// ── 请求 DTO ────────────────────────────────────────────────

/// 求值请求。
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct EvaluateRequest {
    /// 表达式。
    #[serde(default)]
    pub expr: String,
    /// 可选设置；省略则用会话当前设置。
    #[serde(default)]
    pub settings: Option<SettingsDto>,
    /// 可选光标位置，仅用于错误高亮上下文。
    #[serde(default)]
    pub cursor: Option<usize>,
}

/// 设置片段。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct SettingsDto {
    /// `"deg" | "rad" | "grad"`。
    #[serde(default)]
    pub angle_mode: Option<String>,
    /// 8 / 16 / 32 / 64。
    #[serde(default)]
    pub word_size: Option<u8>,
    /// 数字格式。
    #[serde(default)]
    pub number_format: Option<FormatDto>,
}

/// 数字格式片段；`None` 表示沿用会话里的值。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct FormatDto {
    /// `"auto" | "scientific" | "fixed"`。
    #[serde(default)]
    pub notation: Option<String>,
    /// `"significant" | "decimal_places"`。
    #[serde(default)]
    pub precision_mode: Option<String>,
    /// 1..=15。
    #[serde(default)]
    pub precision: Option<u8>,
    /// `"off" | "improper" | "mixed"`。
    #[serde(default)]
    pub fraction_mode: Option<String>,
    /// 千位分隔。
    #[serde(default)]
    pub grouping: Option<bool>,
}

impl FormatDto {
    /// 把片段合并进基础设置；任何非法取值返回 `InvalidSettings`。
    pub fn merge_into(&self, base: NumberFormatSettings) -> Result<NumberFormatSettings> {
        let mut out = base;
        if let Some(n) = &self.notation {
            out.notation = Notation::from_id(&n).ok_or_else(|| {
                EngineError::with_message(ErrorKind::InvalidSettings, format!("未知记数法 {}", n))
            })?;
        }
        if let Some(p) = &self.precision_mode {
            out.precision_mode = PrecisionMode::from_id(&p).ok_or_else(|| {
                EngineError::with_message(ErrorKind::InvalidSettings, format!("未知精度模式 {}", p))
            })?;
        }
        if let Some(p) = self.precision {
            if p < MIN_PRECISION || p > MAX_PRECISION {
                return Err(EngineError::with_message(
                    ErrorKind::InvalidSettings,
                    format!(
                        "精度必须介于 {}~{}，实得 {}",
                        MIN_PRECISION, MAX_PRECISION, p
                    ),
                ));
            }
            out.precision = p;
        }
        if let Some(f) = &self.fraction_mode {
            out.fraction_mode = FractionMode::from_id(&f).ok_or_else(|| {
                EngineError::with_message(ErrorKind::InvalidSettings, format!("未知分数模式 {}", f))
            })?;
        }
        if let Some(g) = self.grouping {
            out.grouping = g;
        }
        crate::format::validate(&out)?;
        Ok(out)
    }

    /// 在默认设置之上构造一套完整设置（供不落会话的一次性格式化使用）。
    pub fn to_settings(&self, base: NumberFormatSettings) -> Result<NumberFormatSettings> {
        self.merge_into(base)
    }
}

impl SettingsDto {
    /// 把片段套用到引擎会话；任一项非法则整体拒绝，不留下半 applied 的状态。
    pub fn apply_to(&self, engine: &mut Engine) -> Result<()> {
        let angle = match &self.angle_mode {
            Some(a) => Some(AngleMode::from_id(a).ok_or_else(|| {
                EngineError::with_message(ErrorKind::InvalidSettings, format!("未知角度模式 {}", a))
            })?),
            None => None,
        };
        let fmt = match &self.number_format {
            Some(f) => Some(f.merge_into(engine.settings().format)?),
            None => None,
        };
        if let Some(w) = self.word_size {
            crate::base::validate_word_size(w)?;
        }
        engine.apply_settings(angle, self.word_size, fmt)
    }
}

/// 单位换算请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ConvertRequest {
    /// 数值表达式（与 `query` 二选一）。
    #[serde(default)]
    pub value: Option<String>,
    /// 源单位。
    #[serde(default)]
    pub from: String,
    /// 目标单位。
    #[serde(default)]
    pub to: String,
    /// 自然语言查询，如 `12.7 inch in mm`。
    #[serde(default)]
    pub query: Option<String>,
}

/// 设置变量请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct SetVariableRequest {
    /// 变量名。
    #[serde(default)]
    pub name: String,
    /// 右值表达式；先求值再存。
    #[serde(default)]
    pub expr: String,
}

/// 结构化数字格式化请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct FormatNumberRequest {
    /// 数值表达式字符串，如 `1/3`。
    #[serde(default)]
    pub value: String,
    /// 一次性格式设置（不落会话）。
    #[serde(default)]
    pub settings: Option<FormatDto>,
}

/// `calc_apply_edit` 请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct EditRequestDto {
    /// 当前文本。
    #[serde(default)]
    pub text: String,
    /// 光标（char 偏移）。
    #[serde(default)]
    pub cursor: usize,
    /// 动作标识。
    #[serde(default)]
    pub action: String,
    /// 载荷。
    #[serde(default)]
    pub payload: String,
}

/// 角度模式请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct AngleModeRequest {
    /// `"deg" | "rad" | "grad"`。
    #[serde(default)]
    pub angle_mode: String,
}

/// 位宽请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct WordSizeRequest {
    /// 8 / 16 / 32 / 64。
    #[serde(default)]
    pub word_size: u8,
}

/// 重置会话请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ResetSessionRequest {
    /// 是否保留 `ans`，默认 true（Q9）。
    #[serde(default = "default_true")]
    pub keep_ans: bool,
}

fn default_true() -> bool {
    true
}

/// 删除变量请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct NameRequest {
    /// 变量名。
    #[serde(default)]
    pub name: String,
}

/// 单位列表请求。
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ListUnitsRequest {
    /// 类别标识；空/缺省返回全部 10 类。
    #[serde(default)]
    pub category: Option<String>,
}

// ── 响应 DTO ────────────────────────────────────────────────

/// 数值的 JSON 形态（内部标签 `kind`）。
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum NumDto {
    /// 有理数。
    Rational {
        /// 分子。
        num: i64,
        /// 分母。
        den: i64,
    },
    /// 浮点。
    Float {
        /// 值。
        value: f64,
    },
    /// 非有限值。
    Special {
        /// `"nan" | "inf" | "-inf"`。
        which: &'static str,
    },
}

impl NumDto {
    /// 由 [`Num`] 生成。
    pub fn of(n: &Num) -> Self {
        match n {
            Num::Rational { num, den } => NumDto::Rational {
                num: *num,
                den: *den,
            },
            Num::Float(f) => NumDto::Float { value: *f },
            Num::Special(Special::Nan) => NumDto::Special { which: "nan" },
            Num::Special(Special::Infinity) => NumDto::Special { which: "inf" },
            Num::Special(Special::NegInfinity) => NumDto::Special { which: "-inf" },
        }
    }
}

/// 变量信息。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct VariableInfoDto {
    /// 名字。
    pub name: String,
    /// 显示值。
    pub display: String,
    /// 是否只读。
    pub readonly: bool,
}

impl VariableInfoDto {
    /// 由领域类型生成。
    pub fn of(v: &VariableInfo) -> Self {
        Self {
            name: v.name.clone(),
            display: v.display.clone(),
            readonly: v.readonly,
        }
    }
}

/// 求值结果。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct EvalResultDto {
    /// 精确值。
    pub value: NumDto,
    /// f64 近似值。
    pub approx: f64,
    /// 显示串。
    pub display: String,
    /// 分数串（非分数模式为 null）。
    pub fraction: Option<String>,
    /// 四种进制。
    pub base: BaseRepr,
    /// 本次产生的变量/ans 变更。
    pub assignments: Vec<VariableInfoDto>,
    /// 是否为整数。
    pub is_integer: bool,
}

impl EvalResultDto {
    /// 由领域类型生成。
    pub fn of(r: &EvalResult) -> Self {
        Self {
            value: NumDto::of(&r.value),
            approx: r.value.to_f64(),
            display: r.display.clone(),
            fraction: r.fraction.clone(),
            base: r.base.clone(),
            assignments: r.assignments.iter().map(VariableInfoDto::of).collect(),
            is_integer: r.value.is_int(),
        }
    }
}

/// 常量信息。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ConstantInfoDto {
    /// 符号。
    pub symbol: String,
    /// 中文名。
    pub name: String,
    /// 单位。
    pub unit: String,
    /// 值（字符串，避免 Dart 端二次精度损失）。
    pub value: String,
    /// 分类。
    pub category: String,
    /// 别名。
    pub aliases: Vec<String>,
}

impl ConstantInfoDto {
    /// 由领域类型生成。
    pub fn of(c: &ConstantInfo) -> Self {
        Self {
            symbol: c.symbol.clone(),
            name: c.name.clone(),
            unit: c.unit.clone(),
            value: crate::format::plain_decimal(&Num::float(c.value)),
            category: c.category.clone(),
            aliases: c.aliases.clone(),
        }
    }
}

/// 单位信息（与 [`crate::units::UnitInfo`] 同构，此处显式声明以固定契约）。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct UnitInfoDto {
    /// id。
    pub id: String,
    /// 符号。
    pub symbol: String,
    /// 中文名。
    pub name: String,
    /// 类别。
    pub category: String,
    /// `proportional` / `affine`。
    pub kind: String,
}

/// 类别信息。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct CategoryInfoDto {
    /// id。
    pub id: String,
    /// 中文名。
    pub name: String,
    /// 单位列表。
    pub units: Vec<UnitInfoDto>,
}

impl CategoryInfoDto {
    /// 由领域类型生成。
    pub fn of(c: &CategoryInfo) -> Self {
        Self {
            id: c.id.to_string(),
            name: c.name.to_string(),
            units: c
                .units
                .iter()
                .map(|u| UnitInfoDto {
                    id: u.id.to_string(),
                    symbol: u.symbol.to_string(),
                    name: u.name.to_string(),
                    category: u.category.to_string(),
                    kind: u.kind.to_string(),
                })
                .collect(),
        }
    }
}

/// 换算结果。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ConvertResultDto {
    /// 源单位。
    pub from: UnitInfoDto,
    /// 目标单位。
    pub to: UnitInfoDto,
    /// 输入值。
    pub input_value: NumDto,
    /// 输出值。
    pub output_value: NumDto,
    /// 输入显示串。
    pub input_display: String,
    /// 输出显示串。
    pub output_display: String,
}

impl ConvertResultDto {
    /// 由领域类型生成。
    pub fn of(r: &ConvertResult) -> Self {
        Self {
            from: UnitInfoDto {
                id: r.from.id.to_string(),
                symbol: r.from.symbol.to_string(),
                name: r.from.name.to_string(),
                category: r.from.category.to_string(),
                kind: r.from.kind.to_string(),
            },
            to: UnitInfoDto {
                id: r.to.id.to_string(),
                symbol: r.to.symbol.to_string(),
                name: r.to.name.to_string(),
                category: r.to.category.to_string(),
                kind: r.to.kind.to_string(),
            },
            input_value: NumDto::of(&r.input_value),
            output_value: NumDto::of(&r.output_value),
            input_display: r.input_display.clone(),
            output_display: r.output_display.clone(),
        }
    }
}

/// 格式化结果。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct FormattedValueDto {
    /// 显示串。
    pub display: String,
    /// 分数串。
    pub fraction: Option<String>,
    /// f64 近似值。
    pub approx: f64,
    /// 是否整数。
    pub is_integer: bool,
}

impl FormattedValueDto {
    /// 由领域类型生成。
    pub fn of(v: &FormattedValue) -> Self {
        Self {
            display: v.display.clone(),
            fraction: v.fraction.clone(),
            approx: v.approx,
            is_integer: v.is_integer,
        }
    }
}

/// 编辑结果。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct EditResultDto {
    /// 新文本。
    pub text: String,
    /// 新光标。
    pub cursor: usize,
    /// 是否变化。
    pub changed: bool,
}

impl EditResultDto {
    /// 由领域类型生成。
    pub fn of(r: &EditResult) -> Self {
        Self {
            text: r.text.clone(),
            cursor: r.cursor,
            changed: r.changed,
        }
    }
}

/// 版本信息。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct VersionDto {
    /// 引擎版本。
    pub version: String,
    /// 引擎名。
    pub engine: String,
    /// C ABI 版本。
    pub abi: u32,
}

/// 单布尔回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct OkDto {
    /// 是否成功。
    pub ok: bool,
}

/// 单名回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct NameDto {
    /// 名字。
    pub name: String,
}

/// 角度模式回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct AngleModeDto {
    /// 角度模式标识。
    pub angle_mode: String,
}

/// 位宽回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct WordSizeDto {
    /// 位宽。
    pub word_size: u8,
}

/// 常量列表回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ConstantsListDto {
    /// 常量数组。
    pub constants: Vec<ConstantInfoDto>,
}

/// 单位列表回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct UnitsListDto {
    /// 类别数组。
    pub categories: Vec<CategoryInfoDto>,
}

/// 变量列表回执。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct VariablesListDto {
    /// 变量数组（含 ans）。
    pub variables: Vec<VariableInfoDto>,
}

/// 统一信封。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct Envelope<T: Serialize> {
    /// 是否成功。
    pub ok: bool,
    /// 成功载荷。
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<T>,
    /// 错误载荷。
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<ErrorDto>,
}

/// 错误信息。
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct ErrorDto {
    /// 数字错误码。
    pub code: u16,
    /// 稳定 snake_case 名称。
    pub kind: &'static str,
    /// 中文文案。
    pub message: String,
    /// 出错区间。
    #[serde(skip_serializing_if = "Option::is_none")]
    pub span: Option<Span>,
}

impl ErrorDto {
    /// 由 [`EngineError`] 生成。
    pub fn of(e: &EngineError) -> Self {
        Self {
            code: e.kind.code(),
            kind: e.kind.stable_name(),
            message: e.message.clone(),
            span: e.span,
        }
    }
}

// ── 分发 ────────────────────────────────────────────────────

fn ok<T: Serialize>(data: &T) -> String {
    let env = Envelope {
        ok: true,
        data: serde_json::to_value(data).ok(),
        error: None,
    };
    serde_json::to_string(&env).unwrap_or_else(|_| fallback())
}

fn err(e: &EngineError) -> String {
    let env: Envelope<Value> = Envelope {
        ok: false,
        data: None,
        error: Some(ErrorDto::of(e)),
    };
    serde_json::to_string(&env).unwrap_or_else(|_| fallback())
}

/// 序列化彻底失败时的兜底串；**永不返回空串**，保证 Dart 侧 jsonDecode 不炸。
fn fallback() -> String {
    r#"{"ok":false,"error":{"code":5002,"kind":"internal_error","message":"引擎内部错误"}}"#
        .to_string()
}

fn parse_payload<P: serde::de::DeserializeOwned>(json: &str) -> Result<P> {
    let v: Value = if json.trim().is_empty() {
        Value::Object(serde_json::Map::new())
    } else {
        serde_json::from_str(json).map_err(|e| {
            EngineError::with_message(ErrorKind::InvalidRequest, format!("请求不是合法 JSON：{}", e))
        })?
    };
    serde_json::from_value(v).map_err(|e| {
        EngineError::with_message(ErrorKind::InvalidRequest, format!("请求字段不匹配：{}", e))
    })
}

/// 所有 API 的统一入口。
///
/// `method` 取值见架构 §5.2；未知方法返回 `InvalidRequest`。
/// 返回值**永远**是一段合法 JSON。
pub fn dispatch(method: &str, payload_json: &str, engine: &mut Engine) -> String {
    match method {
        "version" | "calc_version" => ok(&VersionDto {
            version: crate::ENGINE_VERSION.to_string(),
            engine: crate::ENGINE_NAME.to_string(),
            abi: crate::ABI_VERSION,
        }),

        "evaluate_preview" => match parse_payload::<EvaluateRequest>(payload_json) {
            Ok(req) => match handle_evaluate(engine, &req, false) {
                Ok(d) => ok(&d),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "evaluate_commit" => match parse_payload::<EvaluateRequest>(payload_json) {
            Ok(req) => match handle_evaluate(engine, &req, true) {
                Ok(d) => ok(&d),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "convert" => match parse_payload::<ConvertRequest>(payload_json) {
            Ok(req) => match handle_convert(engine, &req) {
                Ok(d) => ok(&d),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "list_constants" => {
            let list: Vec<ConstantInfoDto> = engine.list_constants().iter().map(ConstantInfoDto::of).collect();
            ok(&ConstantsListDto { constants: list })
        }

        "list_units" => match parse_payload::<ListUnitsRequest>(payload_json) {
            Ok(req) => {
                let cat = match req.category.as_deref().map(|s| s.trim()).unwrap_or("") {
                    "" => None,
                    other => match UnitCategory::from_id(other) {
                        Some(c) => Some(c),
                        None => {
                            return err(&EngineError::with_message(
                                ErrorKind::InvalidRequest,
                                format!("未知单位类别 {}", other),
                            ))
                        }
                    },
                };
                let list: Vec<CategoryInfoDto> =
                    engine.list_units(cat).iter().map(CategoryInfoDto::of).collect();
                ok(&UnitsListDto { categories: list })
            }
            Err(e) => err(&e),
        },

        "list_variables" => {
            let list: Vec<VariableInfoDto> =
                engine.list_variables().iter().map(VariableInfoDto::of).collect();
            ok(&VariablesListDto { variables: list })
        }

        "format_number" => match parse_payload::<FormatNumberRequest>(payload_json) {
            Ok(req) => match handle_format_number(engine, &req) {
                Ok(d) => ok(&d),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "set_variable" => match parse_payload::<SetVariableRequest>(payload_json) {
            Ok(req) => match engine.set_variable(&req.name, &req.expr) {
                Ok(v) => ok(&VariableInfoDto::of(&v)),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "delete_variable" => match parse_payload::<NameRequest>(payload_json) {
            Ok(req) => match engine.delete_variable(&req.name) {
                Ok(()) => ok(&NameDto { name: req.name }),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "set_angle_mode" => match parse_payload::<AngleModeRequest>(payload_json) {
            Ok(req) => match AngleMode::from_id(&req.angle_mode) {
                Some(m) => {
                    engine.set_angle_mode(m);
                    ok(&AngleModeDto {
                        angle_mode: m.id().to_string(),
                    })
                }
                None => err(&EngineError::with_message(
                    ErrorKind::InvalidSettings,
                    format!("未知角度模式 {}", req.angle_mode),
                )),
            },
            Err(e) => err(&e),
        },

        "set_word_size" => match parse_payload::<WordSizeRequest>(payload_json) {
            Ok(req) => match engine.set_word_size(req.word_size) {
                Ok(()) => ok(&WordSizeDto {
                    word_size: req.word_size,
                }),
                Err(e) => err(&e),
            },
            Err(e) => err(&e),
        },

        "reset_session" => match parse_payload::<ResetSessionRequest>(payload_json) {
            Ok(req) => {
                if req.keep_ans {
                    engine.reset_session();
                } else {
                    engine.reset_session();
                    engine.session_mut().ans = None;
                }
                ok(&OkDto { ok: true })
            }
            Err(e) => err(&e),
        },

        "apply_edit" => match parse_payload::<EditRequestDto>(payload_json) {
            Ok(req) => {
                let action = EditAction::from_id(&req.action).unwrap_or(EditAction::InsertStr);
                let result = edit::apply_edit(EditRequest {
                    text: req.text,
                    cursor: req.cursor,
                    action,
                    payload: req.payload,
                });
                ok(&EditResultDto::of(&result))
            }
            Err(e) => err(&e),
        },

        other => err(&EngineError::with_message(
            ErrorKind::InvalidRequest,
            format!("未知方法 {}", other),
        )),
    }
}

fn handle_evaluate(
    engine: &mut Engine,
    req: &EvaluateRequest,
    commit: bool,
) -> Result<EvalResultDto> {
    if let Some(s) = &req.settings {
        s.apply_to(engine)?;
    }
    let r = if commit {
        engine.evaluate_commit(&req.expr)?
    } else {
        engine.evaluate_preview(&req.expr)?
    };
    Ok(EvalResultDto::of(&r))
}

fn handle_convert(engine: &mut Engine, req: &ConvertRequest) -> Result<ConvertResultDto> {
    if let Some(q) = &req.query {
        if !q.trim().is_empty() {
            let r = engine.convert_query(q)?;
            return Ok(ConvertResultDto::of(&r));
        }
    }
    let raw = req.value.as_deref().ok_or_else(|| {
        EngineError::with_message(ErrorKind::InvalidRequest, "换算请求需要 value 或 query")
    })?;
    let v = crate::eval::eval_simple(raw, engine.settings())?;
    if req.from.is_empty() || req.to.is_empty() {
        return Err(EngineError::with_message(
            ErrorKind::InvalidRequest,
            "换算请求需要 from 与 to",
        ));
    }
    let r = engine.convert(&v, &req.from, &req.to)?;
    Ok(ConvertResultDto::of(&r))
}

fn handle_format_number(engine: &Engine, req: &FormatNumberRequest) -> Result<FormattedValueDto> {
    let v = crate::eval::eval_simple(&req.value, engine.settings())?;
    match &req.settings {
        Some(f) => {
            let s = f.to_settings(engine.settings().format)?;
            let display = crate::format::format_number(&v, &s)?;
            Ok(FormattedValueDto {
                display,
                fraction: crate::format::format_fraction(&v, s.fraction_mode),
                approx: v.to_f64(),
                is_integer: v.is_int(),
            })
        }
        None => Ok(FormattedValueDto::of(&engine.format_number(&v)?)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn num_dto_shape() {
        assert_eq!(
            serde_json::to_string(&NumDto::of(&Num::rational(7, 2).unwrap())).unwrap(),
            r#"{"kind":"rational","num":7,"den":2}"#
        );
        assert_eq!(
            serde_json::to_string(&NumDto::of(&Num::float(3.5))).unwrap(),
            r#"{"kind":"float","value":3.5}"#
        );
        assert_eq!(
            serde_json::to_string(&NumDto::of(&Num::Special(Special::Infinity))).unwrap(),
            r#"{"kind":"special","which":"inf"}"#
        );
    }

    #[test]
    fn error_envelope_shape() {
        let out = dispatch("evaluate_preview", r#"{"expr":"1/0"}"#, &mut Engine::new());
        assert!(out.contains(r#""ok":false"#));
        assert!(out.contains(r#""code":2000"#));
        assert!(out.contains(r#""kind":"division_by_zero""#));
    }

    #[test]
    fn success_envelope_shape() {
        let out = dispatch("evaluate_preview", r#"{"expr":"1+2"}"#, &mut Engine::new());
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["ok"], true);
        assert_eq!(v["data"]["display"], "3");
        assert_eq!(v["data"]["is_integer"], true);
        assert_eq!(v["data"]["base"]["word_size"], 64);
        assert!(v.get("error").is_none());
    }

    #[test]
    fn unknown_method_is_invalid_request() {
        let out = dispatch("no_such_method", "{}", &mut Engine::new());
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["error"]["code"], 5000);
    }

    #[test]
    fn malformed_json_is_invalid_request() {
        let out = dispatch("evaluate_preview", "{oops", &mut Engine::new());
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["error"]["code"], 5000);
    }

    #[test]
    fn settings_are_applied_and_persisted() {
        let mut e = Engine::new();
        let out = dispatch(
            "evaluate_preview",
            r#"{"expr":"sin(100)","settings":{"angle_mode":"grad"}}"#,
            &mut e,
        );
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["display"], "1");
        assert_eq!(e.settings().angle_mode, AngleMode::Grad);
    }

    #[test]
    fn invalid_settings_rejected() {
        let mut e = Engine::new();
        let out = dispatch(
            "evaluate_preview",
            r#"{"expr":"1","settings":{"number_format":{"precision":99}}}"#,
            &mut e,
        );
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["error"]["code"], 5001);
        let out2 = dispatch("set_word_size", r#"{"word_size":24}"#, &mut e);
        let v2: Value = serde_json::from_str(&out2).unwrap();
        assert_eq!(v2["error"]["code"], 5001);
    }

    #[test]
    fn convert_contract() {
        let mut e = Engine::new();
        let out = dispatch("convert", r#"{"value":"12.7","from":"inch","to":"mm"}"#, &mut e);
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["output_display"], "322.58 mm");
        assert_eq!(v["data"]["from"]["id"], "inch");
        assert_eq!(v["data"]["to"]["category"], "length");
        let out2 = dispatch("convert", r#"{"query":"1 inch in kg"}"#, &mut e);
        let v2: Value = serde_json::from_str(&out2).unwrap();
        assert_eq!(v2["error"]["code"], 3001);
    }

    #[test]
    fn list_contracts() {
        let mut e = Engine::new();
        let out = dispatch("list_units", "{}", &mut e);
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["categories"].as_array().unwrap().len(), 10);
        let out2 = dispatch("list_units", r#"{"category":"temperature"}"#, &mut e);
        let v2: Value = serde_json::from_str(&out2).unwrap();
        assert_eq!(v2["data"]["categories"][0]["units"][0]["kind"], "affine");
        let out3 = dispatch("list_units", r#"{"category":"nope"}"#, &mut e);
        assert_eq!(
            serde_json::from_str::<Value>(&out3).unwrap()["error"]["code"],
            5000
        );
        let out4 = dispatch("list_constants", "{}", &mut e);
        let v4: Value = serde_json::from_str(&out4).unwrap();
        assert!(v4["data"]["constants"].as_array().unwrap().len() >= 12);
        assert_eq!(v4["data"]["constants"][0]["symbol"], "π");
    }

    #[test]
    fn variable_contract() {
        let mut e = Engine::new();
        let out = dispatch("set_variable", r#"{"name":"a","expr":"3+4"}"#, &mut e);
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["name"], "a");
        assert_eq!(v["data"]["display"], "7");
        let out2 = dispatch("list_variables", "{}", &mut e);
        let v2: Value = serde_json::from_str(&out2).unwrap();
        assert_eq!(v2["data"]["variables"][0]["name"], "a");
        let out3 = dispatch("delete_variable", r#"{"name":"a"}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out3).unwrap()["data"]["name"], "a");
        let out4 = dispatch("list_variables", "{}", &mut e);
        let v4: Value = serde_json::from_str(&out4).unwrap();
        assert_eq!(v4["data"]["variables"].as_array().unwrap().len(), 0);
    }

    #[test]
    fn ans_and_reset_contract() {
        let mut e = Engine::new();
        dispatch("evaluate_commit", r#"{"expr":"5"}"#, &mut e);
        let out = dispatch("list_variables", "{}", &mut e);
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["variables"][0]["name"], "ans");
        assert_eq!(v["data"]["variables"][0]["readonly"], true);
        dispatch("reset_session", r#"{"keep_ans":true}"#, &mut e);
        let out2 = dispatch("evaluate_preview", r#"{"expr":"ans*2"}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out2).unwrap()["data"]["display"], "10");
        dispatch("reset_session", r#"{"keep_ans":false}"#, &mut e);
        let out3 = dispatch("evaluate_preview", r#"{"expr":"ans"}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out3).unwrap()["error"]["code"], 4000);
    }

    #[test]
    fn format_number_contract() {
        let mut e = Engine::new();
        let out = dispatch("format_number", r#"{"value":"1/3"}"#, &mut e);
        assert_eq!(
            serde_json::from_str::<Value>(&out).unwrap()["data"]["display"],
            "0.3333333333"
        );
        let out2 = dispatch(
            "format_number",
            r#"{"value":"1/3+1/6","settings":{"fraction_mode":"improper"}}"#,
            &mut e,
        );
        assert_eq!(serde_json::from_str::<Value>(&out2).unwrap()["data"]["display"], "1/2");
    }

    #[test]
    fn apply_edit_contract() {
        let mut e = Engine::new();
        let out = dispatch(
            "apply_edit",
            r#"{"text":"(","cursor":1,"action":"insert","payload":")"}"#,
            &mut e,
        );
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["text"], "()");
        assert_eq!(v["data"]["cursor"], 1);
        assert_eq!(v["data"]["changed"], true);
    }

    #[test]
    fn version_contract() {
        let mut e = Engine::new();
        let out = dispatch("version", "{}", &mut e);
        let v: Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["data"]["engine"], "calculator_core");
        assert_eq!(v["data"]["abi"], 1);
    }

    #[test]
    fn angle_mode_and_word_size_contract() {
        let mut e = Engine::new();
        let out = dispatch("set_angle_mode", r#"{"angle_mode":"rad"}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out).unwrap()["data"]["angle_mode"], "rad");
        let out2 = dispatch("set_angle_mode", r#"{"angle_mode":"xxx"}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out2).unwrap()["error"]["code"], 5001);
        let out3 = dispatch("set_word_size", r#"{"word_size":32}"#, &mut e);
        assert_eq!(serde_json::from_str::<Value>(&out3).unwrap()["data"]["word_size"], 32);
    }

    #[test]
    fn dispatch_never_returns_empty_string() {
        let mut e = Engine::new();
        for m in ["", "nope", "evaluate_preview", "convert", "apply_edit"] {
            let out = dispatch(m, "", &mut e);
            assert!(!out.is_empty());
            serde_json::from_str::<Value>(&out).expect("必须是合法 JSON");
        }
    }
}
