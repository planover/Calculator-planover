//! T04：单位换算 —— 10 个类别 × 多组换算 + 跨类报错 + 绝对零度。
//!
//! 覆盖 PRD P0-15 / P1-09。

mod common;

use calculator_core::error::ErrorKind;
use calculator_core::num::Num;
use calculator_core::units::{self, UnitCategory, UnitDef};
use common::{assert_close, convert};

/// 换算并断言（相对误差）。
fn cv(value: &str, from: &str, to: &str, want: f64) {
    let got = convert(value, from, to);
    let tol = (want.abs() * 1e-9).max(1e-12);
    assert_close(got, want, tol, &format!("{} {} → {}", value, from, to));
}

#[test]
fn length() {
    cv("1", "inch", "mm", 25.4);
    cv("1", "m", "cm", 100.0);
    cv("1", "km", "m", 1000.0);
    cv("1", "ft", "inch", 12.0);
    cv("1", "mi", "km", 1.609344);
    cv("1", "yd", "m", 0.9144);
    cv("12.7", "inch", "mm", 322.58);
    cv("1", "nmi", "m", 1852.0);
    cv("1", "ly", "km", 9.4607304725808e12);
    cv("100", "cm", "m", 1.0);
}

#[test]
fn mass() {
    cv("1", "kg", "g", 1000.0);
    cv("1", "kg", "lb", 2.2046226218487757);
    cv("1", "lb", "oz", 16.0);
    cv("1", "t", "kg", 1000.0);
    cv("1", "g", "mg", 1000.0);
    cv("1", "st", "kg", 6.35029318);
    cv("1", "ct", "g", 0.2);
}

#[test]
fn temperature_is_affine() {
    cv("100", "C", "F", 212.0);
    cv("100", "C", "K", 373.15);
    cv("0", "C", "F", 32.0);
    cv("32", "F", "C", 0.0);
    cv("212", "F", "C", 100.0);
    cv("0", "K", "C", -273.15);
    cv("273.15", "K", "C", 0.0);
    cv("-40", "C", "F", -40.0);
    cv("0", "C", "R", 491.67);
    cv("100", "C", "Re", 80.0);
    cv("100", "C", "N", 33.0);
}

#[test]
fn below_absolute_zero_is_rejected() {
    let c = units::lookup_unit("C").unwrap();
    let f = units::lookup_unit("F").unwrap();
    let k = units::lookup_unit("K").unwrap();
    let v = Num::int(-300);
    assert_eq!(units::convert(&v, c, f).unwrap_err().kind, ErrorKind::BelowAbsoluteZero);
    assert_eq!(units::convert(&v, c, k).unwrap_err().kind, ErrorKind::BelowAbsoluteZero);
    let v2 = Num::int(-1);
    assert_eq!(units::convert(&v2, k, c).unwrap_err().kind, ErrorKind::BelowAbsoluteZero);
    // -273.15 °C 正好是 0 K，边界上允许
    let v3 = Num::rational(-27315, 100).unwrap();
    assert!(units::convert(&v3, c, k).is_ok());
}

#[test]
fn time() {
    cv("1", "h", "min", 60.0);
    cv("1", "min", "s", 60.0);
    cv("1", "d", "h", 24.0);
    cv("1", "s", "ms", 1000.0);
    cv("1", "ms", "us", 1000.0);
    cv("1", "us", "ns", 1000.0);
    cv("1", "week", "d", 7.0);
    cv("1", "year", "d", 365.25);
}

#[test]
fn area() {
    cv("1", "m2", "cm2", 10000.0);
    cv("1", "km2", "m2", 1e6);
    cv("1", "ha", "m2", 10000.0);
    cv("1", "ft2", "in2", 144.0);
    cv("1", "yd2", "ft2", 9.0);
    cv("1", "acre", "m2", 4046.8564224);
    cv("1", "cm2", "mm2", 100.0);
}

#[test]
fn volume() {
    cv("1", "l", "ml", 1000.0);
    cv("1", "m3", "l", 1000.0);
    cv("1", "cl", "ml", 10.0);
    cv("1", "gal_us", "l", 3.785411784);
    cv("1", "gal_uk", "l", 4.54609);
    cv("1", "ft3", "l", 28.316846592);
    cv("1", "cup", "ml", 236.5882365);
    cv("1", "in3", "ml", 16.387064);
}

#[test]
fn data_storage_si_and_iec() {
    // SI 十进制
    cv("1", "gb", "mb", 1000.0);
    cv("1", "mb", "kb", 1000.0);
    cv("1", "kb", "byte", 1000.0);
    cv("1", "tb", "gb", 1000.0);
    // IEC 二进制
    cv("1", "gib", "mib", 1024.0);
    cv("1", "mib", "kib", 1024.0);
    cv("1", "kib", "byte", 1024.0);
    cv("1", "tib", "gib", 1024.0);
    // 位与字节
    cv("1", "byte", "bit", 8.0);
    cv("1", "gib", "gb", 1.073741824);
}

