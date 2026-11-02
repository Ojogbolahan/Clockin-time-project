import 'package:flutter/material.dart';
import 'models/clock_in_record.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/wifi_monitor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local persistent storage
  final storageService = await StorageService.init();

  // 2. Initialize notification service
  final notificationService = NotificationService();

  // 3. Initialize Wi-Fi monitor
  final wifiMonitorService =
      WifiMonitorService(storageService, notificationService);

  // Setup notification action handler (e.g., when "Clock In Now" button on notification is tapped)
  await notificationService.initialize(
    onSelectNotification: (payload) {
      debugPrint('Notification clicked with payload: $payload');
    },
    onClockInAction: () async {
      final now = DateTime.now();
      final ssid = await wifiMonitorService.getCurrentSsid();
      final record = ClockInRecord(
        id: now.millisecondsSinceEpoch.toString(),
        timestamp: now,
        type: PunchType.clockIn,
        wifiSsid: ssid,
        source: 'auto_prompt',
      );
      await storageService.setClockedInStatus(true, timestamp: now);
      await storageService.addRecord(record);
      await notificationService.cancelPrompt();
      debugPrint('Clock-in performed via notification action button at $now');
    },
  );

  runApp(ClockInApp(
    storageService: storageService,
    notificationService: notificationService,
    wifiMonitorService: wifiMonitorService,
  ));
}

class ClockInApp extends StatelessWidget {
  final StorageService storageService;
  final NotificationService notificationService;
  final WifiMonitorService wifiMonitorService;

  const ClockInApp({
    super.key,
    required this.storageService,
    required this.notificationService,
    required this.wifiMonitorService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Work Clock-In Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: HomeScreen(
        storageService: storageService,
        notificationService: notificationService,
        wifiMonitorService: wifiMonitorService,
      ),
    );
  }
}
