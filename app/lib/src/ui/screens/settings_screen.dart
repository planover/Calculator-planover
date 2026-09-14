/// 设置页（架构 §T05 要点 9 / PRD §4.3 / §5 I3 / §13 Dart 部分）。
///
/// 分组：
/// - 外观：主题（≥16 固定主题 + 跟随系统）、区域格式（与语言解耦，LC-01）、语言；
/// - 计算：角度（含 Turns，UI-22）、位宽、−3²=−9 说明；
/// - 显示格式：记数法（含 Engineering，CP-08）、精度模式/精度、分数、千位分隔、
///   提交方式（calculate-on-fly / 手动，UI-13）；
/// - 关于：版本、引擎、记忆寄存器与 `ans` 区别说明（CP-17）、复数不支持说明（CP-19）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/locale_registry.dart';
import '../../models/eval_settings.dart';
import '../../models/submit_mode.dart';
import '../../state/calculator_controller.dart';
import '../../state/locale_controller.dart';
import '../../state/region_format_controller.dart';
import '../../state/settings_controller.dart';
import '../../storage/settings_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../l10n/region_registry.dart';

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
            const _ThemeRow(),
            const _RegionRow(),
            _LanguageRow(),
          ]),
          _Section(title: l10n.tr('ui.settings.calculation'), children: <Widget>[
            const _AngleRow(),
            const _WordSizeRow(),
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
            children: const <Widget>[
              _NotationRow(),
              _PrecisionModeRow(),
              _PrecisionRow(),
              _FractionRow(),
              _GroupingRow(),
              _SubmitRow(),
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
            const _AnsVsMemoryCard(),
            const _ComplexHelpCard(),
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

/// 主题选择（下拉，覆盖全部 ≥16 固定主题 + 跟随系统，TH-07/TH-08）。
class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.theme')),
      subtitle: DropdownButton<AppThemeMode>(
        isExpanded: true,
        value: settings.themeMode,
        items: AppThemeMode.values
            .map(
              (AppThemeMode m) => DropdownMenuItem<AppThemeMode>(
                value: m,
                child: Text(l10n.tr(themeNameKey[m]!)),
              ),
            )
            .toList(growable: false),
        onChanged: (AppThemeMode? m) {
          if (m != null) {
            settings.setThemeMode(m);
          }
        },
      ),
    );
  }
}

/// 区域格式选择（与语言解耦，LC-01）。
class _RegionRow extends StatelessWidget {
  const _RegionRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final RegionFormatController region =
        Provider.of<RegionFormatController>(context, listen: true);
    final LocaleController locale =
        Provider.of<LocaleController>(context, listen: false);
    return ListTile(
      title: Text(l10n.tr('ui.settings.region')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButton<String?>(
            isExpanded: true,
            value: region.isAuto ? null : region.regionTag,
            items: RegionRegistry.options
                .map(
                  (RegionFormat? r) => DropdownMenuItem<String?>(
                    value: r?.tag,
                    child: Text(r == null
                        ? l10n.tr('ui.settings.regionAuto')
                        : '${r.native}  (${r.english})'),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? tag) => region.setRegion(tag),
          ),
          TextButton(
            onPressed: () => region.setRegion(locale.manualTag),
            child: Text(l10n.tr('ui.settings.regionSyncLanguage')),
          ),
        ],
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
  const _AngleRow();
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
          ButtonSegment<AngleMode>(
            value: AngleMode.turns,
            label: Text('TURNS'),
          ),
        ],
        selected: <AngleMode>{calc.angleMode},
        onSelectionChanged: (Set<AngleMode> s) => calc.setAngleMode(s.first),
      ),
    );
  }
}

class _WordSizeRow extends StatelessWidget {
  const _WordSizeRow();
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
  const _NotationRow();
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
          ButtonSegment<Notation>(
            value: Notation.engineering,
            label: Text(l10n.tr('ui.settings.notationEngineering')),
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
  const _PrecisionModeRow();
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
  const _PrecisionRow();
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
  const _FractionRow();
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
  const _GroupingRow();
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

/// 提交方式：calculate-on-fly（自动）/ 手动（UI-13）。
class _SubmitRow extends StatelessWidget {
  const _SubmitRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    return ListTile(
      title: Text(l10n.tr('ui.settings.submitMode')),
      subtitle: SegmentedButton<SubmitMode>(
        segments: <ButtonSegment<SubmitMode>>[
          ButtonSegment<SubmitMode>(
            value: SubmitMode.auto,
            label: Text(l10n.tr('ui.settings.submitAuto')),
          ),
          ButtonSegment<SubmitMode>(
            value: SubmitMode.manual,
            label: Text(l10n.tr('ui.settings.submitManual')),
          ),
        ],
        selected: <SubmitMode>{settings.submitMode},
        onSelectionChanged: (Set<SubmitMode> s) =>
            settings.setSubmitMode(s.first),
      ),
    );
  }
}

/// 记忆寄存器与 `ans` 的区别说明（CP-17）。
class _AnsVsMemoryCard extends StatelessWidget {
  const _AnsVsMemoryCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.padMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.tr('ui.help.ansVsMemoryTitle'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Tokens.padSm),
            Text(l10n.tr('ui.help.ansVsMemoryBody')),
          ],
        ),
      ),
    );
  }
}

/// 不支持复数的用户告知（CP-19，已由 P2 提升为 P1 本期交付）。
class _ComplexHelpCard extends StatelessWidget {
  const _ComplexHelpCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: false).l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.padMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.tr('ui.help.complexTitle'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Tokens.padSm),
            Text(l10n.tr('ui.help.complexBody')),
          ],
        ),
      ),
    );
  }
}
