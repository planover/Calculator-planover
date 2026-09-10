/// JSON 模型契约测试 —— 验证 Dart 模型与 Rust `api.rs` 的 DTO **逐字段对齐**。
///
/// 为什么这层测试最重要（架构 §3.15 的分层验证策略）：
/// 本机没有 Flutter/Dart SDK 以外的真机，但 JSON 契约错了 App 会整页白屏或静默显示错值，
/// 而这类错误在 UI 上极难定位。把 Rust 真实输出的 JSON 固化成用例，
/// 等于给 FFI 语义在 Dart 侧再加一道锁。
///
/// 铁律：**不 import `native_engine.dart` / `dart:ffi`**（架构风险 R3），
/// 这里测的是纯数据结构，不需要加载 `.so`。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:calculator_planover/src/models/base_repr.dart';
import 'package:calculator_planover/src/models/constant_info.dart';
import 'package:calculator_planover/src/models/convert_result.dart';
import 'package:calculator_planover/src/models/engine_error.dart';
import 'package:calculator_planover/src/models/eval_result.dart';
import 'package:calculator_planover/src/models/eval_settings.dart';
import 'package:calculator_planover/src/models/history_entry.dart';
import 'package:calculator_planover/src/models/number_value.dart';
import 'package:calculator_planover/src/models/unit_info.dart';
import 'package:calculator_planover/src/models/variable_info.dart';

