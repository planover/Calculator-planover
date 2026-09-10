//! 进制表示与按位运算。
//!
//! 负数一律按**二进制补码**表示（Q6），位宽可选 8/16/32/64，默认 64。
//! 例：`~0` 在 64 位宽下是 `-1`，十六进制显示 `FFFFFFFFFFFFFFFF`。

use serde::Serialize;

use crate::error::{EngineError, ErrorKind, Result};
use crate::num::Num;

/// 进制。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Base {
    /// 二进制。
    Bin,
    /// 八进制。
    Oct,
    /// 十进制。
    Dec,
    /// 十六进制。
    Hex,
}

impl Base {
    /// 基数。
    pub fn radix(&self) -> u32 {
        match self {
            Base::Bin => 2,
            Base::Oct => 8,
            Base::Dec => 10,
            Base::Hex => 16,
        }
    }

    /// 字面量前缀。
    pub fn prefix(&self) -> &'static str {
        match self {
            Base::Bin => "0b",
            Base::Oct => "0o",
            Base::Dec => "",
            Base::Hex => "0x",
        }
    }

    /// 稳定标识，写入 JSON。
    pub fn id(&self) -> &'static str {
        match self {
            Base::Bin => "bin",
            Base::Oct => "oct",
            Base::Dec => "dec",
            Base::Hex => "hex",
        }
    }
}

/// 同一数值在四种进制下的表示。
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct BaseRepr {
    /// 十进制串。
    pub dec: String,
    /// 十六进制串（大写，负数取补码无符号形式）。
    pub hex: String,
    /// 八进制串。
    pub oct: String,
    /// 二进制串。
    pub bin: String,
    /// 位宽 8/16/32/64。
    pub word_size: u8,
    /// 是否为整数；`false` 时只给 `dec`（含小数），其余为空串。
    pub is_integer: bool,
}

/// 合法位宽集合。
pub const WORD_SIZES: [u8; 4] = [8, 16, 32, 64];

/// 校验位宽；非法返回 `InvalidSettings`。
pub fn validate_word_size(w: u8) -> Result<()> {
    if WORD_SIZES.contains(&w) {
        Ok(())
    } else {
        Err(EngineError::with_message(
            ErrorKind::InvalidSettings,
            format!("位宽必须是 8/16/32/64，实得 {}", w),
        ))
    }
}

/// 把 `v` 按位宽截断并符号扩展回 i64（即"二进制补码"语义）。
pub fn mask_to_width(v: i64, word_size: u8) -> i64 {
    let bits = word_size as u32;
    if bits >= 64 || bits == 0 {
        return v;
    }
    let mask: u64 = (1u64 << bits) - 1;
    let truncated = (v as u64) & mask;
    let shift = 64 - bits;
    ((truncated << shift) as i64) >> shift
}

/// 取 `v` 在给定位宽下的**无符号**位模式，用于进制格式化。
fn as_unsigned(v: i64, word_size: u8) -> u64 {
    let bits = word_size as u32;
    if bits >= 64 || bits == 0 {
        v as u64
    } else {
        (v as u64) & ((1u64 << bits) - 1)
    }
}

/// 按进制格式化整数；负数按位宽取补码后输出无符号形式。
pub fn format_in_base(v: i64, base: Base, word_size: u8) -> String {
    let u = as_unsigned(v, word_size);
    match base {
        Base::Bin => format!("{:b}", u),
        Base::Oct => format!("{:o}", u),
        Base::Dec => v.to_string(),
        Base::Hex => format!("{:X}", u),
    }
}

