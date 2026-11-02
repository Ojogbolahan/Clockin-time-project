import 'dart:convert';

class AppSettings {
  final List<String> officeSsids;
  final int cooldownHours;
  final bool enableSound;
  final bool enableVibration;
  final bool autoPromptEnabled;
  final DateTime? lastPromptTimestamp;
  final String? clockInUrl;

  AppSettings({
    this.officeSsids = const ['Office-WiFi', 'Work-5G'],
    this.cooldownHours = 8,
    this.enableSound = true,
    this.enableVibration = true,
    this.autoPromptEnabled = true,
    this.lastPromptTimestamp,
    this.clockInUrl,
  });

  AppSettings copyWith({
    List<String>? officeSsids,
    int? cooldownHours,
    bool? enableSound,
    bool? enableVibration,
    bool? autoPromptEnabled,
    DateTime? lastPromptTimestamp,
    String? clockInUrl,
  }) {
    return AppSettings(
      officeSsids: officeSsids ?? this.officeSsids,
      cooldownHours: cooldownHours ?? this.cooldownHours,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      autoPromptEnabled: autoPromptEnabled ?? this.autoPromptEnabled,
      lastPromptTimestamp: lastPromptTimestamp ?? this.lastPromptTimestamp,
      clockInUrl: clockInUrl ?? this.clockInUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'officeSsids': officeSsids,
      'cooldownHours': cooldownHours,
      'enableSound': enableSound,
      'enableVibration': enableVibration,
      'autoPromptEnabled': autoPromptEnabled,
      'lastPromptTimestamp': lastPromptTimestamp?.toIso8601String(),
      'clockInUrl': clockInUrl,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      officeSsids: List<String>.from(map['officeSsids'] ?? ['Office-WiFi', 'Work-5G']),
      cooldownHours: (map['cooldownHours'] as num?)?.toInt() ?? 8,
      enableSound: (map['enableSound'] as bool?) ?? true,
      enableVibration: (map['enableVibration'] as bool?) ?? true,
      autoPromptEnabled: (map['autoPromptEnabled'] as bool?) ?? true,
      lastPromptTimestamp: map['lastPromptTimestamp'] != null
          ? DateTime.tryParse(map['lastPromptTimestamp'] as String)
          : null,
      clockInUrl: map['clockInUrl'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) =>
      AppSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}
