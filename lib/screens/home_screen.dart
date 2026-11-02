import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_settings.dart';
import '../models/clock_in_record.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/wifi_monitor_service.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final NotificationService notificationService;
  final WifiMonitorService wifiMonitorService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.notificationService,
    required this.wifiMonitorService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isClockedIn = false;
  DateTime? _lastClockInTime;
  String? _currentSsid;
  bool _isLoadingWifi = false;
  Timer? _shiftTimer;
  Duration _shiftDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadState();
    _startWifiMonitoring();
    _startShiftTicker();
  }

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  void _loadState() {
    setState(() {
      _isClockedIn = widget.storageService.isClockedIn();
      _lastClockInTime = widget.storageService.getLastClockInTime();
      _updateShiftDuration();
    });
  }

  void _startShiftTicker() {
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isClockedIn && _lastClockInTime != null) {
        setState(() {
          _updateShiftDuration();
        });
      }
    });
  }

  void _updateShiftDuration() {
    if (_isClockedIn && _lastClockInTime != null) {
      _shiftDuration = DateTime.now().difference(_lastClockInTime!);
    } else {
      _shiftDuration = Duration.zero;
    }
  }

  Future<void> _startWifiMonitoring() async {
    setState(() => _isLoadingWifi = true);
    await widget.wifiMonitorService.ensureWifiPermissions();
    await widget.notificationService.requestPermissions();

    await widget.wifiMonitorService.startMonitoring(
      onSsidChanged: (ssid) {
        if (mounted) {
          setState(() {
            _currentSsid = ssid;
            _isLoadingWifi = false;
          });
        }
      },
    );

    final initialSsid = await widget.wifiMonitorService.getCurrentSsid();
    if (mounted) {
      setState(() {
        _currentSsid = initialSsid;
        _isLoadingWifi = false;
      });
    }
  }

  Future<void> _toggleClockStatus() async {
    final now = DateTime.now();
    final newStatus = !_isClockedIn;

    final record = ClockInRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: now,
      type: newStatus ? PunchType.clockIn : PunchType.clockOut,
      wifiSsid: _currentSsid,
      source: 'manual',
    );

    await widget.storageService.setClockedInStatus(newStatus, timestamp: now);
    await widget.storageService.addRecord(record);
    await widget.notificationService.cancelPrompt();

    _loadState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '✅ Clocked in at ${DateFormat('hh:mm a').format(now)}'
                : '⏹️ Clocked out at ${DateFormat('hh:mm a').format(now)}',
          ),
          backgroundColor: newStatus ? Colors.green.shade700 : Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _triggerTestAlarm() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulating arrival at office Wi-Fi...'),
        duration: Duration(seconds: 2),
      ),
    );

    final triggered =
        await widget.wifiMonitorService.checkWifiAndPromptIfMatched(
      bypassCooldown: true,
    );

    if (!triggered && mounted) {
      // If not on an office Wi-Fi, trigger test prompt with placeholder name
      final settings = widget.storageService.getSettings();
      final sampleSsid = settings.officeSsids.isNotEmpty
          ? settings.officeSsids.first
          : 'Office-WiFi';
      await widget.notificationService.showClockInPrompt(
        wifiSsid: sampleSsid,
        playSound: settings.enableSound,
        enableVibration: settings.enableVibration,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 Test alert sent for "$sampleSsid"! Check your notifications.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    }
  }

  bool _isOfficeNetwork() {
    if (_currentSsid == null) return false;
    final settings = widget.storageService.getSettings();
    return settings.officeSsids.any(
      (s) => s.trim().toLowerCase() == _currentSsid!.toLowerCase(),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isOffice = _isOfficeNetwork();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Clock-In Alarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Punch History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(storageService: widget.storageService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    storageService: widget.storageService,
                    wifiMonitorService: widget.wifiMonitorService,
                  ),
                ),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final ssid = await widget.wifiMonitorService.getCurrentSsid();
          setState(() => _currentSsid = ssid);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wi-Fi Status Banner
              _buildWifiStatusCard(isOffice, theme),
              const SizedBox(height: 24),

              // Main Punch Card
              _buildPunchCard(theme),
              const SizedBox(height: 24),

              // Test & Simulation Actions
              _buildSimulationCard(theme),
              const SizedBox(height: 24),

              // Quick Info Card
              _buildConfigSummaryCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWifiStatusCard(bool isOffice, ThemeData theme) {
    final statusColor = isOffice ? Colors.green : Colors.amber.shade800;
    final statusIcon = isOffice ? Icons.wifi : Icons.wifi_off;
    final title = _currentSsid != null
        ? (isOffice ? 'Connected to Office Wi-Fi' : 'Connected to Non-Office Wi-Fi')
        : 'Wi-Fi Disconnected / Unknown';
    final subtitle = _currentSsid != null
        ? 'SSID: "$_currentSsid"'
        : 'Connect to office Wi-Fi to auto-trigger clock-in prompt';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_isLoadingWifi)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildPunchCard(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Text(
              _isClockedIn ? 'CURRENT SHIFT' : 'CURRENT STATUS',
              style: TextStyle(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isClockedIn ? _formatDuration(_shiftDuration) : 'Not Clocked In',
              style: TextStyle(
                fontSize: _isClockedIn ? 42 : 28,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: _isClockedIn ? Colors.green.shade700 : Colors.grey.shade800,
              ),
            ),
            if (_isClockedIn && _lastClockInTime != null) ...[
              const SizedBox(height: 6),
              Text(
                'Since ${DateFormat('hh:mm a').format(_lastClockInTime!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleClockStatus,
                icon: Icon(
                  _isClockedIn ? Icons.stop_circle_outlined : Icons.check_circle_outline,
                  size: 24,
                ),
                label: Text(
                  _isClockedIn ? 'CLOCK OUT' : 'CLOCK IN',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isClockedIn ? Colors.red.shade600 : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationCard(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notification_important_outlined, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Test Alarm & Notification',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Verify how employees receive the alarm prompt when joining office Wi-Fi.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _triggerTestAlarm,
              icon: const Icon(Icons.alarm),
              label: const Text('Fire Clock-In Alarm Now'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSummaryCard(ThemeData theme) {
    final settings = widget.storageService.getSettings();
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Office Network Triggers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: settings.officeSsids
                  .map(
                    (s) => Chip(
                      avatar: const Icon(Icons.wifi, size: 16),
                      label: Text(s),
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Cooldown period: ${settings.cooldownHours}h (prevents repeated alarms during shift)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
