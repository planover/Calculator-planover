/// 记忆指示器（PRD §13.1 CP-07）—— 记忆寄存器非零时显示 `M` 徽标。
///
/// 点击可展开 [MemorySheet] 查看记忆值。与 `ans` 指示器采用不同视觉样式（CP-17）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/calculator_controller.dart';
import '../widgets/memory_sheet.dart';

/// 记忆指示器。
class MemoryIndicator extends StatelessWidget {
  /// 构造指示器。
  const MemoryIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    if (!calc.hasMemory) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: 'memory indicator',
      button: true,
      onTap: () => MemorySheet.show(context),
      child: GestureDetector(
        onTap: () => MemorySheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'M',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
