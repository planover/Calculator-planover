/// UX-08 应用图标资源守护（`[C]` 类）：结构 / 安全区 / 可辨识性。
///
/// 背景：`ic_launcher_foreground.xml` 原为一个 431 字节的手写矢量（白色粗 "E"），
/// 无自适应分层、无单色层、且几何**未按安全区设计**。本测试把"图标合规"变成可断言项，
/// 防止后续改动悄悄破坏安全区或丢掉层级。
///
/// 三条断言来源（增量 PRD v3 §5.7 + 架构 v3 §5）：
///   1. **自适应结构**：`mipmap-anydpi-v26/ic_launcher.xml` 必须含
///      `background` / `foreground` / `monochrome` 三层（Android 13+ 主题图标要 monochrome）。
///   2. **圆形安全区**：Google 自适应图标规范中，始终可见的是**居中直径 66dp 的圆**
///      （半径 33dp）。本测试解析前景 `pathData` 的坐标，断言其包围盒四角到画布中心
///      (54,54) 的距离 ≤ 33dp，否则圆形遮罩（如 Pixel 启动器）会裁掉四角。
///   3. **小尺寸可辨识**：48dp 显示下最小笔画 ≥ 2dp ⇒ 108dp 源稿上 ≥ 4.5dp。
///      本测试通过断言"前景包围盒不触边（留出 ≥18dp 余量）"与"存在 evenOdd 挖空"间接守护；
///      具体笔画宽度由 `tools/generate_app_icon.py` 的几何自检负责（那里有精确数值）。
///
/// ⚠️ **路径约定**：`flutter test` 的 cwd 是包根 `app/`，故资源相对路径为
/// `android/app/src/main/res/...`。为避免路径写错导致难以定位的失败，
/// 这里用**多候选探测**并在全部失败时给出清晰报错（曾有过相对路径少一层、
/// 级联出十余个"未定义"错误的教训）。
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// 资源目录候选（按优先级）。首个存在者胜出。
const List<String> _resCandidates = <String>[
  'android/app/src/main/res', // flutter test cwd = app/（正解）
  '../app/android/app/src/main/res', // 若从仓库根运行
  'app/android/app/src/main/res', // 若从仓库根运行（另一形式）
];

/// 定位资源目录；全部候选都不存在时明确失败。
Directory _resDir() {
  for (final String c in _resCandidates) {
    final Directory d = Directory(c);
    if (d.existsSync()) {
      return d;
    }
  }
  fail('未找到 Android 资源目录。已尝试: ${_resCandidates.join(" | ")}'
      '（当前 cwd=${Directory.current.path}）');
}

String _read(Directory res, String rel) {
  final File f = File('${res.path}/$rel');
  if (!f.existsSync()) {
    fail('资源缺失: ${f.path}');
  }
  return f.readAsStringSync();
}

/// 从前景 `pathData` 中抽取所有**坐标点**，返回 (xs, ys)。
///
/// 只解析本仓库生成器实际产出的命令形态（`M x,y` / `H x` / `V y` / `A rx,ry 0 0 1 x,y`），
/// 以避免把半径值（如 1.2）误当坐标计入包围盒。若某天换了路径语法，本函数会返回偏小的
/// 集合——故额外用 `assert` 风格的下界检查（见用例内）保证"解析结果非空且合理"。
({List<double> xs, List<double> ys}) _extractPoints(String pathData) {
  final List<double> xs = <double>[];
  final List<double> ys = <double>[];

  void grabAll(RegExp re, int xi, int yi, {int? only}) {
    for (final RegExpMatch m in re.allMatches(pathData)) {
      if (only == 0) {
        xs.add(double.parse(m.group(xi)!));
      } else if (only == 1) {
        ys.add(double.parse(m.group(yi)!));
      } else {
        xs.add(double.parse(m.group(xi)!));
        ys.add(double.parse(m.group(yi)!));
      }
    }
  }

  grabAll(RegExp(r'M\s*([\d.]+)\s*,\s*([\d.]+)'), 1, 2);
  grabAll(RegExp(r'H\s*([\d.]+)'), 1, 2, only: 0);
  // ⚠️ `H` / `V` 各只有 1 个捕获组，故 yi 必须传 1（早期传 2 导致
  //    `RangeError: Value not in range: 2`，CI 实测）。
  grabAll(RegExp(r'V\s*([\d.]+)'), 1, 1, only: 1);
  grabAll(RegExp(r'A\s*[\d.]+\s*,\s*[\d.]+\s+0\s+0\s+1\s+([\d.]+)\s*,\s*([\d.]+)'), 1, 2);
  return (xs: xs, ys: ys);
}

