//! 记忆寄存器（`M+` / `M-` / `MC` / `MR` 的后端）。
//!
//! 设计约定（增量 PRD v2 §13.1 CP-01）：
//! - **单一**寄存器，初值 `0`，值类型复用 [`Num`]；
//! - **独立于 `ans`**：两者互不影响（M+ 不改 `ans`，改 `ans` 不改记忆）；
//! - **随 `reset_session` 清零**，但执行"清空历史"不清零（后者是 Dart 侧行为，
//!   不经过本模块；由调用方保证）。
//!
//! [`Memory::recall_text`] 生成可**原样回插**到表达式的字面量：负值包成 `(-x)`，
//! 保证插回后语法正确（CP-05）。

use crate::num::Num;

/// 单一记忆寄存器。
#[derive(Debug, Clone, PartialEq)]
pub struct Memory {
    value: Num,
}

impl Default for Memory {
    fn default() -> Self {
        Self::new()
    }
}

impl Memory {
    /// 新建寄存器（初值 0）。
    pub fn new() -> Self {
        Self { value: Num::zero() }
    }

    /// 当前记忆值。
    pub fn value(&self) -> Num {
        self.value
    }

    /// 是否为 0（UI 据此决定是否显示 `M` 指示器）。
    pub fn is_zero(&self) -> bool {
        self.value.is_zero()
    }

    /// `M+`：`memory = memory + v`，返回更新后的记忆值。
    pub fn add(&mut self, v: &Num) -> Num {
        self.value = self.value.add(v);
        self.value
    }

    /// `M-`：`memory = memory - v`，返回更新后的记忆值。
    pub fn subtract(&mut self, v: &Num) -> Num {
        self.value = self.value.sub(v);
        self.value
    }

    /// `MC`：清零（对已为 0 的寄存器执行是幂等无副作用的）。
    pub fn clear(&mut self) {
        self.value = Num::zero();
    }

    /// `MR`：生成回插到表达式的字面量。
    ///
    /// - 非负整数 / 小数 → 直接十进制（如 `5`、`0`、`0.25`）；
    /// - 负值 → 包成 `(-x)`（如 `(-5)`），保证插回表达式语法正确；
    /// - 化不出有限小数的有理数 → 用分数形式（如 `2/3`）。
    pub fn recall_text(&self) -> String {
        let neg = self.value.to_f64() < 0.0;
        let body = positive_literal(&self.value);
        if neg {
            format!("(-{})", body)
        } else {
            body
        }
    }
}

/// 把数值渲染成**非负**的、可被词法器解析的字面量。
///
/// 与格式化器（`format::format_number`）区分：后者可能产出 `1.2×10³` 这类
/// **不可回插**的展示串，本函数只产出合法数字字面量。
fn positive_literal(n: &Num) -> String {
    if let Ok(i) = n.try_as_i64() {
        return i.unsigned_abs().to_string();
    }
    match n {
        Num::Rational { num, den } => {
            if let Some(s) = crate::format::exact_decimal_string(*num, *den) {
                return s.trim_start_matches('-').to_string();
            }
            // 化不出有限小数（如 2/3）：用分数表达式，插回后仍可求值。
            format!("{}/{}", num.unsigned_abs(), den)
        }
        // 浮点：Rust 的 `{}` 全用定位记法（不会出现指数），可被词法器解析。
        Num::Float(f) => format!("{}", f.abs()),
        // 非有限值不应出现在记忆里；兜底成 0，避免插入非法文本。
        Num::Special(_) => "0".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn starts_at_zero() {
        let m = Memory::new();
        assert!(m.is_zero());
        assert_eq!(m.value(), Num::zero());
    }

    #[test]
    fn add_and_subtract_accumulate() {
        let mut m = Memory::new();
        assert_eq!(m.add(&Num::int(5)), Num::int(5));
        assert_eq!(m.add(&Num::int(5)), Num::int(10));
        assert_eq!(m.subtract(&Num::int(5)), Num::int(5));
        assert_eq!(m.subtract(&Num::int(5)), Num::zero());
        assert_eq!(m.subtract(&Num::int(5)), Num::int(-5));
    }

    #[test]
    fn clear_is_idempotent() {
        let mut m = Memory::new();
        m.add(&Num::int(7));
        assert!(!m.is_zero());
        m.clear();
        assert!(m.is_zero());
        m.clear();
        assert!(m.is_zero());
    }

    #[test]
    fn recall_text_forms() {
        let mut m = Memory::new();
        assert_eq!(m.recall_text(), "0");
        m.add(&Num::int(5));
        assert_eq!(m.recall_text(), "5");
        m.clear();
        m.subtract(&Num::int(5));
        assert_eq!(m.recall_text(), "(-5)");
        let mut m2 = Memory::new();
        m2.add(&Num::rational(1, 4).unwrap());
        assert_eq!(m2.recall_text(), "0.25");
        let mut m3 = Memory::new();
        m3.subtract(&Num::rational(1, 4).unwrap());
        assert_eq!(m3.recall_text(), "(-0.25)");
    }
}
