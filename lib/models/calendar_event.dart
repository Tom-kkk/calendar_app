import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'reminder_settings.dart';

/// 日历事件模型
/// 符合 RFC5545 标准的基本要求
@HiveType(typeId: 0)
class CalendarEvent {
  CalendarEvent({
    String? id,
    required this.title,
    this.description,
    required this.start,
    required this.end,
    this.location,
    this.colorHex,
    List<ReminderSetting>? reminders,
    this.isAllDay = false,
    this.recurrenceRule,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        reminders = reminders ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 唯一标识符（UUID）
  @HiveField(0)
  final String id;

  /// 事件标题
  @HiveField(1)
  final String title;

  /// 事件描述（可选）
  @HiveField(2)
  final String? description;

  /// 开始时间
  @HiveField(3)
  final DateTime start;

  /// 结束时间
  @HiveField(4)
  final DateTime end;

  /// 地点（可选）
  @HiveField(5)
  final String? location;

  /// 颜色标识（可选，使用十六进制颜色值）
  @HiveField(6)
  final int? colorHex;

  /// 提醒设置列表
  @HiveField(7)
  final List<ReminderSetting> reminders;

  /// 是否全天事件
  @HiveField(8)
  final bool isAllDay;

  /// 重复规则（RRULE，符合 RFC5545 标准）
  /// 例如: "FREQ=DAILY;INTERVAL=1" 表示每天重复
  @HiveField(9)
  final String? recurrenceRule;

  /// 创建时间
  @HiveField(10)
  final DateTime createdAt;

  /// 更新时间
  @HiveField(11)
  final DateTime updatedAt;

  /// 创建副本并更新指定字段
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    String? location,
    int? colorHex,
    List<ReminderSetting>? reminders,
    bool? isAllDay,
    String? recurrenceRule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      location: location ?? this.location,
      colorHex: colorHex ?? this.colorHex,
      reminders: reminders ?? this.reminders,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 检查事件是否在指定日期
  bool isOnDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    return dateOnly.isAtSameMomentAs(startOnly) ||
        dateOnly.isAtSameMomentAs(endOnly) ||
        (dateOnly.isAfter(startOnly) && dateOnly.isBefore(endOnly));
  }

  /// 检查事件是否在指定时间范围内
  bool overlapsWith(DateTime rangeStart, DateTime rangeEnd) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  /// 获取事件持续时间
  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CalendarEvent(id: $id, title: $title, start: $start, end: $end)';
  }
}

/// CalendarEvent 的 Hive 适配器
class CalendarEventAdapter extends TypeAdapter<CalendarEvent> {
  @override
  final int typeId = 0;

  @override
  CalendarEvent read(BinaryReader reader) {
    // 读取基本字段
    final id = reader.readString();
    final title = reader.readString();
    final description = reader.readBool() ? reader.readString() : null;
    final start = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final end = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final location = reader.readBool() ? reader.readString() : null;
    final colorHex = reader.readBool() ? reader.readInt() : null;

    // 读取提醒设置列表（存储为 List<Map>）
    final remindersList = reader.readList() as List;
    final reminders = remindersList
        .map((item) {
          final map = item as Map;
          return ReminderSetting(
            beforeTime: Duration(milliseconds: map['beforeTime'] as int),
            type: ReminderType.values[map['type'] as int],
          );
        })
        .toList();

    final isAllDay = reader.readBool();
    final recurrenceRule = reader.readBool() ? reader.readString() : null;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return CalendarEvent(
      id: id,
      title: title,
      description: description,
      start: start,
      end: end,
      location: location,
      colorHex: colorHex,
      reminders: reminders,
      isAllDay: isAllDay,
      recurrenceRule: recurrenceRule,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEvent obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeBool(obj.description != null);
    if (obj.description != null) {
      writer.writeString(obj.description!);
    }
    writer.writeInt(obj.start.millisecondsSinceEpoch);
    writer.writeInt(obj.end.millisecondsSinceEpoch);
    writer.writeBool(obj.location != null);
    if (obj.location != null) {
      writer.writeString(obj.location!);
    }
    writer.writeBool(obj.colorHex != null);
    if (obj.colorHex != null) {
      writer.writeInt(obj.colorHex!);
    }
    // 将 ReminderSetting 列表序列化为 List<Map>
    writer.writeList(
      obj.reminders
          .map((r) => {
                'beforeTime': r.beforeTime.inMilliseconds,
                'type': r.type.index,
              } as Map<String, dynamic>)
          .toList(),
    );
    writer.writeBool(obj.isAllDay);
    writer.writeBool(obj.recurrenceRule != null);
    if (obj.recurrenceRule != null) {
      writer.writeString(obj.recurrenceRule!);
    }
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}

