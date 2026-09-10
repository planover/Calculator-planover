/// 历史抽屉（架构 §T05 要点 7 / PRD §4.2 / P0-20）。
///
/// `showModalBottomSheet` + `DraggableScrollableSheet`：初始高度 0.7、最大 0.85。
/// 列表来自 [HistoryController]；点击某条把表达式载入输入行；支持单条删除与
/// "清空全部"（二次确认对话框）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/history_entry.dart';
import '../../state/calculator_controller.dart';
import '../../state/history_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';
import '../../utils/date_format.dart';

/// 历史抽屉。
class HistorySheet {
  /// 拉起历史抽屉。
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HistorySheetBody(),
    );
  }
}

class _HistorySheetBody extends StatelessWidget {
  const _HistorySheetBody();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    final HistoryController history =
        Provider.of<HistoryController>(context, listen: true);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (BuildContext ctx, ScrollController scroll) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Tokens.padMd),
              child: Row(
                children: <Widget>[
                  Text(
                    l10n.tr('ui.history.title'),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: l10n.tr('ui.common.clear'),
                    onPressed: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (BuildContext d) => AlertDialog(
                          title: Text(l10n.tr('ui.history.title')),
                          content: Text(l10n.tr('ui.history.clearConfirm')),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(d).pop(false),
                              child: Text(l10n.tr('ui.common.cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(d).pop(true),
                              child: Text(l10n.tr('ui.common.clear')),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await history.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.entries.isEmpty
                  ? Center(
                      child: Text(l10n.tr('ui.history.empty')),
                    )
                  : ListView.separated(
                      controller: scroll,
                      itemCount: history.entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext c, int i) {
                        final HistoryEntry e = history.entries[i];
                        return _HistoryTile(entry: e);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    final HistoryController history =
        Provider.of<HistoryController>(context, listen: false);

    return ListTile(
      title: Text(entry.expr),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '= ${entry.result}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            formatTimestamp(entry.ts),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.tr('ui.common.delete'),
        onPressed: () => history.delete(entry.id!),
      ),
      onTap: () {
        calc.setText(entry.expr);
        Navigator.of(context).pop();
      },
    );
  }
}
