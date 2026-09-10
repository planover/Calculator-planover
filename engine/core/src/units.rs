//! 单位换算：10 个类别，比例型 + 仿射型（温度）双路径。
//!
//! 换算策略：源值 → 该类别的 **SI 基准单位** → 目标单位。
//! 比例型 `si = v * factor`，反算 `v = si / factor`；
//! 仿射型（温度）`si = v * scale + offset`，反算 `v = (si - offset) / scale`。
//! 跨类别 → `IncompatibleUnits`；温度低于 0 K → `BelowAbsoluteZero`。

use serde::Serialize;

use crate::error::{EngineError, ErrorKind, Result};
use crate::num::Num;

/// 单位类别。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum UnitCategory {
    /// 长度（基准 m）。
    Length,
    /// 质量（基准 kg）。
    Mass,
    /// 温度（基准 K，仿射）。
    Temperature,
    /// 时间（基准 s）。
    Time,
    /// 面积（基准 m²）。
    Area,
    /// 体积（基准 m³）。
    Volume,
    /// 数据存储（基准 bit，SI 与 IEC 双套并存）。
    DataStorage,
    /// 速度（基准 m/s）。
    Speed,
    /// 压力（基准 Pa）。
    Pressure,
    /// 能量（基准 J）。
    Energy,
}

impl UnitCategory {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            UnitCategory::Length => "length",
            UnitCategory::Mass => "mass",
            UnitCategory::Temperature => "temperature",
            UnitCategory::Time => "time",
            UnitCategory::Area => "area",
            UnitCategory::Volume => "volume",
            UnitCategory::DataStorage => "data_storage",
            UnitCategory::Speed => "speed",
            UnitCategory::Pressure => "pressure",
            UnitCategory::Energy => "energy",
        }
    }

    /// 中文名。
    pub fn name(&self) -> &'static str {
        match self {
            UnitCategory::Length => "长度",
            UnitCategory::Mass => "质量",
            UnitCategory::Temperature => "温度",
            UnitCategory::Time => "时间",
            UnitCategory::Area => "面积",
            UnitCategory::Volume => "体积",
            UnitCategory::DataStorage => "数据存储",
            UnitCategory::Speed => "速度",
            UnitCategory::Pressure => "压力",
            UnitCategory::Energy => "能量",
        }
    }

    /// SI 基准单位的符号（仅用于文档与调试输出）。
    pub fn base_symbol(&self) -> &'static str {
        match self {
            UnitCategory::Length => "m",
            UnitCategory::Mass => "kg",
            UnitCategory::Temperature => "K",
            UnitCategory::Time => "s",
            UnitCategory::Area => "m²",
            UnitCategory::Volume => "m³",
            UnitCategory::DataStorage => "bit",
            UnitCategory::Speed => "m/s",
            UnitCategory::Pressure => "Pa",
            UnitCategory::Energy => "J",
        }
    }

    /// 全部 10 个类别。
    pub fn all() -> &'static [UnitCategory] {
        &ALL_CATEGORIES
    }

    /// 该类别下的全部单位（≥6 个）。
    pub fn units(&self) -> &'static [UnitDef] {
        match self {
            UnitCategory::Length => LENGTH,
            UnitCategory::Mass => MASS,
            UnitCategory::Temperature => TEMPERATURE,
            UnitCategory::Time => TIME,
            UnitCategory::Area => AREA,
            UnitCategory::Volume => VOLUME,
            UnitCategory::DataStorage => DATA,
            UnitCategory::Speed => SPEED,
            UnitCategory::Pressure => PRESSURE,
            UnitCategory::Energy => ENERGY,
        }
    }

    /// 从标识解析。
    pub fn from_id(s: &str) -> Option<UnitCategory> {
        ALL_CATEGORIES
            .iter()
            .copied()
            .find(|c| c.id() == s.trim().to_lowercase())
    }
}

/// 全部类别。
pub static ALL_CATEGORIES: [UnitCategory; 10] = [
    UnitCategory::Length,
    UnitCategory::Mass,
    UnitCategory::Temperature,
    UnitCategory::Time,
    UnitCategory::Area,
    UnitCategory::Volume,
    UnitCategory::DataStorage,
    UnitCategory::Speed,
    UnitCategory::Pressure,
    UnitCategory::Energy,
];

