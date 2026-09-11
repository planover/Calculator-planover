/// 提交方式（PRD §3.2 UI-11~13 / 裁决 D1）。
///
/// 与"calculate-on-fly"语义对应：
/// - [auto]：边输入边实时出结果（原版默认行为），默认选项；
/// - [manual]：需显式提交（物理 Enter / 结果区长按 / Simple 的 `=`）才把结果写入历史。
library;

/// 提交方式。
enum SubmitMode {
  /// 自动（calculate-on-fly）。
  auto,

  /// 手动（需按 = / Enter 等显式提交）。
  manual,
}
