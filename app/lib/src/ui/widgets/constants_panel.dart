/// 常量面板（架构 §T05 / PRD §4.1 ⑤⑥）。
///
/// 列出引擎常量，点击把符号插入光标处（走 [CalculatorController.applyEdit]，
/// 不本地拼字符串）。常量名经 [AppLocalizations.constantName] 按语言回退。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/constant_info.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';

/// 常量面板。
class ConstantsPanel extends StatelessWidget {
  /// 构造常量面板。
  const ConstantsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final List<ConstantInfo> constants = calc.engine.listConstants();

    if (constants.isEmpty) {
      return Center(
        child: Text(
          '—',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.padSm),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Tokens.padXs,
        crossAxisSpacing: Tokens.padXs,
        childAspectRatio: 2.4,
        children: constants
            .map(
              (ConstantInfo c) => FilledButton.tonal(
                onPressed: () =>
                    calc.applyEdit('insert', payload: c.symbol),
                style: FilledButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.padSm,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      c.symbol,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.constantName(c.symbol, c.name),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