void main() {
  late Directory res;

  setUpAll(() {
    res = _resDir();
  });

  test('自适应图标含 background / foreground / monochrome 三层（UX-08.1）', () {
    final String xml = _read(res, 'mipmap-anydpi-v26/ic_launcher.xml');
    expect(xml.contains('<adaptive-icon'), isTrue,
        reason: 'ic_launcher.xml 必须是 <adaptive-icon>');
    for (final String layer in <String>['background', 'foreground', 'monochrome']) {
      expect(xml.contains('<$layer'), isTrue,
          reason: '缺少 $layer 层（monochrome 是 Android 13+ 主题图标所必需）');
    }
    // 三层必须指向存在的 drawable，避免"引用了不存在的资源"这类仅在打包时才暴露的问题。
    for (final String d in <String>[
      'ic_launcher_background',
      'ic_launcher_foreground',
      'ic_launcher_monochrome',
    ]) {
      expect(xml.contains('@drawable/$d'), isTrue, reason: '未引用 @drawable/$d');
      expect(File('${res.path}/drawable/$d.xml').existsSync(), isTrue,
          reason: 'drawable/$d.xml 不存在');
    }
  });

  test('前景几何落在 66dp 圆形安全区内（UX-08.2）', () {
    final String xml = _read(res, 'drawable/ic_launcher_foreground.xml');
    expect(xml.contains('android:viewportWidth="108"'), isTrue);
    expect(xml.contains('android:viewportHeight="108"'), isTrue);
    // 挖空（显示屏 + 键位）依赖 evenOdd，缺了它就变成实心块。
    expect(xml.contains('android:fillType="evenOdd"'), isTrue,
        reason: '前景必须使用 evenOdd 才能挖出显示屏与键位');

    final RegExpMatch? pd = RegExp(r'android:pathData="([^"]+)"').firstMatch(xml);
    expect(pd, isNotNull, reason: '未找到 pathData');
    final ({List<double> xs, List<double> ys}) pts = _extractPoints(pd!.group(1)!);

    // 解析结果合理性：非空，且不应包含半径之类的小数值拉低包围盒。
    expect(pts.xs.length, greaterThanOrEqualTo(4), reason: '坐标解析结果过少');
    expect(pts.ys.length, greaterThanOrEqualTo(4), reason: '坐标解析结果过少');

    final double x0 = pts.xs.reduce((a, b) => a < b ? a : b);
    final double x1 = pts.xs.reduce((a, b) => a > b ? a : b);
    final double y0 = pts.ys.reduce((a, b) => a < b ? a : b);
    final double y1 = pts.ys.reduce((a, b) => a > b ? a : b);

    // 1) 不触边：72dp 可见区为 [18, 90]。
    expect(x0, greaterThanOrEqualTo(18.0), reason: '前景左边界越出可见区');
    expect(y0, greaterThanOrEqualTo(18.0), reason: '前景上边界越出可见区');
    expect(x1, lessThanOrEqualTo(90.0), reason: '前景右边界越出可见区');
    expect(y1, lessThanOrEqualTo(90.0), reason: '前景下边界越出可见区');

    // 2) 66dp 圆形安全区：四角到中心 (54,54) 距离 ≤ 33dp。
    const double cx = 54.0, cy = 54.0, safeR = 33.0;
    final List<List<double>> corners = <List<double>>[
      <double>[x0, y0],
      <double>[x1, y0],
      <double>[x0, y1],
      <double>[x1, y1],
    ];
    for (final List<double> c in corners) {
      final double d = _dist(c[0], c[1], cx, cy);
      expect(d, lessThanOrEqualTo(safeR),
          reason: '前景角 (${c[0]}, ${c[1]}) 到中心 ${d.toStringAsFixed(1)}dp '
              '超出 ${safeR}dp 安全圆 —— 圆形遮罩会裁掉该角');
    }
  });

  test('背景层铺满画布且为渐变（UX-08.3）', () {
    final String xml = _read(res, 'drawable/ic_launcher_background.xml');
    expect(xml.contains('android:viewportWidth="108"'), isTrue);
    expect(xml.contains('<gradient'), isTrue, reason: '背景应为渐变');
    expect(xml.contains('offset="0"'), isTrue);
    expect(xml.contains('offset="1"'), isTrue);
    // 满铺画布，否则遮罩边缘会露底。
    expect(RegExp(r'M0,0\s+H108\s+V108\s+H0\s+Z').hasMatch(xml), isTrue,
        reason: '背景路径须满铺 108×108 画布');
  });

  test('单色层与前景同形（UX-08.4）', () {
    String pathOf(String xml) =>
        RegExp(r'android:pathData="([^"]+)"').firstMatch(xml)!.group(1)!;
    final String fg = pathOf(_read(res, 'drawable/ic_launcher_foreground.xml'));
    final String mono = pathOf(_read(res, 'drawable/ic_launcher_monochrome.xml'));
    expect(mono, fg,
        reason: '单色层须与前景同形（否则主题图标与常规图标形状不一致）');
  });
}

double _dist(double ax, double ay, double bx, double by) =>
    math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2)).toDouble();
