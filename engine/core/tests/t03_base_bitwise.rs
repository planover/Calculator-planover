//! T03：进制转换与按位运算（≥20 组）+ 位宽设置。
//!
//! 覆盖 PRD P0-14 / P1-06。

mod common;

use calculator_core::base::{self, Base, BaseRepr, BitOp};
use calculator_core::num::Num;

/// 表驱动：`(十进制输入, hex, oct, bin)`。
fn check(dec: i64, hex: &str, oct: &str, bin: &str, word: u8) {
    assert_eq!(base::format_in_base(dec, Base::Hex, word), hex, "{} hex", dec);
    assert_eq!(base::format_in_base(dec, Base::Oct, word), oct, "{} oct", dec);
    assert_eq!(base::format_in_base(dec, Base::Bin, word), bin, "{} bin", dec);
    assert_eq!(base::format_in_base(dec, Base::Dec, word), dec.to_string());
}

#[test]
fn twenty_plus_base_conversion_cases() {
    // (dec, hex, oct, bin) —— 全部按 64 位宽
    check(0, "0", "0", "0", 64);
    check(1, "1", "1", "1", 64);
    check(2, "2", "2", "10", 64);
    check(7, "7", "7", "111", 64);
    check(8, "8", "10", "1000", 64);
    check(10, "A", "12", "1010", 64);
    check(15, "F", "17", "1111", 64);
    check(16, "10", "20", "10000", 64);
    check(31, "1F", "37", "11111", 64);
    check(63, "3F", "77", "111111", 64);
    check(64, "40", "100", "1000000", 64);
    check(100, "64", "144", "1100100", 64);
    check(127, "7F", "177", "1111111", 64);
    check(128, "80", "200", "10000000", 64);
    check(255, "FF", "377", "11111111", 64);
    check(256, "100", "400", "100000000", 64);
    check(511, "1FF", "777", "111111111", 64);
    check(1024, "400", "2000", "10000000000", 64);
    check(4095, "FFF", "7777", "111111111111", 64);
    check(65535, "FFFF", "177777", "1111111111111111", 64);
    check(65280, "FF00", "177400", "1111111100000000", 64);
    check(305419896, "12345678", "2215053170", "10010001101000101011001111000", 64);
}

#[test]
fn twos_complement_negative_representation() {
    // Q6：负数按二进制补码显示
    assert_eq!(base::format_in_base(-1, Base::Hex, 64), "FFFFFFFFFFFFFFFF");
    assert_eq!(base::format_in_base(!0i64, Base::Hex, 64), "FFFFFFFFFFFFFFFF");
    assert_eq!(base::format_in_base(-1, Base::Hex, 32), "FFFFFFFF");
    assert_eq!(base::format_in_base(-1, Base::Hex, 16), "FFFF");
    assert_eq!(base::format_in_base(-1, Base::Hex, 8), "FF");
    assert_eq!(base::format_in_base(-2, Base::Hex, 8), "FE");
    assert_eq!(base::format_in_base(-128, Base::Hex, 8), "80");
    assert_eq!(base::format_in_base(-1, Base::Bin, 8), "11111111");
    assert_eq!(base::format_in_base(-1, Base::Dec, 64), "-1");
}

#[test]
fn word_size_masking() {
    assert_eq!(base::mask_to_width(0x1FF, 8), -1);
    assert_eq!(base::mask_to_width(255, 8), -1);
    assert_eq!(base::mask_to_width(127, 8), 127);
    assert_eq!(base::mask_to_width(128, 8), -128);
    assert_eq!(base::mask_to_width(0x1_FFFF, 16), -1);
    assert_eq!(base::mask_to_width(0xFFFF_FFFF, 32), -1);
    assert_eq!(base::mask_to_width(-1, 64), -1);
    assert!(base::validate_word_size(8).is_ok());
    assert!(base::validate_word_size(16).is_ok());
    assert!(base::validate_word_size(32).is_ok());
    assert!(base::validate_word_size(64).is_ok());
    assert!(base::validate_word_size(12).is_err());
    assert!(base::validate_word_size(0).is_err());
}

#[test]
fn parse_in_base_roundtrips() {
    let cases: &[(&str, Base, i64)] = &[
        ("FF", Base::Hex, 255),
        ("0xFF", Base::Hex, 255),
        ("ff", Base::Hex, 255),
        ("1010", Base::Bin, 10),
        ("0b1010", Base::Bin, 10),
        ("17", Base::Oct, 15),
        ("0o17", Base::Oct, 15),
        ("255", Base::Dec, 255),
        ("-1", Base::Dec, -1),
        ("0", Base::Hex, 0),
        ("377", Base::Oct, 255),
    ];
    for (s, b, want) in cases {
        assert_eq!(base::parse_in_base(s, *b, 64).unwrap(), *want, "解析 {}", s);
    }
    assert!(base::parse_in_base("GG", Base::Hex, 64).is_err());
    assert!(base::parse_in_base("2", Base::Bin, 64).is_err());
    assert!(base::parse_in_base("", Base::Dec, 64).is_err());
}