/// 换算模型。
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum UnitKind {
    /// 比例型：`value_si = value * factor`。
    Proportional {
        /// 相对 SI 基准的倍率。
        factor: f64,
    },
    /// 仿射型：`value_si = value * scale + offset`（温度专用）。
    Affine {
        /// 倍率。
        scale: f64,
        /// 偏移。
        offset: f64,
    },
}

impl UnitKind {
    /// 稳定标识。
    pub fn id(&self) -> &'static str {
        match self {
            UnitKind::Proportional { .. } => "proportional",
            UnitKind::Affine { .. } => "affine",
        }
    }

    /// 转到 SI 基准值。
    pub fn to_si(&self, v: f64) -> f64 {
        match self {
            UnitKind::Proportional { factor } => v * factor,
            UnitKind::Affine { scale, offset } => v * scale + offset,
        }
    }

    /// 从 SI 基准值转回。
    pub fn from_si(&self, si: f64) -> f64 {
        match self {
            UnitKind::Proportional { factor } => si / factor,
            UnitKind::Affine { scale, offset } => (si - offset) / scale,
        }
    }
}

/// 一个单位定义。
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct UnitDef {
    /// 稳定 id，如 `inch`。
    pub id: &'static str,
    /// 展示符号，如 `inch` / `°C`。
    pub symbol: &'static str,
    /// 中文名。
    pub name: &'static str,
    /// 所属类别。
    pub category: UnitCategory,
    /// 换算模型。
    pub kind: UnitKind,
    /// 别名（含中文名与常见缩写）。
    pub aliases: &'static [&'static str],
}

impl UnitDef {
    /// 转到该类别的 SI 基准值。
    pub fn to_si(&self, v: f64) -> f64 {
        self.kind.to_si(v)
    }

    /// 从 SI 基准值转回本单位的数值。
    pub fn from_si(&self, si: f64) -> f64 {
        self.kind.from_si(si)
    }
}

/// 单位展示信息（JSON 直出）。
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct UnitInfo {
    /// 稳定 id。
    pub id: &'static str,
    /// 展示符号。
    pub symbol: &'static str,
    /// 中文名。
    pub name: &'static str,
    /// 类别标识。
    pub category: &'static str,
    /// `proportional` / `affine`。
    pub kind: &'static str,
}

impl UnitInfo {
    /// 由 [`UnitDef`] 生成。
    pub fn of(u: &'static UnitDef) -> Self {
        Self {
            id: u.id,
            symbol: u.symbol,
            name: u.name,
            category: u.category.id(),
            kind: u.kind.id(),
        }
    }
}

/// 类别展示信息（JSON 直出）。
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct CategoryInfo {
    /// 类别标识。
    pub id: &'static str,
    /// 中文名。
    pub name: &'static str,
    /// 该类别下的单位。
    pub units: Vec<UnitInfo>,
}

impl CategoryInfo {
    /// 由类别生成。
    pub fn of(c: UnitCategory) -> Self {
        Self {
            id: c.id(),
            name: c.name(),
            units: c.units().iter().map(UnitInfo::of).collect(),
        }
    }
}

// ── 单位表 ──────────────────────────────────────────────────

static LENGTH: &[UnitDef] = &[
    UnitDef { id: "nm", symbol: "nm", name: "纳米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1e-9 }, aliases: &["nanometer"] },
    UnitDef { id: "um", symbol: "μm", name: "微米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1e-6 }, aliases: &["µm", "micron"] },
    UnitDef { id: "mm", symbol: "mm", name: "毫米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1e-3 }, aliases: &["毫米"] },
    UnitDef { id: "cm", symbol: "cm", name: "厘米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1e-2 }, aliases: &["厘米"] },
    UnitDef { id: "m", symbol: "m", name: "米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["米", "meter"] },
    UnitDef { id: "km", symbol: "km", name: "千米", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1000.0 }, aliases: &["公里", "kilometer"] },
    UnitDef { id: "inch", symbol: "inch", name: "英寸", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 0.0254 }, aliases: &["in", "英寸"] },
    UnitDef { id: "ft", symbol: "ft", name: "英尺", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 0.3048 }, aliases: &["foot", "英尺"] },
    UnitDef { id: "yd", symbol: "yd", name: "码", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 0.9144 }, aliases: &["yard", "码"] },
    UnitDef { id: "mi", symbol: "mi", name: "英里", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1609.344 }, aliases: &["mile", "英里"] },
    UnitDef { id: "nmi", symbol: "nmi", name: "海里", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 1852.0 }, aliases: &["海里"] },
    UnitDef { id: "ly", symbol: "ly", name: "光年", category: UnitCategory::Length, kind: UnitKind::Proportional { factor: 9.4607304725808e15 }, aliases: &["光年", "lightyear"] },
];

