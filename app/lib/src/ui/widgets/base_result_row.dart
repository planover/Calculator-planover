/// 进制结果行（架构 §T05 要点 12 / PRD §4.1 ④）。
///
/// 展示同一结果在 DEC / HEX / OCT / BIN 下的表示。整数且 [BaseRepr.isInteger] 时
/// 才显示 HEX / OCT / BIN（非整数时 Rust 只填 `dec`）。点击某进制把其值复制到剪贴板。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/base_repr.dart';
import '../../theme/tokens.dart';

/// 进制结果行。
class BaseResultRow extends StatelessWidget {
  /// 构造进制行。
  const BaseResultRow({super.key, required this.base});

  /// 当前进制表示（可为空，如尚未求值）。
  final BaseRepr? base;

  @override
  Widget build(BuildContext context) {
    final BaseRepr? b = base;
    if (b == null || b.dec.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<Widget> cells = <Widget>[
      _cell(context, 'DEC', b.dec),
    ];
    if (b.isInteger) {
      if (b.hex.isNotEmpty) cells.add(_cell(context, 'HEX', b.hex));
      if (b.oct.isNotEmpty) cells.add(_cell(context, 'OCT', b.oct));
      if (b.bin.isNotEmpty) cells.add(_cell(context, 'BIN', b.bin));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.displayPad,
        vertical: Tokens.padXs,
      ),
      child: Wrap(
        spacing: Tokens.padLg,
        runSpacing: Tokens.padSm,
        children: cells,
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: '$label $value',
      button: true,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.padXs),
        child: RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: '$label  ',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: value,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
