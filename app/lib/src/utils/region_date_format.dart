/// 区域时间/日期格式化 —— **纯 Dart**，刻意不依赖 `Intl.defaultLocale`（架构 A2/A3）。
///
/// 为什么自研而不用 `intl.DateFormat`：
/// 1. A3 铁律：语言与区域彻底解耦。`intl` 的 `DateFormat` 依赖 `Intl.defaultLocale`
///    或显式传入的 locale —— 一旦用了它，月份/星期名就会跟着**界面语言**走，
///    正是我们要修正的原版缺陷（RF-D-02 明确要求月份/星期名随**区域格式**语言）；
/// 2. `intl` 的 locale 数据在 `flutter test` 宿主上未必齐全，自研可用**确定性**表
///    锁定断言（CI 无需 locale 数据）；
/// 3. 只需要"历史条目短时间/短日期"这一处展示，自研成本远低于引入一份 ICU 数据。
///
/// 模式串覆盖（PRD §6.3/§6.4 P0）：
/// - 时间：`H:mm` / `HH:mm` / `h:mm tt` / `hh:mm tt`（RF-T-02），分隔符可配（RF-T-01），
///   12/24 制由模式串推导（RF-T-05），AM/PM 符号可配（RF-T-04）；
/// - 日期短：`M/d/yyyy` / `yyyy-MM-dd` / `dd/MM/yyyy` / `M/d/yy`（RF-D-01）；
/// - 长日期：`dddd, MMMM d, yyyy` 等预设，月份/星期名随**区域格式语言**（RF-D-02）；
/// - 每周第一天由 [RegionFormatConfig.weekStart] 提供（RF-D-03）。
library;

import '../models/region_format_config.dart';

/// AM/PM 之"上午"。
const int _am = 0;

/// AM/PM 之"下午"。
const int _pm = 1;

/// 区域语言 → 月份/星期名表。语言键取区域标签的**语言子段**（如 `de-DE` → `de`）。
///
/// 只收录本轮 [RegionRegistry.supported] 相关语言；未收录者回落英文，
/// 保证任意标签都有确定输出（不抛异常、不崩）。
class _Names {
  const _Names({
    required this.monthsLong,
    required this.monthsShort,
    required this.weekdaysLong,
    required this.weekdaysShort,
  });

  /// 12 个月长名（1 月起）。
  final List<String> monthsLong;

  /// 12 个月短名。
  final List<String> monthsShort;

  /// 7 个星期长名（周日=索引 0，与 `DateTime.weekday` 换算后使用）。
  final List<String> weekdaysLong;

  /// 7 个星期短名（周日=索引 0）。
  final List<String> weekdaysShort;
}

/// 英文名表（默认回落）。
const _Names _en = _Names(
  monthsLong: <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ],
  monthsShort: <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ],
  weekdaysLong: <String>[
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  ],
  weekdaysShort: <String>[
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ],
);

/// 简体中文名表。
const _Names _zh = _Names(
  monthsLong: <String>[
    '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月',
  ],
  monthsShort: <String>[
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ],
  weekdaysLong: <String>[
    '星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六',
  ],
  weekdaysShort: <String>[
    '周日', '周一', '周二', '周三', '周四', '周五', '周六',
  ],
);

/// 德文名表。
const _Names _de = _Names(
  monthsLong: <String>[
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ],
  monthsShort: <String>[
    'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
    'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
  ],
  weekdaysLong: <String>[
    'Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag',
  ],
  weekdaysShort: <String>[
    'So.', 'Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.',
  ],
);

/// 法文名表。
const _Names _fr = _Names(
  monthsLong: <String>[
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ],
  monthsShort: <String>[
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ],
  weekdaysLong: <String>[
    'dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi',
  ],
  weekdaysShort: <String>[
    'dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.',
  ],
);

/// 西班牙文名表。
const _Names _es = _Names(
  monthsLong: <String>[
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ],
  monthsShort: <String>[
    'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
    'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.',
  ],
  weekdaysLong: <String>[
    'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado',
  ],
  weekdaysShort: <String>[
    'dom.', 'lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.',
  ],
);

