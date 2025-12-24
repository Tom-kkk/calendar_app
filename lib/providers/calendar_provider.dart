import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

/// 日/周/月视图枚举
enum CalendarView { day, week, month }

/// 全局日历状态
class CalendarState {
  CalendarState({
    required this.selectedDate,
    required this.currentView,
    Map<DateTime, List<CalendarEvent>>? events,
  }) : events = events ?? {};

  final DateTime selectedDate;
  final CalendarView currentView;
  final Map<DateTime, List<CalendarEvent>> events;

  CalendarState copyWith({
    DateTime? selectedDate,
    CalendarView? currentView,
    Map<DateTime, List<CalendarEvent>>? events,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      currentView: currentView ?? this.currentView,
      events: events ?? this.events,
    );
  }
}

/// CalendarState 的状态管理器
class CalendarNotifier extends StateNotifier<CalendarState> {
  final StorageService _storageService;
  final NotificationService _notificationService = NotificationService();

  CalendarNotifier(this._storageService)
      : super(
          CalendarState(
            selectedDate: DateTime.now(),
            currentView: CalendarView.month,
          ),
        ) {
    // 初始化时加载保存的事件
    _loadEvents();
  }

  /// 从存储服务加载事件
  Future<void> _loadEvents() async {
    try {
      final events = _storageService.getAllEvents();
      loadEvents(events);
    } catch (e) {
      // 如果加载失败（例如存储服务未初始化），忽略错误
      // 应用启动时会先初始化存储服务
    }
  }

