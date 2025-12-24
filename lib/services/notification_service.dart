import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/calendar_event.dart';
import '../models/reminder_settings.dart';

/// 通知服务
/// 负责管理日程提醒的本地通知
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 通用初始化设置
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 初始化插件
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android 请求权限（Android 13+）
    await _requestAndroidPermissions();

    _initialized = true;
  }

  /// Android 权限请求（Android 13+）
  Future<void> _requestAndroidPermissions() async {
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  /// 处理通知点击事件
  void _onNotificationTapped(NotificationResponse response) {
    // 可以在这里处理通知点击后的操作
    // 例如：打开事件详情页面
    // 目前只记录，可以根据需要扩展
  }

  /// 调度事件的所有提醒
  /// [event] 要调度提醒的事件
  Future<void> scheduleEventReminders(CalendarEvent event) async {
    if (!_initialized) {
      await initialize();
    }

    // 取消该事件的所有旧提醒
    await cancelEventReminders(event.uid);

    // 如果事件已过期，不调度提醒
    if (event.end.isBefore(DateTime.now())) {
      return;
    }

    // 为每个提醒设置调度通知
    for (final reminder in event.reminders) {
      if (reminder.type != ReminderType.notification) {
        continue; // 只处理通知类型的提醒
      }

      // 计算提醒触发时间
      final triggerTime = event.start.subtract(reminder.beforeTime);

      // 如果提醒时间已过，跳过
      if (triggerTime.isBefore(DateTime.now())) {
        continue;
      }

      // 生成唯一通知ID（使用事件UID和提醒ID组合）
      final notificationId = _generateNotificationId(event.uid, reminder.id);

      // 设置通知详情
      final notificationDetails = _buildNotificationDetails(event, reminder);

      // 调度通知（payload用于标识事件UID，便于取消）
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        event.title,
        _buildNotificationBody(event),
        tz.TZDateTime.from(triggerTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: event.uid, // 使用事件UID作为payload
      );
    }
  }

  /// 取消事件的所有提醒
  Future<void> cancelEventReminders(String eventUid) async {
    if (!_initialized) return;

    // 获取所有已调度的通知
    final pendingNotifications =
        await _notificationsPlugin.pendingNotificationRequests();

    // 找出属于该事件的所有通知并取消
    for (final notification in pendingNotifications) {
      if (notification.payload == eventUid) {
        await _notificationsPlugin.cancel(notification.id);
      }
    }
  }

  /// 取消特定提醒
  Future<void> cancelReminder(String eventUid, String reminderId) async {
    if (!_initialized) return;

    final notificationId = _generateNotificationId(eventUid, reminderId);
    await _notificationsPlugin.cancel(notificationId);
  }

  /// 重新调度所有未过期事件的提醒
  /// [events] 所有事件列表
  Future<void> rescheduleAllReminders(Iterable<CalendarEvent> events) async {
    if (!_initialized) {
      await initialize();
    }

    // 先取消所有现有通知（可选，或者更智能地只更新需要更新的）
    await _notificationsPlugin.cancelAll();

    // 为每个未过期的事件调度提醒
    final now = DateTime.now();
    for (final event in events) {
      if (event.end.isAfter(now)) {
        await scheduleEventReminders(event);
      }
    }
  }

  /// 生成通知ID
  /// 使用事件UID和提醒ID的哈希值组合
  int _generateNotificationId(String eventUid, String reminderId) {
    final combined = '$eventUid:$reminderId';
    return combined.hashCode.abs() % 2147483647; // 确保ID在有效范围内
  }

  /// 构建通知详情
  NotificationDetails _buildNotificationDetails(
    CalendarEvent event,
    ReminderSetting reminder,
  ) {
    // Android 通知详情
    final androidDetails = AndroidNotificationDetails(
      'calendar_reminders', // 频道ID
      '日程提醒', // 频道名称
      channelDescription: '显示日程事件的提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    // iOS 通知详情
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// 构建通知正文
  String _buildNotificationBody(CalendarEvent event) {
    final buffer = StringBuffer();

    // 添加时间信息
    if (event.isAllDay) {
      buffer.writeln('全天事件');
    } else {
      final startTime = _formatDateTime(event.start);
      final endTime = _formatDateTime(event.end);
      buffer.writeln('$startTime - $endTime');
    }

    // 添加地点信息
    if (event.location != null && event.location!.isNotEmpty) {
      buffer.writeln('📍 ${event.location}');
    }

    // 添加描述信息（如果有且较短）
    if (event.description != null &&
        event.description!.isNotEmpty &&
        event.description!.length <= 100) {
      buffer.writeln(event.description);
    }

    return buffer.toString().trim();
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (eventDay.isAtSameMomentAs(today)) {
      dateStr = '今天';
    } else if (eventDay.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      dateStr = '明天';
    } else if (eventDay.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      dateStr = '昨天';
    } else {
      dateStr = '${dateTime.month}月${dateTime.day}日';
    }

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    return '$dateStr $timeStr';
  }

  /// 获取所有待处理的通知数量
  Future<int> getPendingNotificationsCount() async {
    if (!_initialized) return 0;
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    return pending.length;
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    await _notificationsPlugin.cancelAll();
  }
}