static MASS: &[UnitDef] = &[
    UnitDef { id: "mg", symbol: "mg", name: "毫克", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 1e-6 }, aliases: &["毫克"] },
    UnitDef { id: "g", symbol: "g", name: "克", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 1e-3 }, aliases: &["克", "gram"] },
    UnitDef { id: "kg", symbol: "kg", name: "千克", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["公斤", "kilogram"] },
    UnitDef { id: "t", symbol: "t", name: "吨", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 1000.0 }, aliases: &["吨", "tonne"] },
    UnitDef { id: "oz", symbol: "oz", name: "盎司", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 0.028349523125 }, aliases: &["ounce", "盎司"] },
    UnitDef { id: "lb", symbol: "lb", name: "磅", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 0.45359237 }, aliases: &["pound", "磅"] },
    UnitDef { id: "st", symbol: "st", name: "英石", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 6.35029318 }, aliases: &["stone", "英石"] },
    UnitDef { id: "ct", symbol: "ct", name: "克拉", category: UnitCategory::Mass, kind: UnitKind::Proportional { factor: 0.0002 }, aliases: &["carat", "克拉"] },
];

// 温度：全部为仿射变换（Kelvin 的 scale=1 / offset=0 退化成比例，仍走仿射路径保持一致）
static TEMPERATURE: &[UnitDef] = &[
    UnitDef { id: "C", symbol: "°C", name: "摄氏度", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 1.0, offset: 273.15 }, aliases: &["c", "摄氏度", "celsius"] },
    UnitDef { id: "F", symbol: "°F", name: "华氏度", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 0.5555555555555556, offset: 255.3722222222222 }, aliases: &["f", "华氏度", "fahrenheit"] },
    UnitDef { id: "K", symbol: "K", name: "开尔文", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 1.0, offset: 0.0 }, aliases: &["k", "开尔文", "kelvin"] },
    UnitDef { id: "R", symbol: "°R", name: "兰氏度", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 0.5555555555555556, offset: 0.0 }, aliases: &["rankine", "兰氏度"] },
    UnitDef { id: "Re", symbol: "°Ré", name: "列氏度", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 1.25, offset: 273.15 }, aliases: &["reaumur", "列氏度"] },
    UnitDef { id: "N", symbol: "°N", name: "牛顿度", category: UnitCategory::Temperature, kind: UnitKind::Affine { scale: 3.0303030303030303, offset: 273.15 }, aliases: &["newton", "牛顿度"] },
];

static TIME: &[UnitDef] = &[
    UnitDef { id: "ns", symbol: "ns", name: "纳秒", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 1e-9 }, aliases: &["纳秒"] },
    UnitDef { id: "us", symbol: "μs", name: "微秒", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 1e-6 }, aliases: &["µs", "微秒"] },
    UnitDef { id: "ms", symbol: "ms", name: "毫秒", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 1e-3 }, aliases: &["毫秒"] },
    UnitDef { id: "s", symbol: "s", name: "秒", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["秒", "sec", "second"] },
    UnitDef { id: "min", symbol: "min", name: "分钟", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 60.0 }, aliases: &["分钟", "minute"] },
    UnitDef { id: "h", symbol: "h", name: "小时", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 3600.0 }, aliases: &["小时", "hour"] },
    UnitDef { id: "d", symbol: "d", name: "天", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 86400.0 }, aliases: &["天", "day"] },
    UnitDef { id: "week", symbol: "周", name: "周", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 604800.0 }, aliases: &["周", "week"] },
    UnitDef { id: "year", symbol: "年", name: "年（儒略年）", category: UnitCategory::Time, kind: UnitKind::Proportional { factor: 31557600.0 }, aliases: &["年", "year"] },
];