  /// 保存所有事件到存储服务
  Future<void> _saveAllEvents() async {
    try {
      final allEvents = <CalendarEvent>[];
      for (final eventList in state.events.values) {
        allEvents.addAll(eventList);
      }
      await _storageService.saveEvents(allEvents);
    } catch (e) {
      // 保存失败时忽略错误，避免影响用户体验
    }
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: DateTime(date.year, date.month, date.day));
  }

  void switchView(CalendarView view) {
    state = state.copyWith(currentView: view);
  }

  void goToday() {
    selectDate(DateTime.now());
  }

  /// 导航到上一月
  void goPreviousMonth() {
    final current = state.selectedDate;
    final previousMonth = DateTime(current.year, current.month - 1, current.day);
    selectDate(previousMonth);
  }

  /// 导航到下一月
  void goNextMonth() {
    final current = state.selectedDate;
    final nextMonth = DateTime(current.year, current.month + 1, current.day);
    selectDate(nextMonth);
  }

  /// 导航到上一周
  void goPreviousWeek() {
    final current = state.selectedDate;
    final previousWeek = current.subtract(const Duration(days: 7));
    selectDate(previousWeek);
  }

  /// 导航到下一周
  void goNextWeek() {
    final current = state.selectedDate;
    final nextWeek = current.add(const Duration(days: 7));
    selectDate(nextWeek);
  }

  /// 导航到上一天
  void goPreviousDay() {
    final current = state.selectedDate;
    final previousDay = current.subtract(const Duration(days: 1));
    selectDate(previousDay);
  }

  /// 导航到下一天
  void goNextDay() {
    final current = state.selectedDate;
    final nextDay = current.add(const Duration(days: 1));
    selectDate(nextDay);
  }

  /// 从外部（例如事件 Provider / 存储层）批量加载事件，替换当前事件映射
  void loadEvents(Iterable<CalendarEvent> events) {
    final Map<DateTime, List<CalendarEvent>> map = {};
    for (final e in events) {
      final key = DateTime(e.start.year, e.start.month, e.start.day);
      map.putIfAbsent(key, () => <CalendarEvent>[]).add(e);
    }
    state = state.copyWith(events: map);
    // 加载完所有事件后，重新调度所有提醒
    _rescheduleAllReminders();
  }

  /// 重新调度所有未过期事件的提醒
  Future<void> _rescheduleAllReminders() async {
    try {
      final allEvents = <CalendarEvent>[];
      for (final eventList in state.events.values) {
        allEvents.addAll(eventList);
      }
      await _notificationService.rescheduleAllReminders(allEvents);
    } catch (e) {
      // 调度失败时忽略错误，避免影响用户体验
    }
  }

  List<CalendarEvent> eventsFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return state.events[key] ?? const [];
  }

  /// 指定日期范围内的所有事件（闭区间）
  List<CalendarEvent> eventsInRange(DateTime start, DateTime end) {
    final result = <CalendarEvent>[];
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);

    for (final entry in state.events.entries) {
      final day = entry.key;
      if ((day.isAtSameMomentAs(rangeStart) || day.isAfter(rangeStart)) &&
          (day.isAtSameMomentAs(rangeEnd) || day.isBefore(rangeEnd))) {
        result.addAll(entry.value);
      }
    }
    return result;
  }

  void addEvent(CalendarEvent event) {
    final key = DateTime(event.start.year, event.start.month, event.start.day);
    final updated = Map<DateTime, List<CalendarEvent>>.from(state.events);
    final list = <CalendarEvent>[...(updated[key] ?? const <CalendarEvent>[]), event];
    updated[key] = list;
    state = state.copyWith(events: updated);
    // 保存到存储
    _saveAllEvents();
    // 调度提醒
    _scheduleEventReminders(event);
  }

  /// 调度事件的提醒
  Future<void> _scheduleEventReminders(CalendarEvent event) async {
    try {
      await _notificationService.scheduleEventReminders(event);
    } catch (e) {
      // 调度失败时忽略错误，避免影响用户体验
    }
  }

  /// 更新事件（根据 uid）
  void updateEvent(CalendarEvent event) {
    final updated = Map<DateTime, List<CalendarEvent>>.from(state.events);

    // 先从所有日期里移除旧事件
    for (final entry in updated.entries.toList()) {
      updated[entry.key] =
          entry.value.where((e) => e.uid != event.uid).toList(growable: true);
      if (updated[entry.key]!.isEmpty) {
        updated.remove(entry.key);
      }
    }

    // 再按新开始日期插入
    final key = DateTime(event.start.year, event.start.month, event.start.day);
    final list = <CalendarEvent>[...(updated[key] ?? const <CalendarEvent>[]), event];
    updated[key] = list;

    state = state.copyWith(events: updated);
    // 保存到存储
    _saveAllEvents();
    // 取消旧提醒并调度新提醒
    _cancelEventReminders(event.uid);
    _scheduleEventReminders(event);
  }

  /// 取消事件的提醒
  Future<void> _cancelEventReminders(String eventUid) async {
    try {
      await _notificationService.cancelEventReminders(eventUid);
    } catch (e) {
      // 取消失败时忽略错误
    }
  }

  /// 删除事件
  void removeEvent(String uid) {
    final updated = Map<DateTime, List<CalendarEvent>>.from(state.events);
    for (final entry in updated.entries.toList()) {
      updated[entry.key] =
          entry.value.where((e) => e.uid != uid).toList(growable: true);
      if (updated[entry.key]!.isEmpty) {
        updated.remove(entry.key);
      }
    }
    state = state.copyWith(events: updated);
    // 先从存储中删除事件
    _deleteEventFromStorage(uid);
    // 保存到存储（同步剩余事件）
    _saveAllEvents();
    // 取消提醒
    _cancelEventReminders(uid);
  }

  /// 从存储中删除事件
  Future<void> _deleteEventFromStorage(String uid) async {
    try {
      await _storageService.deleteEvent(uid);
    } catch (e) {
      // 删除失败时忽略错误，避免影响用户体验
    }
  }
}

/// StorageService Provider
/// 注意：存储服务应该在 main.dart 中初始化后再使用
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'StorageService should be initialized in main.dart and provided via override',
  );
});

/// Provider：对外暴露 CalendarState
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return CalendarNotifier(storageService);
});

