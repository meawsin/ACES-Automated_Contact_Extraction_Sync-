# ACES — Automated Contact Extraction & Sync

> Scan business cards with your phone. AI reads them. Data lands in Google Sheets automatically.

---

## What it does

ACES replaces the manual process of typing visiting card details into a corporate directory. Point your phone at a card, hold steady, and within seconds the contact appears in your shared Google Sheet — name, designation, organisation, mobile, email, address, links, and all.

```
Phone camera → ML Kit OCR → Gemini AI → On Device → Laravel API → Google Sheets 
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android / iOS) |
| On-device OCR | Google ML Kit — Latin script |
| Local storage | Hive (offline-first NoSQL) |
| Backend API | Laravel 12 (PHP 8.2) |
| AI parsing | Gemini 2.5 Flash Lite |
| Cloud storage | Google Sheets API v4 (service account JWT) |

---

## Features

- **Two-sided card scanning** — scans front, vibrates, prompts for back. Skip button for single-sided cards.
- **AI field extraction** — Gemini maps raw OCR text to Name, Designation, Organisation, Mobile, Telephone, Email, FAX, Address, Links. Handles OCR typos and unusual fonts.
- **Offline-first** — scans save locally in Hive. Sync whenever you have connectivity.
- **Conflict detection** — three rules before writing to the sheet:
  - Same person, new designation → ask user to update or keep
  - Same person, new company → ask if same person or new entry
  - Brand new contact → append directly
- **Smart merge** — when updating an existing record, any fields missing from the new scan fall back to the existing sheet values. Old data is never wiped.
- **Manual entry** — add contacts by typing when scanning isn't practical. Full validation.
- **Dark mode** — toggle in the app bar.
- **Filter view** — show All / Pending / Synced contacts.
- **Swipe to remove** — swipe a card left to remove it from the device (does not touch the sheet).

---

## Project structure

```
aces_scanner/          ← Flutter app
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── scan_record.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── scanner_screen.dart
│   │   ├── manual_entry_screen.dart
│   │   └── settings_screen.dart
│   └── services/
│       ├── app_settings.dart
│       └── sync_service.dart

aces_backend/          ← Laravel API
├── app/
│   ├── Http/Controllers/
│   │   ├── CardParserController.php
│   │   └── SyncController.php
│   └── Services/
│       └── GoogleSheetsService.php
├── routes/
│   └── api.php
└── storage/app/
    └── google-service-account.json   ← not committed
```

---

## Setup

### Prerequisites

- Flutter SDK ≥ 3.10
- PHP 8.2, Composer
- A Google Cloud project with the Sheets API enabled
- A Google service account with editor access to your target sheet
- A Gemini API key

### 1 — Clone

```bash
git clone https://github.com/meawsin/ACES-Automated_Contact_Extraction_Sync-.git
cd ACES-Automated_Contact_Extraction_Sync-
```

### 2 — Backend

```bash
cd aces_backend
composer install
cp .env.example .env
php artisan key:generate
```

Edit `.env`:

```env
GEMINI_API_KEY=your_gemini_key_here
GOOGLE_SHEETS_SPREADSHEET_ID=your_sheet_id_here
```

Place your Google service account JSON at:

```
storage/app/google-service-account.json
```

Start the server:

```bash
php artisan serve --host=0.0.0.0 --port=8080
```

> For always-on hosting, deploy to Railway, Render, or any VPS. Update the API URL in the app settings accordingly.

### 3 — Flutter app

```bash
cd aces_scanner
flutter pub get
flutter run
```

Open **Settings** in the app and set the API Base URL to your server address (e.g. `http://192.168.0.148:8080`).

---

## Google Sheet format

The sheet must have this header row in `Sheet1`:

| SL | Name | Designation | Organisation | Mobile | Telephone | Email | FAX | Address | Links |
|---|---|---|---|---|---|---|---|---|---|

---

## API endpoints

| Method | Path | Description |
|---|---|---|
| POST | `/api/parse-card` | Send raw OCR text, receive structured JSON |
| POST | `/api/sync-contact` | Sync one contact to the sheet |
| POST | `/api/resolve-conflict` | Apply a user's conflict resolution decision |

---

## Known limitations

- OCR is Latin-script only. Cards with Bangla, Arabic, or other scripts will not extract correctly. A Gemini Vision fallback is planned.
- The PHP dev server (`php -S`) forks a new process per request. Token caching uses both a static property and the Laravel file cache to mitigate repeated JWT fetches, but cold-start syncs still take a few extra seconds.
- No authentication between the app and the Laravel API. Suitable for internal/LAN use. Add an `X-API-Key` middleware before exposing to the internet.

---

## Roadmap

- [ ] Gemini Vision OCR for non-Latin scripts (Bangla, Arabic, Chinese)
- [ ] Microsoft Excel via Microsoft Graph API (original spec; blocked on Azure account)
- [ ] User-defined sheet URL (multi-tenant mode — paste your own Sheet link)
- [ ] API key authentication between app and backend
- [ ] NFC card reading as alternative input
- [ ] Branded APK with organisation logo
- [ ] Deploy backend to always-on hosting

---

## License

Internal project — not published to pub.dev or packaged for distribution.
