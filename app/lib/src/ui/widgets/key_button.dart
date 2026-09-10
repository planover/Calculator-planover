/// 单个计算器按键（架构 §T05 要点 6 / P1-14）。
///
/// 封装：语义标签（Semantics）、点击、长按（单次）、长按连发（[onLongPressStart] /
/// [onLongPressEnd]，用于 ⌫ 连续删除）。视觉用 `ColorScheme` 的容器色，避免硬编码。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 按键色调。
enum KeyTone {
  /// 普通数字 / 括号。
  normal,

  /// 运算符 / 函数。
  function,

  /// 主操作（=）。
  accent,

  /// 危险（C / 清空）。
  danger,
}

/// 计算器按键。
class KeyButton extends StatefulWidget {
  /// 构造一个按键。
  const KeyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.semanticLabel,
    this.tone = KeyTone.normal,
    this.span = 1,
  });

  /// 按键内容（通常是 [Text] 或符号）。
  final Widget label;

  /// 点击。
  final VoidCallback onTap;

  /// 长按（单次触发，如 C 长按清空全部）。
  final VoidCallback? onLongPress;

  /// 长按开始：用于连发（如 ⌫ 连续删除）。
  final VoidCallback? onLongPressStart;

  /// 长按结束：停止连发。
  final VoidCallback? onLongPressEnd;

  /// 无障碍标签（P1-14）。
  final String? semanticLabel;

  /// 色调。
  final KeyTone tone;

  /// 跨列数（0 键跨 2 列）。
  final int span;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  Color _background(ThemeData theme) {
    switch (widget.tone) {
      case KeyTone.function:
        return theme.colorScheme.surfaceContainerHigh;
      case KeyTone.accent:
        return theme.colorScheme.primary;
      case KeyTone.danger:
        return theme.colorScheme.errorContainer;
      case KeyTone.normal:
        return theme.colorScheme.surfaceContainerLow;
    }
  }

  Color _foreground(ThemeData theme) {
    switch (widget.tone) {
      case KeyTone.accent:
        return theme.colorScheme.onPrimary;
      case KeyTone.danger:
        return theme.colorScheme.onErrorContainer;
      case KeyTone.function:
      case KeyTone.normal:
        return theme.colorScheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget child = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _background(theme),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: Tokens.fontSizeKey,
          color: _foreground(theme),
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        child: widget.label,
      ),
    );

    // Expanded 必须是 Row/Column 的**直接**子节点；若被 Semantics 包住会抛
    // ParentDataWidget 断言（CI test 暴露）。故把 Expanded 提到最外层，
    // Semantics 置于其内部——语义与行为完全不变。
    return Expanded(
      flex: widget.span,
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        excludeSemantics: widget.semanticLabel != null,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.padXs),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onLongPressStart: widget.onLongPressStart == null
                ? null
                : (_) {
                    widget.onLongPressStart?.call();
                    _repeatTimer?.cancel();
                    _repeatTimer = Timer.periodic(
                      const Duration(milliseconds: 80),
                      (_) => widget.onLongPressStart?.call(),
                    );
                  },
            onLongPressEnd: widget.onLongPressEnd == null
                ? null
                : (_) {
                    _repeatTimer?.cancel();
                    _repeatTimer = null;
                    widget.onLongPressEnd?.call();
                  },
            onLongPressMoveUpdate: (_) {},
            behavior: HitTestBehavior.opaque,
            child: child,
          ),
        ),
      ),
    );
  }
}
