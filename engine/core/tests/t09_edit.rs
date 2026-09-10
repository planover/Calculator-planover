//! T09：输入编辑纯函数（8 类语义 + 多字节光标）。
//!
//! 覆盖 PRD P0-02：括号自动配对 / 右括号跳过 / 成对删除 / 正常插入 /
//! 字符串插入 / 多字节光标 / 配对高亮 / 动作标识往返。

mod common;

use calculator_core::edit::{apply_edit, matching_paren, EditAction, EditRequest};
use calculator_core::span::Span;

/// 便捷封装：返回 (新文本, 新光标, 是否变化)。
fn edit(text: &str, cursor: usize, action: EditAction, payload: &str) -> (String, usize, bool) {
    let r = apply_edit(EditRequest::new(text, cursor, action, payload));
    (r.text, r.cursor, r.changed)
}

#[test]
fn open_paren_autopairs() {
    let (t, c, ch) = edit("", 0, EditAction::Insert('('), "(");
    assert_eq!(t, "()");
    assert_eq!(c, 1);
    assert!(ch);
    // 其它开括号同样成对
    let (t2, c2, _) = edit("", 0, EditAction::Insert('['), "[");
    assert_eq!(t2, "[]");
    assert_eq!(c2, 1);
}

#[test]
fn closer_skipped_when_already_present() {
    // 光标已在右括号左侧时，再敲右括号应"跳过"而不是重复
    let (t, c, ch) = edit("()", 1, EditAction::Insert(')'), ")");
    assert_eq!(t, "()");
    assert_eq!(c, 2);
    assert!(ch);
}

#[test]
fn typed_closer_advances_past_preexisting() {
    let (t, c, _) = edit("(1+2", 4, EditAction::Insert(')'), ")");
    assert_eq!(t, "(1+2)");
    assert_eq!(c, 5);
}

#[test]
fn normal_character_insert() {
    let (t, c, _) = edit("1+", 2, EditAction::Insert('3'), "3");
    assert_eq!(t, "1+3");
    assert_eq!(c, 3);
}

#[test]
fn insert_string_moves_cursor_by_char_count() {
    let (t, c, _) = edit("1+", 2, EditAction::InsertStr, "sin(");
    assert_eq!(t, "1+sin(");
    assert_eq!(c, 6);
}

#[test]
fn backspace_deletes_empty_pair() {
    let (t, c, _) = edit("()", 1, EditAction::Backspace, "");
    assert_eq!(t, "");
    assert_eq!(c, 0);
    // 括号内已有内容时只删一个字符
        let (t2, c2, _) = edit("(1)", 2, EditAction::Backspace, "");
        assert_eq!(t2, "()");
    assert_eq!(c2, 1);
}

#[test]
fn delete_removes_pair_or_single() {
    let (t, c, _) = edit("()", 0, EditAction::Delete, "");
    assert_eq!(t, "");
    assert_eq!(c, 0);
    // 普通字符只删一个
    let (t2, c2, _) = edit("abc", 0, EditAction::Delete, "");
    assert_eq!(t2, "bc");
    assert_eq!(c2, 0);
}

#[test]
fn multibyte_cursor_handled_by_char() {
    // 多字节字符（π）按 char 计，而不是字节计
    let (t, c, _) = edit("", 0, EditAction::InsertStr, "π+");
    assert_eq!(t, "π+");
    assert_eq!(c, 2);
    // 在 π 之后插入，光标停在正确的 char 位置
    let (t2, c2, _) = edit("π", 1, EditAction::InsertStr, "x");
    assert_eq!(t2, "πx");
    assert_eq!(c2, 2);
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
    assert_eq!(EditAction::InsertStr.id(), "insert_str");
}