static AREA: &[UnitDef] = &[
    UnitDef { id: "mm2", symbol: "mm²", name: "平方毫米", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 1e-6 }, aliases: &["平方毫米"] },
    UnitDef { id: "cm2", symbol: "cm²", name: "平方厘米", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 1e-4 }, aliases: &["平方厘米"] },
    UnitDef { id: "m2", symbol: "m²", name: "平方米", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["平方米"] },
    UnitDef { id: "km2", symbol: "km²", name: "平方千米", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 1e6 }, aliases: &["平方公里"] },
    UnitDef { id: "ha", symbol: "ha", name: "公顷", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 10000.0 }, aliases: &["公顷", "hectare"] },
    UnitDef { id: "acre", symbol: "acre", name: "英亩", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 4046.8564224 }, aliases: &["英亩"] },
    UnitDef { id: "ft2", symbol: "ft²", name: "平方英尺", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 0.09290304 }, aliases: &["平方英尺"] },
    UnitDef { id: "yd2", symbol: "yd²", name: "平方码", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 0.83612736 }, aliases: &["平方码"] },
    UnitDef { id: "in2", symbol: "in²", name: "平方英寸", category: UnitCategory::Area, kind: UnitKind::Proportional { factor: 0.00064516 }, aliases: &["平方英寸"] },
];

static VOLUME: &[UnitDef] = &[
    UnitDef { id: "ml", symbol: "mL", name: "毫升", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 1e-6 }, aliases: &["毫升"] },
    UnitDef { id: "cl", symbol: "cL", name: "厘升", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 1e-5 }, aliases: &["厘升"] },
    UnitDef { id: "l", symbol: "L", name: "升", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 1e-3 }, aliases: &["升", "liter"] },
    UnitDef { id: "m3", symbol: "m³", name: "立方米", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["立方米"] },
    UnitDef { id: "ft3", symbol: "ft³", name: "立方英尺", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 0.028316846592 }, aliases: &["立方英尺"] },
    UnitDef { id: "in3", symbol: "in³", name: "立方英寸", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 1.6387064e-5 }, aliases: &["立方英寸"] },
    UnitDef { id: "gal_us", symbol: "gal(US)", name: "加仑（美）", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 0.003785411784 }, aliases: &["gal", "加仑"] },
    UnitDef { id: "gal_uk", symbol: "gal(UK)", name: "加仑（英）", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 0.00454609 }, aliases: &["英制加仑"] },
    UnitDef { id: "cup", symbol: "cup", name: "杯（美制）", category: UnitCategory::Volume, kind: UnitKind::Proportional { factor: 2.365882365e-4 }, aliases: &["杯"] },
];

