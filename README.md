<div align="center">

# Scanify

### Offline QR & Barcode Scanner with Custom Code Generator

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

<br/>

<a href="https://play.google.com/store/apps/details?id=com.scanify.qrbarcode">
  <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" height="70" alt="Get it on Google Play"/>
</a>

</div>

---

## Overview

Scanify is a lightweight, privacy focused utility for high speed barcode and QR code scanning and instant vector generation. Operating 100% offline without requiring internet access, it supports all standard 1D and 2D formats, provides searchable local history, and offers custom code generation for Wi-Fi passwords, contact cards, and text.

---

## Key Features

* **Sub 100ms Recognition:** High performance camera feed scanning supporting QR, UPC, EAN, Code 128, and Data Matrix.
* **100% Offline Operation:** Complete privacy with zero network requests. All scans and generated codes stay strictly on device.
* **Searchable Local Database:** Scans are automatically saved into a local SQLite database with quick search, filtering, and copy to clipboard actions.
* **Custom Code Generator:** Create crisp vector QR codes for Wi-Fi networks, URLs, plain text, SMS, and vCard contact cards.
* **Hardware Sensor Controls:** Instant flashlight toggle, front and back camera switching, and autofocus optimization for low light environments.

---

## Tech Stack

| Component | Technology |
|---|---|
| **Framework** | Flutter 3.x (Android) |
| **Language** | Dart |
| **Camera Engine** | Mobile Scanner 7.x (Google ML Kit Native) |
| **Local Database** | SQLite (sqflite) |
| **State Management** | Provider |
| **Vector Generation** | QR Flutter, Barcode Widget |

---

## Architecture

```text
lib/
├── core/                  # Theme constants, design tokens, and database helpers
├── models/                # Scan result models and barcode format types
├── providers/             # State providers for camera controls and scan history
├── screens/               # Scanner viewfinder, Generator screen, History list
└── main.dart              # Database initialization and app root
```

---

## Engineering Highlights

### 16KB Page Size Alignment
Google Play enforces 16KB memory page size alignment for Android 15 devices. Scanify was upgraded to modern native scanner bindings with `android.nativePageSize=16K` enabled in Gradle properties, ensuring smooth execution on newer chipsets.

### Camera Hardware Lifecycle Management
To prevent battery drain and camera hardware lock leaks, Scanify strictly releases camera sensors upon screen transition and re-initializes autofocus streams when returning to the viewfinder.

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/qimar/scanify.git

# Enter project directory
cd scanify

# Get dependencies
flutter pub get

# Run on device
flutter run
```

---

## License

Distributed under the MIT License. See `LICENSE` for details.
