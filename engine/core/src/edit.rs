//! 输入编辑纯函数：括号自动配对 / 右括号跳过 / 成对删除 / 配对高亮。
//!
//! 全部为纯函数、无 IO、无状态，因此可以在 Rust 侧 100% 单测覆盖，
//! Dart 侧只负责把结果写回 `TextEditingController`（对应 PRD P0-02）。

use crate::span::Span;

/// 编辑动作。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EditAction {
    /// 插入单个字符（字符本身放在 `payload` 里，便于 JSON 传输）。
    Insert(char),
    /// 插入字符串（粘贴、插入函数模板等）。
    InsertStr,
    /// 退格（删除光标前一个字符）。
    Backspace,
    /// 删除（删除光标后一个字符）。
    Delete,
}

impl EditAction {
    /// 稳定标识（JSON 取值）。
    pub fn id(&self) -> &'static str {
        match self {
            EditAction::Insert(_) => "insert",
            EditAction::InsertStr => "insert_str",
            EditAction::Backspace => "backspace",
            EditAction::Delete => "delete",
        }
    }

    /// 从标识解析；`insert` 的字符缺省为 `\0`，实际字符从 payload 取。
    pub fn from_id(s: &str) -> Option<EditAction> {
        match s.trim().to_lowercase().as_str() {
            "insert" => Some(EditAction::Insert('\0')),
            "insert_str" | "insertstr" | "paste" => Some(EditAction::InsertStr),
            "backspace" => Some(EditAction::Backspace),
            "delete" | "del" => Some(EditAction::Delete),
            _ => None,
        }
    }
}

/// 编辑请求。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EditRequest {
    /// 当前文本。
    pub text: String,
    /// 光标位置（char 偏移）。
    pub cursor: usize,
    /// 动作。
    pub action: EditAction,
    /// 载荷：Insert 时是要插入的字符，InsertStr 时是整串。
    pub payload: String,
}

/// 编辑结果。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EditResult {
    /// 新文本。
    pub text: String,
    /// 新光标位置（char 偏移）。
    pub cursor: usize,
    /// 文本是否发生变化（用于判断是否需要触发重算）。
    pub changed: bool,
}

impl EditRequest {
    /// 便捷构造。
    pub fn new(text: &str, cursor: usize, action: EditAction, payload: &str) -> Self {
        Self {
            text: text.to_string(),
            cursor,
            action,
            payload: payload.to_string(),
        }
    }
}

const OPENERS: [char; 3] = ['(', '[', '{'];
const CLOSERS: [char; 3] = [')', ']', '}'];

fn closing_of(c: char) -> Option<char> {
    match c {
        '(' => Some(')'),
        '[' => Some(']'),
        '{' => Some('}'),
        _ => None,
    }
}

fn opening_of(c: char) -> Option<char> {
    match c {
        ')' => Some('('),
        ']' => Some('['),
        '}' => Some('{'),
        _ => None,
    }
}

fn is_opener(c: char) -> bool {
    OPENERS.contains(&c)
}

fn is_closer(c: char) -> bool {
    CLOSERS.contains(&c)
}

fn clamp_cursor(text: &str, cursor: usize) -> usize {
    cursor.min(text.chars().count())
}

