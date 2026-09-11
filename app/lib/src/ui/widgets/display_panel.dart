/// 显示区面板（架构 §T05 要点 12 / PRD §4.1 ② ③ ④）。
///
/// 包含：大字号预览行（[PreviewLine]）、角度模式切换（[AngleModeSwitch]）、
/// 进制结果行（[BaseResultRow]），以及 `M` / `Ans` 指示器（CP-07 / CP-17）。
/// 结果行长按 → 保存到历史（UI-12 显式提交入口之一）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/calculator_controller.dart';
import '../../theme/tokens.dart';
import '../widgets/angle_mode_switch.dart';
import '../widgets/base_result_row.dart';
import '../widgets/memory_indicator.dart';
import '../widgets/preview_line.dart';

/// 显示区面板。
class DisplayPanel extends StatelessWidget {
  /// 构造显示区。
  const DisplayPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Tokens.padSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 结果行长按 → 保存到历史（UI-12）。
          GestureDetector(
            onLongPress: () => calc.commit(),
            child: const PreviewLine(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.displayPad,
              vertical: Tokens.padSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // 记忆寄存器 `M` 指示器与 `Ans` 指示器采用不同视觉样式（CP-17）。
                const _AnsIndicator(),
                Row(
                  children: <Widget>[
                    const MemoryIndicator(),
                    const SizedBox(width: Tokens.padSm),
                    const AngleModeSwitch(),
                  ],
                ),
              ],
            ),
          ),
          BaseResultRow(base: calc.base),
        ],
      ),
    );
  }
}

/// `Ans` 指示器（与 `M` 不同样式，CP-17）：有上次结果时显示。
class _AnsIndicator extends StatelessWidget {
  const _AnsIndicator();

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    if (calc.resultText.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Ans',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