#[test]
fn speed() {
    cv("1", "km_h", "m_s", 0.2777777777777778);
    cv("1", "m_s", "km_h", 3.6);
    cv("1", "mph", "km_h", 1.609344);
    cv("1", "knot", "km_h", 1.852);
    cv("1", "ft_s", "m_s", 0.3048);
    cv("1", "mach", "km_h", 1225.08);
}

#[test]
fn pressure() {
    cv("1", "bar", "pa", 100000.0);
    cv("1", "kpa", "pa", 1000.0);
    cv("1", "mpa", "kpa", 1000.0);
    cv("1", "atm", "pa", 101325.0);
    cv("1", "atm", "psi", 14.695948775513449);
    cv("1", "bar", "psi", 14.503773773020923); // 与 units.rs 的 psi=6894.757293168361（NIST 精确值）一致：100000/6894.757293168361
    cv("1", "mmhg", "pa", 133.322387415);
    cv("1", "mbar", "pa", 100.0);
}

#[test]
fn energy() {
    cv("1", "kj", "j", 1000.0);
    cv("1", "kcal", "j", 4184.0);
    cv("1", "cal", "j", 4.184);
    cv("1", "wh", "j", 3600.0);
    cv("1", "kwh", "j", 3600000.0);
    cv("1", "btu", "j", 1055.05585262);
    cv("1", "kwh", "kcal", 860.4206500956023);
}

#[test]
fn cross_category_conversions_are_rejected() {
    let pairs: &[(&str, &str)] = &[
        ("inch", "kg"),
        ("m", "s"),
        ("j", "pa"),
        ("C", "m"),
        ("byte", "m"),
        ("km_h", "j"),
    ];
    for (a, b) in pairs {
        let ua = units::lookup_unit(a).unwrap();
        let ub = units::lookup_unit(b).unwrap();
        assert_eq!(
            units::convert(&Num::int(1), ua, ub).unwrap_err().kind,
            ErrorKind::IncompatibleUnits,
            "{} → {}",
            a,
            b
        );
    }
}

#[test]
fn every_category_has_at_least_six_units() {
    assert_eq!(UnitCategory::all().len(), 10);
    for c in UnitCategory::all() {
        assert!(
            c.units().len() >= 6,
            "{} 只有 {} 个单位",
            c.name(),
            c.units().len()
        );
        for u in c.units() {
            assert!(!u.id.is_empty());
            assert!(!u.name.is_empty());
            assert!(!u.symbol.is_empty());
            assert_eq!(u.category, *c, "{} 的类别标注不一致", u.id);
        }
    }
}

#[test]
fn unit_ids_are_unique_within_category() {
    for c in UnitCategory::all() {
        let mut seen = std::collections::HashSet::new();
        for u in c.units() {
            assert!(seen.insert(u.id), "{} 类别下 id 重复：{}", c.name(), u.id);
        }
    }
}

#[test]
fn query_parsing_variants() {
    let variants = [
        "12.7 inch in mm",
        "12.7 inch to mm",
        "12.7 inch -> mm",
        "12.7 inch → mm",
        "12.7inch→mm",
        "  12.7 inch in mm  ",
    ];
    for q in variants {
        let (v, f, t) = units::parse_convert_query(q).unwrap_or_else(|e| panic!("{}: {:?}", q, e));
        assert_eq!(v, Num::rational(127, 10).unwrap(), "{}", q);
        assert_eq!(f.id, "inch", "{}", q);
        assert_eq!(t.id, "mm", "{}", q);
    }
}

#[test]
fn query_parsing_errors() {
    assert_eq!(
        units::parse_convert_query("inch to mm").unwrap_err().kind,
        ErrorKind::InvalidRequest
    );
    assert_eq!(
        units::parse_convert_query("12.7").unwrap_err().kind,
        ErrorKind::InvalidRequest
    );
    assert_eq!(
        units::parse_convert_query("1 zzz in mm").unwrap_err().kind,
        ErrorKind::UnknownUnit
    );
}

#[test]
fn temperature_units_are_affine_kind() {
    for u in UnitCategory::Temperature.units() {
        assert_eq!(u.kind.id(), "affine", "{} 应为仿射型", u.id);
    }
    for u in UnitCategory::Length.units() {
        assert_eq!(u.kind.id(), "proportional");
    }
    let _: &UnitDef = units::lookup_unit("°C").unwrap();
    assert_eq!(units::lookup_unit("°C").unwrap().id, "C");
    assert_eq!(units::lookup_unit("°F").unwrap().id, "F");
}

#[test]
fn lookup_is_case_insensitive_but_exact_first() {
    assert_eq!(units::lookup_unit("MB").unwrap().id, "mb");
    assert_eq!(units::lookup_unit("MiB").unwrap().id, "mib");
    assert_eq!(units::lookup_unit("mib").unwrap().id, "mib");
    assert_eq!(units::lookup_unit("inch").unwrap().id, "inch");
    assert_eq!(units::lookup_unit("in").unwrap().id, "inch");
    assert_eq!(units::lookup_unit("英寸").unwrap().id, "inch");
    assert!(units::lookup_unit("nope").is_none());
}
