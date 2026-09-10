# Calculator-planover

Android 科学计算器：**Rust 计算内核 + Flutter UI**，applicationId `org.solovyev.android.calculator`，应用名 `Calculator-planover`。

## 架构总览

```
┌────────────────────┐      dart:ffi (C ABI)      ┌──────────────────────────┐
│   Flutter (Dart)   │ ───────────────────────────▶ │  engine/ffi  (cdylib)   │
│   UI / 输入编辑    │ ◀─────────────────────────── │  calc_*  C 导出函数      │
└────────────────────┘     JSON over CString        └────────────┬─────────────┘
                                                                │ dispatch
                                                                ▼
                                                    ┌──────────────────────────┐
                                                    │  engine/core (rlib)       │
                                                    │  全部逻辑 + 全部测试       │
                                                    └──────────────────────────┘
```

- **`engine/core`**（`calculator_core`，**仅 rlib**）：承载全部计算逻辑与**全部测试**，
  可在任意桌面环境 `cargo test -p calculator_core` 验证，不依赖 Android / Flutter / IO / 系统时间。
- **`engine/ffi`**（`calculator_ffi`，**仅 cdylib**）：C ABI 胶水层（`#[no_mangle] extern "C"`
  + CString/serde）。`dispatch(method, json, &mut Engine) -> String` 是纯字符串函数，
  JSON 契约由 `calculator_core` 的单测 100% 覆盖。
- **`app/`**：Flutter 工程骨架（`pubspec.yaml` / `analysis_options.yaml` / `android/` 原生壳层）。
  Dart `lib/**` 资源在后续轮次落地。
- **`tools/`**：原生壳层生成、Rust 产物打入 jniLibs、本地一键构建测试脚本。

## 关键约定

- 代码注释解释 **WHY**（中文）。
- 数值类型：`Num = 精确有理数(i64/i64) ∪ f64 ∪ 非有限值`，无 GMP/MPFR。
- 业务语义：`-3^2 = -9`；隐式乘法 `2(3+4)`、`2π`；`% = a/100`（故 `200*10% = 20`）；
  阶乘仅非负整数；按位运算按位宽二进制补码（8/16/32/64）；温度仿射变换，低于绝对零度报错；
  `ans` 与历史**解耦**（Q9：重置保留 `ans`）。
- 错误统一为 `EngineError { kind, span }`，跨 FFI 用 `catch_unwind` 兜底，不 panic。
- 运行时依赖仅 3 个：`serde`、`serde_json`、`libc`。
- 仓库用 Rust workspace，`default-members = ["core"]`，故 `cargo test` 只链接 rlib、
  不碰 cdylib，本地无 MSVC linker 也能全绿。

## 本地验证

```bash
# Rust 内核（主验收项：必须 ALL GREEN）
cd engine
cargo test -p calculator_core

# 或一键脚本
./tools/build_and_test.sh      # Linux / macOS / CI
tools\build_and_test.ps1       # Windows(MSVC)
```

## 构建 Android APK（release）

```bash
# 1) 交叉编译 Rust cdylib
cd engine
cargo install cargo-ndk
cargo ndk -t aarch64-linux-android -o ../app/android/app/src/main/jniLibs build -p calculator_ffi --release

# 2) 把产物打入 jniLibs
python3 tools/patch_android.py --artifacts app/android/app/src/main/jniLibs

# 3) 构建 APK
cd app && flutter pub get && flutter build apk --release
```

## 测试覆盖

`engine/core/tests/` 下集成测试：

| 文件 | 覆盖 |
|------|------|
| `t01_arithmetic.rs` | 四则 / 优先级 / 隐式乘法 / 百分号 / 阶乘 / 精度基线 |
| `t02_trig_log.rs` | 三角 / 反三角 / 对数 / 幂根 / 取整 / 双曲 / 随机 |
| `t03_base_bitwise.rs` | 进制转换(≥20) / 二进制补码 / 位宽 / 按位运算 |
| `t04_units.rs` | 10 类单位换算 / 温度仿射 / 跨类拒绝 |
| `t05_format.rs` | 科学 / 定点 / 有效位 / 小数位 / 分数 / 分组 |
| `t06_errors.rs` | 不完整表达式 / 定义域 / 未知函数 / 参数个数 / 非整数 |
| `t07_session_vars.rs` | 变量赋值 / ans 解耦 / 重置保留 ans / 保留名 |
| `t08_api_json.rs` | `api::dispatch` 全部 method 的 JSON 契约 |
| `t09_edit.rs` | 输入编辑纯函数（8 类语义 + 多字节光标） |

## 目录结构

```
Calculator-planover/
├── engine/
│   ├── Cargo.toml            # workspace（default-members=[core]）
│   ├── rust-toolchain.toml   # 固定 1.83.0
│   ├── core/                 # rlib + 全部测试
│   └── ffi/                  # cdylib
├── app/                      # Flutter 骨架（android/ 原生壳层）
├── tools/                    # 构建与打包脚本
└── .github/workflows/        # ci.yml / release.yml
```
