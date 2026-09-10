//! 常量表。

/// 一个常量定义。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ConstantDef {
    /// 主符号，如 `π` / `c`。
    pub symbol: &'static str,
    /// 中文名，如 `圆周率` / `光速`。
    pub name: &'static str,
    /// 单位字符串（无量纲常量为空串）。
    pub unit: &'static str,
    /// 数值（f64 精度，物理常量采用 SI 2019 定义值）。
    pub value: f64,
    /// 分类：`math` / `physics` / `chem`。
    pub category: &'static str,
    /// 别名，用于键盘与解析（含 ASCII 拼写）。
    pub aliases: &'static [&'static str],
}

/// 全部常量（≥12 项，P0-12）。
pub static CONSTANTS: &[ConstantDef] = &[
    ConstantDef {
        symbol: "π",
        name: "圆周率",
        unit: "",
        value: std::f64::consts::PI,
        category: "math",
        aliases: &["pi", "PI"],
    },
    ConstantDef {
        symbol: "e",
        name: "自然常数",
        unit: "",
        value: std::f64::consts::E,
        category: "math",
        aliases: &["E"],
    },
    ConstantDef {
        symbol: "φ",
        name: "黄金比例",
        unit: "",
        value: 1.6180339887498948,
        category: "math",
        aliases: &["phi"],
    },
    ConstantDef {
        symbol: "τ",
        name: "圆周率的两倍 (2π)",
        unit: "",
        value: 6.283185307179586,
        category: "math",
        aliases: &["tau"],
    },
    ConstantDef {
        symbol: "c",
        name: "光速",
        unit: "m/s",
        value: 299792458.0,
        category: "physics",
        aliases: &[],
    },
    ConstantDef {
        symbol: "h",
        name: "普朗克常数",
        unit: "J·s",
        value: 6.62607015e-34,
        category: "physics",
        aliases: &[],
    },
    ConstantDef {
        symbol: "ħ",
        name: "约化普朗克常数",
        unit: "J·s",
        value: 1.054571817e-34,
        category: "physics",
        aliases: &["hbar"],
    },
    ConstantDef {
        symbol: "G",
        name: "引力常数",
        unit: "m³/(kg·s²)",
        value: 6.67430e-11,
        category: "physics",
        aliases: &[],
    },
    ConstantDef {
        symbol: "N_A",
        name: "阿伏伽德罗常数",
        unit: "1/mol",
        value: 6.02214076e23,
        category: "chem",
        aliases: &["NA", "avo"],
    },
    ConstantDef {
        symbol: "R",
        name: "理想气体常数",
        unit: "J/(mol·K)",
        value: 8.314462618,
        category: "chem",
        aliases: &[],
    },
    // 元电荷与 e（自然常数）重名，故主符号用 e_c，键盘/面板展示时用 e_c 区分
    ConstantDef {
        symbol: "e_c",
        name: "元电荷",
        unit: "C",
        value: 1.602176634e-19,
        category: "physics",
        aliases: &["ec", "q_e"],
    },
    ConstantDef {
        symbol: "ε₀",
        name: "真空介电常数",
        unit: "F/m",
        value: 8.8541878128e-12,
        category: "physics",
        aliases: &["eps0", "epsilon0"],
    },
    ConstantDef {
        symbol: "m_e",
        name: "电子质量",
        unit: "kg",
        value: 9.1093837015e-31,
        category: "physics",
        aliases: &["me"],
    },
    ConstantDef {
        symbol: "m_p",
        name: "质子质量",
        unit: "kg",
        value: 1.67262192369e-27,
        category: "physics",
        aliases: &["mp"],
    },
    ConstantDef {
        symbol: "g",
        name: "标准重力加速度",
        unit: "m/s²",
        value: 9.80665,
        category: "physics",
        aliases: &["g0"],
    },
    ConstantDef {
        symbol: "k_B",
        name: "玻尔兹曼常数",
        unit: "J/K",
        value: 1.380649e-23,
        category: "physics",
        aliases: &["kB", "k"],
    },
    ConstantDef {
        symbol: "atm",
        name: "标准大气压",
        unit: "Pa",
        value: 101325.0,
        category: "physics",
        aliases: &[],
    },
];

/// 全部常量。
pub fn all() -> &'static [ConstantDef] {
    CONSTANTS
}

/// 按符号或别名查找常量。
///
/// 查找顺序：符号精确 → 别名精确 → 全表不区分大小写。最后一步是为了让
/// 键盘里敲的 `PI` / `pi` 都能命中，但精确匹配优先，不会被大小写折叠抢走。
pub fn lookup(symbol_or_alias: &str) -> Option<&'static ConstantDef> {
    if let Some(c) = CONSTANTS.iter().find(|c| c.symbol == symbol_or_alias) {
        return Some(c);
    }
    if let Some(c) = CONSTANTS
        .iter()
        .find(|c| c.aliases.contains(&symbol_or_alias))
    {
        return Some(c);
    }
    let needle = symbol_or_alias.to_lowercase();
    CONSTANTS
        .iter()
        .find(|c| c.symbol.to_lowercase() == needle || c.aliases.iter().any(|a| a.to_lowercase() == needle))
}

/// 是否为已注册的常量名（保留名判定用）。
pub fn is_constant_name(name: &str) -> bool {
    lookup(name).is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn at_least_twelve_constants() {
        assert!(all().len() >= 12, "常量数量 {}", all().len());
    }

    #[test]
    fn every_constant_is_well_formed() {
        for c in all() {
            assert!(!c.symbol.is_empty(), "symbol 不可为空");
            assert!(!c.name.is_empty(), "{} 缺少中文名", c.symbol);
            assert!(c.value.is_finite(), "{} 的值非有限", c.symbol);
            assert!(!c.category.is_empty());
            // 单位允许为空（无量纲），但不允许只含空白
            assert_eq!(c.unit.trim(), c.unit);
        }
    }

    #[test]
    fn light_speed_is_exact() {
        let c = lookup("c").unwrap();
        assert_eq!(c.value, 299792458.0);
        assert_eq!(c.unit, "m/s");
        assert_eq!(c.name, "光速");
    }

    #[test]
    fn required_symbols_present() {
        for s in ["π", "e", "φ", "c", "h", "G", "N_A", "R", "e_c", "ε₀", "m_e", "g"] {
            assert!(
                lookup(s).is_some(),
                "缺少常量 {}", s
            );
        }
    }

    #[test]
    fn aliases_and_case_insensitive_lookup() {
        assert_eq!(lookup("pi").unwrap().symbol, "π");
        assert_eq!(lookup("PI").unwrap().symbol, "π");
        assert_eq!(lookup("tau").unwrap().symbol, "τ");
        assert_eq!(lookup("hbar").unwrap().symbol, "ħ");
        assert_eq!(lookup("NA").unwrap().symbol, "N_A");
    }

    #[test]
    fn e_and_elementary_charge_are_distinct() {
        assert_eq!(lookup("e").unwrap().name, "自然常数");
        assert_eq!(lookup("e_c").unwrap().name, "元电荷");
        assert_ne!(lookup("e").unwrap().value, lookup("e_c").unwrap().value);
    }

    #[test]
    fn unknown_name_is_none() {
        assert!(lookup("not_a_constant").is_none());
        assert!(!is_constant_name("foo"));
    }
}
