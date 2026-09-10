//! JSON 读取辅助 —— 让所有 `fromJson` 都满足架构 §10.2.5：
//! **任何缺失 / 类型不符的字段都要给默认值，永不 throw**。
//!
//! 为什么需要这层：Rust 的 DTO 用 `#[serde(skip_serializing_if = "Option::is_none")]`，
//! 字段会**整消失**（而不是给 null）；再加上 JSON 里数字没有 int/double 之分，
//! 直接 `json['x'] as int` 在 `x` 是 double 或缺失时会抛异常并让整页崩掉。
//! 这里统一做"宽容读取"，保证一条脏数据最多让某个字段变成默认值。

/// 从一个可能是 Map 的对象里读整数；失败回落到 [fallback]。
int readInt(Object? json, String key, int fallback) {
  final Object? v = _field(json, key);
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  if (v is String) {
    // Rust usize/u64 在极端情况下被序列化成字符串，这里兜住
    return int.tryParse(v) ?? fallback;
  }
  return fallback;
}

/// 读浮点；失败回落到 [fallback]。
double readDouble(Object? json, String key, double fallback) {
  final Object? v = _field(json, key);
  if (v is double) {
    return v;
  }
  if (v is num) {
    return v.toDouble();
  }
  if (v is String) {
    return double.tryParse(v) ?? fallback;
  }
  return fallback;
}

/// 读字符串；失败回落到 [fallback]。
String readString(Object? json, String key, String fallback) {
  final Object? v = _field(json, key);
  if (v is String) {
    return v;
  }
  if (v is num || v is bool) {
    // 常量表里的 value 有时是纯数字文本，统一转成字符串便于直接展示
    return v.toString();
  }
  return fallback;
}

/// 读布尔；失败回落到 [fallback]。
bool readBool(Object? json, String key, bool fallback) {
  final Object? v = _field(json, key);
  if (v is bool) {
    return v;
  }
  if (v is num) {
    return v != 0;
  }
  if (v is String) {
    return v == 'true';
  }
  return fallback;
}

/// 读可为 null 的字符串（区分"字段缺失"与"显式 null"）。
String? readNullableString(Object? json, String key) {
  final Object? v = _field(json, key);
  if (v == null) {
    return null;
  }
  if (v is String) {
    return v;
  }
  return v.toString();
}

/// 读子对象；不存在或不是对象时返回 null。
Map<String, dynamic>? readMap(Object? json, String key) {
  final Object? v = _field(json, key);
  if (v is Map) {
    return Map<String, dynamic>.from(v);
  }
  return null;
}

/// 读对象数组；不存在或类型不符时返回空数组（永不返回 null，省去调用方判空）。
List<Map<String, dynamic>> readMapList(Object? json, String key) {
  final Object? v = _field(json, key);
  if (v is! List) {
    return const <Map<String, dynamic>>[];
  }
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  for (final Object? item in v) {
    if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
}

/// 读字符串数组。
List<String> readStringList(Object? json, String key) {
  final Object? v = _field(json, key);
  if (v is! List) {
    return const <String>[];
  }
  final List<String> out = <String>[];
  for (final Object? item in v) {
    if (item is String) {
      out.add(item);
    } else if (item != null) {
      out.add(item.toString());
    }
  }
  return out;
}

/// 读枚举：把 JSON 里的 snake_case 字符串映射成 Dart 枚举。
///
/// [values] 是 "字符串 → 枚举值" 的表；未命中（或字段缺失）时用 [fallback]。
T readEnum<T>(Object? json, String key, T fallback, Map<String, T> values) {
  final Object? v = _field(json, key);
  if (v is! String) {
    return fallback;
  }
  return values[v] ?? fallback;
}

/// 把非 null 的字段写进 [out]（用于 toJson 时省略 null，贴近 Rust 的行为）。
void putIfNotNull(Map<String, dynamic> out, String key, Object? value) {
  if (value != null) {
    out[key] = value;
  }
}

/// 取字段的通用入口：只认 Map，其余一律当作"读不到"。
Object? _field(Object? json, String key) {
  if (json is Map) {
    return json[key];
  }
  return null;
}
