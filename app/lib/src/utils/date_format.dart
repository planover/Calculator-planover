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
