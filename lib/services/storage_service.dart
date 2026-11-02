import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/clock_in_record.dart';

class StorageService {
  static const _keySettings = 'app_settings';
  static const _keyRecords = 'clock_in_records';
  static const _keyIsClockedIn = 'is_clocked_in';
  static const _keyLastClockInTime = 'last_clock_in_time';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Settings ---
  AppSettings getSettings() {
    final jsonStr = _prefs.getString(_keySettings);
    if (jsonStr == null || jsonStr.isEmpty) {
      return AppSettings();
    }
    try {
      return AppSettings.fromJson(jsonStr);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_keySettings, settings.toJson());
  }

  Future<void> updateLastPromptTime(DateTime time) async {
    final current = getSettings();
    final updated = current.copyWith(lastPromptTimestamp: time);
    await saveSettings(updated);
  }

  // --- Clock In Status ---
  bool isClockedIn() {
    return _prefs.getBool(_keyIsClockedIn) ?? false;
  }

  DateTime? getLastClockInTime() {
    final timeStr = _prefs.getString(_keyLastClockInTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> setClockedInStatus(bool clockedIn, {DateTime? timestamp}) async {
    await _prefs.setBool(_keyIsClockedIn, clockedIn);
    if (clockedIn) {
      final now = timestamp ?? DateTime.now();
      await _prefs.setString(_keyLastClockInTime, now.toIso8601String());
    }
  }

  // --- Records History ---
  List<ClockInRecord> getRecords() {
    final list = _prefs.getStringList(_keyRecords) ?? [];
    return list
        .map((item) {
          try {
            return ClockInRecord.fromJson(item);
          } catch (_) {
            return null;
          }
        })
        .whereType<ClockInRecord>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addRecord(ClockInRecord record) async {
    final current = getRecords();
    current.insert(0, record);
    // Keep last 100 entries
    final trimmed = current.take(100).toList();
    final serialized = trimmed.map((r) => r.toJson()).toList();
    await _prefs.setStringList(_keyRecords, serialized);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keyRecords);
  }
}
