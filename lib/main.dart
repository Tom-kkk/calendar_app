import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'providers/calendar_provider.dart';
import 'views/day_view.dart';
import 'views/week_view.dart';
import 'views/month_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // 本地存储初始化
  tz.initializeTimeZones(); // 加载时区数据，供本地通知使用
  await initializeDateFormatting('zh_CN', null); // 初始化中文本地化数据

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          final calendar = ref.watch(calendarProvider);
          final notifier = ref.read(calendarProvider.notifier);

          return DefaultTabController(
            initialIndex: _viewToIndex(calendar.currentView),
            length: 3,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Calendar'),
                    actions: const [_OverflowMenu()],
                    bottom: TabBar(
                      onTap: (index) => notifier.switchView(_indexToView(index)),
                      tabs: const [
                        Tab(text: '日'),
                        Tab(text: '周'),
                        Tab(text: '月'),
                      ],
                    ),
                  ),
                  body: const TabBarView(
                    children: [
                      DayView(),
                      WeekView(),
                      MonthView(),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TODO: 快速创建事件')),
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

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择：$value')),
        );
      },
      itemBuilder: (context) => const [
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
