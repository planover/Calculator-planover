/// 功能页签（架构 §T05 / PRD §4.1 ⑤⑥）。
///
/// 四个页签：函数 / 常量 / 变量 / 单位。
/// - 函数：科学函数网格，点击插入对应文本（走引擎，符号与 Rust lexer 对齐）；
/// - 常量 / 变量：各自面板；
/// - 单位：跳转到单位换算页（[onOpenConverter]）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';
import 'constants_panel.dart';
import 'variables_panel.dart';

/// 功能页签。
class FunctionTabs extends StatelessWidget {
  /// 构造页签。
  const FunctionTabs({super.key, required this.onOpenConverter});

  /// 点击"单位"页签里的按钮时回调（打开单位换算页）。
  final VoidCallback onOpenConverter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: l10n.tr('ui.tabs.functions')),
              Tab(text: l10n.tr('ui.tabs.constants')),
              Tab(text: l10n.tr('ui.tabs.variables')),
              Tab(text: l10n.tr('ui.tabs.units')),
            ],
          ),
          SizedBox(
            height: 96,
            child: TabBarView(
              children: <Widget>[
                const _FunctionGrid(),
                const ConstantsPanel(),
                const VariablesPanel(),
                Center(
                  child: FilledButton.icon(
                    onPressed: onOpenConverter,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(l10n.tr('ui.unitConverter.open')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 科学函数网格。
class _FunctionGrid extends StatelessWidget {
  const _FunctionGrid();

  static const List<(String, String)> _fns = <(String, String)>[
    ('sin', 'sin('),
    ('cos', 'cos('),
    ('tan', 'tan('),
    ('ln', 'ln('),
    ('log', 'log('),
    ('√', '√('),
    ('x²', '^2'),
    ('xʸ', '^('),
    ('asin', 'asin('),
    ('acos', 'acos('),
    ('atan', 'atan('),
    ('lg', 'lg('),
    ('log₂', 'log2('),
    ('∛', 'cbrt('),
    ('x³', '^3'),
    ('eˣ', 'exp('),
    ('π', 'π'),
    ('n!', '!'),
    ('mod', 'mod('),
    ('1/x', '1/('),
    ('|x|', 'abs('),
    ('±', '(-'),
    ('%', '%'),
    ('(', '('),
    (')', ')'),
    (',', ','),
  ];

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.padSm),
      child: Wrap(
        spacing: Tokens.padXs,
        runSpacing: Tokens.padXs,
        children: _fns
            .map(
              ((String, String) f) => OutlinedButton(
                onPressed: () => calc.applyEdit('insert', payload: f.$2),
                child: Text(f.$1),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
