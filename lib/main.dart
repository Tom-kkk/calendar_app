import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'models/calendar_event.dart';
import 'models/reminder_settings.dart';
import 'providers/calendar_provider.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'views/day_view.dart';
import 'views/week_view.dart';
import 'views/month_view.dart';
import 'views/event_form_view.dart';
import 'utils/lunar_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // 本地存储初始化

  // 注册 Hive 适配器
  Hive.registerAdapter(CalendarEventAdapter());
  Hive.registerAdapter(ReminderSettingAdapter());

  // 初始化存储服务
  final storageService = StorageService();
  await storageService.init();

  tz.initializeTimeZones(); // 加载时区数据，供本地通知使用
  await initializeDateFormatting('zh_CN', null); // 初始化中文本地化数据

  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(ProviderScope(
    overrides: [
      // 提供已初始化的存储服务实例
      storageServiceProvider.overrideWithValue(storageService),
    ],
    child: const MainApp(),
  ));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        useMaterial3: true,
      ),
      home: Consumer(
        builder: (context, ref, _) {
          final calendar = ref.watch(calendarProvider);
          final notifier = ref.read(calendarProvider.notifier);

          return DefaultTabController(
            initialIndex: _viewToIndex(calendar.currentView),
            length: 3,
            child: Builder(
              builder: (context) {
                final date = calendar.selectedDate;
                final theme = Theme.of(context);
                final weekNumber = _getWeekNumber(date);
                final lunarDateStr = LunarUtils.getLunarDateString(date);

                return Scaffold(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  body: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '第$weekNumber周',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.expand_less),
                                    onPressed: () {},
                                    tooltip: '展开/收起',
                                  ),
                                  const _OverflowMenu(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy年MM月dd日', 'zh_CN').format(date),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '农历 $lunarDateStr',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TabBar(
                              onTap: (index) => notifier.switchView(_indexToView(index)),
                              indicator: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelColor: theme.colorScheme.onPrimary,
                              unselectedLabelColor:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                              tabs: const [
                                Tab(text: '日'),
                                Tab(text: '周'),
                                Tab(text: '月'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const TabBarView(
                              children: [
                                DayView(),
                                WeekView(),
                                MonthView(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      final selectedDate = calendar.selectedDate;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EventFormView(
                            initialDate: selectedDate,
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

int _viewToIndex(CalendarView view) {
  switch (view) {
    case CalendarView.day:
      return 0;
    case CalendarView.week:
      return 1;
    case CalendarView.month:
      return 2;
  }
}

CalendarView _indexToView(int index) {
  switch (index) {
    case 0:
      return CalendarView.day;
    case 1:
      return CalendarView.week;
    case 2:
    default:
      return CalendarView.month;
  }
}

int _getWeekNumber(DateTime date) {
  final year = date.year;
  final jan4 = DateTime(year, 1, 4);
  final jan4Weekday = jan4.weekday;
  final firstWeekStart = jan4.subtract(Duration(days: jan4Weekday - 1));
  final weekStart = date.subtract(Duration(days: date.weekday - 1));
  if (weekStart.isBefore(firstWeekStart)) {
    final prevYearDec31 = DateTime(year - 1, 12, 31);
    return _getWeekNumber(prevYearDec31);
  }
  final daysDiff = weekStart.difference(firstWeekStart).inDays;
  final weekNumber = (daysDiff ~/ 7) + 1;
  return weekNumber > 53 ? 53 : weekNumber;
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'test_notification') {
          // 测试通知功能
          final notificationService = NotificationService();
          await notificationService.showTestNotification(
            title: '日程提醒测试',
            body: '今天 14:30 - 15:30\n📍 会议室A\n这是一个测试通知，用于验证通知功能',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('测试通知已发送，请查看通知栏'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (value == 'settings') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('设置功能开发中')),
            );
          }
        } else if (value == 'view_options') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('视图选项功能开发中')),
            );
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'test_notification',
          child: Row(
            children: [
              Icon(Icons.notifications_active, size: 20),
              SizedBox(width: 8),
              Text('测试通知'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: Text('设置'),
        ),
        PopupMenuItem(
          value: 'view_options',
          child: Text('视图选项'),
        ),
      ],
    );
  }
}
