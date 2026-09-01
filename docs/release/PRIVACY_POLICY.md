# Flowa — Privacy Policy

_Last updated: 18 June 2026_

Flowa ("we", "us") is a calm productivity app that helps you plan focused tasks,
block distracting apps during focus sessions, and track gentle progress. This
policy explains what we collect, why, and your choices. **Host this page at a
public URL and link it in your Google Play listing and in‑app Settings.**

## Summary
- We collect your **phone number** (to sign you in) and the **profile, tasks and
  progress** you create in the app.
- App‑blocking works **on your device**. We use **Usage Access** to see which app
  is in the foreground so we can pause it during a session. We do **not** read
  your screen content, keystrokes, or the contents of other apps, and this data
  never leaves your device.
- We do not sell your data or use it for advertising.

## Information we collect
1. **Account data** — your mobile phone number, verified by SMS code via Firebase
   Authentication.
2. **Profile data** — display name, chosen avatar, and primary focus type.
3. **App content** — tasks/goals you create (title, category, date, time,
   duration, reminders) and your gamification stats (points, streak, focus time).
4. **Blocking preferences** — the list of app package names you choose to block.
   This is used only to configure on‑device blocking.
5. **Device permission state** — whether Usage Access / overlay permissions are
   granted (checked locally; not stored on our servers).

We do **not** collect your contacts, location, photos, microphone, or the
content of any other app.

## How the app‑blocking permissions are used
- **Usage Access (PACKAGE_USAGE_STATS)** — read locally, in a foreground service,
  to detect the package name of the app currently in the foreground so Flowa can
  show a "Stay focused" screen when a *blocked* app is opened during an active
  session. We do not log app‑usage history or transmit it anywhere.
- **Display over other apps (SYSTEM_ALERT_WINDOW)** — to draw the focus screen on
  top of a blocked app.
- **Foreground service (special use)** — to keep an active focus session running
  with a visible, ongoing notification.
- **Notifications** — to remind you 5 minutes before a task and to nudge your
  streak in the evening.

Flowa does **not** use Android's Accessibility Service.

## How we store and process data
- Account, profile, task and progress data are stored in **Google Firebase**
  (Authentication and Cloud Firestore) under your account. Each user can read and
  write only their own data; a limited set of fields (name, avatar, points,
  focus hours) is visible to other signed‑in users in the **Growth Circle
  leaderboard**.
- AI scheduling ("Zen Schedule") sends the goal text you type to a Google Cloud
  Function, which calls the Gemini API to generate a suggested plan. The text is
  used only to produce that plan and is not stored by us beyond the request.

## Data sharing
We use the following processors: **Google Firebase** (auth, database, functions,
messaging) and the **Google Gemini API** (AI planning). We do not share your
data with advertisers or data brokers.

## Data retention and deletion
Your data is retained while your account exists. To delete your account and all
associated data, contact us at the email below and we will remove it from
Firebase. (A self‑service in‑app "Delete account" action is planned.)

## Children
Flowa is not directed to children under 13 and we do not knowingly collect their
data.

## Your choices
- You can revoke Usage Access / overlay permissions at any time in Android
  Settings; blocking simply stops working until re‑granted.
- You can disable notifications in Android Settings.

## Contact
Questions or deletion requests: **muxammadjonovjasur88@gmail.com**
