/// 设置页（架构 §T05 要点 9 / PRD §4.3）。
///
/// 分组：外观（主题 / 语言）、计算（角度 / 位宽 / −3²=−9 说明）、显示格式
/// （记数法 / 精度模式 / 精度 / 分数 / 千位分隔）、关于（版本 / 引擎）。
/// 角度与位宽经 [CalculatorController] 下发引擎；其余经 [SettingsController] 持久化。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/locale_registry.dart';
import '../../models/eval_settings.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../state/settings_controller.dart';
import '../../storage/settings_store.dart';
import '../../theme/tokens.dart';

/// 设置页。
class SettingsScreen extends StatelessWidget {
  /// 构造设置页。
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tr('ui.settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.padMd),
        children: <Widget>[
          _Section(title: l10n.tr('ui.settings.appearance'), children: <Widget>[
            _ThemeRow(),
            _LanguageRow(),
          ]),
          _Section(title: l10n.tr('ui.settings.calculation'), children: <Widget>[
            _AngleRow(),
            _WordSizeRow(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.padSm),
              child: Text(
                l10n.tr('ui.settings.negPowNote'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ]),
          _Section(
            title: l10n.tr('ui.settings.displayFormat'),
            children: <Widget>[
              _NotationRow(),
              _PrecisionModeRow(),
              _PrecisionRow(),
              _FractionRow(),
              _GroupingRow(),
            ],
          ),
          _Section(title: l10n.tr('ui.settings.about'), children: <Widget>[
            ListTile(
              title: Text(l10n.tr('ui.settings.version')),
              subtitle: const Text('1.0.0 (build 1)'),
            ),
            ListTile(
              title: Text(l10n.tr('ui.settings.engine')),
            ),
          ]),
        ],
      ),
    );
  }
}

/// 分组卡片。
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.padMd),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.padMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.padSm),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.theme')),
      subtitle: SegmentedButton<AppThemeMode>(
        segments: <ButtonSegment<AppThemeMode>>[
          ButtonSegment<AppThemeMode>(
            value: AppThemeMode.system,
            label: Text(l10n.tr('ui.settings.themeSystem')),
          ),
          ButtonSegment<AppThemeMode>(
            value: AppThemeMode.light,
            label: Text(l10n.tr('ui.settings.themeLight')),
          ),
          ButtonSegment<AppThemeMode>(
            value: AppThemeMode.dark,
            label: Text(l10n.tr('ui.settings.themeDark')),
          ),
        ],
        selected: <AppThemeMode>{settings.themeMode},
        onSelectionChanged: (Set<AppThemeMode> s) =>
            settings.setThemeMode(s.first),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    final LocaleController locale =
        Provider.of<LocaleController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.language')),
      subtitle: DropdownButton<String?>(
        isExpanded: true,
        value: locale.isAuto ? null : locale.manualTag,
        items: <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l10n.tr('ui.settings.languageAuto')),
          ),
          for (final AppLocale l in LocaleRegistry.supported)
            DropdownMenuItem<String?>(
              value: l.tag,
              child: Text('${l.native}  (${l.english})'),
            ),
        ],
        onChanged: (String? tag) => locale.setLocale(tag),
      ),
    );
  }
}

class _AngleRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.angleMode')),
      subtitle: SegmentedButton<AngleMode>(
        segments: const <ButtonSegment<AngleMode>>[
          ButtonSegment<AngleMode>(
            value: AngleMode.deg,
            label: Text('DEG'),
          ),
          ButtonSegment<AngleMode>(
            value: AngleMode.rad,
            label: Text('RAD'),
          ),
          ButtonSegment<AngleMode>(
            value: AngleMode.grad,
            label: Text('GRAD'),
          ),
        ],
        selected: <AngleMode>{calc.angleMode},
        onSelectionChanged: (Set<AngleMode> s) => calc.setAngleMode(s.first),
      ),
    );
  }
}

class _WordSizeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final CalculatorController calc =
        Provider.of<CalculatorController>(context, listen: true);
    final int ws = calc.settingsWordSize;
    return ListTile(
      title: Text(l10n.tr('ui.settings.wordSize')),
      subtitle: SegmentedButton<int>(
        segments: validWordSizes
            .map(
              (int w) => ButtonSegment<int>(
                value: w,
                label: Text('$w'),
              ),
            )
            .toList(growable: false),
        selected: <int>{ws},
        onSelectionChanged: (Set<int> s) => calc.setWordSize(s.first),
      ),
    );
  }
}

class _NotationRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.notation')),
      subtitle: SegmentedButton<Notation>(
        segments: <ButtonSegment<Notation>>[
          ButtonSegment<Notation>(
            value: Notation.auto,
            label: Text(l10n.tr('ui.settings.notationAuto')),
          ),
          ButtonSegment<Notation>(
            value: Notation.scientific,
            label: Text(l10n.tr('ui.settings.notationScientific')),
          ),
          ButtonSegment<Notation>(
            value: Notation.fixed,
            label: Text(l10n.tr('ui.settings.notationFixed')),
          ),
        ],
        selected: <Notation>{settings.settings.notation},
        onSelectionChanged: (Set<Notation> s) =>
            settings.setNotation(s.first),
      ),
    );
  }
}

class _PrecisionModeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.precisionMode')),
      subtitle: SegmentedButton<PrecisionMode>(
        segments: <ButtonSegment<PrecisionMode>>[
          ButtonSegment<PrecisionMode>(
            value: PrecisionMode.significant,
            label: Text(l10n.tr('ui.settings.precisionSignificant')),
          ),
          ButtonSegment<PrecisionMode>(
            value: PrecisionMode.decimalPlaces,
            label: Text(l10n.tr('ui.settings.precisionDecimalPlaces')),
          ),
        ],
        selected: <PrecisionMode>{settings.settings.precisionMode},
        onSelectionChanged: (Set<PrecisionMode> s) =>
            settings.setPrecisionMode(s.first),
      ),
    );
  }
}

class _PrecisionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    final int p = settings.settings.precision;
    return ListTile(
      title: Text(l10n.tr('ui.settings.precision')),
      subtitle: Slider(
        value: p.toDouble(),
        min: minPrecision.toDouble(),
        max: maxPrecision.toDouble(),
        divisions: maxPrecision - minPrecision,
        label: '$p',
        onChanged: (double v) => settings.setPrecision(v.round()),
      ),
    );
  }
}

class _FractionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.fraction')),
      subtitle: SegmentedButton<FractionMode>(
        segments: <ButtonSegment<FractionMode>>[
          ButtonSegment<FractionMode>(
            value: FractionMode.off,
            label: Text(l10n.tr('ui.settings.fractionOff')),
          ),
          ButtonSegment<FractionMode>(
            value: FractionMode.improper,
            label: Text(l10n.tr('ui.settings.fractionImproper')),
          ),
          ButtonSegment<FractionMode>(
            value: FractionMode.mixed,
            label: Text(l10n.tr('ui.settings.fractionMixed')),
          ),
        ],
        selected: <FractionMode>{settings.settings.fractionMode},
        onSelectionChanged: (Set<FractionMode> s) =>
            settings.setFractionMode(s.first),
      ),
    );
  }
}

class _GroupingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return SwitchListTile(
      title: Text(l10n.tr('ui.settings.grouping')),
      value: settings.settings.grouping,
      onChanged: (bool v) => settings.setGrouping(v),
    );
  }
}