// 数据存储：基准取 bit，SI 十进制（kB/MB/GB）与 IEC 二进制（KiB/MiB/GiB）**两套并存**
static DATA: &[UnitDef] = &[
    UnitDef { id: "bit", symbol: "bit", name: "比特", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["b", "比特"] },
    UnitDef { id: "byte", symbol: "B", name: "字节", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8.0 }, aliases: &["B", "字节"] },
    UnitDef { id: "kb", symbol: "kB", name: "千字节(10³)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8.0e3 }, aliases: &["KB", "kilobyte"] },
    UnitDef { id: "mb", symbol: "MB", name: "兆字节(10⁶)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8.0e6 }, aliases: &["megabyte"] },
    UnitDef { id: "gb", symbol: "GB", name: "吉字节(10⁹)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8.0e9 }, aliases: &["gigabyte"] },
    UnitDef { id: "tb", symbol: "TB", name: "太字节(10¹²)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8.0e12 }, aliases: &["terabyte"] },
    UnitDef { id: "kib", symbol: "KiB", name: "千字节(2¹⁰)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8192.0 }, aliases: &["kibibyte"] },
    UnitDef { id: "mib", symbol: "MiB", name: "兆字节(2²⁰)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8388608.0 }, aliases: &["mebibyte"] },
    UnitDef { id: "gib", symbol: "GiB", name: "吉字节(2³⁰)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8589934592.0 }, aliases: &["gibibyte"] },
    UnitDef { id: "tib", symbol: "TiB", name: "太字节(2⁴⁰)", category: UnitCategory::DataStorage, kind: UnitKind::Proportional { factor: 8796093022208.0 }, aliases: &["tebibyte"] },
];

static SPEED: &[UnitDef] = &[
    UnitDef { id: "m_s", symbol: "m/s", name: "米每秒", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["米每秒"] },
    UnitDef { id: "km_h", symbol: "km/h", name: "千米每小时", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 0.2777777777777778 }, aliases: &["公里每小时", "kph"] },
    UnitDef { id: "mph", symbol: "mph", name: "英里每小时", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 0.44704 }, aliases: &["英里每小时"] },
    UnitDef { id: "ft_s", symbol: "ft/s", name: "英尺每秒", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 0.3048 }, aliases: &["英尺每秒"] },
    UnitDef { id: "knot", symbol: "kn", name: "节", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 0.5144444444444445 }, aliases: &["节", "knot"] },
    UnitDef { id: "mach", symbol: "Ma", name: "马赫（海平面 15℃）", category: UnitCategory::Speed, kind: UnitKind::Proportional { factor: 340.3 }, aliases: &["马赫"] },
];

static PRESSURE: &[UnitDef] = &[
    UnitDef { id: "pa", symbol: "Pa", name: "帕斯卡", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["帕", "pascal"] },
    UnitDef { id: "kpa", symbol: "kPa", name: "千帕", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 1000.0 }, aliases: &["千帕"] },
    UnitDef { id: "mpa", symbol: "MPa", name: "兆帕", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 1e6 }, aliases: &["兆帕"] },
    UnitDef { id: "bar", symbol: "bar", name: "巴", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 100000.0 }, aliases: &["巴"] },
    UnitDef { id: "mbar", symbol: "mbar", name: "毫巴", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 100.0 }, aliases: &["毫巴"] },
    UnitDef { id: "psi", symbol: "psi", name: "磅每平方英寸", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 6894.757293168361 }, aliases: &["磅每平方英寸"] },
    UnitDef { id: "atm", symbol: "atm", name: "标准大气压", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 101325.0 }, aliases: &["标准大气压"] },
    UnitDef { id: "mmhg", symbol: "mmHg", name: "毫米汞柱", category: UnitCategory::Pressure, kind: UnitKind::Proportional { factor: 133.322387415 }, aliases: &["毫米汞柱", "torr"] },
];

static ENERGY: &[UnitDef] = &[
    UnitDef { id: "j", symbol: "J", name: "焦耳", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 1.0 }, aliases: &["焦", "joule"] },
    UnitDef { id: "kj", symbol: "kJ", name: "千焦", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 1000.0 }, aliases: &["千焦"] },
    UnitDef { id: "cal", symbol: "cal", name: "卡", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 4.184 }, aliases: &["卡"] },
    UnitDef { id: "kcal", symbol: "kcal", name: "千卡", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 4184.0 }, aliases: &["大卡", "千卡"] },
    UnitDef { id: "wh", symbol: "Wh", name: "瓦时", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 3600.0 }, aliases: &["瓦时"] },
    UnitDef { id: "kwh", symbol: "kWh", name: "千瓦时", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 3600000.0 }, aliases: &["度", "千瓦时"] },
    UnitDef { id: "ev", symbol: "eV", name: "电子伏", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 1.602176634e-19 }, aliases: &["电子伏"] },
    UnitDef { id: "btu", symbol: "BTU", name: "英热单位", category: UnitCategory::Energy, kind: UnitKind::Proportional { factor: 1055.05585262 }, aliases: &["英热单位"] },
];

/// 按 id / 符号 / 别名查找单位。
///
/// 匹配顺序：id 精确 → symbol 精确 → alias 精确 → 全表不区分大小写。
/// 精确优先，避免 `MB` 被 `mB` 之类的大小写折叠抢匹配。
pub fn lookup_unit(id_or_alias: &str) -> Option<&'static UnitDef> {
    let mut exact: Option<&'static UnitDef> = None;
    for c in UnitCategory::all() {
        for u in c.units() {
            if u.id == id_or_alias || u.symbol == id_or_alias || u.aliases.contains(&id_or_alias) {
                exact = Some(u);
                break;
            }
        }
        if exact.is_some() {
            return exact;
        }
    }
    let needle = id_or_alias.to_lowercase();
    for c in UnitCategory::all() {
        for u in c.units() {
            if u.id.to_lowercase() == needle
                || u.symbol.to_lowercase() == needle
                || u.aliases.iter().any(|a| a.to_lowercase() == needle)
            {
                return Some(u);
            }
        }
    }
    None
}

