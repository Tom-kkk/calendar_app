/// 农历工具类
/// 提供公历转农历、节气计算等功能
class LunarUtils {
  // 农历数据表（1900-2100年）
  // 每个数据项包含：农历年份、闰月月份、每月天数（12或13个月）
  // 数据格式：0x五位十六进制数，从高位到低位：
  // - 第1位：闰月月份（0表示无闰月）
  // - 第2-5位：12个月的大小月情况（1表示大月30天，0表示小月29天）
  static const List<int> _lunarInfo = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04bd7, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
    0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
    0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
    0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
    0x0d520,
  ];

  // 天干
  static const List<String> _gan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

  // 地支
  static const List<String> _zhi = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

  // 生肖
  static const List<String> _animals = ['鼠', '牛', '虎', '兔', '龙', '蛇', '马', '羊', '猴', '鸡', '狗', '猪'];

  // 农历月份
  static const List<String> _lunarMonths = [
    '正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'
  ];

  // 农历日期
  static const List<String> _lunarDays = [
    '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'
  ];

  // 节气名称
  static const List<String> _solarTerms = [
    '小寒', '大寒', '立春', '雨水', '惊蛰', '春分',
    '清明', '谷雨', '立夏', '小满', '芒种', '夏至',
    '小暑', '大暑', '立秋', '处暑', '白露', '秋分',
    '寒露', '霜降', '立冬', '小雪', '大雪', '冬至'
  ];

  // 节气分钟偏移表（自 1900-01-06 02:05 UTC 起算），来源：农历通用算法
  static const List<int> _solarTermInfo = [
    0, 21208, 42467, 63836, 85337, 107014, 128867, 150921, 173149, 195551, 218072,
    240693, 263343, 285989, 308563, 331033, 353350, 375494, 397447, 419210, 440795,
    462224, 483532, 504758
  ];

  // 节气基准时间：1900-01-06 02:05 UTC
  static final DateTime _solarTermBase = DateTime.utc(1900, 1, 6, 2, 5);

  // 传统节日映射表（农历月日 -> 节日名称）
  static const Map<String, String> _traditionalFestivals = {
    '1-1': '春节',
    '1-15': '元宵节',
    '2-2': '龙抬头',
    '5-5': '端午节',
    '7-7': '七夕',
    '7-15': '中元节',
    '8-15': '中秋节',
    '9-9': '重阳节',
    '10-15': '下元节',
    '12-8': '腊八节',
    '12-23': '小年',
    '12-30': '除夕',
    '12-29': '除夕', // 有些年份腊月只有29天
  };

  /// 获取农历年份信息
  static int _getLunarYearInfo(int year) {
    if (year < 1900 || year > 2100) {
      return _lunarInfo[0]; // 默认返回1900年的数据
    }
    return _lunarInfo[year - 1900];
  }

  /// 获取农历年份的闰月月份（0表示无闰月）
  static int _getLeapMonth(int year) {
    return _getLunarYearInfo(year) & 0xf;
  }

  /// 获取农历年份某月的大小（true表示大月30天，false表示小月29天）
  /// month: 1-12 表示正常月份，13 表示闰月
  static bool _isBigMonth(int year, int month) {
    final info = _getLunarYearInfo(year);
    if (month >= 1 && month <= 12) {
      // 正常月份：从第4位开始（bit 16-27）
      return ((info >> (16 - month)) & 0x1) == 1;
    }
    // 闰月由第17位（0x10000）标记大小
    final leapMonth = _getLeapMonth(year);
    if (month == 13 && leapMonth > 0) {
      return (info & 0x10000) != 0;
    }
    return false;
  }

  /// 获取农历年份的总月数
  static int _getLunarMonthCount(int year) {
    return _getLeapMonth(year) > 0 ? 13 : 12;
  }

  /// 计算两个日期之间的天数差
  static int _daysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  /// 公历转农历
  /// 返回农历信息：{year: 农历年, month: 农历月, day: 农历日, isLeapMonth: 是否闰月}
  static Map<String, dynamic> solarToLunar(DateTime solarDate) {
    // 基准日期：1900年1月31日（农历正月初一）
    final baseDate = DateTime(1900, 1, 31);
    final targetDate = DateTime(solarDate.year, solarDate.month, solarDate.day);
    
    // 计算天数差
    int offset = _daysBetween(baseDate, targetDate);
    
    if (offset < 0) {
      // 如果日期早于1900年1月31日，返回默认值
      return {'year': 1900, 'month': 1, 'day': 1, 'isLeapMonth': false};
    }

    int lunarYear = 1900;
    int lunarMonth = 1;
    int lunarDay = 1;
    bool isLeapMonth = false;

    // 从1900年开始逐年计算
    while (lunarYear < 2101) {
      final leapMonth = _getLeapMonth(lunarYear);
      final monthCount = leapMonth > 0 ? 13 : 12;
      int yearDays = 0;

      // 计算这一年的总天数
      // 先计算正常月份
      for (int month = 1; month <= 12; month++) {
        final isBig = _isBigMonth(lunarYear, month);
        final monthDays = isBig ? 30 : 29;
        yearDays += monthDays;
        
        // 如果这个月是闰月，需要插入闰月
        if (leapMonth == month) {
          final leapIsBig = _isBigMonth(lunarYear, 13);
          final leapDays = leapIsBig ? 30 : 29;
          yearDays += leapDays;
        }
      }

      if (offset < yearDays) {
        // 在这一年内
        int currentMonth = 1;
        for (int month = 1; month <= 12; month++) {
          final isBig = _isBigMonth(lunarYear, month);
          final monthDays = isBig ? 30 : 29;
          
          // 如果这个月是闰月，先处理闰月
          if (leapMonth == month) {
            final leapIsBig = _isBigMonth(lunarYear, 13);
            final leapDays = leapIsBig ? 30 : 29;
            
            if (offset < leapDays) {
              lunarMonth = month;
              lunarDay = offset + 1;
              isLeapMonth = true;
              break;
            }
            offset -= leapDays;
          }
          
          // 处理正常月份
          if (offset < monthDays) {
            lunarMonth = month;
            lunarDay = offset + 1;
            isLeapMonth = false;
            break;
          }
          offset -= monthDays;
        }
        break;
      }

      offset -= yearDays;
      lunarYear++;
    }

    return {
      'year': lunarYear,
      'month': lunarMonth,
      'day': lunarDay,
      'isLeapMonth': isLeapMonth,
    };
  }

  /// 获取农历日期字符串
  static String getLunarDateString(DateTime solarDate) {
    final lunar = solarToLunar(solarDate);
    final month = lunar['month'] as int;
    final day = lunar['day'] as int;
    final isLeapMonth = lunar['isLeapMonth'] as bool;

    String monthStr = '';
    if (month >= 1 && month <= 12) {
      monthStr = _lunarMonths[month - 1];
      if (isLeapMonth) {
        monthStr = '闰$monthStr';
      }
      monthStr += '月';
    }

    String dayStr = '';
    if (day >= 1 && day <= 30) {
      dayStr = _lunarDays[day - 1];
    }

    return '$monthStr$dayStr';
  }

  /// 获取农历年份字符串（天干地支）
  static String getLunarYearString(int year) {
    final ganIndex = (year - 4) % 10;
    final zhiIndex = (year - 4) % 12;
    return '${_gan[ganIndex]}${_zhi[zhiIndex]}';
  }

  /// 获取生肖
  static String getAnimal(int year) {
    return _animals[(year - 4) % 12];
  }

  /// 计算指定年份的第 n 个节气对应的公历日期
  /// n: 0-23，对应24节气
  static DateTime _getSolarTermDate(int year, int n) {
    final millis = _solarTermBase.millisecondsSinceEpoch +
        ((year - 1900) * 31556925974.7).round() +
        _solarTermInfo[n] * 60000;
    // 转回本地时区，避免显示日偏差
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }

  /// 获取节气
  /// 返回节气名称，如果不是节气日则返回null
  static String? getSolarTerm(DateTime date) {
    for (int i = 0; i < 24; i++) {
      final termDate = _getSolarTermDate(date.year, i);
      if (termDate.year == date.year &&
          termDate.month == date.month &&
          termDate.day == date.day) {
        return _solarTerms[i];
      }
    }
    return null;
  }

  /// 获取传统节日
  /// 返回节日名称，如果不是传统节日则返回null
  static String? getTraditionalFestival(DateTime solarDate) {
    final lunar = solarToLunar(solarDate);
    final month = lunar['month'] as int;
    final day = lunar['day'] as int;
    final isLeapMonth = lunar['isLeapMonth'] as bool;
    
    // 闰月不计算传统节日
    if (isLeapMonth) {
      return null;
    }
    
    final key = '$month-$day';
    return _traditionalFestivals[key];
  }

  /// 获取完整的农历信息字符串（包含节日和节气）
  static String getFullLunarInfo(DateTime solarDate) {
    final lunarDateStr = getLunarDateString(solarDate);
    final solarTerm = getSolarTerm(solarDate);
    final festival = getTraditionalFestival(solarDate);
    
    // 优先级：节气 > 传统节日 > 农历日期
    if (solarTerm != null) {
      return solarTerm;
    }
    if (festival != null) {
      return festival;
    }
    return lunarDateStr;
  }

  /// 获取农历信息（用于显示）
  /// 返回：{lunarDate: 农历日期, solarTerm: 节气, festival: 传统节日}
  static Map<String, String?> getLunarInfo(DateTime solarDate) {
    return {
      'lunarDate': getLunarDateString(solarDate),
      'solarTerm': getSolarTerm(solarDate),
      'festival': getTraditionalFestival(solarDate),
    };
  }
}
