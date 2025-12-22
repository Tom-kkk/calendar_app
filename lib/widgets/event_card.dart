import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';

/// 通用事件卡片组件
///
/// - 用于在日视图、周视图、月视图中复用
/// - 支持可选的时间展示（例如在高度很小的块中只显示标题）
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.showTime = true,
    this.onTap,
  });

  /// 日历事件
  final CalendarEvent event;

  /// 是否显示开始/结束时间
  final bool showTime;

  /// 点击回调（例如打开详情）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm', 'zh_CN').format(event.start);
    final endTime = DateFormat('HH:mm', 'zh_CN').format(event.end);
    final color = event.colorHex != null
        ? Color(event.colorHex!)
        : Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border(
            left: BorderSide(
              color: color,
              width: 3,
            ),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showTime) ...[
              const SizedBox(height: 2),
              Text(
                '$startTime - $endTime',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