#[test]
fn bitwise_operations() {
    assert_eq!(base::bitwise(BitOp::And, 0b1010, 0b1100, 64), 0b1000);
    assert_eq!(base::bitwise(BitOp::Or, 0b1010, 0b0101, 64), 0b1111);
    assert_eq!(base::bitwise(BitOp::Xor, 0b1010, 0b0110, 64), 0b1100);
    assert_eq!(base::bitwise(BitOp::Shl, 0xFF, 8, 32), 65280);
    assert_eq!(base::bitwise(BitOp::Shr, 0xFF00, 8, 64), 0xFF);
    assert_eq!(base::bitwise(BitOp::Shl, 0xFF, 8, 8), 0); // 8 位宽溢出归零
    assert_eq!(base::bitwise(BitOp::Not, 0, 0, 64), -1); // 64 位宽下 ~0 = -1
    assert_eq!(base::bitwise(BitOp::And, -1, 0xFF, 64), 0xFF);
    assert_eq!(base::bitwise(BitOp::Xor, -1, -1, 64), 0);
}

#[test]
fn bitwise_in_expressions() {
    use common::calc;
    // 表达式里的 `& | ^ ~ << >>` 走 base::bitwise
    let cases: &[(&str, &str)] = &[
        ("0b1010 & 0b1100", "8"),
        ("0b1010 | 0b0101", "15"),
        ("xor(0b1010, 0b0110)", "12"),
        ("~0", "-1"),
        ("~0 + 1", "0"),
        ("1 << 4", "16"),
        ("256 >> 4", "16"),
        ("0xFF & 0x0F", "15"),
        ("0xF0 | 0x0F", "255"),
        ("and(0b1100, 0b1010)", "8"),
        ("or(0b1000, 0b0111)", "15"),
        ("xor(0b1111, 0b0101)", "10"),
        ("not(0)", "-1"),
        ("shl(1, 8)", "256"),
        ("shr(256, 4)", "16"),
        ("(0xFF << 8) & 0xFFFF", "65280"),
    ];
    for (src, want) in cases {
        assert_eq!(calc(src), *want, "表达式 {}", src);
    }
}

#[test]
fn word_size_affects_expression_results() {
    let mut st = common::settings();
    st.word_size = 8;
    assert_eq!(common::calc_with("~0", &st), "-1");
    st.word_size = 32;
    assert_eq!(common::calc_with("~0", &st), "-1");
    st.word_size = 16;
    assert_eq!(common::calc_with("0xFFFF & 0xFFFF", &st), "-1"); // 16 位宽下 0xFFFF 截断为 -1
}

#[test]
fn repr_of_integers_and_fractions() {
    let r: BaseRepr = base::repr_of(&Num::int(255), 64);
    assert!(r.is_integer);
    assert_eq!(r.dec, "255");
    assert_eq!(r.hex, "FF");
    assert_eq!(r.oct, "377");
    assert_eq!(r.bin, "11111111");
    assert_eq!(r.word_size, 64);

    let r2 = base::repr_of(&Num::rational(7, 2).unwrap(), 64);
    assert!(!r2.is_integer);
    assert_eq!(r2.dec, "3.5");
    assert_eq!(r2.hex, "");
    assert_eq!(r2.oct, "");
    assert_eq!(r2.bin, "");

    let r3 = base::repr_of(&Num::int(-1), 32);
    assert_eq!(r3.hex, "FFFFFFFF");
    assert_eq!(r3.word_size, 32);
}

#[test]
fn base_enum_metadata() {
    assert_eq!(Base::Bin.radix(), 2);
    assert_eq!(Base::Oct.radix(), 8);
    assert_eq!(Base::Dec.radix(), 10);
    assert_eq!(Base::Hex.radix(), 16);
    assert_eq!(Base::Bin.prefix(), "0b");
    assert_eq!(Base::Oct.prefix(), "0o");
    assert_eq!(Base::Dec.prefix(), "");
    assert_eq!(Base::Hex.prefix(), "0x");
    assert_eq!(Base::Hex.id(), "hex");
}

#[test]
fn non_integer_bitwise_is_not_an_integer_error() {
    use calculator_core::error::ErrorKind;
    assert_eq!(
        common::try_calc("1.5 & 1").unwrap_err().kind,
        ErrorKind::NotAnInteger
    );
    assert_eq!(
        common::try_calc("~1.5").unwrap_err().kind,
        ErrorKind::NotAnInteger
    );
}