/// 意大利文名表。
const _Names _it = _Names(
  monthsLong: <String>[
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ],
  monthsShort: <String>[
    'gen.', 'feb.', 'mar.', 'apr.', 'mag.', 'giu.',
    'lug.', 'ago.', 'set.', 'ott.', 'nov.', 'dic.',
  ],
  weekdaysLong: <String>[
    'domenica', 'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato',
  ],
  weekdaysShort: <String>[
    'dom.', 'lun.', 'mar.', 'mer.', 'gio.', 'ven.', 'sab.',
  ],
);

/// 葡萄牙文名表（巴西）。
const _Names _pt = _Names(
  monthsLong: <String>[
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ],
  monthsShort: <String>[
    'jan.', 'fev.', 'mar.', 'abr.', 'mai.', 'jun.',
    'jul.', 'ago.', 'set.', 'out.', 'nov.', 'dez.',
  ],
  weekdaysLong: <String>[
    'domingo', 'segunda-feira', 'terça-feira', 'quarta-feira',
    'quinta-feira', 'sexta-feira', 'sábado',
  ],
  weekdaysShort: <String>[
    'dom.', 'seg.', 'ter.', 'qua.', 'qui.', 'sex.', 'sáb.',
  ],
);

/// 荷兰文名表。
const _Names _nl = _Names(
  monthsLong: <String>[
    'januari', 'februari', 'maart', 'april', 'mei', 'juni',
    'juli', 'augustus', 'september', 'oktober', 'november', 'december',
  ],
  monthsShort: <String>[
    'jan.', 'feb.', 'mrt.', 'apr.', 'mei', 'jun.',
    'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.',
  ],
  weekdaysLong: <String>[
    'zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag',
  ],
  weekdaysShort: <String>[
    'zo.', 'ma.', 'di.', 'wo.', 'do.', 'vr.', 'za.',
  ],
);

/// 瑞典文名表。
const _Names _sv = _Names(
  monthsLong: <String>[
    'januari', 'februari', 'mars', 'april', 'maj', 'juni',
    'juli', 'augusti', 'september', 'oktober', 'november', 'december',
  ],
  monthsShort: <String>[
    'jan.', 'feb.', 'mars', 'apr.', 'maj', 'juni',
    'juli', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.',
  ],
  weekdaysLong: <String>[
    'söndag', 'måndag', 'tisdag', 'onsdag', 'torsdag', 'fredag', 'lördag',
  ],
  weekdaysShort: <String>[
    'sön', 'mån', 'tis', 'ons', 'tor', 'fre', 'lör',
  ],
);

/// 波兰文名表。
const _Names _pl = _Names(
  monthsLong: <String>[
    'styczeń', 'luty', 'marzec', 'kwiecień', 'maj', 'czerwiec',
    'lipiec', 'sierpień', 'wrzesień', 'październik', 'listopad', 'grudzień',
  ],
  monthsShort: <String>[
    'sty.', 'lut.', 'mar.', 'kwi.', 'maj', 'cze.',
    'lip.', 'sie.', 'wrz.', 'paź.', 'lis.', 'gru.',
  ],
  weekdaysLong: <String>[
    'niedziela', 'poniedziałek', 'wtorek', 'środa', 'czwartek', 'piątek', 'sobota',
  ],
  weekdaysShort: <String>[
    'niedz.', 'pon.', 'wt.', 'śr.', 'czw.', 'pt.', 'sob.',
  ],
);

/// 俄文名表。
const _Names _ru = _Names(
  monthsLong: <String>[
    'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
    'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
  ],
  monthsShort: <String>[
    'янв.', 'фев.', 'март', 'апр.', 'май', 'июнь',
    'июль', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
  ],
  weekdaysLong: <String>[
    'воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота',
  ],
  weekdaysShort: <String>[
    'вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб',
  ],
);

