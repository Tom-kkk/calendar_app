import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';

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
  CalendarNotifier()
      : super(
          CalendarState(
            selectedDate: DateTime.now(),
            currentView: CalendarView.month,
          ),
        );

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
  }
}

/// Provider：对外暴露 CalendarState
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});

