/// UX-01 静态守护：`lib/**` 下**不得**存在"展示文案处用 `listen: false` 读取 `l10n`"。
///
/// 根因（架构 §3.1）：`Provider.of<LocaleController>(context, listen: false).l10n`
/// 在**展示文案**处取值 → 该 Widget **不订阅** `LocaleController`，语言切换后文案不刷新
/// （而多被 `const` 构造的元素也不会重建）。
///
/// 合法例外：`listen: false` / `context.read` 仅用于**触发 action**
/// （如 `locale.setLocale(...)` / 取 `locale.manualTag` 传给 `region.setRegion`），
/// **不解引用 `.l10n`** → 不匹配本规则。
///
/// 覆盖的缺陷形态（对**整份文件内容**做多行正则，`\s` 含换行，跨行亦可捕获）：
///   ① `Provider.of<LocaleController>(context, listen: false).l10n`
///      —— 容忍 `context` / `listen : false` 之间任意空白（含换行），
///         以及 `false` 之后的**尾逗号** `listen: false,)`；
///   ② `context.read<LocaleController>().l10n`
///      —— `Provider.of(..., listen: false)` 的等价扩展写法（`read` 即不订阅）。
///
/// ⚠️ **本断言的能力边界（以下形态明确不覆盖，勿误解为已守住）**：
///   - **中间变量形态**：`final c = Provider.of<LocaleController>(context,
///     listen: false);` …（后续）`c.l10n` —— 正则无法跨越"先存 Controller、再取
///     `.l10n`"的数据流。此类**需人工评审**或改用 AST 级检查。
///   - `context.select` **不**列为缺陷：`context.select` 会**订阅**（值变化即重建），
///     语义上等价 `listen: true`，故**故意不匹配**本规则（避免误报）。
///
/// 铁律：本测试用 `dart:io` 扫描源码，须在 `app/` 包根目录运行（`flutter test` 的 cwd）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ 下不存在"展示文案处 listen:false / context.read 读 l10n"（UX-01）', () {
    // 形态①：`Provider.of<LocaleController>(context, listen: false).l10n`
    //   `context` 与 `listen:false` 间任意空白（含换行）；`false` 后容忍尾逗号；
    //   `)` 与 `.l10n` 间仅允许空白。
    final RegExp providerOfDefect = RegExp(
      r'Provider\s*\.\s*of\s*<\s*LocaleController\s*>\s*\(\s*context\s*,'
      r'\s*listen\s*:\s*false\s*,?\s*\)\s*\.\s*l10n',
      multiLine: true,
    );

    // 形态②：`context.read<LocaleController>().l10n`（等价 listen:false）。
    final RegExp readDefect = RegExp(
      r'context\s*\.\s*read\s*<\s*LocaleController\s*>\s*\(\s*\)\s*\.\s*l10n',
      multiLine: true,
    );

    final List<RegExp> defects = <RegExp>[providerOfDefect, readDefect];

    final Directory libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: '测试须在 app/ 包根目录运行（当前 cwd=${Directory.current.path}）',
    );

    final List<String> offenders = <String>[];
    int scanned = 0;
    for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      scanned++;
      final String content = entity.readAsStringSync();
      for (final RegExp defect in defects) {
        for (final RegExpMatch m in defect.allMatches(content)) {
          final int line =
              '\n'.allMatches(content.substring(0, m.start)).length + 1;
          offenders.add(
            '${entity.path}:$line: ${m.group(0)!.replaceAll(RegExp(r"\s+"), " ")}',
          );
        }
      }
    }

    // 防"空扫"假绿：确实扫到了 lib 下的 Dart 文件。
    expect(scanned, greaterThan(0), reason: '未扫描到任何 lib/**/*.dart');

    expect(
      offenders,
      isEmpty,
      reason: '发现展示文案处用 listen:false / context.read 读取 l10n'
          '（应改 listen:true / context.watch）：\n${offenders.join('\n')}',
    );
  });
}
