import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/calendar_event.dart';
import '../models/reminder_settings.dart';
import '../providers/calendar_provider.dart';

/// 事件表单视图
/// 用于添加或编辑日历事件
class EventFormView extends ConsumerStatefulWidget {
  /// 可选：传入现有事件进行编辑
  final CalendarEvent? event;
  
  /// 可选：预设的开始日期
  final DateTime? initialDate;

  const EventFormView({
    super.key,
    this.event,
    this.initialDate,
  });

  @override
  ConsumerState<EventFormView> createState() => _EventFormViewState();
}

class _EventFormViewState extends ConsumerState<EventFormView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  int? _selectedColor;
  List<ReminderSetting> _reminders = [];

  // 预定义的颜色选项
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    
    // 初始化表单数据
    if (widget.event != null) {
      // 编辑模式：使用现有事件数据
      final event = widget.event!;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _locationController.text = event.location ?? '';
      _startDate = event.start;
      _startTime = TimeOfDay.fromDateTime(event.start);
      _endDate = event.end;
      _endTime = TimeOfDay.fromDateTime(event.end);
      _isAllDay = event.isAllDay;
      _selectedColor = event.colorHex;
      _reminders = List.from(event.reminders);
    } else {
      // 新建模式：使用默认值或传入的初始日期
      final now = widget.initialDate ?? DateTime.now();
      _startDate = DateTime(now.year, now.month, now.day);
      _startTime = TimeOfDay.fromDateTime(now);
      _endDate = _startDate;
      _endTime = TimeOfDay(
        hour: _startTime.hour,
        minute: (_startTime.minute + 60) % 60,
      );
      if (_endTime.hour == _startTime.hour) {
        _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// 选择开始日期
  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // 如果结束日期早于开始日期，自动调整
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  /// 选择开始时间
  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // 如果结束时间早于或等于开始时间，自动调整
        final startDateTime = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _startTime.hour,
          _startTime.minute,
        );
        final endDateTime = DateTime(
          _endDate.year,
          _endDate.month,
          _endDate.day,
          _endTime.hour,
          _endTime.minute,
        );
        if (endDateTime.isBefore(startDateTime) || 
            endDateTime.isAtSameMomentAs(startDateTime)) {
          _endTime = TimeOfDay(
            hour: _startTime.hour,
            minute: (_startTime.minute + 30) % 60,
          );
          if (_endTime.hour == _startTime.hour && _endTime.minute <= _startTime.minute) {
            _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
          }
        }
      });
    }
  }

  /// 选择结束日期
  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  /// 选择结束时间
  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  /// 添加提醒
  void _addReminder() {
    showDialog(
      context: context,
      builder: (context) => _ReminderPickerDialog(
        onReminderSelected: (reminder) {
          setState(() {
            _reminders.add(reminder);
          });
        },
      ),
    );
  }

  /// 删除提醒
  void _removeReminder(int index) {
    setState(() {
      _reminders.removeAt(index);
    });
  }

  /// 保存事件
  void _saveEvent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 构建开始和结束时间
    final startDateTime = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );

    final endDateTime = _isAllDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );

    // 验证结束时间必须晚于开始时间
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束时间必须晚于开始时间')),
      );
      return;
    }

    // 创建或更新事件
    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      start: startDateTime,
      end: endDateTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      colorHex: _selectedColor,
      reminders: _reminders,
      isAllDay: _isAllDay,
      createdAt: widget.event?.createdAt,
      updatedAt: DateTime.now(),
    );

    // 保存到状态管理
    ref.read(calendarProvider.notifier).addEvent(event);

    // 返回上一页
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.event == null ? '事件已创建' : '事件已更新'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? '新建事件' : '编辑事件'),
        actions: [
          TextButton(
            onPressed: _saveEvent,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题输入
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题 *',
                hintText: '输入事件标题',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入事件标题';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // 全天事件开关
            SwitchListTile(
              title: const Text('全天事件'),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                });
              },
            ),
            const SizedBox(height: 8),

            // 开始日期和时间
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('开始日期'),
                    subtitle: Text(DateFormat('yyyy年MM月dd日', 'zh_CN').format(_startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _selectStartDate,
                  ),
                ),
                if (!_isAllDay)
                  Expanded(
                    child: ListTile(
                      title: const Text('开始时间'),
                      subtitle: Text(_startTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: _selectStartTime,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 结束日期和时间
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('结束日期'),
                    subtitle: Text(DateFormat('yyyy年MM月dd日', 'zh_CN').format(_endDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _selectEndDate,
                  ),
                ),
                if (!_isAllDay)
                  Expanded(
                    child: ListTile(
                      title: const Text('结束时间'),
                      subtitle: Text(_endTime.format(context)),
                      trailing: const Icon(Icons.access_time),
                      onTap: _selectEndTime,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 描述输入
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '输入事件描述（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // 地点输入
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '输入事件地点（可选）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // 颜色选择
            ListTile(
              title: const Text('颜色'),
              subtitle: Wrap(
                spacing: 8,
                children: [
                  ..._colorOptions.map((color) {
                    final colorHex = color.value;
                    final isSelected = _selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = isSelected ? null : colorHex;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 提醒设置
            ListTile(
              title: const Text('提醒'),
              subtitle: _reminders.isEmpty
                  ? const Text('无提醒')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _reminders.asMap().entries.map((entry) {
                        final index = entry.key;
                        final reminder = entry.value;
                        return Chip(
                          label: Text(_formatReminder(reminder)),
                          onDeleted: () => _removeReminder(index),
                        );
                      }).toList(),
                    ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addReminder,
              ),
            ),
            const SizedBox(height: 24),

            // 保存按钮
            ElevatedButton(
              onPressed: _saveEvent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('保存事件'),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化提醒显示文本
  String _formatReminder(ReminderSetting reminder) {
    final minutes = reminder.beforeTime.inMinutes;
    if (minutes < 60) {
      return '提前 $minutes 分钟';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '提前 $hours 小时';
    } else {
      final days = minutes ~/ 1440;
      return '提前 $days 天';
    }
  }
}

/// 提醒选择对话框
class _ReminderPickerDialog extends StatefulWidget {
  final Function(ReminderSetting) onReminderSelected;

  const _ReminderPickerDialog({
    required this.onReminderSelected,
  });

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  // 预定义的提醒选项（分钟）
  final List<int> _reminderOptions = [
    5,
    15,
    30,
    60,
    120,
    1440, // 1天
    2880, // 2天
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择提醒时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _reminderOptions.map((minutes) {
          return ListTile(
            title: Text(_formatReminderTime(minutes)),
            onTap: () {
              widget.onReminderSelected(
                ReminderSetting(
                  beforeTime: Duration(minutes: minutes),
                  type: ReminderType.notification,
                ),
              );
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  String _formatReminderTime(int minutes) {
    if (minutes < 60) {
      return '提前 $minutes 分钟';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '提前 $hours 小时';
    } else {
      final days = minutes ~/ 1440;
      return '提前 $days 天';
    }
  }
}


