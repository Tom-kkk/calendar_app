import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';
import 'event_form_view.dart';

/// 月视图组件
/// 使用table_calendar库实现完整的月视图功能
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 同步外部选中的日期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(calendarProvider);
      if (!isSameDay(state.selectedDate, _selectedDay)) {
        final selected = state.selectedDate;
        setState(() {
          _selectedDay = DateTime(selected.year, selected.month, selected.day);
          _focusedDay = DateTime(selected.year, selected.month, selected.day);
        });
      }
    });
  }

  /// 将DateTime转换为只包含年月日的键（用于事件映射）
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取指定日期的事件列表
  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final notifier = ref.read(calendarProvider.notifier);
    final normalized = _normalizeDate(day);
    return notifier.eventsFor(normalized);
  }

  /// 获取指定日期是否有事件
  bool _isEventDay(DateTime day) {
    return _getEventsForDay(day).isNotEmpty;
  }

  /// 获取指定日期的事件数量
  int _getEventCount(DateTime day) {
    return _getEventsForDay(day).length;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    // 同步选中日期和焦点日期
    final normalizedSelected = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );
    if (!isSameDay(_selectedDay, normalizedSelected)) {
      _selectedDay = normalizedSelected;
      // 如果选中的日期不在当前显示的月份，更新focusedDay
      if (_focusedDay.year != normalizedSelected.year ||
          _focusedDay.month != normalizedSelected.month) {
        _focusedDay = normalizedSelected;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(1900, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarFormat: _calendarFormat,
            locale: 'zh_CN',
            availableCalendarFormats: const {
              CalendarFormat.month: '月',
              CalendarFormat.twoWeeks: '两周',
              CalendarFormat.week: '周',
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              formatButtonTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              defaultTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
              markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
              weekendStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                // 更新全局状态
                notifier.selectDate(selectedDay);
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              // 当月份切换时，同步更新全局状态（但不改变选中日期）
              // 如果当前选中的日期不在新月份中，则选中新月份的第一天
              if (_focusedDay.year != _selectedDay.year ||
                  _focusedDay.month != _selectedDay.month) {
                // 保持选中日期不变，只更新focusedDay
              }
            },
            // 自定义事件标记构建器
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                
                // 如果事件数量超过3个，显示数字
                if (events.length > 3) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${events.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                
                // 显示事件标记点
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events.take(3).map<Widget>((event) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: event.colorHex != null
                            ? Color(event.colorHex!)
                            : Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        // 选中日期的事件列表
        Expanded(
          child: _buildEventList(state),
        ),
      ],
    );
  }

  /// 构建选中日期的事件列表
  Widget _buildEventList(CalendarState state) {
    final events = _getEventsForDay(_selectedDay);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '${DateFormat('yyyy年MM月dd日', 'zh_CN').format(_selectedDay)}\n暂无事件',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDay),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventCard(event);
            },
          ),
        ),
      ],
    );
  }

  /// 构建事件卡片
  Widget _buildEventCard(CalendarEvent event) {
    final isAllDay = event.start.hour == 0 &&
        event.start.minute == 0 &&
        event.end.hour == 23 &&
        event.end.minute == 59;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: EventCard(
          event: event,
          showTime: !isAllDay,
          onTap: () {
            _showEventDetails(event);
          },
        ),
      ),
    );
  }

  /// 显示事件详情
  void _showEventDetails(CalendarEvent event) {
    final startTime = DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN').format(event.start);
    final endTime = DateFormat('yyyy年MM月dd日 HH:mm', 'zh_CN').format(event.end);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.description != null && event.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '描述: ${event.description}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text('开始时间: $startTime'),
              Text('结束时间: $endTime'),
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('地点: ${event.location}'),
              ],
              if (event.isAllDay) ...[
                const SizedBox(height: 8),
                const Text('全天事件'),
              ],
              if (event.reminders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '提醒: ${event.reminders.map((r) {
                    final minutes = r.beforeTime.inMinutes;
                    if (minutes < 60) {
                      return '提前 $minutes 分钟';
                    } else if (minutes < 1440) {
                      return '提前 ${minutes ~/ 60} 小时';
                    } else {
                      return '提前 ${minutes ~/ 1440} 天';
                    }
                  }).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteEvent(event);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('删除'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _editEvent(event);
            },
            icon: const Icon(Icons.edit),
            label: const Text('编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 编辑事件
  void _editEvent(CalendarEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFormView(event: event),
      ),
    );
  }

  /// 删除事件
  void _deleteEvent(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除事件"${event.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(calendarProvider.notifier).removeEvent(event.uid);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('事件已删除')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

