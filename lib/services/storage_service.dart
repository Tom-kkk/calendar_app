import 'package:hive_flutter/hive_flutter.dart';
import '../models/calendar_event.dart';

/// 存储服务
/// 使用 Hive 进行本地持久化存储
class StorageService {
  static const String _boxName = 'calendar_events';
  Box<CalendarEvent>? _box;

  /// 初始化存储服务
  Future<void> init() async {
    _box = await Hive.openBox<CalendarEvent>(_boxName);
  }

  /// 获取所有事件
  List<CalendarEvent> getAllEvents() {
    if (_box == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _box!.values.toList();
  }

  /// 保存事件（新增或更新）
  Future<void> saveEvent(CalendarEvent event) async {
    if (_box == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    await _box!.put(event.uid, event);
  }

  /// 删除事件
  Future<void> deleteEvent(String uid) async {
    if (_box == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    await _box!.delete(uid);
  }

  /// 批量保存事件
  Future<void> saveEvents(List<CalendarEvent> events) async {
    if (_box == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    final Map<String, CalendarEvent> eventsMap = {
      for (final event in events) event.uid: event
    };
    await _box!.putAll(eventsMap);
  }

  /// 清空所有事件
  Future<void> clearAll() async {
    if (_box == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    await _box!.clear();
  }

  /// 关闭存储
  Future<void> close() async {
    await _box?.close();
  }
}