/// 执行一次编辑。
pub fn apply_edit(req: EditRequest) -> EditResult {
    let chars: Vec<char> = req.text.chars().collect();
    let cursor = clamp_cursor(&req.text, req.cursor);

    match req.action {
        EditAction::Insert(fallback_ch) => {
            let ch = req.payload.chars().next().unwrap_or(fallback_ch);
            if ch == '\0' {
                return EditResult {
                    text: req.text,
                    cursor,
                    changed: false,
                };
            }
            let mut out = chars.clone();
            if is_opener(ch) {
                // 开括号：成对插入，光标停在中间
                let close = closing_of(ch).unwrap_or(ch);
                out.insert(cursor, ch);
                out.insert(cursor + 1, close);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor: cursor + 1,
                    changed: true,
                }
            } else if is_closer(ch) {
                // 右括号已存在且就在光标处 → 跳过而不是重复插入
                if chars.get(cursor) == Some(&ch) {
                    return EditResult {
                        text: req.text,
                        cursor: cursor + 1,
                        changed: true,
                    };
                }
                let prev = if cursor > 0 { chars.get(cursor - 1).copied() } else { None };
                out.insert(cursor, ch);
                // 刚由自动配对补上的右括号：光标留在括号内部，符合用户预期。
                // 判断依据：光标前一个字符恰好是待插入右括号的配对左括号。
                let stay = prev == opening_of(ch);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor: if stay { cursor } else { cursor + 1 },
                    changed: true,
                }
            } else {
                out.insert(cursor, ch);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor: cursor + 1,
                    changed: true,
                }
            }
        }
        EditAction::InsertStr => {
            if req.payload.is_empty() {
                return EditResult {
                    text: req.text,
                    cursor,
                    changed: false,
                };
            }
            let mut out = chars.clone();
            let n = req.payload.chars().count();
            for (i, c) in req.payload.chars().enumerate() {
                out.insert(cursor + i, c);
            }
            EditResult {
                text: out.into_iter().collect(),
                cursor: cursor + n,
                changed: true,
            }
        }
        EditAction::Backspace => {
            if cursor == 0 {
                return EditResult {
                    text: req.text,
                    cursor: 0,
                    changed: false,
                };
            }
            let prev = chars[cursor - 1];
            let next = chars.get(cursor).copied();
            let mut out = chars.clone();
            if is_opener(prev) && next.is_some_and(|n| closing_of(prev) == Some(n)) {
                // 空括号对：一次删掉两个
                out.remove(cursor - 1);
                out.remove(cursor - 1);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor: cursor - 1,
                    changed: true,
                }
            } else {
                out.remove(cursor - 1);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor: cursor - 1,
                    changed: true,
                }
            }
        }
        EditAction::Delete => {
            if cursor >= chars.len() {
                return EditResult {
                    text: req.text,
                    cursor,
                    changed: false,
                };
            }
            let cur = chars[cursor];
            let next = chars.get(cursor + 1).copied();
            let mut out = chars.clone();
            if is_opener(cur) && next.is_some_and(|n| closing_of(cur) == Some(n)) {
                out.remove(cursor);
                out.remove(cursor);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor,
                    changed: true,
                }
            } else {
                out.remove(cursor);
                EditResult {
                    text: out.into_iter().collect(),
                    cursor,
                    changed: true,
                }
            }
        }
    }
}

/// 返回光标处（或光标前一个字符处）括号与其配对括号的区间。
///
/// 无匹配返回 `None`。区间为单字符 char 偏移，Dart 可直接高亮。
pub fn matching_paren(text: &str, cursor: usize) -> Option<(Span, Span)> {
    let chars: Vec<char> = text.chars().collect();
    if chars.is_empty() {
        return None;
    }
    let cursor = clamp_cursor(text, cursor);
    // 优先看光标右侧，其次光标左侧（与常见编辑器一致）
    let candidates: [isize; 2] = [cursor as isize, cursor as isize - 1];
    for c in candidates {
        if c < 0 || (c as usize) >= chars.len() {
            continue;
        }
        let idx = c as usize;
        let ch = chars[idx];
        if is_opener(ch) {
            if let Some(m) = scan_match(&chars, idx, true) {
                return Some((Span::new(idx, idx + 1), Span::new(m, m + 1)));
            }
        } else if is_closer(ch) {
            if let Some(m) = scan_match(&chars, idx, false) {
                return Some((Span::new(m, m + 1), Span::new(idx, idx + 1)));
            }
        }
    }
    None
}

