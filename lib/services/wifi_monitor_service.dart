import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/app_settings.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class WifiMonitorService {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  String? _currentSsid;

  String? get currentSsid => _currentSsid;

  WifiMonitorService(this._storageService, this._notificationService);

  Future<void> startMonitoring({Function(String? ssid)? onSsidChanged}) async {
    // Initial check
    await checkWifiAndPromptIfMatched(onSsidChanged: onSsidChanged);

    // Listen to network transitions
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        log('Network connectivity changed: $results');
        if (results.contains(ConnectivityResult.wifi)) {
          await checkWifiAndPromptIfMatched(onSsidChanged: onSsidChanged);
        } else {
          _currentSsid = null;
          onSsidChanged?.call(null);
        }
      },
    );
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Check permissions required by iOS & Android to read Wi-Fi SSID
  Future<bool> ensureWifiPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    return status.isGranted;
  }

  /// Fetches the sanitized SSID currently connected to
  Future<String?> getCurrentSsid() async {
    try {
      final hasPermission = await ensureWifiPermissions();
      if (!hasPermission) {
        log('Location permission not granted; cannot read SSID');
        return null;
      }
      String? ssid = await _networkInfo.getWifiName();
      if (ssid != null) {
        // Strip quotes if any (e.g. '"MyOffice"' -> 'MyOffice')
        ssid = ssid.replaceAll('"', '').trim();
        if (ssid.isEmpty || ssid == '<unknown ssid>') {
          ssid = null;
        }
      }
      _currentSsid = ssid;
      return ssid;
    } catch (e) {
      log('Error reading Wi-Fi SSID: $e');
      return null;
    }
  }

  /// Core logic: Checks if the current Wi-Fi matches office SSID and triggers alarm if cooldown passed
  Future<bool> checkWifiAndPromptIfMatched({
    bool bypassCooldown = false,
    Function(String? ssid)? onSsidChanged,
  }) async {
    final settings = _storageService.getSettings();
    if (!settings.autoPromptEnabled && !bypassCooldown) {
      return false;
    }

    final ssid = await getCurrentSsid();
    onSsidChanged?.call(ssid);

    if (ssid == null) {
      return false;
    }

    // Check if the current SSID is in the list of recognized office networks
    final isOfficeWifi = settings.officeSsids.any(
      (officeSsid) => officeSsid.trim().toLowerCase() == ssid.toLowerCase(),
    );

    if (!isOfficeWifi) {
      log('Connected to Wi-Fi "$ssid", which is not an office network.');
      return false;
    }

    // Check if user is already clocked in
    final alreadyClockedIn = _storageService.isClockedIn();
    if (alreadyClockedIn && !bypassCooldown) {
      log('User is already clocked in. Prompt suppressed.');
      return false;
    }

    // Check cooldown period
    if (!bypassCooldown && settings.lastPromptTimestamp != null) {
      final diff = DateTime.now().difference(settings.lastPromptTimestamp!);
      if (diff.inHours < settings.cooldownHours) {
        log(
          'Cooldown active: Last prompt was ${diff.inHours}h ${diff.inMinutes % 60}m ago (Cooldown: ${settings.cooldownHours}h).',
        );
        return false;
      }
    }

    // Fire prompt notification & alarm
    await _notificationService.showClockInPrompt(
      wifiSsid: ssid,
      playSound: settings.enableSound,
      enableVibration: settings.enableVibration,
    );

    // Update last prompt timestamp
    await _storageService.updateLastPromptTime(DateTime.now());
    log('Clock-in prompt triggered for office Wi-Fi: $ssid');
    return true;
  }
}
