/// 实时预览行（架构 §T05 要点 5 / §10.2.3 / PRD §4.1 ②）。
///
/// - 正常：右对齐、次要色显示预览结果；
/// - 错误：红色文案（不完整表达式则灰色提示）；
/// - 若 [EngineException.span] 非空，用 [RichText] 在
///   `text.substring(span.start, span.end)` 处加红色下划线高亮出错位置。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/engine_exception.dart';
import '../../l10n/app_localizations.dart';
import '../../models/engine_error.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';

/// 预览行。
class PreviewLine extends StatelessWidget {
  /// 构造预览行。
  const PreviewLine({super.key});

  @override
  Widget build(BuildContext context) {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    final ThemeData theme = Theme.of(context);

    if (calc.error == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Text(
            calc.preview,
            textAlign: TextAlign.right,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: Tokens.fontSizePreview,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final EngineException err = calc.error!;
    final Color errColor = err.isIncompleteExpression
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.error;
    final String message = l10n.errorText(err.kind, err.message);
    final ErrorSpan? span = calc.errorSpan;

    if (span != null && span.start >= 0 && span.end <= calc.text.length) {
      final TextSpan highlighted = TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: Tokens.fontSizePreview,
          color: theme.colorScheme.onSurface,
        ),
        children: <TextSpan>[
          TextSpan(text: calc.text.substring(0, span.start)),
          TextSpan(
            text: calc.text.substring(span.start, span.end),
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: errColor,
              color: errColor,
            ),
          ),
          if (span.end < calc.text.length)
            TextSpan(text: calc.text.substring(span.end)),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(message, style: TextStyle(color: errColor)),
          RichText(text: highlighted),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        message,
        textAlign: TextAlign.right,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: Tokens.fontSizePreview,
          color: errColor,
        ),
      ),
    );
  }
}
