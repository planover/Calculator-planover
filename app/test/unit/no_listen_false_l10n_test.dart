/// UX-01 静态守护：`lib/**` 下**不得**存在"展示文案处用 `listen: false` 读取 `l10n`"。
///
/// 根因（架构 §3.1）：`Provider.of<LocaleController>(context, listen: false).l10n`
/// 在**展示文案**处取值 → 该 Widget **不订阅** `LocaleController`，语言切换后文案不刷新
/// （而多被 `const` 构造的元素也不会重建）。
///
/// 合法例外：`listen: false` 仅用于**触发 action**（如 `locale.setLocale(...)` /
/// 取 `locale.manualTag` 传给 `region.setRegion`），**不解引用 `.l10n`** → 不匹配本规则。
///
/// 铁律：本测试用 `dart:io` 扫描源码，须在 `app/` 包根目录运行（`flutter test` 的 cwd）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ 下不存在"展示文案处 listen:false 读 l10n"（UX-01）', () {
    // 允许 `context` 与 `listen : false` 之间有空白；`>` 与 `.` 之间允许换行/空白。
    final RegExp defect = RegExp(
      r'Provider\s*\.\s*of\s*<\s*LocaleController\s*>\s*\(\s*context\s*,'
      r'\s*listen\s*:\s*false\s*\)\s*\.\s*l10n',
    );

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
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (defect.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    // 防"空扫"假绿：确实扫到了 lib 下的 Dart 文件。
    expect(scanned, greaterThan(0), reason: '未扫描到任何 lib/**/*.dart');

    expect(
      offenders,
      isEmpty,
      reason: '发现展示文案处用 listen:false 读取 l10n（应改 listen:true）：\n'
          '${offenders.join('\n')}',
    );
  });
}
