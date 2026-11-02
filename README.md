# Office Arrival Clock-In Alarm (Flutter)

A cross-platform Flutter application that monitors connection to designated **Office Wi-Fi networks** and triggers an **alarm & high-priority clock-in prompt** as soon as an employee arrives at work.

---

## 🚀 Features

- **Automatic Wi-Fi Arrival Detection**: Detects when the device connects to any configured office Wi-Fi SSID (`connectivity_plus` & `network_info_plus`).
- **High-Priority Alarm Prompt**: Displays an alert notification with sound, vibration, and an interactive **"Clock In Now"** action button.
- **Smart Debouncing / Cooldown**: Prevents annoying repeated alerts if Wi-Fi drops and reconnects (e.g. walking between floors or to the break room). Configurable to 4h, 8h (shift), or 24h.
- **Direct Clock-In Tracking**:
  - Live shift duration timer when clocked in.
  - One-tap manual Clock-In / Clock-Out toggle.
  - Full punch history log with timestamps and connected Wi-Fi network names.
- **In-App Testing & Simulation**: Includes a **"Fire Clock-In Alarm Now"** button to preview the alert sound and notification behavior immediately.
- **Configurable Settings**:
  - Add multiple office SSIDs (e.g., `Company-Staff`, `Company-5G`).
  - One-tap button to grab and save the currently connected Wi-Fi network.
  - Toggle sound, vibration, and auto-prompts.

---

## 📁 Project Structure

```
office_clockin_alarm/
├── lib/
│   ├── main.dart                      # App entry point & background notification action handler
│   ├── models/
│   │   ├── app_settings.dart          # Configurable trigger SSIDs, cooldown, sound prefs
│   │   └── clock_in_record.dart       # Punch data model (timestamp, SSID, source)
│   ├── services/
│   │   ├── storage_service.dart       # Persistent state via SharedPreferences
│   │   ├── notification_service.dart  # High-priority alarm notifications & action buttons
│   │   └── wifi_monitor_service.dart  # Wi-Fi SSID detection & cooldown evaluation
│   └── screens/
│       ├── home_screen.dart           # Wi-Fi status banner, Punch button, Shift timer, Test alarm
│       ├── settings_screen.dart       # SSID management, Cooldown dropdown, Toggles
│       └── history_screen.dart        # Logged punch-ins/outs with timestamps & SSIDs
├── android/app/src/main/
│   └── AndroidManifest.xml            # Configured Wi-Fi, Location, and Notification permissions
├── ios/Runner/
│   └── Info.plist                     # iOS Wi-Fi & Location usage descriptions
└── pubspec.yaml                       # Dependencies
```

---

## 📱 How It Works Under The Hood

```
[Employee arrives at office]
         │
         ▼
[Phone auto-connects to Office Wi-Fi]
         │
         ▼
[WifiMonitorService reads SSID via NetworkInfo]
         │
         ▼
[Matches SSID against Office List?] ──No──► [Do nothing]
         │ Yes
         ▼
[Already Clocked In or In Cooldown?] ──Yes──► [Suppress duplicate prompt]
         │ No
         ▼
[Trigger High-Priority Alarm Notification]
         │
         ├── Option A: Tap "Clock In Now" button directly in notification banner
         └── Option B: Tap notification to open app -> Tap big CLOCK IN button
```

---

## 🛠️ How to Run

### Prerequisites
- Flutter SDK (3.5+ recommended)
- Android Studio / Xcode or an emulator/physical device

### Installation Steps

1. Navigate to the project directory:
   ```bash
   cd C:\Users\USER\.gemini\antigravity\scratch\office_clockin_alarm
   ```

2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```

3. Run on your connected device or simulator:
   ```bash
   flutter run
   ```

---

## 🔒 Notes on Operating System Permissions

Both Google (Android 10+) and Apple (iOS 13+) treat the connected Wi-Fi network name (SSID) as sensitive location data (because BSSIDs can pinpoint physical coordinates). 

- **Android**: Prompts for `Location (While using app)` and `Notifications` permission on first launch.
- **iOS**: Requires `Location Permission` and the `Access WiFi Information` entitlement in Xcode.
- Once granted, the app reads the SSID whenever connectivity changes and triggers the alarm seamlessly.
