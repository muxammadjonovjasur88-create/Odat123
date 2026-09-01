/// Lightweight date/time formatting helpers (no intl dependency needed yet).
library;

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Countdown clock from a number of seconds, e.g. 1496 → "24:56".
String formatClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

/// 24-hour clock from minutes-since-midnight, e.g. 480 → "08:00".
String formatHm24(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// 12-hour clock from minutes-since-midnight, e.g. 1260 → "09:00 PM".
String formatHm12(int minutes) {
  final h24 = minutes ~/ 60;
  final m = (minutes % 60).toString().padLeft(2, '0');
  final period = h24 >= 12 ? 'PM' : 'AM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '${h.toString().padLeft(2, '0')}:$m $period';
}

/// Human duration, e.g. 25 → "25 min", 120 → "2 hours", 90 → "1h 30m".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '${h}h ${m}m';
}

/// Compact number formatting (e.g. 1500 -> 1.5k, 1500000 -> 1.5M)
String formatCompactNumber(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}m';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
  }
  return value.toInt().toString();
}

/// "September 2024".
String formatMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "Wednesday, 13 September".
String formatLongDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// Short weekday label, e.g. "Mon".
String shortWeekday(DateTime d) => _weekdays[d.weekday - 1].substring(0, 3);

/// The Monday on or before [d] (week start).
DateTime mondayOf(DateTime d) {
  final dayOnly = DateTime(d.year, d.month, d.day);
  return dayOnly.subtract(Duration(days: dayOnly.weekday - 1));
}
