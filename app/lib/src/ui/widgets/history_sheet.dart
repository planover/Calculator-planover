/// 历史抽屉（架构 §T05 要点 7 / PRD §4.2 / P0-20）。
///
/// `showModalBottomSheet` + `DraggableScrollableSheet`：初始高度 0.7、最大 0.85。
/// 列表来自 [HistoryController]；点击某条把表达式载入输入行；支持单条删除与
/// "清空全部"（二次确认对话框）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/region_format_presets.dart';
import '../../models/history_entry.dart';
import '../../models/region_format_config.dart';
import '../../state/calculator_controller.dart';
import '../../state/history_controller.dart';
import '../../state/locale_controller.dart';
import '../../state/region_format_controller.dart';
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
    // 区域格式决定历史时间/日期（RF-T-06 / RF-D-07），与界面语言无关（A3）。
    // 用可选查找：未注入 RegionFormatController 的测试/预览场景回落默认预设，
    // 不因缺 Provider 而崩（既有 history_marker_test 未注入该 Provider）。
    final RegionFormatConfig regionConfig = _regionConfig(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (BuildContext ctx, ScrollController scroll) {
        final List<HistoryEntry> entries = history.entries;
        // 按短日期分组（RF-D-07）：同一天的条目归为一组，首条前插入日期头。
        final List<_HistoryRow> rows = _buildRows(entries, regionConfig);
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
              child: entries.isEmpty
                  ? Center(
                      child: Text(l10n.tr('ui.history.empty')),
                    )
                  : ListView.builder(
                      controller: scroll,
                      itemCount: rows.length,
                      itemBuilder: (BuildContext c, int i) {
                        final _HistoryRow row = rows[i];
                        final String? header = row.header;
                        if (header != null) {
                          return _DateHeader(label: header);
                        }
                        return _HistoryTile(
                          entry: row.entry!,
                          regionConfig: regionConfig,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// 解析当前区域时间/日期配置；未注入 [RegionFormatController] 时回落默认预设。
///
/// 用可空的 `Provider.of<RegionFormatController?>`（`listen: false`）实现"可选依赖"：
/// 既有测试只注入 3 个 Provider，此处不能因缺 Provider 而崩。
RegionFormatConfig _regionConfig(BuildContext context) {
  final RegionFormatController? region =
      Provider.of<RegionFormatController?>(context, listen: true);
  return region?.config ?? RegionFormatPresets.resolve(null);
}

/// 历史列表的一行：要么是日期分组头，要么是一条记录。
class _HistoryRow {
  /// 日期分组头（`null` 表示这是记录行）。
  const _HistoryRow.header(this.header) : entry = null;

  /// 记录行。
  const _HistoryRow.entry(this.entry) : header = null;

  /// 分组头文案；非 null 时 [entry] 为 null。
  final String? header;

  /// 记录；非 null 时 [header] 为 null。
  final HistoryEntry? entry;
}

/// 按短日期分组构造渲染行（RF-D-07）。
List<_HistoryRow> _buildRows(
  List<HistoryEntry> entries,
  RegionFormatConfig config,
) {
  final List<_HistoryRow> rows = <_HistoryRow>[];
  String lastKey = '';
  for (final HistoryEntry e in entries) {
    if (e.ts > 0) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(e.ts);
      final String key = regionDateGroupKey(dt);
      if (key != lastKey) {
        lastKey = key;
        rows.add(_HistoryRow.header(formatRegionDate(dt, config)));
      }
    }
    rows.add(_HistoryRow.entry(e));
  }
  return rows;
}

/// 日期分组头。
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.padMd,
        Tokens.padSm,
        Tokens.padMd,
        Tokens.padSm / 2,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.regionConfig});

  final HistoryEntry entry;
  final RegionFormatConfig regionConfig;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    final HistoryController history =
        Provider.of<HistoryController>(context, listen: false);

    return ListTile(
      title: Row(
        children: <Widget>[
          if (entry.usedMemory)
            Padding(
              padding: const EdgeInsets.only(right: Tokens.padSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'M',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          Expanded(child: Text(entry.expr)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '= ${entry.result}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            formatRegionTimestamp(entry.ts, regionConfig),
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
