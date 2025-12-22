import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';

/// 日视图组件
/// 显示单日详细时间轴，精确到小时/分钟
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  late final ScrollController _timeLabelController;
  late final ScrollController _contentController;
  bool _isSyncing = false;

  @override
  void dispose() {
    _timeLabelController
      ..removeListener(_syncFromLabels)
      ..dispose();
    _contentController
      ..removeListener(_syncFromContent)
      ..dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _timeLabelController = ScrollController();
    _contentController = ScrollController();
    _contentController.addListener(_syncFromContent);
    _timeLabelController.addListener(_syncFromLabels);
  }

  void _syncFromContent() {
    if (_isSyncing) return;
    _isSyncing = true;
    _timeLabelController.jumpTo(_contentController.offset.clamp(
      _timeLabelController.position.minScrollExtent,
      _timeLabelController.position.maxScrollExtent,
    ));
    _isSyncing = false;
  }

  void _syncFromLabels() {
    if (_isSyncing) return;
    _isSyncing = true;
    _contentController.jumpTo(_timeLabelController.offset.clamp(
      _contentController.position.minScrollExtent,
      _contentController.position.maxScrollExtent,
    ));
    _isSyncing = false;
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

  /// 计算事件在时间轴上的位置（以分钟为单位）
  double _getEventTopPosition(DateTime startTime, DateTime dayStart) {
    final diff = startTime.difference(dayStart);
    return diff.inMinutes.toDouble();
  }

  /// 计算事件的高度（以分钟为单位）
  double _getEventHeight(DateTime startTime, DateTime endTime) {
    final diff = endTime.difference(startTime);
    return diff.inMinutes.toDouble();
  }

  /// 判断是否为全天事件
  bool _isAllDayEvent(CalendarEvent event) {
    return event.start.hour == 0 &&
        event.start.minute == 0 &&
        event.end.hour == 23 &&
        event.end.minute == 59;
  }

  /// 获取当天开始时间（00:00）
  DateTime _getDayStart(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final selectedDate = state.selectedDate;
    final dayStart = _getDayStart(selectedDate);
    final events = _getEventsForDay(selectedDate);
    
    // 分离全天事件和普通事件
    final allDayEvents = events.where(_isAllDayEvent).toList();
    final timedEvents = events.where((e) => !_isAllDayEvent(e)).toList();

    return Column(
      children: [
        // 日期头部
        _buildDayHeader(selectedDate),
        const Divider(height: 1),
        // 全天事件区域
        if (allDayEvents.isNotEmpty) _buildAllDayEvents(allDayEvents),
        // 时间轴区域
        Expanded(
          child: _buildTimeAxis(dayStart, timedEvents),
        ),
      ],
    );
  }

  /// 构建日期头部
  Widget _buildDayHeader(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 日期信息
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy年MM月dd日', 'zh_CN').format(date),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                DateFormat('EEEE', 'zh_CN').format(date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
          // 导航按钮
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  ref.read(calendarProvider.notifier).goPreviousDay();
                },
                tooltip: '上一天',
              ),
              TextButton(
                onPressed: () {
                  ref.read(calendarProvider.notifier).goToday();
                },
                child: const Text('今天'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(calendarProvider.notifier).goNextDay();
                },
                tooltip: '下一天',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建全天事件区域
  Widget _buildAllDayEvents(List<CalendarEvent> events) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '全天',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: events.map<Widget>((event) {
              return _buildAllDayEventChip(event);
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建全天事件标签
  Widget _buildAllDayEventChip(CalendarEvent event) {
    return InkWell(
      onTap: () {
        _showEventDetails(event);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: event.colorHex != null
              ? Color(event.colorHex!).withOpacity(0.2)
              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
          border: Border(
            left: BorderSide(
              color: event.colorHex != null
                  ? Color(event.colorHex!)
                  : Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          event.title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: event.colorHex != null
                ? Color(event.colorHex!)
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// 构建时间轴
  Widget _buildTimeAxis(DateTime dayStart, List<CalendarEvent> events) {
    // 生成24小时的时间刻度
    final hours = List.generate(24, (index) => index);
    // 每小时60像素，总共1440像素
    const hourHeight = 60.0;
    const totalHeight = 24 * hourHeight;

    return Row(
      children: [
        // 时间标签列（固定宽度）
        SizedBox(
          width: 60,
          child: ListView.builder(
            controller: _timeLabelController,
            itemCount: hours.length,
            itemBuilder: (context, index) {
              final hour = hours[index];
              return Container(
                height: hourHeight,
                padding: const EdgeInsets.only(right: 8, top: 4),
                alignment: Alignment.topRight,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
              );
            },
          ),
        ),
        // 分隔线
        Container(
          width: 1,
          color: Theme.of(context).dividerColor,
        ),
        // 事件区域（可滚动）
        Expanded(
          child: SingleChildScrollView(
            controller: _contentController,
            child: SizedBox(
              height: totalHeight,
              child: Stack(
                children: [
                  // 时间网格线
                  _buildTimeGrid(hours, hourHeight),
                  // 事件块
                  ...events.map((event) => _buildEventBlock(event, dayStart, hourHeight)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建时间网格线
  Widget _buildTimeGrid(List<int> hours, double hourHeight) {
    return Column(
      children: hours.map((hour) {
        return Container(
          height: hourHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建事件块
  Widget _buildEventBlock(CalendarEvent event, DateTime dayStart, double hourHeight) {
    // 计算事件在时间轴上的位置
    final top = _getEventTopPosition(event.start, dayStart);
    final height = _getEventHeight(event.start, event.end);
    
    // 每分钟对应1像素，每小时60像素
    final topPixels = top;
    final heightPixels = height.clamp(20.0, double.infinity); // 最小高度20像素

    return Positioned(
      left: 8,
      right: 8,
      top: topPixels,
      height: heightPixels,
      child: EventCard(
        event: event,
        showTime: heightPixels > 30,
        onTap: () => _showEventDetails(event),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('开始时间: $startTime'),
            Text('结束时间: $endTime'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
