import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/event_card.dart';
import 'event_form_view.dart';

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
        // 全天事件区域（始终显示，即使没有事件也显示时间标签）
        _buildAllDayEvents(allDayEvents),
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('yyyy年MM月dd日', 'zh_CN').format(date),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('EEEE', 'zh_CN').format(date),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                  overflow: TextOverflow.ellipsis,
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
                  ref.read(calendarProvider.notifier).goPreviousDay();
                },
                tooltip: '上一天',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              TextButton(
                onPressed: () {
                  ref.read(calendarProvider.notifier).goToday();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('今天'),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  ref.read(calendarProvider.notifier).goNextDay();
                },
                tooltip: '下一天',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
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
          // 时间标签列（与时间轴对齐）
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
          // 事件内容区域
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: events.isEmpty
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth.isFinite 
                            ? constraints.maxWidth 
                            : double.infinity;
                        // 确保每个事件卡片的最大宽度不超过可用空间减去边距
                        final maxEventWidth = availableWidth > 16 
                            ? availableWidth - 16 
                            : availableWidth;
                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: events.map<Widget>((event) {
                            return SizedBox(
                              width: maxEventWidth > 0 ? maxEventWidth : null,
                              child: _buildAllDayEventChip(event),
                            );
                          }).toList(),
                        );
                      },
                    ),
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
      child: InkWell(
        onTap: () {
          _showEventDetails(event);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 6),
              // 事件标题 - 使用Flexible确保不会溢出
              Flexible(
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
              child: GestureDetector(
                onTapDown: (details) {
                  _handleTimeAxisTap(details, dayStart, hourHeight);
                },
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
        ),
      ],
    );
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
      right: 4,
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
  void _handleTimeAxisTap(TapDownDetails details, DateTime dayStart, double hourHeight) {
    // 计算点击位置对应的时间（分钟）
    final localPosition = details.localPosition;
    final minutes = localPosition.dy;
    final hours = (minutes / hourHeight).floor();
    final mins = ((minutes % hourHeight) / hourHeight * 60).floor();
    
    // 创建新事件的开始时间
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
