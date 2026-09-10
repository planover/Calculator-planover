/// 单位与类别展示信息 —— 镜像 `api.rs` 的 `UnitInfoDto` / `CategoryInfoDto`。
library;

import '../utils/json_helpers.dart';

/// 一个单位。
class UnitInfo {
  const UnitInfo({
    this.id = '',
    this.symbol = '',
    this.name = '',
    this.category = '',
    this.kind = 'proportional',
  });

  /// 稳定 id，如 `inch`。
  final String id;

  /// 展示符号，如 `inch` / `°C`。
  final String symbol;

  /// 中文名。
  final String name;

  /// 所属类别标识，如 `length`。
  final String category;

  /// 换算模型：`proportional` 或 `affine`（温度）。
  final String kind;

  /// 是否仿射型（温度专用，UI 需要提示"含偏移"）。
  bool get isAffine => kind == 'affine';

  /// 宽容解析。
  factory UnitInfo.fromJson(Object? json) => UnitInfo(
        id: readString(json, 'id', ''),
        symbol: readString(json, 'symbol', ''),
        name: readString(json, 'name', ''),
        category: readString(json, 'category', ''),
        kind: readString(json, 'kind', 'proportional'),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'symbol': symbol,
        'name': name,
        'category': category,
        'kind': kind,
      };

  @override
  String toString() => 'UnitInfo($id/$symbol)';
}

/// 一个单位类别（如"长度"）。
class CategoryInfo {
  const CategoryInfo({this.id = '', this.name = '', this.units = const <UnitInfo>[]});

  /// 类别标识，如 `length`。
  final String id;

  /// 中文名，如 `长度`。
  final String name;

  /// 该类别下的全部单位。
  final List<UnitInfo> units;

  /// 宽容解析。
  factory CategoryInfo.fromJson(Object? json) => CategoryInfo(
        id: readString(json, 'id', ''),
        name: readString(json, 'name', ''),
        units: readMapList(json, 'units')
            .map(UnitInfo.fromJson)
            .toList(growable: false),
      );

  /// 转成 JSON。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'units': units.map((UnitInfo u) => u.toJson()).toList(),
      };

  @override
  String toString() => 'CategoryInfo($id, ${units.length} units)';
}