/// 换算；跨类别返回 `IncompatibleUnits`，温度低于 0 K 返回 `BelowAbsoluteZero`。
pub fn convert(value: &Num, from: &UnitDef, to: &UnitDef) -> Result<Num> {
    if from.category != to.category {
        return Err(EngineError::with_message(
            ErrorKind::IncompatibleUnits,
            format!("不能把 {} 换算成 {}", from.name, to.name),
        ));
    }
    let si = from.to_si(value.to_f64());
    if from.category == UnitCategory::Temperature && si < 0.0 {
        return Err(EngineError::with_message(
            ErrorKind::BelowAbsoluteZero,
            "温度低于绝对零度（0 K）",
        ));
    }
    Ok(normalize(to.from_si(si)))
}

/// 结果是"整且可精确表示"时用整数承载，让 `1 GiB = 1024 MiB` 显示成 `1,024`。
fn normalize(v: f64) -> Num {
    if v.is_finite()
        && v.fract() == 0.0
        && v.abs() <= 9_007_199_254_740_992.0
        && v >= i64::MIN as f64
        && v <= i64::MAX as f64
    {
        Num::int(v as i64)
    } else {
        Num::float(v)
    }
}

/// 解析 `"12.7 inch in mm"` / `"... to mm"` / `"... -> mm"` 形式的查询串。
pub fn parse_convert_query(q: &str) -> Result<(Num, &'static UnitDef, &'static UnitDef)> {
    let q = q.trim();
    let end = crate::lexer::scan_number_prefix(q).ok_or_else(|| {
        EngineError::with_message(ErrorKind::InvalidRequest, "换算表达式开头需要一个数值")
    })?;
    let value = crate::lexer::parse_number_literal(&q[..end])?;
    let rest = q[end..].trim();
    if rest.is_empty() {
        return Err(EngineError::with_message(
            ErrorKind::InvalidRequest,
            "缺少目标单位",
        ));
    }
    let mut words: Vec<&str> = Vec::new();
    for w in rest.split_whitespace() {
        if is_connector(w) {
            continue;
        }
        words.push(w);
    }
    if words.len() < 2 {
        // 支持 `12.7inch→mm` 这种完全不带空格的写法
        let mut split: Option<(&str, &str)> = None;
        for sep in ["→", "->", "=>", "=>"] {
            if let Some((a, b)) = rest.split_once(sep) {
                split = Some((a, b));
                break;
            }
        }
        match split {
            Some((a, b)) => words = vec![a, b],
            None => {
                return Err(EngineError::with_message(
                    ErrorKind::InvalidRequest,
                    "换算表达式需要「源单位」和「目标单位」，如 12.7 inch in mm",
                ))
            }
        }
    }
    let from = lookup_unit(words[0]).ok_or_else(|| {
        EngineError::with_message(ErrorKind::UnknownUnit, format!("未知单位 {}", words[0]))
    })?;
    let to = lookup_unit(words[1]).ok_or_else(|| {
        EngineError::with_message(ErrorKind::UnknownUnit, format!("未知单位 {}", words[1]))
    })?;
    Ok((value, from, to))
}

fn is_connector(w: &str) -> bool {
    matches!(
        w.to_lowercase().as_str(),
        "in" | "to" | "->" | "→" | "=" | "as" | "等于" | "换成" | "to_unit"
    )
}

