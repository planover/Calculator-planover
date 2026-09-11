/// 科学函数面板（PRD §3.2 UI-07）—— `ƒ` 键弹出的底部抽屉。
///
/// 复用 [ScientificFunctionGrid]（与函数页签同一份网格），点击插入对应文本走引擎。
library;

import 'package:flutter/material.dart';

import 'function_tabs.dart';

/// 科学函数面板。
class FunctionSheet {
  /// 拉起科学函数面板。
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FunctionSheetBody(),
    );
  }
}

class _FunctionSheetBody extends StatelessWidget {
  const _FunctionSheetBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'ƒ',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            const Expanded(child: ScientificFunctionGrid()),
          ],
        ),
      ),
    );
  }
}
