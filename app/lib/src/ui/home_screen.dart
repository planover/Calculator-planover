/// 主界面（架构 §T05 / PRD §4.1）。
///
/// 竖向布局：顶栏（设置 / 历史入口）→ 表达式输入行 → 显示区面板
/// （预览 / 角度 / 进制）→ 功能页签 → 科学键盘。历史以底部抽屉拉起。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';
import '../screens/settings_screen.dart';
import '../screens/unit_converter_screen.dart';
import '../widgets/display_panel.dart';
import '../widgets/expression_field.dart';
import '../widgets/function_tabs.dart';
import '../widgets/history_sheet.dart';
import '../widgets/keypad.dart';

/// 主界面。
class HomeScreen extends StatelessWidget {
  /// 构造主界面。
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('ui.app.title')),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.tr('ui.settings.title'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.tr('ui.history.title'),
            onPressed: () => HistorySheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ExpressionField(),
            const DisplayPanel(),
            FunctionTabs(
              onOpenConverter: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UnitConverterScreen(),
                ),
              ),
            ),
            Expanded(child: Keypad()),
          ],
        ),
      ),
    );
  }
}
