//! 源码区间。

use serde::{Deserialize, Serialize};

/// 源码区间，**使用 Unicode 标量（char）偏移，不是字节偏移**。
///
/// 这么做是为了让 Dart 侧能直接 `text.substring(span.start, span.end)` 拿到出错片段，
/// 免去 Dart（UTF-16）与 Rust（UTF-8）之间的二次换算。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct Span {
    /// 起始字符下标（含）。
    pub start: usize,
    /// 结束字符下标（不含）。
    pub end: usize,
}

impl Span {
    /// 构造一个区间；`end < start` 时自动规整为 `[start, start)`。
    pub fn new(start: usize, end: usize) -> Self {
        Self {
            start,
            end: end.max(start),
        }
    }

    /// 合并两个区间（取最小起点与最大终点），用于把二元运算两侧的 span 合并成一个。
    pub fn merge(self, other: Span) -> Span {
        Span {
            start: self.start.min(other.start),
            end: self.end.max(other.end),
        }
    }

    /// 区间长度（字符数）。
    pub fn len(&self) -> usize {
        self.end - self.start
    }

    /// 是否为空区间。
    pub fn is_empty(&self) -> bool {
        self.end == self.start
    }
}

/// 把字节偏移转成字符偏移。
///
/// 本 crate 的 lexer 直接按 `char` 迭代，因此不需要它做转换；保留此工具是因为
/// Dart 侧或未来接入的第三方扫描器可能只给字节下标，届时用它做一次性归一。
/// `byte_index` 落在字符中间时返回该字符的起点下标。
pub fn byte_to_char_index(s: &str, byte_index: usize) -> usize {
    let mut acc = 0usize;
    let mut char_count = 0usize;
    for c in s.chars() {
        let end = acc + c.len_utf8();
        // byte_index 落在本字符区间内（不含右端点）即返回该字符的字符下标；
        // 正好落在边界上时归入下一个字符，符合 Dart 侧按 char 截取的习惯。
        if byte_index < end {
            return char_count;
        }
        acc = end;
        char_count += 1;
    }
    char_count
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn span_new_normalizes_reversed_range() {
        let s = Span::new(5, 2);
        assert_eq!(s.start, 5);
        assert_eq!(s.end, 5);
        assert!(s.is_empty());
    }

    #[test]
    fn span_merge_takes_bounds() {
        let a = Span::new(2, 5);
        let b = Span::new(4, 9);
        assert_eq!(a.merge(b), Span::new(2, 9));
    }

    #[test]
    fn byte_to_char_counts_multibyte() {
        let s = "2π+1";
        // '2' 占 1 字节，'π' 占 2 字节
        assert_eq!(byte_to_char_index(s, 0), 0);
        assert_eq!(byte_to_char_index(s, 1), 1);
        assert_eq!(byte_to_char_index(s, 3), 2);
        assert_eq!(byte_to_char_index(s, 4), 3);
        assert_eq!(byte_to_char_index(s, 999), 4);
    }
}
