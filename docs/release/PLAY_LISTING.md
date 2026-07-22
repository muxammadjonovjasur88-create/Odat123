# Flowa — Google Play Store Listing

## App name
Flowa

## Short description (≤ 80 chars)
> Plan calmly, focus deeply. Zen scheduling, app blocking, streaks & gentle stats.

(78 chars.)

## Full description (≤ 4000 chars)
> **Flowa is a calm, Zen productivity app that helps you plan with intention and
> focus without distraction.**
>
> Plan your day on a beautiful calendar — by hand, or let **Zen Schedule** (AI)
> turn a goal into a gentle, time‑blocked plan. When a focus session begins,
> Flowa quietly **pauses your distracting apps** so you can stay present, then
> celebrates your progress with points, streaks, and a friendly community circle.
>
> **Plan with intention**
> • Daily and weekly calendar views
> • Add tasks manually, or describe a goal and let AI place focused blocks
> • Categories for study, sport, work, personal and wellness
>
> **Focus deeply**
> • Pomodoro timer (25/5) for deep work
> • Interval timer with WORK/REST sets for movement and sport
> • Optional app blocking that gently pauses the apps you choose during a session
> • A "Starting Soon" reminder 5 minutes before each task
>
> **Grow gently**
> • Earn points for completed tasks and focus sessions
> • Keep a daily streak — without pressure
> • A "Growth Circle" leaderboard to grow alongside others
> • A calm progress screen with your weekly activity and mindfulness time
>
> **Made to feel calm**
> • Soft, Zen‑inspired design with light and dark modes
> • No ads, no noise — just a quiet space to focus
>
> Sign in securely with your phone number and begin. Flowa keeps app‑blocking
> entirely on your device and never reads your screen content.

## Category & tags
- Category: **Productivity**
- Tags: focus, productivity, pomodoro, app blocker, habits, mindfulness

---

## Permissions — justification for Play review

> **Important:** Flowa does **NOT** use Android's Accessibility Service. App
> detection uses **Usage Access**, the Play‑recommended approach, which avoids
> the heightened scrutiny (and the special declaration form) that accessibility
> blockers receive. If you ever re‑introduce an AccessibilityService, you must
> complete Play Console's **Accessibility/"Permissions Declaration"** form and a
> prominent in‑app disclosure — not required for the current build.

Declare the following in **Play Console → App content → App access / Sensitive
permissions** and show the in‑app permissions screen before requesting each:

| Permission | Why Flowa needs it |
| --- | --- |
| **Usage Access** (`PACKAGE_USAGE_STATS`) | The **core focus‑blocking feature.** Flowa reads only the *package name of the foreground app*, on‑device, in a foreground service, so it can show a "Stay focused" screen when a **blocked** app is opened during an active focus session. No usage history is logged or transmitted; screen content is never read. |
| **Display over other apps** (`SYSTEM_ALERT_WINDOW`) | To draw the calm "Stay focused" overlay on top of a blocked app so the user is gently redirected back to their session. |
| **Foreground service – special use** (`FOREGROUND_SERVICE_SPECIAL_USE`) | Keeps an active focus session alive with an ongoing, low‑priority notification, and powers the on‑device foreground‑app check. Subtype declared in the manifest. |
| **Post notifications** (`POST_NOTIFICATIONS`) | Task reminders (5 minutes before a task) and the evening streak nudge. |
| **Receive boot completed** | Re‑arms an in‑progress focus/blocking session after a reboot. |

### Prominent disclosure (show before requesting Usage Access)
> "Flowa uses Usage Access to detect when a distracting app is opened during a
> focus session, so it can show a focus screen and help you stay on track. Flowa
> reads only which app is in the foreground — never your screen content — and
> this never leaves your device. You can turn this off anytime in Settings."

### Special‑use foreground service justification (paste into Play Console)
> "Flowa runs a foreground service during an active focus session to (1) keep the
> session timer and on‑device app‑blocking running reliably and (2) display an
> ongoing notification so the user always knows blocking is active. It runs only
> while a session is active and stops when the session ends."
