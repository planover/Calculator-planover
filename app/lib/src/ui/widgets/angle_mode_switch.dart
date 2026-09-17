/// 角度模式芯片（架构 §1.7 Q1 裁决：4 段 `SegmentedButton` → **单枚模式芯片**）。
///
/// DEG / RAD / GRAD / TURNS 四选一，但**当前模式常显**于一枚窄芯片（≈ 与 `M` / `Ans`
/// 同级的状态指示器），点按弹出 4 选 1 菜单。切换后 [CalculatorController] 立即把
/// 新模式下发引擎并重算预览（§10：角度唯一来源是 Rust Session，Dart 只缓存 + 下发）。
///
/// 为什么不再是 4 段设置条：4 段（尤其增量新增的第 4 档 `TURNS`）在 411dp（内宽
/// 379px）即把 `display_panel.dart` 那一行撑出 `RenderFlex overflowed by 75 pixels`
/// （IC-17），320dp 更甚（可用 288px）；Release 下溢出静默裁切 = 用户「界面错章杂乱」
/// 的真实构成。单芯片把该行宽度压到 ≈164px ≪ 288px，全档安全。
///
/// 语义契约（**不得回退**）：
/// - `Semantics(label: 'angle mode')` 保留（无障碍 + 供测试定位）；
/// - `Key('angleModeSwitch')` 保留（供测试点击芯片）。
///
/// 引擎零改动：仍只经 `calc.setAngleMode(...)` 走既有下发链路。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/eval_settings.dart';
import '../../state/calculator_controller.dart';
import '../../theme/tokens.dart';

/// 角度模式切换（紧凑单芯片 + 弹出菜单）。
class AngleModeSwitch extends StatelessWidget {
  /// 构造切换器。
  const AngleModeSwitch({super.key});

  /// 展示用缩写（与设置页 `_AngleRow` 的段标签保持一致）。
  static const Map<AngleMode, String> _labels = <AngleMode, String>{
    AngleMode.deg: 'DEG',
    AngleMode.rad: 'RAD',
    AngleMode.grad: 'GRAD',
    AngleMode.turns: 'TURNS',
  };

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    final AngleMode angle = calc.angleMode;
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: 'angle mode',
      button: true,
      child: MenuAnchor(
        // 4 选 1：当前模式前置对勾；选中即经控制器下发引擎（§10）。
        menuChildren: <Widget>[
          for (final AngleMode mode in AngleMode.values)
            MenuItemButton(
              // 稳定 Key（`deg`/`rad`/`grad`/`turns`）供测试选取具体项。
              key: Key('angleModeOption-${mode.id}'),
              onPressed: () {
                calc.setAngleMode(mode);
              },
              leadingIcon: mode == angle
                  ? const Icon(Icons.check, size: 18)
                  : const SizedBox(width: 18),
              child: Text(_labels[mode]!),
            ),
        ],
        builder: (
          BuildContext context,
          MenuController controller,
          Widget? child,
        ) {
          return ConstrainedBox(
            // 架构 §1.7 规格：`ConstrainedBox(maxWidth: 76)` 天花板。
            constraints: const BoxConstraints(maxWidth: 76),
            child: TextButton(
              // Key 保留（供测试点击芯片）。
              key: const Key('angleModeSwitch'),
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              style: TextButton.styleFrom(
                // 紧凑化：去掉 Material 默认的 40dp 高 / 64dp 宽 / 触摸 padding，
                // 让芯片与 `M` / `Ans` 同高（≈24dp），不抬高显示区那一行。
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Tokens.padSm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(color: theme.colorScheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
              ),
              child: Text(
                _labels[angle]!,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
