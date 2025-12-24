import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';

/// 事件列表状态
class EventState {
  const EventState({
    this.isLoading = false,
    this.errorMessage,
    this.events = const <CalendarEvent>[],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<CalendarEvent> events;

  EventState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<CalendarEvent>? events,
  }) {
    return EventState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      events: events ?? this.events,
    );
  }
}

/// 负责事件的加载 / 增删改查 / 筛选
class EventNotifier extends StateNotifier<EventState> {
  EventNotifier() : super(const EventState());

  /// 从数据源加载事件，loader 由上层注入，便于替换 Hive / sqflite 等实现
  Future<void> loadEvents(Future<List<CalendarEvent>> Function() loader) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await loader();
      state = state.copyWith(isLoading: false, events: List.unmodifiable(list));
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 新增事件
  void addEvent(CalendarEvent event) {
    final updated = [...state.events, event];
    state = state.copyWith(events: List.unmodifiable(updated));
  }

  /// 更新事件（按 uid 匹配）
  void updateEvent(CalendarEvent event) {
    final updated = state.events
        .map((e) => e.uid == event.uid ? event : e)
        .toList(growable: false);
    state = state.copyWith(events: List.unmodifiable(updated));
  }

  /// 删除事件
  void deleteEvent(String uid) {
    final updated =
        state.events.where((e) => e.uid != uid).toList(growable: false);
    state = state.copyWith(events: List.unmodifiable(updated));
  }

  /// 指定日期的事件
  List<CalendarEvent> eventsForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return state.events
        .where((e) => e.isOnDate(day))
        .toList(growable: false);
  }

  /// 指定时间范围内的事件
  List<CalendarEvent> eventsInRange(DateTime start, DateTime end) {
    return state.events
        .where((e) => e.overlapsWith(start, end))
        .toList(growable: false);
  }
}

/// 对外暴露的事件 Provider
final eventProvider =
    StateNotifierProvider<EventNotifier, EventState>((ref) {
  return EventNotifier();
});


