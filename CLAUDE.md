# Flowa

A calm, "Zen" productivity mobile app. **Android first**, with the goal of shipping to
Google Play. Production-quality, clean code. The developer tests on a real Android device.

## Core idea (do NOT change any of this)

- **Auth:** Login by phone number + SMS verification, then a profile is set up.
- **Calendar:** Goals/tasks are planned on a calendar with **daily** and **weekly** views.
- **Task creation — two ways:**
  1. User enters tasks manually.
  2. **AI plans them** ("Zen Schedule") — user writes their goal, AI places tasks with
     times into the calendar.
- **App blocking ("Starting Soon"):** 5 minutes before a task starts, the distracting apps
  the user chose (Instagram, Telegram, YouTube, etc.) get blocked until the task/goal is
  finished.
- **During a task:**
  - **Pomodoro (25 min)** for study / deep work.
  - **Interval timer** for sport — WORK/REST phases with sets (e.g. "Yoga Flow, set 2 of 4").
- **Points system:** Completing daily tasks earns points that accumulate until the end of
  the week and **reset at the start of each week (Monday)**. Everyone sees each other's
  points in a shared **"Community / Growth Circle" leaderboard** — friendly, not aggressive.
- **Progress:** Achievements, streaks ("X days streak"), and a stats/progress screen.
- **Theming:** Light mode + dark mode.

## Tech stack

- **Flutter** (stable), **Dart**.
- **State:** Riverpod. **Routing:** go_router. **Local storage:** Hive.
- **Backend:** Firebase — Auth (Phone/SMS), Cloud Firestore, Cloud Messaging, Cloud Functions.
- **AI:** Gemini API, called **ONLY via a Cloud Function** (never put the key in the app).
- **App blocking:** Native **Android Kotlin** via **MethodChannel** (Accessibility Service).

## Design source

The `design/` folder contains **21 PNG screenshots** (from Figma) — the exact target for
every screen. Style: calm Zen aesthetic — cream/off-white backgrounds, sage/forest green
accents, soft rounded cards, gentle shadows, generous whitespace.

**Before building ANY screen, OPEN its matching PNG and replicate it closely** — layout,
spacing, colors, fonts, component sizes. Extract the real colors and fonts from the images.

### Screen → file map

| PNG | Screen |
| --- | --- |
| 01_welcome | Welcome |
| 02_discover | Intro / discover |
| 03_sign_in | Phone sign-in |
| 04_verify_code | OTP verification |
| 05_setup_profile | Profile setup |
| 06_daily_plan_full | Daily plan (full) |
| 07_daily_plan_empty | Daily plan (empty) |
| 08_weekly_view | Weekly view |
| 09_add_goal | Add goal |
| 10_starting_soon | Starting Soon warning |
| 11_ai_planner | AI planner (Zen Schedule) |
| 12_deep_focus | Pomodoro |
| 13_active_focus | Sport interval timer |
| 14_goal_reached | Goal reached |
| 15_blocking | App blocking |
| 16_community | Community leaderboard |
| 17_point_system | Point system |
| 18_profile | Profile |
| 19_settings | Settings |
| 20_progress | Stats / progress |
| 21_dark_mode | Dark mode |

## Architecture

- **Feature-first:** `lib/features/<feature>/{data,domain,presentation}`.
- **Core:** `lib/core/{theme,widgets,router,services,constants}`.
- Build **ONE reusable** `AppButton` and reuse it everywhere; same for `AppCard`,
  `AppInput`, `AppChip`. Keep widgets small and consistent.

## Rules

- Null-safe. `dart format` clean. `flutter analyze` must pass. App must compile after each step.
- No hardcoded secrets.
- When asked for a feature, build **ONLY that feature**, match its design PNG, keep it
  consistent with this file, and **confirm it compiles before finishing**.
