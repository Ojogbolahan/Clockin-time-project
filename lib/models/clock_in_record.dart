import 'dart:convert';

enum PunchType { clockIn, clockOut }

class ClockInRecord {
  final String id;
  final DateTime timestamp;
  final PunchType type;
  final String? wifiSsid;
  final String source; // 'auto_prompt', 'manual'

  ClockInRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    this.wifiSsid,
    this.source = 'manual',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type == PunchType.clockIn ? 'clockIn' : 'clockOut',
      'wifiSsid': wifiSsid,
      'source': source,
    };
  }

  factory ClockInRecord.fromMap(Map<String, dynamic> map) {
    return ClockInRecord(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      type: map['type'] == 'clockIn' ? PunchType.clockIn : PunchType.clockOut,
      wifiSsid: map['wifiSsid'] as String?,
      source: (map['source'] as String?) ?? 'manual',
    );
  }

  String toJson() => json.encode(toMap());

  factory ClockInRecord.fromJson(String source) =>
      ClockInRecord.fromMap(json.decode(source) as Map<String, dynamic>);
}
