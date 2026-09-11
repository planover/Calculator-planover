/// 记忆寄存器面板（PRD §13.1 CP-06 / UI-05）—— `M` 键弹出的底部抽屉。
///
/// 展示当前记忆值，并提供 `M+` / `M-` / `MC` / `MR` 四个操作，分别调用
/// [CalculatorController.memoryAdd] / [memorySubtract] / [memoryClear] / [memoryRecall]。
/// 记忆寄存器独立于 `ans`（CP-17），由引擎维护。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';

/// 记忆寄存器面板。
class MemorySheet {
  /// 拉起记忆面板。
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MemorySheetBody(),
    );
  }
}

class _MemorySheetBody extends StatelessWidget {
  const _MemorySheetBody();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);

    final Widget valueLine = calc.hasMemory
        ? Text(
            calc.memory.display,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.right,
          )
        : Text(
            l10n.tr('ui.memory.empty'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.right,
          );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.padMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  l10n.tr('ui.memory.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.tr('ui.common.close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.padMd),
              child: valueLine,
            ),
            Wrap(
              spacing: Tokens.padSm,
              runSpacing: Tokens.padSm,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: calc.memoryAdd,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.tr('ui.memory.add')),
                ),
                ElevatedButton.icon(
                  onPressed: calc.memorySubtract,
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.tr('ui.memory.subtract')),
                ),
                ElevatedButton.icon(
                  onPressed: calc.memoryClear,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.tr('ui.memory.clear')),
                ),
                ElevatedButton.icon(
                  onPressed: calc.memoryRecall,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(l10n.tr('ui.memory.recall')),
                ),
              ],
            ),
            const SizedBox(height: Tokens.padMd),
          ],
        ),
      ),
    );
  }
}
