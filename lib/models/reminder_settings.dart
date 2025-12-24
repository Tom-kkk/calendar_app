import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// 提醒类型枚举
enum ReminderType {
  /// 通知提醒
  notification,
  /// 邮件提醒（预留）
  email,
  /// 声音提醒
  sound,
}

/// 提醒设置模型
@HiveType(typeId: 1)
class ReminderSetting {
  ReminderSetting({
    String? id,
    required this.beforeTime,
    this.type = ReminderType.notification,
    this.timeZoneId,
  }) : id = id ?? const Uuid().v4();

  /// VALARM UID（对应 RFC5545 UID，便于跟踪/取消）
  @HiveField(0)
  final String id;

  /// 提前时间（例如：提前15分钟）
  @HiveField(1)
  final Duration beforeTime;

  /// 提醒类型
  @HiveField(2)
  final ReminderType type;

  /// 提醒触发使用的时区（TZID），为空时默认设备时区
  @HiveField(3)
  final String? timeZoneId;

  ReminderSetting copyWith({
    String? id,
    Duration? beforeTime,
    ReminderType? type,
    String? timeZoneId,
  }) {
    return ReminderSetting(
      id: id ?? this.id,
      beforeTime: beforeTime ?? this.beforeTime,
      type: type ?? this.type,
      timeZoneId: timeZoneId ?? this.timeZoneId,
    );
  }

  /// 从毫秒数创建 Duration（用于 Hive 序列化）
  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    return ReminderSetting(
      id: json['id'] as String?,
      beforeTime: Duration(milliseconds: json['beforeTime'] as int),
      type: ReminderType.values[json['type'] as int],
      timeZoneId: json['timeZoneId'] as String?,
    );
  }

  /// 转换为 JSON（用于 Hive 序列化）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'beforeTime': beforeTime.inMilliseconds,
      'type': type.index,
      'timeZoneId': timeZoneId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderSetting &&
        other.id == id &&
        other.beforeTime == beforeTime &&
        other.type == type &&
        other.timeZoneId == timeZoneId;
  }

  @override
  int get hashCode =>
      id.hashCode ^ beforeTime.hashCode ^ type.hashCode ^ timeZoneId.hashCode;

  @override
  String toString() {
    return 'ReminderSetting(id: $id, beforeTime: $beforeTime, type: $type, tz: $timeZoneId)';
  }
}

/// ReminderSetting 的 Hive 适配器
class ReminderSettingAdapter extends TypeAdapter<ReminderSetting> {
  @override
  final int typeId = 1;

  @override
  ReminderSetting read(BinaryReader reader) {
    final id = reader.readString();
    final beforeTimeMs = reader.readInt();
    final typeIndex = reader.readInt();
    final hasTimeZone = reader.readBool();
    return ReminderSetting(
      id: id,
      beforeTime: Duration(milliseconds: beforeTimeMs),
      type: ReminderType.values[typeIndex],
      timeZoneId: hasTimeZone ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSetting obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.beforeTime.inMilliseconds);
    writer.writeInt(obj.type.index);
    writer.writeBool(obj.timeZoneId != null);
    if (obj.timeZoneId != null) {
      writer.writeString(obj.timeZoneId!);
    }
  }
}