/// 列出全部类别信息。
pub fn all_categories() -> Vec<CategoryInfo> {
    UnitCategory::all().iter().copied().map(CategoryInfo::of).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cv(v: &str, from: &str, to: &str) -> Result<Num> {
        let f = lookup_unit(from).unwrap_or_else(|| panic!("未知单位 {}", from));
        let t = lookup_unit(to).unwrap_or_else(|| panic!("未知单位 {}", to));
        let n = crate::lexer::parse_number_literal(v).unwrap();
        convert(&n, f, t)
    }

    #[test]
    fn ten_categories_with_at_least_six_units_each() {
        assert_eq!(UnitCategory::all().len(), 10);
        for c in UnitCategory::all() {
            assert!(c.units().len() >= 6, "{} 只有 {} 个单位", c.name(), c.units().len());
        }
    }

    #[test]
    fn length_conversions() {
        assert!((cv("1", "inch", "mm").unwrap().to_f64() - 25.4).abs() < 1e-9);
        assert!((cv("1", "m", "cm").unwrap().to_f64() - 100.0).abs() < 1e-9);
        assert!((cv("1", "mi", "km").unwrap().to_f64() - 1.609344).abs() < 1e-9);
        assert!((cv("1", "ft", "inch").unwrap().to_f64() - 12.0).abs() < 1e-9);
    }

    #[test]
    fn temperature_is_affine() {
        assert!((cv("100", "C", "F").unwrap().to_f64() - 212.0).abs() < 1e-9);
        assert!((cv("100", "C", "K").unwrap().to_f64() - 373.15).abs() < 1e-9);
        assert!((cv("32", "F", "C").unwrap().to_f64() - 0.0).abs() < 1e-9);
        assert!((cv("0", "C", "K").unwrap().to_f64() - 273.15).abs() < 1e-9);
        assert_eq!(
            cv("-300", "C", "F").unwrap_err().kind,
            ErrorKind::BelowAbsoluteZero
        );
    }

    #[test]
    fn data_storage_has_both_si_and_iec() {
        assert_eq!(cv("1", "gib", "mib").unwrap(), Num::int(1024));
        assert_eq!(cv("1", "gb", "mb").unwrap(), Num::int(1000));
        assert_eq!(cv("1", "byte", "bit").unwrap(), Num::int(8));
        assert_eq!(cv("1", "mib", "kib").unwrap(), Num::int(1024));
    }

    #[test]
    fn cross_category_is_rejected() {
        assert_eq!(cv("1", "inch", "kg").unwrap_err().kind, ErrorKind::IncompatibleUnits);
        assert_eq!(cv("1", "s", "m").unwrap_err().kind, ErrorKind::IncompatibleUnits);
        assert_eq!(cv("1", "j", "pa").unwrap_err().kind, ErrorKind::IncompatibleUnits);
    }

    #[test]
    fn unknown_units() {
        assert!(lookup_unit("not_a_unit").is_none());
    }

    #[test]
    fn query_parsing() {
        for q in ["12.7 inch in mm", "12.7 inch to mm", "12.7 inch -> mm", "12.7 inch → mm", "12.7inch→mm"] {
            let (v, f, t) = parse_convert_query(q).unwrap();
            assert_eq!(v, Num::rational(127, 10).unwrap());
            assert_eq!(f.id, "inch");
            assert_eq!(t.id, "mm");
        }
        assert!(parse_convert_query("inch to mm").is_err());
        assert_eq!(
            parse_convert_query("1 zzz in mm").unwrap_err().kind,
            ErrorKind::UnknownUnit
        );
    }

    #[test]
    fn category_ids_and_infos() {
        assert_eq!(UnitCategory::from_id("data_storage"), Some(UnitCategory::DataStorage));
        assert_eq!(UnitCategory::Length.base_symbol(), "m");
        let infos = all_categories();
        assert_eq!(infos.len(), 10);
        assert_eq!(infos[0].id, "length");
        assert_eq!(CategoryInfo::of(UnitCategory::Temperature).units[0].kind, "affine");
        assert_eq!(CategoryInfo::of(UnitCategory::Length).units[0].kind, "proportional");
    }

    #[test]
    fn remaining_categories_convert() {
        assert!((cv("1", "kg", "lb").unwrap().to_f64() - 2.2046226218487757).abs() < 1e-9);
        assert_eq!(cv("1", "h", "min").unwrap(), Num::int(60));
        assert_eq!(cv("1", "ha", "m2").unwrap(), Num::int(10000));
        assert!((cv("1", "l", "ml").unwrap().to_f64() - 1000.0).abs() < 1e-9);
        assert!((cv("1", "km_h", "m_s").unwrap().to_f64() - 0.2777777777777778).abs() < 1e-12);
        assert!((cv("1", "bar", "pa").unwrap().to_f64() - 100000.0).abs() < 1e-9);
        assert!((cv("1", "kcal", "j").unwrap().to_f64() - 4184.0).abs() < 1e-9);
    }
}
