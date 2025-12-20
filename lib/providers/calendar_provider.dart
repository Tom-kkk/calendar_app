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

  List<CalendarEvent> eventsFor(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return state.events[key] ?? const [];
  }

  void addEvent(CalendarEvent event) {
    final key = DateTime(event.start.year, event.start.month, event.start.day);
    final updated = Map<DateTime, List<CalendarEvent>>.from(state.events);
    final list = <CalendarEvent>[...(updated[key] ?? const <CalendarEvent>[]), event];
    updated[key] = list;
    state = state.copyWith(events: updated);
  }
}

/// Provider：对外暴露 CalendarState
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});

