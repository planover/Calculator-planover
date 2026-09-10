/// 显示区面板（架构 §T05 要点 12 / PRD §4.1 ② ③ ④）。
///
/// 包含：大字号预览行（[PreviewLine]）、角度模式切换（[AngleModeSwitch]）、
/// 进制结果行（[BaseResultRow]）。表达式输入行（①）在 [HomeScreen] 中独立放置。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/calculator_controller.dart';
import '../../theme/tokens.dart';
import 'angle_mode_switch.dart';
import 'base_result_row.dart';
import 'preview_line.dart';

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
          const PreviewLine(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.displayPad,
              vertical: Tokens.padSm,
            ),
            child: const Align(
              alignment: Alignment.centerRight,
              child: AngleModeSwitch(),
            ),
          ),
          BaseResultRow(base: calc.base),
        ],
      ),
    );
  }
}
