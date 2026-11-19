<p align="center">
  <img src="assets/app_icon/app_icon_full.png" width="120" alt="Tinda 360 logo" />
</p>

<h1 align="center">Tinda 360</h1>

<p align="center">
  <strong>Free offline Android POS for sari-sari stores</strong><br>
  Built by <a href="https://bukluran.com">Bukluran ng Kalinga ng Mamamayang Distrito Singko Inc.</a>
</p>

<p align="center">
  <a href="https://github.com/GodYtteria/Tinda360/releases/latest"><img src="https://img.shields.io/github/v/release/GodYtteria/Tinda360?style=flat-square&color=0F5C4A&label=release" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache%202.0-0F5C4A?style=flat-square" alt="License"></a>
  <a href="https://github.com/GodYtteria/Tinda360/actions"><img src="https://img.shields.io/badge/platform-Android-34A853?style=flat-square&logo=android&logoColor=white" alt="Platform"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/built%20with-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Built with Flutter"></a>
  <a href="https://tinda360.bukluran.com"><img src="https://img.shields.io/badge/website-tinda360.bukluran.com-F2A23A?style=flat-square" alt="Website"></a>
</p>

<p align="center">
  <a href="https://github.com/GodYtteria/Tinda360/releases/latest/download/app-arm64-v8a-release.apk">
    <img src="https://img.shields.io/badge/⬇_Download_APK-33_MB-0F5C4A?style=for-the-badge" alt="Download APK">
  </a>
</p>

---

## Why Tinda 360?

Many sari-sari stores are minded by a relative or neighbor while the owner is away. Counting stock is hard, utang lives in a notebook, and the owner cannot tell if the earnings are right or the cash drawer is short.

**Tinda 360** is a simple phone app that works **completely offline** — the person at the counter just taps to sell, stock cannot be oversold, and every peso is tracked automatically. No monthly fees. No internet required. No ads.

> Built by a registered non-profit for communities across the Philippines. **1,000+ store owners** are already using the early version.

---

## Screenshots

<p align="center">
  <img src="website/screenshots/pos.png" width="180" alt="POS Screen" />
  &nbsp;&nbsp;
  <img src="website/screenshots/checkout.png" width="180" alt="Checkout" />
  &nbsp;&nbsp;
  <img src="website/screenshots/saledone.png" width="180" alt="Sale Complete" />
  &nbsp;&nbsp;
  <img src="website/screenshots/ai_chat.png" width="180" alt="AI Assistant" />
</p>

---

## Features

| Feature | Description |
|---------|-------------|
| **POS** | Sell with cash, e-wallet, or utang. Quick peso buttons, instant change, split payment, optional interest. |
| **Inventory** | Live stock ledger, low-stock alerts, barcode scanner, expiry tracking, restock shopping list. |
| **Utang Ledger** | Per-suki balances, credit limits, partial payments, history, and reminders. |
| **Smart Store Assistant** | On-device AI — ask about sales, profit, trends, busiest hours, loyal customers, stock forecast, and more. |
| **Reports** | Today, week, month, or custom range. Revenue, profit, expenses, returns, trend charts, and Top 3 products. |
| **Multi-Store** | Switch between stores, each with its own database and Google Drive backup. |
| **Bantay Mode** | PIN-protected sensitive actions. Every sale records who was on duty. |
| **Cash Count** | End-of-day cash count to reconcile the drawer. |
| **Receipts** | Share as text or print on a 58mm thermal printer. |
| **Backup** | Google Drive (private app folder) or local file export. |
| **Offline-First** | Everything runs on-device. No internet needed except for optional backup. |
| **Bilingual** | Filipino and English UI. Dark mode and large text accessible. |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | [Flutter](https://flutter.dev) (Dart) |
| Database | [Drift](https://drift.simonbinder.eu/) (SQLite) |
| State | [Riverpod](https://riverpod.dev/) |
| AI | On-device intent matching (no cloud API) |
| Backup | Google Drive `appdata` scope |
| CI/CD | GitHub Releases |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Android SDK (API 21+)
- A physical device or emulator

### Build from source

```bash
# Clone the repo
git clone https://github.com/GodYtteria/Tinda360.git
cd Tinda360

# Install dependencies
flutter pub get

# Generate database code
dart run build_runner build --delete-conflicting-outputs

# Generate localizations
flutter gen-l10n

# Run tests
flutter test

# Build release APK
flutter build apk --release --split-per-abi
```

### Configuration

| File | Purpose |
|------|---------|
| `config/dart_defines.json` | Google OAuth web client ID (create your own for backup) |
| `android/key.properties` | Signing keystore details (never committed) |

> **Note:** The app works fully offline without Google credentials. The OAuth client ID is only needed if you want to enable Google Drive backup.

---

## Project Structure

```
lib/
├── core/           # Domain models (money, products, sales, customers)
├── data/
│   ├── db/         # Drift database, tables, migrations
│   └── repositories/  # Data access layer
├── features/
│   ├── pos/        # Point of sale, checkout, cart, receipts
│   ├── inventory/  # Product management, CSV import/export
│   ├── utang/      # Customer debt tracking, payments
│   ├── ulat/       # Reports, cash count, expenses
│   ├── chat/       # Smart Store Assistant (on-device AI)
│   ├── settings/   # Store profile, backup, multi-store
│   ├── onboarding/ # First-run setup, splash screen
│   └── home/       # Home screen, error states
├── services/       # Backup, biometrics, printing, crash logs
├── shared/         # Reusable widgets, formatters
├── theme/          # Design tokens, colors, typography
└── l10n/           # Filipino and English translations

test/               # 100+ unit and widget tests
website/            # Static site (tinda360.bukluran.com)
```

---

## Privacy & Data Safety

- **No analytics, no tracking, no ads** — zero third-party telemetry
- **All data stays on-device** — sales, stock, and utang never leave your phone unless you choose to back up
- **Google Drive backup** uses only the `drive.appdata` scope — Tinda 360 cannot read your other Drive files
- **Centavo-exact math** — integer minor-unit accounting, no floating-point rounding errors

Read the full [Privacy Policy](https://tinda360.bukluran.com/privacy) and [Terms of Service](https://tinda360.bukluran.com/terms).

---

## Support the Mission

Tinda 360 is free and open source — built by a non-profit for communities that need it most. Here is how you can help:

- **Donate** — Help cover testing devices and community deployment → [Get in touch](mailto:officialtinda360@bukluran.com?subject=Donation%20Inquiry)
- **Volunteer** — Developers, designers, translators, community organizers → [Join the team](mailto:officialtinda360@bukluran.com?subject=Volunteer%20Inquiry)
- **Partner** — LGUs, NGOs, corporations for sari-sari store digitization → [Become a partner](mailto:officialtinda360@bukluran.com?subject=Partnership%20Inquiry)

---

## License

```
Copyright 2026 Bukluran ng Kalinga ng Mamamayang Distrito Singko Inc.

Licensed under the Apache License, Version 2.0.
See LICENSE and NOTICE for details.
```

The **Bukluran** and **Tinda 360** names and logos are not covered by the Apache License and may not be used to suggest endorsement of a modified version without written permission.

---

<p align="center">
  <sub>Made with ❤️ in the Philippines by <a href="https://bukluran.com">Bukluran</a></sub>
</p>