void main() {
  group('NumberValue', () {
    test('解析有理数', () {
      final NumberValue v =
          NumberValue.fromJson(<String, Object?>{'kind': 'rational', 'num': 7, 'den': 2});
      expect(v.kind, NumberKind.rational);
      expect(v.numerator, 7);
      expect(v.denominator, 2);
      expect(v.toDouble(), 3.5);
    });

    test('解析浮点与特殊值', () {
      final NumberValue f =
          NumberValue.fromJson(<String, Object?>{'kind': 'float', 'value': 3.5});
      expect(f.kind, NumberKind.float);
      expect(f.value, 3.5);

      final NumberValue negInf =
          NumberValue.fromJson(<String, Object?>{'kind': 'special', 'which': '-inf'});
      expect(negInf.kind, NumberKind.special);
      expect(negInf.which, SpecialKind.negInf);
    });

    test('脏数据不抛异常', () {
      expect(NumberValue.fromJson(null).kind, NumberKind.rational);
      expect(NumberValue.fromJson('x').toDouble(), 0.0);
      expect(NumberValue.fromJson(<String, Object?>{'kind': 'float', 'value': 'oops'}).value, 0.0);
    });

    test('往返稳定', () {
      const NumberValue src = NumberValue(
        kind: NumberKind.rational,
        numerator: 22,
        denominator: 7,
      );
      final NumberValue back = NumberValue.fromJson(src.toJson());
      expect(back.numerator, 22);
      expect(back.denominator, 7);
    });
  });

  group('EvalResult', () {
    const Map<String, Object?> sample = <String, Object?>{
      'value': <String, Object?>{'kind': 'rational', 'num': 7, 'den': 2},
      'approx': 3.5,
      'display': '3.5',
      'fraction': null,
      'base': <String, Object?>{
        'dec': '3.5',
        'hex': '',
        'oct': '',
        'bin': '',
        'word_size': 64,
        'is_integer': false,
      },
      'assignments': <Object?>[
        <String, Object?>{'name': 'ans', 'display': '3.5', 'readonly': true},
      ],
      'is_integer': false,
    };

    test('解析完整结果', () {
      final EvalResult r = EvalResult.fromJson(sample);
      expect(r.display, '3.5');
      expect(r.isInteger, false);
      expect(r.value.numerator, 7);
      expect(r.base.wordSize, 64);
      expect(r.assignments, hasLength(1));
      expect(r.assignments.single.name, 'ans');
      expect(r.assignments.single.readonly, true);
    });

    test('缺失字段回落到安全值', () {
      final EvalResult r = EvalResult.fromJson(<String, Object?>{});
      expect(r.display, '');
      expect(r.base.wordSize, 64);
      expect(r.assignments, isEmpty);
    });
  });

  group('EvalSettings', () {
    test('解析嵌套 SettingsDto', () {
      final EvalSettings s = EvalSettings.fromJson(<String, Object?>{
        'angle_mode': 'rad',
        'word_size': 32,
        'number_format': <String, Object?>{
          'notation': 'scientific',
          'precision_mode': 'decimal_places',
          'precision': 6,
          'fraction_mode': 'improper',
          'grouping': false,
        },
      });
      expect(s.angleMode, AngleMode.rad);
      expect(s.wordSize, 32);
      expect(s.notation, Notation.scientific);
      expect(s.precisionMode, PrecisionMode.decimalPlaces);
      expect(s.precision, 6);
      expect(s.fractionMode, FractionMode.improper);
      expect(s.grouping, false);
    });

    test('解析扁平 FormatDto', () {
      final EvalSettings s = EvalSettings.fromJson(<String, Object?>{
        'notation': 'fixed',
        'precision': 3,
      });
      expect(s.notation, Notation.fixed);
      expect(s.precision, 3);
      // 扁平写法里没有的字段走默认
      expect(s.angleMode, AngleMode.deg);
      expect(s.wordSize, 64);
    });

    test('越界精度被夹回 1..15', () {
      expect(
        EvalSettings.fromJson(<String, Object?>{'precision': 99}).precision,
        maxPrecision,
      );
      expect(
        EvalSettings.fromJson(<String, Object?>{'precision': 0}).precision,
        minPrecision,
      );
    });

    test('toJson 产出嵌套、toFormatJson 产出扁平', () {
      const EvalSettings s =
          EvalSettings(angleMode: AngleMode.grad, wordSize: 16);
      expect(s.toJson()['angle_mode'], 'grad');
      expect(s.toJson()['number_format'], isA<Map>());
      expect(s.toFormatJson()['grouping'], true);
      expect(s.toFormatJson().containsKey('word_size'), false);
    });
  });

  group('EngineError', () {
    test('解析错误信封', () {
      final EngineError e = EngineError.fromJson(<String, Object?>{
        'code': 2000,
        'kind': 'division_by_zero',
        'message': '除数不能为零',
        'span': <String, Object?>{'start': 2, 'end': 3},
      });
      expect(e.code, 2000);
      expect(e.kind, 'division_by_zero');
      expect(e.span?.start, 2);
      expect(e.span?.end, 3);
    });

    test('无 span 时为 null', () {
      final EngineError e = EngineError.fromJson(<String, Object?>{'code': 1});
      expect(e.span, isNull);
      expect(e.kind, 'internal_error');
    });
  });

  group('常量 / 单位 / 变量 / 换算', () {
    test('解析常量', () {
      final ConstantInfo c = ConstantInfo.fromJson(<String, Object?>{
        'symbol': 'π',
        'name': '圆周率',
        'unit': '',
        'value': '3.141592653589793',
        'category': 'math',
        'aliases': <Object?>['pi', 'PI'],
      });
      expect(c.symbol, 'π');
      expect(c.aliases, contains('pi'));
    });

    test('解析单位类别', () {
      final CategoryInfo cat = CategoryInfo.fromJson(<String, Object?>{
        'id': 'length',
        'name': '长度',
        'units': <Object?>[
          <String, Object?>{'id': 'inch', 'symbol': 'inch', 'name': '英寸',
            'category': 'length', 'kind': 'proportional'},
        ],
      });
      expect(cat.id, 'length');
      expect(cat.units.single.id, 'inch');
      expect(cat.units.single.kind, 'proportional');
    });

    test('解析变量', () {
      final VariableInfo v = VariableInfo.fromJson(<String, Object?>{
        'name': 'ans',
        'display': '42',
        'readonly': true,
      });
      expect(v.name, 'ans');
      expect(v.readonly, true);
    });

    test('解析换算结果', () {
      final ConvertResult r = ConvertResult.fromJson(<String, Object?>{
        'from': <String, Object?>{'id': 'inch', 'symbol': 'inch', 'name': '英寸',
          'category': 'length', 'kind': 'proportional'},
        'to': <String, Object?>{'id': 'mm', 'symbol': 'mm', 'name': '毫米',
          'category': 'length', 'kind': 'proportional'},
        'input_value': <String, Object?>{'kind': 'rational', 'num': 127, 'den': 10},
        'output_value': <String, Object?>{'kind': 'float', 'value': 322.58},
        'input_display': '12.7 inch',
        'output_display': '322.58 mm',
      });
      expect(r.from.id, 'inch');
      expect(r.to.id, 'mm');
      expect(r.outputDisplay, '322.58 mm');
      expect(r.outputValue.kind, NumberKind.float);
    });
  });

  group('BaseRepr / HistoryEntry', () {
    test('解析进制表示', () {
      final BaseRepr b = BaseRepr.fromJson(<String, Object?>{
        'dec': '255', 'hex': 'FF', 'oct': '377', 'bin': '11111111',
        'word_size': 32, 'is_integer': true,
      });
      expect(b.hex, 'FF');
      expect(b.wordSize, 32);
      expect(b.isInteger, true);
    });

    test('历史条目往返', () {
      final HistoryEntry e = HistoryEntry.fromMap(<String, Object?>{
        'id': 7, 'expr': '1+2', 'result': '3', 'ts': 1700000000000, 'kind': 0,
      });
      expect(e.id, 7);
      expect(e.kind, HistoryKind.calculation);
      final Map<String, dynamic> back = e.toMap();
      expect(back['expr'], '1+2');
      expect(back['kind'], 0);
    });

    test('历史条目默认不带 id（交给 SQLite 自增）', () {
      final HistoryEntry e = HistoryEntry(
        expr: 'sin(30)',
        result: '0.5',
        ts: 1700000000001,
        kind: HistoryKind.conversion,
      );
      expect(e.toMap().containsKey('id'), false);
      expect(e.toMap()['kind'], 1);
    });
  });
}
