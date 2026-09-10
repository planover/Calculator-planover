/// 入口占位 —— **T05 会整体替换**本文件。
///
/// 为什么先放一个占位：架构 §T01 的验收条件要求 `flutter analyze` 有 `lib/` 可分析，
/// 空目录会让 CI 直接红。这里只做最小可编译实现，不承载任何业务逻辑。
///
/// 真正的入口（T05）会：`ensureInitialized` → 构造 `NativeEngine` →
/// `MultiProvider` 注入 Settings / History / Calculator 三个控制器 → 启动 App。
library;

import 'package:flutter/material.dart';

/// 应用入口。
void main() {
  runApp(const PlaceholderApp());
}

/// 占位应用。
class PlaceholderApp extends StatelessWidget {
  /// 构造占位应用。
  const PlaceholderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator-planover',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const Scaffold(
        body: Center(child: Text('Calculator-planover — UI 层 T05 落地中')),
      ),
    );
  }
}