/// 日文名表。
const _Names _ja = _Names(
  monthsLong: <String>[
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ],
  monthsShort: <String>[
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ],
  weekdaysLong: <String>[
    '日曜日', '月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日',
  ],
  weekdaysShort: <String>[
    '日', '月', '火', '水', '木', '金', '土',
  ],
);

/// 韩文名表。
const _Names _ko = _Names(
  monthsLong: <String>[
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ],
  monthsShort: <String>[
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ],
  weekdaysLong: <String>[
    '일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일',
  ],
  weekdaysShort: <String>[
    '일', '월', '화', '수', '목', '금', '토',
  ],
);

/// 泰文名表。
const _Names _th = _Names(
  monthsLong: <String>[
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ],
  monthsShort: <String>[
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ],
  weekdaysLong: <String>[
    'วันอาทิตย์', 'วันจันทร์', 'วันอังคาร', 'วันพุธ',
    'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์',
  ],
  weekdaysShort: <String>[
    'อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.',
  ],
);

/// 语言子段 → 名表。
const Map<String, _Names> _namesByLanguage = <String, _Names>{
  'en': _en,
  'zh': _zh,
  'de': _de,
  'fr': _fr,
  'es': _es,
  'it': _it,
  'pt': _pt,
  'nl': _nl,
  'sv': _sv,
  'pl': _pl,
  'ru': _ru,
  'ja': _ja,
  'ko': _ko,
  'th': _th,
  'hi': _en, // 印地语月份名暂以英文呈现（P2 人工校订扩展位）
  'tr': _en,
  'ar': _en,
  'el': _en,
};

/// 区域时间/日期格式化器（无状态，纯函数）。
abstract final class RegionDateFormatter {
  /// 取某区域语言的名表；未知语言回落英文。
  static _Names _names(String language) =>
      _namesByLanguage[language.toLowerCase().split('-').first] ?? _en;

  /// 按区域配置格式化**短时间**（RF-T-02 / RF-T-05 / RF-T-06）。
  ///
  /// 例：`H:mm` + `:` → `9:05`；`hh:mm tt` + `:` → `09:05 AM`。
  static String formatTime(DateTime dt, RegionFormatConfig config) {
    final int minute = dt.minute;
    final String sep = config.timeSeparator;
    final String mm = _2(minute);
    final bool pm = dt.hour >= 12;

    if (config.use12h) {
      final int hour12 = _to12h(dt.hour);
      final String hh = config.padHour ? _2(hour12) : '$hour12';
      final String tt = pm ? config.pmSymbol : config.amSymbol;
      return '$hh$sep$mm $tt';
    }
    final String hh = config.padHour ? _2(dt.hour) : '${dt.hour}';
    return '$hh$sep$mm';
  }

  /// 按区域配置格式化**短日期**（RF-D-01 / RF-D-07）。
  ///
  /// 例：`M/d/yyyy` → `9/9/2025`；`dd/MM/yyyy` → `09/09/2025`；`yyyy-MM-dd` → `2025-09-09`。
  static String formatDate(DateTime dt, RegionFormatConfig config) {
    final String pattern = config.customDatePattern ?? _shortDatePattern(config.datePattern);
    return formatPattern(dt, pattern, config);
  }

