/// 角度模式段控件（架构 §T05 要点 12 / PRD §4.1 ③）。
///
/// DEG / RAD / GRAD 三选一；切换后 [CalculatorController] 立即把新模式下发引擎并
/// 重算预览（§10：角度唯一来源是 Rust Session，Dart 只缓存 + 下发）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/eval_settings.dart';
import '../../state/calculator_controller.dart';

/// 角度模式切换。
class AngleModeSwitch extends StatelessWidget {
  /// 构造切换器。
  const AngleModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    final AngleMode angle = calc.angleMode;

    return Semantics(
      label: 'angle mode',
      child: SegmentedButton<AngleMode>(
        segments: const <ButtonSegment<AngleMode>>[
          ButtonSegment<AngleMode>(
            value: AngleMode.deg,
            label: Text('DEG'),
          ),
          ButtonSegment<AngleMode>(
            value: AngleMode.rad,
            label: Text('RAD'),
          ),
          ButtonSegment<AngleMode>(
            value: AngleMode.grad,
            label: Text('GRAD'),
          ),
        ],
        selected: <AngleMode>{angle},
        onSelectionChanged: (Set<AngleMode> selection) {
          calc.setAngleMode(selection.first);
        },
      ),
    );
  }
}
