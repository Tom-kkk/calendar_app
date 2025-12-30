import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';
import '../utils/lunar_utils.dart';
import 'event_form_view.dart';

/// 周视图组件
/// 显示一周7天的日程安排，支持时间轴展示
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key});

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
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
    _timeLabelController.addListener(_syncFromLabels);
    _contentController.addListener(_syncFromContent);
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

  void _syncFromContent() {
    if (_isSyncing) return;
    _isSyncing = true;
    _timeLabelController.jumpTo(_contentController.offset.clamp(
      _timeLabelController.position.minScrollExtent,
      _timeLabelController.position.maxScrollExtent,
    ));
    _isSyncing = false;
  }

  /// 获取一周的开始日期（周一）
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1=Monday, 7=Sunday
    return date.subtract(Duration(days: weekday - 1));
  }

  /// 获取一周的所有日期
  List<DateTime> _getWeekDays(DateTime date) {
    final weekStart = _getWeekStart(date);
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
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
    // 优先使用模型的isAllDay属性
    if (event.isAllDay) {
      return true;
    }
    // 兼容旧数据：如果开始时间为00:00且结束时间为23:59，也认为是全天事件
    return event.start.hour == 0 &&
        event.start.minute == 0 &&
        event.end.hour == 23 &&
        event.end.minute == 59;
  }

  /// 获取当天开始时间（00:00）
  DateTime _getDayStart(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 判断事件是否跨越多个日期
  bool _isMultiDayEvent(CalendarEvent event, DateTime day) {
    final dayStart = _getDayStart(day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return event.start.isBefore(dayEnd) && event.end.isAfter(dayStart);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final selectedDate = state.selectedDate;
    final weekDays = _getWeekDays(selectedDate);

    return Column(
      children: [
        // 周头部：显示日期和导航
        _buildWeekHeader(weekDays, selectedDate),
        const Divider(height: 1),
        // 时间轴区域（上方显示日期头，全天事件行，下方同步滚动时间轴）
        Expanded(
          child: Column(
            children: [
              _buildDayHeaderRow(weekDays),
              Container(height: 1, color: Theme.of(context).dividerColor),
              // 全天事件区域
              _buildAllDayEventsRow(weekDays),
              Expanded(child: _buildWeekTimeAxis(weekDays)),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建周头部
  Widget _buildWeekHeader(List<DateTime> weekDays, DateTime selectedDate) {
    final weekStart = weekDays.first;
    final isCurrentWeek = _isCurrentWeek(weekStart);
    final weekNumber = _getWeekNumber(weekStart);
    final year = weekStart.year;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 周信息
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year年第$weekNumber周',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (isCurrentWeek)
                  Text(
                    '本周',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
          ),
          // 导航按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  ref.read(calendarProvider.notifier).goPreviousWeek();
                },
                tooltip: '上一周',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              TextButton(
                onPressed: () {
                  ref.read(calendarProvider.notifier).goToday();
                },
                child: const Text('今天'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(calendarProvider.notifier).goNextWeek();
                },
                tooltip: '下一周',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 判断是否为当前周
  bool _isCurrentWeek(DateTime weekStart) {
    final now = DateTime.now();
    final currentWeekStart = _getWeekStart(now);
    return weekStart.year == currentWeekStart.year &&
        weekStart.month == currentWeekStart.month &&
        weekStart.day == currentWeekStart.day;
  }

  /// 计算一年中的第几周（ISO 8601标准）
  /// 第一周是包含1月4日的那一周
  int _getWeekNumber(DateTime date) {
    final year = date.year;
    final jan4 = DateTime(year, 1, 4);
    final jan4Weekday = jan4.weekday; // 1=Monday, 7=Sunday
    
    // 计算第一周的开始日期（包含1月4日的周一）
    final firstWeekStart = jan4.subtract(Duration(days: jan4Weekday - 1));
    
    // 计算当前日期所在周的开始日期
    final currentWeekStart = _getWeekStart(date);
    
    // 如果当前周的开始日期在1月4日之前，可能属于上一年的最后一周
    if (currentWeekStart.isBefore(firstWeekStart)) {
      // 检查是否属于上一年的最后一周
      final prevYearDec31 = DateTime(year - 1, 12, 31);
      final prevYearWeekStart = _getWeekStart(prevYearDec31);
      if (currentWeekStart.year == year - 1 && 
          currentWeekStart.isAfter(prevYearDec31.subtract(const Duration(days: 6)))) {
        // 属于上一年的最后一周，需要计算上一年的周数
        return _getWeekNumber(prevYearDec31);
      }
      return 1; // 否则是第一周
    }
    
    // 计算从第一周开始到当前周的天数差
    final daysDiff = currentWeekStart.difference(firstWeekStart).inDays;
    final weekNumber = (daysDiff ~/ 7) + 1;
    
    // 检查是否超出52周（有些年份有53周）
    return weekNumber > 53 ? 53 : weekNumber;
  }

  /// 构建日期头部横排
  Widget _buildDayHeaderRow(List<DateTime> weekDays) {
    return Row(
      children: [
        // 占位，与左侧时间刻度宽度保持一致，保证日期头与事件列对齐
        SizedBox(
          width: 61, // 60刻度 + 1分隔线
        ),
        // 日期列
        Expanded(
          child: Row(
            children: weekDays.asMap().entries.expand((entry) {
              final index = entry.key;
              final day = entry.value;
              final isLast = index == weekDays.length - 1;
              return [
                Expanded(child: _buildDayHeader(day)),
                  if (!isLast)
                  Container(
                    width: 1,
                    color: Theme.of(context).dividerColor,
                  ),
              ];
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建全天事件行
  Widget _buildAllDayEventsRow(List<DateTime> weekDays) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间标签列（与时间轴对齐，60+1=61像素）
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 12),
              child: Text(
                '全天',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          // 分隔线（与时间轴对齐）
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          // 日期列
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekDays.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final isLast = index == weekDays.length - 1;
                final events = _getEventsForDay(day);
                final allDayEvents = events.where(_isAllDayEvent).toList();
                return Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : Border(
                              right: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                    ),
                    child: allDayEvents.isEmpty
                        ? const SizedBox.shrink()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth.isFinite 
                                  ? constraints.maxWidth 
                                  : double.infinity;
                              // 确保每个事件卡片的最大宽度不超过可用空间减去边距
                              final maxEventWidth = availableWidth > 8 
                                  ? availableWidth - 8 
                                  : availableWidth;
                              return Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: allDayEvents.map<Widget>((event) {
                                  return SizedBox(
                                    width: maxEventWidth > 0 ? maxEventWidth : null,
                                    child: _buildAllDayEventChip(event),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建全天事件标签
  Widget _buildAllDayEventChip(CalendarEvent event) {
    final color = event.colorHex != null
        ? Color(event.colorHex!)
        : Theme.of(context).colorScheme.primary;
    final backgroundColor = color.withOpacity(0.15);
    final borderColor = color.withOpacity(0.4);
    
    return Material(
      color: Colors.transparent,
      child: ClipRect(
        child: InkWell(
          onTap: () {
            _showEventDetails(event);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              // 使用最大主轴尺寸，配合 Expanded 防止文本溢出报错
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // 颜色指示点
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                // 事件标题 - 使用 Expanded 占满剩余空间，避免文字溢出
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建周时间轴（时间刻度与事件区域同步滚动）
  Widget _buildWeekTimeAxis(List<DateTime> weekDays) {
    // 每小时60像素，总共1440像素
    const hourHeight = 60.0;
    const totalHeight = 24 * hourHeight;
    final hours = List.generate(24, (index) => index);

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
        // 日期列（统一一个垂直滚动器，避免多控件共用同一controller）
        Expanded(
          child: SingleChildScrollView(
            controller: _contentController,
            child: SizedBox(
              height: totalHeight,
              child: Row(
                children: weekDays.asMap().entries.expand((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final isLast = index == weekDays.length - 1;
                  return [
                    Expanded(
                      child: GestureDetector(
                        onTapDown: (details) {
                          _handleTimeAxisTap(details, day, hourHeight);
                        },
                        child: Stack(
                          children: [
                            _buildTimeGrid(hours, hourHeight),
                            ..._buildDayEvents(day, hourHeight),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                  ];
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建日期头部
  Widget _buildDayHeader(DateTime day) {
    final isToday = _isToday(day);
    final isSelected = ref.watch(calendarProvider).selectedDate.year == day.year &&
        ref.watch(calendarProvider).selectedDate.month == day.month &&
        ref.watch(calendarProvider).selectedDate.day == day.day;
    final events = _getEventsForDay(day);
    final allDayEvents = events.where(_isAllDayEvent).toList();
    final lunarInfo = LunarUtils.getLunarInfo(day);
    final solarTerm = lunarInfo['solarTerm'];
    final festival = lunarInfo['festival'];
    final lunarDay = lunarInfo['lunarDay'];
    
    // 确定显示文本和颜色
    String displayText = '';
    Color textColor;
    FontWeight fontWeight = FontWeight.normal;
    
    if (solarTerm != null) {
      displayText = solarTerm;
      textColor = Theme.of(context).colorScheme.error;
      fontWeight = FontWeight.bold;
    } else if (festival != null) {
      displayText = festival;
      textColor = Theme.of(context).colorScheme.primary;
      fontWeight = FontWeight.bold;
    } else {
      // 默认只显示农历“日”，不包含月份
      displayText = lunarDay ?? '';
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }

    return InkWell(
      onTap: () {
        ref.read(calendarProvider.notifier).selectDate(day);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // 星期
            Text(
              DateFormat('E', 'zh_CN').format(day),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
            const SizedBox(height: 4),
            // 日期
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isToday
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            // 农历日期、节气或传统节日
            if (displayText.isNotEmpty)
              Text(
                displayText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: textColor,
                      fontWeight: fontWeight,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  /// 判断是否为今天
  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  /// 构建时间网格线
  Widget _buildTimeGrid(List<int> hours, double hourHeight) {
    return SizedBox(
      height: hours.length * hourHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: hours.asMap().entries.map((entry) {
          final index = entry.key;
          final hour = entry.value;
          // 最后一个小时不需要底部边框，避免溢出
          final isLast = index == hours.length - 1;
          return SizedBox(
            height: hourHeight,
            child: Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建某一天的事件块
  List<Widget> _buildDayEvents(DateTime day, double hourHeight) {
    final dayStart = _getDayStart(day);
    final events = _getEventsForDay(day);
    final timedEvents = events.where((e) => !_isAllDayEvent(e)).toList();

    return timedEvents.map<Widget>((event) {
      // 计算事件在时间轴上的位置
      final eventStart = event.start.isBefore(dayStart) ? dayStart : event.start;
      final eventEnd = event.end.isAfter(dayStart.add(const Duration(days: 1)))
          ? dayStart.add(const Duration(days: 1))
          : event.end;

      final top = _getEventTopPosition(eventStart, dayStart);
      final height = _getEventHeight(eventStart, eventEnd);
      final topPixels = top;
      final heightPixels = height.clamp(20.0, double.infinity);

      return Positioned(
        left: 4,
        right: 4,
        top: topPixels,
        height: heightPixels,
        child: EventCard(
          event: event,
          showTime: heightPixels > 30,
          onTap: () => _showEventDetails(event),
        ),
      );
    }).toList();
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
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _editEvent(event);
                },
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
              ),
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
            ],
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

  /// 创建新事件
  void _createNewEvent(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFormView(
          initialDate: date,
        ),
      ),
    );
  }

  /// 处理时间轴点击事件
  void _handleTimeAxisTap(TapDownDetails details, DateTime day, double hourHeight) {
    // 计算点击位置对应的时间（分钟）
    final localPosition = details.localPosition;
    final minutes = localPosition.dy;
    final hours = (minutes / hourHeight).floor();
    final mins = ((minutes % hourHeight) / hourHeight * 60).floor();
    
    // 创建新事件的开始时间
    final dayStart = _getDayStart(day);
    final startTime = dayStart.add(Duration(hours: hours, minutes: mins));
    // 结束时间默认为开始时间后1小时
    final endTime = startTime.add(const Duration(hours: 1));
    
    // 打开新建事件表单
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFormView(
          initialDate: startTime,
        ),
      ),
    );
  }
}