  /// 按任意模式串格式化（RF-X-02 自定义占位符）。
  ///
  /// 支持占位符：`yyyy` `yy` `MMMM` `MMM` `MM` `M` `dd` `d` `dddd` `ddd` `HH` `H`
  /// `hh` `h` `mm` `m` `ss` `s` `tt` `t`。其余字符原样保留。
  /// 月份/星期名按 [RegionFormatConfig.regionLanguage] 取（RF-D-02）。
  static String formatPattern(
    DateTime dt,
    String pattern,
    RegionFormatConfig config,
  ) {
    final _Names names = _names(config.regionLanguage);
    final int month = dt.month;
    final int weekday = dt.weekday % 7; // DateTime: 周一=1..周日=7 → 周日=0..周六=6
    final bool pm = dt.hour >= 12;
    final int hour12 = _to12h(dt.hour);

    final StringBuffer out = StringBuffer();
    int i = 0;
    while (i < pattern.length) {
      final String rest = pattern.substring(i);
      if (rest.startsWith('yyyy')) {
        out.write(_4(dt.year));
        i += 4;
      } else if (rest.startsWith('yy')) {
        out.write(_2(dt.year % 100));
        i += 2;
      } else if (rest.startsWith('MMMM')) {
        out.write(names.monthsLong[month - 1]);
        i += 4;
      } else if (rest.startsWith('MMM')) {
        out.write(names.monthsShort[month - 1]);
        i += 3;
      } else if (rest.startsWith('MM')) {
        out.write(_2(month));
        i += 2;
      } else if (rest.startsWith('dddd')) {
        out.write(names.weekdaysLong[weekday]);
        i += 4;
      } else if (rest.startsWith('ddd')) {
        out.write(names.weekdaysShort[weekday]);
        i += 3;
      } else if (rest.startsWith('dd')) {
        out.write(_2(dt.day));
        i += 2;
      } else if (rest.startsWith('HH')) {
        out.write(_2(dt.hour));
        i += 2;
      } else if (rest.startsWith('hh')) {
        out.write(_2(hour12));
        i += 2;
      } else if (rest.startsWith('mm')) {
        out.write(_2(dt.minute));
        i += 2;
      } else if (rest.startsWith('ss')) {
        out.write(_2(dt.second));
        i += 2;
      } else if (rest.startsWith('tt')) {
        out.write(pm ? config.pmSymbol : config.amSymbol);
        i += 2;
      } else if (rest.startsWith('M')) {
        out.write('$month');
        i += 1;
      } else if (rest.startsWith('d')) {
        out.write('${dt.day}');
        i += 1;
      } else if (rest.startsWith('H')) {
        out.write('${dt.hour}');
        i += 1;
      } else if (rest.startsWith('h')) {
        out.write('$hour12');
        i += 1;
      } else if (rest.startsWith('m')) {
        out.write('${dt.minute}');
        i += 1;
      } else if (rest.startsWith('s')) {
        out.write('${dt.second}');
        i += 1;
      } else if (rest.startsWith('t')) {
        final String tt = pm ? config.pmSymbol : config.amSymbol;
        out.write(tt.isEmpty ? '' : tt[0]);
        i += 1;
      } else {
        out.write(pattern[i]);
        i += 1;
      }
    }
    return out.toString();
  }

  /// 预设短日期 → 模式串。
  static String _shortDatePattern(DatePattern p) {
    switch (p) {
      case DatePattern.mdy:
        return 'M/d/yyyy';
      case DatePattern.ymd:
        return 'yyyy-MM-dd';
      case DatePattern.dmy:
        return 'dd/MM/yyyy';
      case DatePattern.mdyy:
        return 'M/d/yy';
    }
  }

  /// 24 小时制 → 12 小时制（0 → 12，13 → 1 ……）。
  static int _to12h(int hour24) {
    final int h = hour24 % 12;
    return h == 0 ? 12 : h;
  }

  /// 该区域配置下"每周第一天"的星期码（周日=0..周六=6，RF-D-03）。
  static int firstDayOfWeek(RegionFormatConfig config) {
    switch (config.weekStart) {
      case WeekStart.sunday:
        return 0;
      case WeekStart.monday:
        return 1;
      case WeekStart.saturday:
        return 6;
    }
  }

  /// 补零到两位。
  static String _2(int v) => v < 10 ? '0$v' : '$v';

  /// 补零到四位。
  static String _4(int v) {
    if (v >= 1000) {
      return '$v';
    }
    return v.toString().padLeft(4, '0');
  }
}

/// AM/PM 常量对外暴露（供测试断言 hour-of-day 语义）。
const int kAm = _am;

/// PM 常量对外暴露。
const int kPm = _pm;
