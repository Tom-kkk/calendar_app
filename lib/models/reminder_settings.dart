import 'package:hive/hive.dart';

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
    required this.beforeTime,
    this.type = ReminderType.notification,
  });

  /// 提前时间（例如：提前15分钟）
  @HiveField(0)
  final Duration beforeTime;

  /// 提醒类型
  @HiveField(1)
  final ReminderType type;

  /// 从毫秒数创建 Duration（用于 Hive 序列化）
  factory ReminderSetting.fromJson(Map<String, dynamic> json) {
    return ReminderSetting(
      beforeTime: Duration(milliseconds: json['beforeTime'] as int),
      type: ReminderType.values[json['type'] as int],
    );
  }

  /// 转换为 JSON（用于 Hive 序列化）
  Map<String, dynamic> toJson() {
    return {
      'beforeTime': beforeTime.inMilliseconds,
      'type': type.index,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderSetting &&
        other.beforeTime == beforeTime &&
        other.type == type;
  }

  @override
  int get hashCode => beforeTime.hashCode ^ type.hashCode;

  @override
  String toString() {
    return 'ReminderSetting(beforeTime: $beforeTime, type: $type)';
  }
}

/// ReminderSetting 的 Hive 适配器
class ReminderSettingAdapter extends TypeAdapter<ReminderSetting> {
  @override
  final int typeId = 1;

  @override
  ReminderSetting read(BinaryReader reader) {
    final beforeTimeMs = reader.readInt();
    final typeIndex = reader.readInt();
    return ReminderSetting(
      beforeTime: Duration(milliseconds: beforeTimeMs),
      type: ReminderType.values[typeIndex],
    );
  }

  @override
  void write(BinaryWriter writer, ReminderSetting obj) {
    writer.writeInt(obj.beforeTime.inMilliseconds);
    writer.writeInt(obj.type.index);
  }
}