/// 按进制解析字符串为 i64。
///
/// 允许带前缀（`0x` / `0b` / `0o`）与负号；超出位宽可表示范围返回 `Overflow`。
pub fn parse_in_base(s: &str, base: Base, word_size: u8) -> Result<i64> {
    let t = s.trim().replace('_', "");
    if t.is_empty() {
        return Err(EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    let (neg, body) = match t.strip_prefix('-') {
        Some(rest) => (true, rest),
        None => (false, t.as_str()),
    };
    let body = {
        let lower = body.to_ascii_lowercase();
        for p in ["0x", "0b", "0o"] {
            if let Some(rest) = lower.strip_prefix(p) {
                return parse_into_width(neg, rest, base, word_size, body);
            }
        }
        body
    };
    parse_into_width(neg, body, base, word_size, body)
}

fn parse_into_width(
    neg: bool,
    body: &str,
    base: Base,
    word_size: u8,
    original: &str,
) -> Result<i64> {
    if body.is_empty() {
        return Err(EngineError::with_message(
            ErrorKind::InvalidNumberLiteral,
            format!("“{}” 不是合法的 {} 进制数", original, base.radix()),
        ));
    }
    let mag = u64::from_str_radix(body, base.radix()).map_err(|_| {
        EngineError::with_message(
            ErrorKind::InvalidNumberLiteral,
            format!("“{}” 不是合法的 {} 进制数", original, base.radix()),
        )
    })?;
    let signed: i64 = if neg {
        mag.wrapping_neg() as i64
    } else {
        mag as i64
    };
    if !neg && mag > as_unsigned(i64::MAX, word_size) && word_size < 64 {
        // 超出该位宽能表示的正数范围
        return Err(EngineError::new(ErrorKind::Overflow));
    }
    Ok(mask_to_width(signed, word_size))
}

/// 位运算操作。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BitOp {
    /// `&`
    And,
    /// `|`
    Or,
    /// `^`
    Xor,
    /// `<<`
    Shl,
    /// `>>`
    Shr,
    /// `~`
    Not,
}

/// 按位运算：先把两侧按位宽归一化，再运算，最后按位宽符号扩展。
pub fn bitwise(op: BitOp, a: i64, b: i64, word_size: u8) -> i64 {
    let bits = word_size as u32;
    let ua = as_unsigned(a, word_size);
    let ub = as_unsigned(b, word_size);
    let r: u64 = match op {
        BitOp::And => ua & ub,
        BitOp::Or => ua | ub,
        BitOp::Xor => ua ^ ub,
        BitOp::Shl => {
            let sh = if b < 0 || b as u32 >= bits {
                bits
            } else {
                b as u32
            };
            if sh >= 64 {
                0
            } else {
                ua << sh
            }
        }
        BitOp::Shr => {
            if b < 0 || b as u32 >= 64 {
                0
            } else {
                ua >> (b as u32)
            }
        }
        // 按位取反：对 `a` 的位模式取反后，复用函数末尾的位宽截断/符号扩展逻辑。
        BitOp::Not => !ua,
    };
    if bits >= 64 {
        r as i64
    } else {
        let mask: u64 = (1u64 << bits) - 1;
        let t = r & mask;
        let shift = 64 - bits;
        ((t << shift) as i64) >> shift
    }
}

/// 由 `Num` 生成四种进制表示。
pub fn repr_of(n: &Num, word_size: u8) -> BaseRepr {
    match n.try_as_i64() {
        Ok(i) => BaseRepr {
            dec: format_in_base(i, Base::Dec, word_size),
            hex: format_in_base(i, Base::Hex, word_size),
            oct: format_in_base(i, Base::Oct, word_size),
            bin: format_in_base(i, Base::Bin, word_size),
            word_size,
            is_integer: true,
        },
        Err(_) => BaseRepr {
            dec: crate::format::plain_decimal(n),
            hex: String::new(),
            oct: String::new(),
            bin: String::new(),
            word_size,
            is_integer: false,
        },
    }
}

/// 解析 `0xFF` / `0b1010` / `0o17` 形式的字面量（lexer 已保证前缀合法）。
pub fn parse_prefixed_literal(text: &str) -> Result<i64> {
    let t = text.replace('_', "");
    let lower = t.to_ascii_lowercase();
    if let Some(b) = lower.strip_prefix("0x") {
        return i64::from_str_radix(b, 16).map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    if let Some(b) = lower.strip_prefix("0b") {
        return i64::from_str_radix(b, 2).map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    if let Some(b) = lower.strip_prefix("0o") {
        return i64::from_str_radix(b, 8).map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral));
    }
    t.parse::<i64>()
        .map_err(|_| EngineError::new(ErrorKind::InvalidNumberLiteral))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twos_complement_hex() {
        assert_eq!(format_in_base(-1, Base::Hex, 64), "FFFFFFFFFFFFFFFF");
        assert_eq!(format_in_base(!0i64, Base::Hex, 64), "FFFFFFFFFFFFFFFF");
        assert_eq!(format_in_base(-1, Base::Hex, 8), "FF");
        assert_eq!(format_in_base(-1, Base::Hex, 16), "FFFF");
        assert_eq!(format_in_base(-1, Base::Hex, 32), "FFFFFFFF");
    }

    #[test]
    fn format_all_bases() {
        assert_eq!(format_in_base(255, Base::Hex, 64), "FF");
        assert_eq!(format_in_base(255, Base::Bin, 64), "11111111");
        assert_eq!(format_in_base(255, Base::Oct, 64), "377");
        assert_eq!(format_in_base(255, Base::Dec, 64), "255");
    }

    #[test]
    fn parse_in_base_roundtrip() {
        assert_eq!(parse_in_base("FF", Base::Hex, 64).unwrap(), 255);
        assert_eq!(parse_in_base("0xFF", Base::Hex, 64).unwrap(), 255);
        assert_eq!(parse_in_base("1010", Base::Bin, 64).unwrap(), 10);
        assert_eq!(parse_in_base("17", Base::Oct, 64).unwrap(), 15);
        assert_eq!(parse_in_base("-1", Base::Dec, 64).unwrap(), -1);
        assert!(parse_in_base("GG", Base::Hex, 64).is_err());
    }

    #[test]
    fn word_size_truncation() {
        assert_eq!(mask_to_width(0x1FF, 8), -1); // 0xFF -> -1
        assert_eq!(mask_to_width(255, 8), -1);
        assert_eq!(mask_to_width(127, 8), 127);
        assert_eq!(mask_to_width(128, 8), -128);
        assert_eq!(mask_to_width(-1, 64), -1);
        assert!(validate_word_size(8).is_ok());
        assert!(validate_word_size(12).is_err());
    }

    #[test]
    fn bitwise_ops() {
        assert_eq!(bitwise(BitOp::And, 0b1010, 0b1100, 64), 0b1000);
        assert_eq!(bitwise(BitOp::Or, 0b1010, 0b0101, 64), 0b1111);
        assert_eq!(bitwise(BitOp::Xor, 0b1010, 0b0110, 64), 0b1100);
        assert_eq!(bitwise(BitOp::Shl, 0xFF, 8, 32), 65280);
        assert_eq!(bitwise(BitOp::Shr, 0xFF00, 8, 64), 0xFF);
        // 位宽 8 时 0xFF << 8 溢出为 0
        assert_eq!(bitwise(BitOp::Shl, 0xFF, 8, 8), 0);
        // 按位取反：64 位宽下 `~0` = 0xFFFF...FFFF = -1（二进制补码）
        assert_eq!(bitwise(BitOp::Not, 0, 0, 64), -1);
        assert_eq!(bitwise(BitOp::Not, 0, 0, 8), -1);
        assert_eq!(bitwise(BitOp::Not, 0xFF, 0, 8), 0);
    }

    #[test]
    fn repr_of_integer_and_fraction() {
        let r = repr_of(&Num::int(255), 64);
        assert!(r.is_integer);
        assert_eq!(r.hex, "FF");
        assert_eq!(r.bin, "11111111");
        let r2 = repr_of(&Num::rational(7, 2).unwrap(), 64);
        assert!(!r2.is_integer);
        assert_eq!(r2.dec, "3.5");
        assert_eq!(r2.hex, "");
    }
}