/// 从 `idx` 出发找配对括号；`forward` 为 true 表示 `idx` 处是开括号。
fn scan_match(chars: &[char], idx: usize, forward: bool) -> Option<usize> {
    let target = chars[idx];
    if forward {
        let close = closing_of(target)?;
        let mut depth = 0usize;
        for (i, c) in chars.iter().enumerate().skip(idx) {
            if *c == target {
                depth += 1;
            } else if *c == close {
                depth -= 1;
                if depth == 0 {
                    return Some(i);
                }
            }
        }
        None
    } else {
        let open = opening_of(target)?;
        let mut depth = 0usize;
        for i in (0..=idx).rev() {
            let c = chars[i];
            if c == target {
                depth += 1;
            } else if c == open {
                depth -= 1;
                if depth == 0 {
                    return Some(i);
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn edit(text: &str, cursor: usize, action: EditAction, payload: &str) -> EditResult {
        apply_edit(EditRequest::new(text, cursor, action, payload))
    }

    #[test]
    fn open_paren_autopairs() {
        let r = edit("", 0, EditAction::Insert('('), "(");
        assert_eq!(r.text, "()");
        assert_eq!(r.cursor, 1);
        assert!(r.changed);
    }

    #[test]
    fn typed_open_bracket_then_closer_stays_inside() {
        // 架构 §5.3.7 的示例：text="(" cursor=1 payload=")" → "()" cursor=1
        let r = edit("(", 1, EditAction::Insert(')'), ")");
        assert_eq!(r.text, "()");
        assert_eq!(r.cursor, 1);
        assert!(r.changed);
    }

    #[test]
    fn closer_is_skipped_when_already_present() {
        let r = edit("()", 1, EditAction::Insert(')'), ")");
        assert_eq!(r.text, "()");
        assert_eq!(r.cursor, 2);
        assert!(r.changed);
    }

    #[test]
    fn closer_after_value_advances() {
        let r = edit("(1+2", 4, EditAction::Insert(')'), ")");
        assert_eq!(r.text, "(1+2)");
        assert_eq!(r.cursor, 5);
    }

    #[test]
    fn normal_character_insert() {
        let r = edit("1+", 2, EditAction::Insert('3'), "3");
        assert_eq!(r.text, "1+3");
        assert_eq!(r.cursor, 3);
    }

    #[test]
    fn insert_string_moves_cursor_by_chars() {
        let r = edit("1+", 2, EditAction::InsertStr, "sin(");
        assert_eq!(r.text, "1+sin(");
        assert_eq!(r.cursor, 6);
        // 多字节字符按 char 计
        let r2 = edit("", 0, EditAction::InsertStr, "π+");
        assert_eq!(r2.cursor, 2);
    }

    #[test]
    fn backspace_deletes_empty_pair() {
        let r = edit("()", 1, EditAction::Backspace, "");
        assert_eq!(r.text, "");
        assert_eq!(r.cursor, 0);
        let r2 = edit("(1)", 2, EditAction::Backspace, "");
        assert_eq!(r2.text, "()");
        assert_eq!(r2.cursor, 1);
    }

    #[test]
    fn backspace_at_start_is_noop() {
        let r = edit("abc", 0, EditAction::Backspace, "");
        assert_eq!(r.text, "abc");
        assert!(!r.changed);
    }

    #[test]
    fn delete_removes_pair_or_single() {
        let r = edit("()", 0, EditAction::Delete, "");
        assert_eq!(r.text, "");
        assert_eq!(r.cursor, 0);
        let r2 = edit("(1)", 1, EditAction::Delete, "");
        assert_eq!(r2.text, "()");
        let r3 = edit("abc", 3, EditAction::Delete, "");
        assert!(!r3.changed);
    }

    #[test]
    fn matching_paren_highlight() {
        assert_eq!(
            matching_paren("(1+2)", 0),
            Some((Span::new(0, 1), Span::new(4, 5)))
        );
        assert_eq!(
            matching_paren("(1+2)", 5),
            Some((Span::new(0, 1), Span::new(4, 5)))
        );
        assert_eq!(matching_paren("(1+2", 0), None);
        assert_eq!(matching_paren("1+2", 1), None);
        assert_eq!(
            matching_paren("((1))", 1),
            Some((Span::new(1, 2), Span::new(3, 4)))
        );
    }

    #[test]
    fn action_ids_roundtrip() {
        assert_eq!(EditAction::from_id("insert"), Some(EditAction::Insert('\0')));
        assert_eq!(EditAction::from_id("insert_str"), Some(EditAction::InsertStr));
        assert_eq!(EditAction::from_id("backspace"), Some(EditAction::Backspace));
        assert_eq!(EditAction::from_id("delete"), Some(EditAction::Delete));
        assert_eq!(EditAction::from_id("nope"), None);
        assert_eq!(EditAction::Insert('x').id(), "insert");
    }
}
