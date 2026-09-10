/// 单位换算页（架构 §T05 要点 10 / PRD §4.4）。
///
/// 双向联动：改任一侧、另一侧立即更新，用 `_side` 标志防止回环（PRD ⑦ 双向实时联动）。
/// 类别页签来自 `engine.listUnits`；单位网格点击把单位设为"当前焦点侧"的源或目标；
/// 换算统一走 `engine.convert`（Dart 不做任何数值运算，约束 C8）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/unit_info.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';

/// 单位换算页。
class UnitConverterScreen extends StatefulWidget {
  /// 构造换算页。
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  late final List<CategoryInfo> _categories;
  late CategoryInfo _category;
  UnitInfo? _fromUnit;
  UnitInfo? _toUnit;
  int _side = 0; // 0 = from, 1 = to
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    _categories = calc.engine.listUnits();
    _category = _categories.isNotEmpty ? _categories.first : const CategoryInfo();
    _fromFocus.addListener(() {
      if (_fromFocus.hasFocus) {
        _side = 0;
      }
    });
    _toFocus.addListener(() {
      if (_toFocus.hasFocus) {
        _side = 1;
      }
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onFromChanged(String v) {
    if (_programmatic) {
      return;
    }
    _side = 0;
    _recompute();
  }

  void _onToChanged(String v) {
    if (_programmatic) {
      return;
    }
    _side = 1;
    _recompute();
  }

  void _pickUnit(UnitInfo u) {
    if (_side == 0) {
      _fromUnit = u;
    } else {
      _toUnit = u;
    }
    _recompute();
  }

  void _recompute() {
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: false);
    if (_fromUnit == null || _toUnit == null) {
      return;
    }
    try {
      if (_side == 0 && _fromCtrl.text.isNotEmpty) {
        final r = calc.engine.convert(
          value: _fromCtrl.text,
          from: _fromUnit!.id,
          to: _toUnit!.id,
        );
        _programmatic = true;
        _toCtrl.text = r.outputDisplay;
        _programmatic = false;
      } else if (_side == 1 && _toCtrl.text.isNotEmpty) {
        final r = calc.engine.convert(
          value: _toCtrl.text,
          from: _toUnit!.id,
          to: _fromUnit!.id,
        );
        _programmatic = true;
        _fromCtrl.text = r.outputDisplay;
        _programmatic = false;
      }
    } on Object {
      // 非法输入 / 不兼容单位：保持另一侧不变，不崩。
    }
  }

  void _swap() {
    final UnitInfo? tmp = _fromUnit;
    _fromUnit = _toUnit;
    _toUnit = tmp;
    final String tmpText = _fromCtrl.text;
    _fromCtrl.text = _toCtrl.text;
    _toCtrl.text = tmpText;
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;

    if (_categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tr('ui.unitConverter.title'))),
        body: Center(child: Text(l10n.tr('ui.unitConverter.placeholder'))),
      );
    }

    final List<UnitInfo> units = _category.units;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('ui.unitConverter.title'))),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Tokens.padMd),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ValueField(
                    controller: _fromCtrl,
                    focus: _fromFocus,
                    unit: _fromUnit,
                    onChanged: _onFromChanged,
                    active: _side == 0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l10n.tr('ui.unitConverter.swap'),
                  onPressed: _swap,
                ),
                Expanded(
                  child: _ValueField(
                    controller: _toCtrl,
                    focus: _toFocus,
                    unit: _toUnit,
                    onChanged: _onToChanged,
                    active: _side == 1,
                  ),
                ),
              ],
            ),
          ),
          DefaultTabController(
            length: _categories.length,
            child: Expanded(
              child: Column(
                children: <Widget>[
                  TabBar(
                    isScrollable: true,
                    onTap: (int i) =>
                        setState(() => _category = _categories[i]),
                    tabs: _categories
                        .map<Widget>((CategoryInfo c) => Tab(text: c.name))
                        .toList(growable: false),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      padding: const EdgeInsets.all(Tokens.padMd),
                      mainAxisSpacing: Tokens.padXs,
                      crossAxisSpacing: Tokens.padXs,
                      childAspectRatio: 2.4,
                      children: units
                          .map(
                            (UnitInfo u) => ChoiceChip(
                              label: Text(
                                '${u.symbol}  ${l10n.unitName(u.id, u.name)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: _fromUnit == u || _toUnit == u,
                              onSelected: (_) => _pickUnit(u),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueField extends StatelessWidget {
  const _ValueField({
    required this.controller,
    required this.focus,
    required this.unit,
    required this.onChanged,
    required this.active,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final UnitInfo? unit;
  final void Function(String) onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Tokens.padSm),
      decoration: BoxDecoration(
        border: Border.all(
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            unit?.symbol ?? '—',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          TextField(
            controller: controller,
            focusNode: focus,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: true),
            onChanged: onChanged,
            decoration: const InputDecoration.collapsed(hintText: ''),
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
