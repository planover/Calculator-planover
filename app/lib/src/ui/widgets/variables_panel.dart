/// 变量面板（架构 §T05 / PRD §4.1 ⑤⑥ / P0-13）。
///
/// 列出引擎变量（含只读的 ans），点击把变量名插入光标处。
/// `ans` 为只读（Dart 不提供删除入口，删除语义在引擎侧）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/variable_info.dart';
import '../../state/calculator_controller.dart';
import '../../theme/tokens.dart';

/// 变量面板。
class VariablesPanel extends StatelessWidget {
  /// 构造变量面板。
  const VariablesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    final List<VariableInfo> variables = calc.engine.listVariables();

    if (variables.isEmpty) {
      return Center(
        child: Text(
          '—',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.padSm),
      child: Wrap(
        spacing: Tokens.padXs,
        runSpacing: Tokens.padXs,
        children: variables
            .map(
              (VariableInfo v) => ActionChip(
                label: Text(v.display.isEmpty ? v.name : '${v.name} = ${v.display}'),
                onPressed: () => calc.applyEdit('insert', payload: v.name),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
