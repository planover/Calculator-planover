/// 轻量日期格式化 —— **刻意不引入 `intl`**（架构 §T04 要点：日期格式自建）。
///
/// 为什么不用 intl：
/// 1. 只需要"历史列表时间戳"这一处展示，引入 intl 会连带拉进 4 万行 ICU 数据，
///    白白增加 APK 体积与初始化耗时；
/// 2. intl 的默认文案是英文，要达到"今天/昨天"的效果还得额外配本地化数据。
///
/// 输出规则（面向中文用户）：
/// - 今天 → `今天 HH:mm`
/// - 昨天 → `昨天 HH:mm`
/// - 本年 → `MM-DD HH:mm`
/// - 跨年 → `YYYY-MM-DD HH:mm`
library;

import '../models/region_format_config.dart';
import 'region_date_format.dart';

/// 把毫秒时间戳格式化成历史列表用的短串。
///
/// [now] 可注入以便测试；非法/为 0 的时间戳返回空串（历史里不该出现 0）。
String formatTimestamp(int ts, {DateTime? now}) {
  if (ts <= 0) {
    return '';
  }
  return formatDateTime(
    DateTime.fromMillisecondsSinceEpoch(ts),
    now: now,
  );
}

/// 格式化一个 [DateTime]。
String formatDateTime(DateTime dt, {DateTime? now}) {
  final DateTime base = now ?? DateTime.now();
  final String hhmm = '${_2(dt.hour)}:${_2(dt.minute)}';

  final DateTime dDay = DateTime(dt.year, dt.month, dt.day);
  final DateTime bDay = DateTime(base.year, base.month, base.day);
  final int diff = bDay.difference(dDay).inDays;

  if (diff == 0) {
    return '今天 $hhmm';
  }
  if (diff == 1) {
    return '昨天 $hhmm';
  }
  if (dt.year == base.year) {
    return '${_2(dt.month)}-${_2(dt.day)} $hhmm';
  }
  return '${dt.year}-${_2(dt.month)}-${_2(dt.day)} $hhmm';
}

/// 补零到两位。
String _2(int v) => v < 10 ? '0$v' : '$v';

// ── 区域格式化的历史时间戳（RF-T-06 / RF-D-07）────────────────────
//
// 上面 [formatTimestamp]/[formatDateTime] 是"相对文案（今天/昨天）"路径，
// 依赖自研语言包；下面两条按**区域格式**渲染（A2：时间/日期在 Dart 侧），
// 供历史条目使用 —— 区域格式决定短时间与短日期，与界面语言无关（A3）。

/// 按区域配置渲染历史条目的**短时间戳**（RF-T-06）。
///
/// 输出形如 `14:32`（24 制）或 `2:32 PM`（12 制，符号随区域）。
String formatRegionTime(int ts, RegionFormatConfig config) {
  if (ts <= 0) {
    return '';
  }
  return RegionDateFormatter.formatTime(
    DateTime.fromMillisecondsSinceEpoch(ts),
    config,
  );
}

/// 按区域配置渲染历史条目的**短日期**（RF-D-07）。
///
/// 输出形如 `2025/9/9`（zh-CN）/ `9/9/2025`（en-US）/ `09.09.2025`（de-DE，由模式串决定）。
String formatRegionDate(DateTime dt, RegionFormatConfig config) =>
    RegionDateFormatter.formatDate(dt, config);

/// 历史分组用的**日期键**（同一天归为一组，RF-D-07）。
///
/// 用 (year, month, day) 三元组拼成的稳定字符串，避免跨月/跨年误判。
String regionDateGroupKey(DateTime dt) =>
    '${dt.year}-${_2(dt.month)}-${_2(dt.day)}';

/// 按区域配置渲染历史条目的**完整时间戳**（短时间 + 短日期，RF-T-06 / RF-D-07）。
///
/// 形如 `14:32 · 2025/9/9`。非法/为 0 的时间戳返回空串。
String formatRegionTimestamp(int ts, RegionFormatConfig config) {
  if (ts <= 0) {
    return '';
  }
  final DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
  final String time = RegionDateFormatter.formatTime(dt, config);
  final String date = RegionDateFormatter.formatDate(dt, config);
  return '$time · $date';
}

