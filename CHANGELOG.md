# Changelog

## v1.0.0

First public release of Tinda 360, an offline point of sale for sari-sari stores.
Source: [v1.0.0 release](https://github.com/GodYtteria/Tinda360/releases/tag/v1.0.0) and [commit history](https://github.com/GodYtteria/Tinda360/commits/main).

### Features

- Sell with cash, e-wallet or utang. Split payment, price change per sale,
  sell by peso amount, and an optional interest on utang.
- Stock that cannot be oversold, items you do not count, expiry dates,
  low stock alerts and a shopping list to share.
- Utang per suki with history, partial payment, reminders and a way to delete a
  wrong line while keeping the record.
- Reports for today, week, month or any dates, with expenses, returns and a
  cash count at the end of the day.
- A PIN for sensitive actions, the name of who is on duty on every sale, and receipts you
  can share as text or print.
- Backup to your own Google Drive or to a file named after your store.
- Works without internet. Filipino and English.
- Seven more intents for the on-device Smart Store Assistant.
- Shared haptics and skeleton loading states across the app.

### Updates

- Animated onboarding steps and feedback.
- Generic sample products instead of brand names during onboarding.
- ProGuard rules and a splash icon for release builds.
- UI migrated to Material UI, with the remaining English strings translated.

### Bug fixes

- Filipino translations corrected.
- Analyzer issues cleared across the app.
- Store registry writes are now atomic, and store switch and delete failures are surfaced.
- Store switching asks for confirmation and the confirm action is labelled clearly.
- Thinking bubble stays visible before the assistant replies.
- Placeholder voice button removed and status dots animated.
- Google account chooser no longer appears during background sync or in Settings.
- Background auth prompts silenced and reports refreshed after import.
- Store data protected on add and delete, and Drive backups isolated per store.
- Receipts shared through the system share sheet, stock entry allowed above 9999,
  and button text overflow prevented.
- Removed-item snackbars clear before showing a new notice and auto-dismiss on a timer.
- Empty states and list skeletons scroll in short-height layouts and large text.

### Repository

- README redesigned for the open-source release.
- Website updated with the community-NGO story, download section and responsive design.
- Website moved out of the source repository.
