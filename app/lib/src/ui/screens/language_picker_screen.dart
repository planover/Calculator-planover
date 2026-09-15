/// 全屏语言选择页面（架构 §3.2.3 / Q3 用户裁决：**路由页面，非弹层**）。
///
/// 为什么是独立全屏路由页而非底部弹层（IC-14）：
/// ① 用户已拍板；② 216 条清单在弹层里必然是窄条，全屏页可**双列 + 居中约束**；
/// ③ 搜索框固定在 `AppBar.bottom`，任意滚动位置都能改查询（可用性优先）。
///
/// 形态对照本项目既有先例 `ui/screens/unit_converter_screen.dart`（同为
/// "页面 + `MaterialPageRoute`"模式）。
///
/// 关键约束（LG-03 不缩减 + UX-02 不卡死）：
/// - 清单仍列全部 216 项，**禁止**"先把 216 项 `map` 成 Widget 列表"；
/// - 列表用 `ListView.builder` / `GridView.builder` 懒加载，首屏构建项 ≤ 30；
/// - 可搜索（匹配 `native`/`english`/`tag`，大小写不敏感、子串匹配）。
///
/// ⚠️ T01 边界：**完成度 %** 与"未校订"标记属 UX-09（T04 落地，见架构 §3.4），
/// 本批 [LanguageOption] 已预留 `completionPct` / `humanReviewed` 字段，但**不注入数据、
/// 不展示**（否则每项会显示误导性的 `0%`）。T04 会在此文件补上展示。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/locale_registry.dart';
import '../../state/locale_controller.dart';
import '../../theme/tokens.dart';

/// 一档语言的展示模型（含完成度，服务于 UX-09）。**与页面解耦，可独立单测**。
class LanguageOption {
  /// 构造一档语言。
  const LanguageOption({
    required this.tag,
    required this.native,
    required this.english,
    this.rtl = false,
    this.completionPct = 0,
    this.humanReviewed = false,
  });

  /// BCP-47 标签（与 `AppLocale.tag` 同形）。
  final String tag;

  /// 母语名称（列表主标题）。
  final String native;

  /// 英文名称（便于检索）。
  final String english;

  /// 是否从右向左书写。
  final bool rtl;

  /// 完成度 0..100（UX-09；T01 不注入）。
  final int completionPct;

  /// 是否有人工校订包（UX-09；T01 不注入）。
  final bool humanReviewed;

  /// 由语言清单条目构造（T01 只带静态字段；T04 补完成度）。
  factory LanguageOption.fromAppLocale(AppLocale a) => LanguageOption(
        tag: a.tag,
        native: a.native,
        english: a.english,
        rtl: a.rtl,
      );
}

/// 选择结果（区分"取消"与"选跟随系统"）。
sealed class LanguagePickResult {
  /// 基类构造（密封：子类须在本文件内）。
  const LanguagePickResult();
}

/// 选中"跟随系统"。
class FollowSystem extends LanguagePickResult {
  /// 构造"跟随系统"结果。
  const FollowSystem();
}

/// 选中某语言。
class PickedTag extends LanguagePickResult {
  /// 构造"选中某标签"结果。
  const PickedTag(this.tag);

  /// 选中的 BCP-47 标签。
  final String tag;
}

/// 全屏语言选择页面（Q3 用户裁决：路由页面，非弹层）。
class LanguagePickerScreen extends StatefulWidget {
  /// 构造语言选择页。
  const LanguagePickerScreen({
    super.key,
    required this.options,
    this.currentTag,
  });

  /// 全量 **216** 条（LG-03：清单不缩减；**不得**预先 map 成 Widget）。
  final List<LanguageOption> options;

  /// 当前生效语言标签；`null` = 跟随系统。
  final String? currentTag;

  /// 从语言清单构造全量条目（供设置页与测试复用；**懒加载在渲染期**）。
  static List<LanguageOption> registryOptions() => LocaleRegistry.supported
      .map<LanguageOption>(LanguageOption.fromAppLocale)
      .toList(growable: false);

  /// 以路由方式打开，返回 [LanguagePickResult?]
  /// （`null` = 用户取消/返回，**不改变当前语言**）。
  static Future<LanguagePickResult?> show(BuildContext context) {
    final LocaleController locale =
        Provider.of<LocaleController>(context, listen: false);
    return Navigator.of(context).push<LanguagePickResult>(
      MaterialPageRoute<LanguagePickResult>(
        builder: (_) => LanguagePickerScreen(
          options: registryOptions(),
          currentTag: locale.manualTag,
        ),
      ),
    );
  }

  @override
  State<LanguagePickerScreen> createState() => _LanguagePickerScreenState();
}

class _LanguagePickerScreenState extends State<LanguagePickerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 过滤后的条目（大小写不敏感、子串匹配 `native`/`english`/`tag`）。
  List<LanguageOption> get _filtered {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where(
          (LanguageOption o) =>
              o.native.toLowerCase().contains(q) ||
              o.english.toLowerCase().contains(q) ||
              o.tag.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n =
        Provider.of<LocaleController>(context, listen: true).l10n;
    final List<LanguageOption> options = _filtered;

    // RTL 兼容（§3.2.3）：页面根显式注入方向；内边距一律 start/end。
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tr('ui.settings.language')),
          // 搜索框固定在 AppBar.bottom：不随列表滚动（长列表可用性优先）。
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Tokens.padMd,
                0,
                Tokens.padMd,
                Tokens.padSm,
              ),
              child: TextField(
                key: const Key('languagePickerSearch'),
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (String v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.tr('ui.settings.language'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
        // 平板/大屏：主内容居中约束（对照 §3.2.3「双列 + maxContentWidth 居中」）。
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // 宽屏双列；窄屏单列。两者都是懒加载 builder。
                if (constraints.maxWidth >= 600) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(Tokens.padMd),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 64,
                    ),
                    itemCount: options.length + 1,
                    itemBuilder: (BuildContext c, int i) => i == 0
                        ? _autoTile(l10n)
                        : _langTile(l10n, options[i - 1]),
                  );
                }
                return ListView.builder(
                  itemCount: options.length + 1,
                  itemBuilder: (BuildContext c, int i) =>
                      i == 0 ? _autoTile(l10n) : _langTile(l10n, options[i - 1]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// "跟随系统"项（固定置顶）。
  Widget _autoTile(AppLocalizations l10n) => ListTile(
        key: const Key('lang_auto'),
        leading: const Icon(Icons.brightness_auto),
        title: Text(l10n.tr('ui.settings.languageAuto')),
        selected: widget.currentTag == null,
        onTap: () => Navigator.of(context).pop(const FollowSystem()),
      );

  /// 一档语言项（T04 在此补 `completionPct` / "未校订"标记）。
  Widget _langTile(AppLocalizations l10n, LanguageOption o) => ListTile(
        key: Key('lang_${o.tag}'),
        title: Text('${o.native}  (${o.english})'),
        selected: widget.currentTag == o.tag,
        onTap: () => Navigator.of(context).pop(PickedTag(o.tag)),
      );
}
