class ParsedScheduleResult {
  const ParsedScheduleResult({
    required this.scheduledDateTime,
    required this.cleanTitle,
    this.hasExplicitDate = false,
    this.hasExplicitTime = false,
    this.hasIntent = false,
    this.repeatType = 'once',
  });

  final DateTime scheduledDateTime;
  final String cleanTitle;
  final bool hasExplicitDate;
  final bool hasExplicitTime;
  final bool hasIntent;
  final String repeatType; // 'once', 'daily', 'weekly'

  bool get isDaily => repeatType == 'daily';
  bool get isWeekly => repeatType == 'weekly';
  bool get hasDateOrTime => hasExplicitDate || hasExplicitTime;
}

class AiDateParser {
  AiDateParser._();

  static final Map<String, int> _monthMap = {
    // Uzbek (Latin)
    'yanvar': 1, 'yan': 1,
    'fevral': 2, 'fev': 2,
    'mart': 3, 'mar': 3,
    'aprel': 4, 'apr': 4,
    'may': 5,
    'iyun': 6, 'iyn': 6,
    'iyul': 7, 'iyl': 7,
    'avgust': 8, 'avg': 8,
    'sentabr': 9, 'sen': 9, 'sent': 9,
    'oktabr': 10, 'okt': 10,
    'noyabr': 11, 'noy': 11,
    'dekabr': 12, 'dek': 12,

    // Russian
    'январ': 1, 'января': 1, 'январь': 1, 'янв': 1,
    'феврал': 2, 'февраля': 2, 'февраль': 2, 'фев': 2,
    'март': 3, 'марта': 3, 'мар': 3,
    'апрел': 4, 'апреля': 4, 'апрель': 4, 'апр': 4,
    'мая': 5,
    'июн': 6, 'июня': 6, 'июнь': 6,
    'июл': 7, 'июля': 7, 'июль': 7,
    'август': 8, 'августа': 8, 'авг': 8,
    'сентябр': 9, 'сентября': 9, 'сентябрь': 9, 'сен': 9,
    'октябр': 10, 'октября': 10, 'октябрь': 10, 'окт': 10,
    'ноябр': 11, 'ноября': 11, 'ноябрь': 11, 'ноя': 11,
    'декабр': 12, 'декабря': 12, 'декабрь': 12, 'дек': 12,

    // English
    'january': 1, 'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3,
    'april': 4,
    'june': 6, 'jun': 6,
    'july': 7, 'jul': 7,
    'august': 8,
    'september': 9, 'sep': 9,
    'october': 10, 'oct': 10,
    'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  /// Parses natural language scheduling requests like:
  /// - "27-avgust 2da uchrashuv belgila" -> 2026-08-27 14:00, "Uchrashuv"
  /// - "Ertaga soat 15:00 da investor bilan uchrashuv"
  /// - "27 августа в 14:00 встреча"
  static ParsedScheduleResult parse(String rawText, {DateTime? fallbackBaseDate}) {
    final now = DateTime.now();
    DateTime targetDate = fallbackBaseDate ?? now;
    int hour = fallbackBaseDate != null ? fallbackBaseDate.hour : 14;
    int minute = fallbackBaseDate != null ? fallbackBaseDate.minute : 0;
    String cleanText = rawText;
    bool hasExplicitDate = false;
    bool hasExplicitTime = false;

    final lower = rawText.toLowerCase();

    final hasIntent = lower.contains('uchrashuv') ||
        lower.contains('eslat') ||
        lower.contains('belgila') ||
        lower.contains('dars') ||
        lower.contains('reja') ||
        lower.contains('jadval') ||
        lower.contains('qo‘y') ||
        lower.contains('qoy') ||
        lower.contains('qo‘sh') ||
        lower.contains('qosh') ||
        lower.contains('kirit') ||
        lower.contains('mashq') ||
        lower.contains('sport') ||
        lower.contains('turnik') ||
        lower.contains('otjimaniya') ||
        lower.contains('yugur') ||
        lower.contains('press') ||
        lower.contains('kitob') ||
        lower.contains('fokus') ||
        lower.contains('trenirovka') ||
        lower.contains('workout') ||
        lower.contains('meeting') ||
        lower.contains('task') ||
        lower.contains('reminder') ||
        lower.contains('schedule') ||
        lower.contains('встреча') ||
        lower.contains('напомни') ||
        lower.contains('запланируй') ||
        lower.contains('поставь') ||
        lower.contains('тренировк') ||
        lower.contains('задач');

    String repeatType = 'once';
    if (lower.contains('2 kunda') ||
        lower.contains('ikki kunda') ||
        lower.contains('har 2 kunda') ||
        lower.contains('har ikki kunda') ||
        lower.contains('через день') ||
        lower.contains('каждые 2 дня') ||
        lower.contains('every 2 days')) {
      repeatType = 'every_2_days';
      cleanText = cleanText.replaceAll(RegExp(r'\b(2 kunda bir|2 kunda|ikki kunda bir|ikki kunda|har 2 kunda|har ikki kunda|через день|каждые 2 дня|every 2 days)\b', caseSensitive: false), '');
    } else if (lower.contains('3 kunda') ||
        lower.contains('uch kunda') ||
        lower.contains('har 3 kunda') ||
        lower.contains('har uch kunda') ||
        lower.contains('каждые 3 дня') ||
        lower.contains('every 3 days')) {
      repeatType = 'every_3_days';
      cleanText = cleanText.replaceAll(RegExp(r'\b(3 kunda bir|3 kunda|uch kunda bir|uch kunda|har 3 kunda|har uch kunda|каждые 3 дня|every 3 days)\b', caseSensitive: false), '');
    } else if (lower.contains('har kuni') ||
        lower.contains('har kun') ||
        lower.contains('har bir kun') ||
        lower.contains('harkuni') ||
        lower.contains('каждый день') ||
        lower.contains('ежедневно') ||
        lower.contains('every day') ||
        lower.contains('daily')) {
      repeatType = 'daily';
      cleanText = cleanText.replaceAll(RegExp(r'\b(har kuni|har kun|har bir kun|harkuni|каждый день|ежедневно|every day|daily)\b', caseSensitive: false), '');
    } else if (lower.contains('har hafta') ||
        lower.contains('har dushanba') ||
        lower.contains('har seshanba') ||
        lower.contains('har chorshanba') ||
        lower.contains('har payshanba') ||
        lower.contains('har juma') ||
        lower.contains('har shanba') ||
        lower.contains('har yakshanba') ||
        lower.contains('каждую неделю') ||
        lower.contains('weekly')) {
      repeatType = 'weekly';
      cleanText = cleanText.replaceAll(RegExp(r'\b(har hafta|har dushanba|har seshanba|har chorshanba|har payshanba|har juma|har shanba|har yakshanba|каждую неделю|weekly)\b', caseSensitive: false), '');
    }

    // 1. Check relative days: "bugun", "ertaga", "indin", "сегодня", "завтра", "послезавтра", "today", "tomorrow"
    if (lower.contains('ertaga') || lower.contains('завтра') || lower.contains('tomorrow')) {
      targetDate = now.add(const Duration(days: 1));
      cleanText = cleanText.replaceAll(RegExp(r'\b(ertaga|ertangi|завтра|tomorrow)\b', caseSensitive: false), '');
      hasExplicitDate = true;
    } else if (lower.contains('indin') || lower.contains('послезавтра')) {
      targetDate = now.add(const Duration(days: 2));
      cleanText = cleanText.replaceAll(RegExp(r'\b(indin|indini|послезавтра)\b', caseSensitive: false), '');
      hasExplicitDate = true;
    } else if (lower.contains('bugun') || lower.contains('сегодня') || lower.contains('today')) {
      targetDate = now;
      cleanText = cleanText.replaceAll(RegExp(r'\b(bugun|bugungi|сегодня|today)\b', caseSensitive: false), '');
      hasExplicitDate = true;
    } else {
      // 2. Check explicit Month and Day e.g. "27-avgust", "27 avgusta", "27th august"
      bool dateFound = false;
      for (final entry in _monthMap.entries) {
        final monthName = entry.key;
        final monthNum = entry.value;

        // Pattern 1: "27-avgust", "27 avgust", "27-августа"
        final pattern1 = RegExp('(\\d{1,2})[\\s\\-_]*(?:число|kuni|chi)?\\s*$monthName(?:da|ga|dagi|gi|да|го|th|st|nd|rd)?', caseSensitive: false);
        final m1 = pattern1.firstMatch(lower);
        if (m1 != null) {
          final day = int.tryParse(m1.group(1)!);
          if (day != null && day >= 1 && day <= 31) {
            int year = now.year;
            if (monthNum < now.month || (monthNum == now.month && day < now.day)) {
              // If date already passed this year, assume next year
              year = now.year + 1;
            }
            targetDate = DateTime(year, monthNum, day);
            cleanText = cleanText.replaceAll(pattern1, '');
            dateFound = true;
            hasExplicitDate = true;
            break;
          }
        }

        // Pattern 2: "avgustning 27-kuni", "avgust 27", "august 27"
        final pattern2 = RegExp('$monthName(?:ning|da|да)?\\s*(\\d{1,2})(?:[- ]*(?:kuni|kunda|числа|число|го|th|st|nd|rd))?', caseSensitive: false);
        final m2 = pattern2.firstMatch(lower);
        if (m2 != null) {
          final day = int.tryParse(m2.group(1)!);
          if (day != null && day >= 1 && day <= 31) {
            int year = now.year;
            if (monthNum < now.month || (monthNum == now.month && day < now.day)) {
              year = now.year + 1;
            }
            targetDate = DateTime(year, monthNum, day);
            cleanText = cleanText.replaceAll(pattern2, '');
            dateFound = true;
            hasExplicitDate = true;
            break;
          }
        }
      }

      // Pattern 3: "27-kuni", "27-число", "27 da" (if no month specified, use current/next month)
      if (!dateFound) {
        final dayOnlyPattern = RegExp(r'\b(\d{1,2})[- ]*(?:число|числа|kuni|kunda)\b', caseSensitive: false);
        final m3 = dayOnlyPattern.firstMatch(lower);
        if (m3 != null) {
          final day = int.tryParse(m3.group(1)!);
          if (day != null && day >= 1 && day <= 31) {
            int month = now.month;
            int year = now.year;
            if (day < now.day) {
              month++;
              if (month > 12) {
                month = 1;
                year++;
              }
            }
            targetDate = DateTime(year, month, day);
            cleanText = cleanText.replaceAll(dayOnlyPattern, '');
            hasExplicitDate = true;
          }
        }
      }
    }

    // 3. Check time: "14:00", "soat 15:30 da", "2da", "2 da", "soat 2da", "в 14:00", "в 2 часа"
    // Time Pattern A: HH:mm format e.g. "14:30", "15:00", "9:00"
    final hhmmPattern = RegExp(r'(?:soat|в|at)?\s*(\d{1,2}):(\d{2})(?:\s*(?:da|ga|dagi|да|am|pm))?', caseSensitive: false);
    final matchA = hhmmPattern.firstMatch(lower);
    if (matchA != null) {
      hour = int.tryParse(matchA.group(1)!) ?? hour;
      minute = int.tryParse(matchA.group(2)!) ?? minute;
      if (lower.contains('pm') && hour < 12) hour += 12;
      cleanText = cleanText.replaceAll(hhmmPattern, '');
      hasExplicitTime = true;
    } else {
      // Time Pattern B: "soat 2 da", "soat 14 da", "soat 2", "в 2 часа", "в 14"
      final soatPattern = RegExp(r'(?:soat|в|at)\s*(\d{1,2})(?:\s*(?:da|ga|dagi|да|часов|часа|ч|am|pm))?', caseSensitive: false);
      final matchB = soatPattern.firstMatch(lower);
      if (matchB != null) {
        hour = int.tryParse(matchB.group(1)!) ?? hour;
        if (hour >= 1 && hour <= 7 && !lower.contains('ertalab') && !lower.contains('tungi') && !lower.contains('утра')) {
          // 1..7 without "morning" implies afternoon (13:00..19:00)
          hour += 12;
        }
        cleanText = cleanText.replaceAll(soatPattern, '');
        hasExplicitTime = true;
      } else {
        // Time Pattern C: "2da", "2 da", "3da", "14da"
        final daPattern = RegExp(r'\b(\d{1,2})\s*(?:-?da|-?ga|dagi|-?да)\b', caseSensitive: false);
        final matchC = daPattern.firstMatch(lower);
        if (matchC != null) {
          hour = int.tryParse(matchC.group(1)!) ?? hour;
          if (hour >= 1 && hour <= 7 && !lower.contains('ertalab') && !lower.contains('tungi') && !lower.contains('утра')) {
            hour += 12;
          }
          cleanText = cleanText.replaceAll(daPattern, '');
          hasExplicitTime = true;
        }
      }
    }

    // 4. Clean command boilerplate words from the title
    cleanText = cleanText
        .replaceAll(RegExp(r'\b(belgila|belgilab ber|belgilagin|rejalashtir|qo‘sh|qosh|kirit|eslatma|eslat|qoy|qo‘y|uchrashuvim bor|uchrashuv bor|запланируй|напомни|поставь|создай|добавь|встреча|schedule|set a reminder|remind me to|create)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\-_,.:;!]+'), ' ')
        .trim();

    if (cleanText.isEmpty) {
      if (lower.contains('uchrashuv') || lower.contains('встреч') || lower.contains('meet')) {
        cleanText = 'Uchrashuv';
      } else {
        cleanText = 'Muhim reja';
      }
    } else {
      // Capitalize first letter
      cleanText = cleanText[0].toUpperCase() + cleanText.substring(1);
    }

    final finalDateTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);

    return ParsedScheduleResult(
      scheduledDateTime: finalDateTime,
      cleanTitle: cleanText,
      hasExplicitDate: hasExplicitDate,
      hasExplicitTime: hasExplicitTime,
      hasIntent: hasIntent,
      repeatType: repeatType,
    );
  }
}
