/// Inputs the daily AI coach uses to shape a personal nudge.
class CoachInput {
  const CoachInput({
    required this.name,
    required this.streak,
    required this.completedToday,
    required this.totalToday,
    required this.weekMinutes,
    this.productiveLabel,
  });

  final String name;
  final int streak;
  final int completedToday;
  final int totalToday;
  final int weekMinutes;

  /// An already-localized label for the user's most productive time, e.g.
  /// "mornings" (resolved by the caller so this stays translation-agnostic).
  final String? productiveLabel;
}

/// A localized coach line: a translation [key] plus its named args. The widget
/// resolves it with `key.tr(namedArgs: args)`.
class CoachTip {
  const CoachTip(this.key, [this.args = const <String, String>{}]);

  final String key;
  final Map<String, String> args;
}

/// Picks a short, personalized daily coaching tip from the user's recent habits.
/// Pure + deterministic: the same [input] and [daySeed] always give the same
/// line, so the tip is stable across a day and gently changes the next.
///
/// Returns a translation key + args (no hardcoded copy), so the AI coach is
/// fully localized. No network call — it composes from local stats.
CoachTip dailyCoachTip(CoachInput input, {required int daySeed}) {
  final remaining = (input.totalToday - input.completedToday).clamp(
    0,
    input.totalToday,
  );

  // Context-aware candidates; the most specific situations come first.
  final candidates = <CoachTip>[
    if (input.streak >= 3)
      CoachTip('coach.streak', {'streak': '${input.streak}'}),
    if (input.completedToday > 0 && remaining == 0)
      const CoachTip('coach.all_done'),
    if (remaining > 0) CoachTip('coach.tasks_left', {'count': '$remaining'}),
    if (input.productiveLabel != null)
      CoachTip('coach.productive', {'label': input.productiveLabel!}),
    if (input.weekMinutes >= 120)
      CoachTip('coach.week_hours', {
        'hours': '${(input.weekMinutes / 60).round()}',
      }),
    // Evergreen fallbacks, always available so there's never an empty coach.
    const CoachTip('coach.evergreen_1'),
    const CoachTip('coach.evergreen_2'),
    const CoachTip('coach.evergreen_3'),
  ];

  return candidates[daySeed % candidates.length];
}

/// A stable day index for [date], so the coach tip changes once per day.
int coachDaySeed(DateTime date) =>
    date.year * 1000 + date.month * 40 + date.day;
