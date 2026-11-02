import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/wifi_monitor_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final WifiMonitorService wifiMonitorService;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.wifiMonitorService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settings = widget.storageService.getSettings();
    _urlController.text = _settings.clockInUrl ?? '';
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(AppSettings updated) async {
    setState(() => _settings = updated);
    await widget.storageService.saveSettings(updated);
  }

  void _addSsid(String ssid) {
    final clean = ssid.trim();
    if (clean.isEmpty) return;
    if (_settings.officeSsids.contains(clean)) return;

    final updatedList = List<String>.from(_settings.officeSsids)..add(clean);
    _saveSettings(_settings.copyWith(officeSsids: updatedList));
    _ssidController.clear();
  }

  void _removeSsid(String ssid) {
    final updatedList = List<String>.from(_settings.officeSsids)..remove(ssid);
    _saveSettings(_settings.copyWith(officeSsids: updatedList));
  }

  Future<void> _addCurrentWifi() async {
    final current = await widget.wifiMonitorService.getCurrentSsid();
    if (current == null || current.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect current Wi-Fi. Ensure location permission is granted.'),
          ),
        );
      }
      return;
    }

    if (_settings.officeSsids.contains(current)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$current" is already in the office list.')),
        );
      }
      return;
    }

    _addSsid(current);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "$current" to office networks!')),
      );
    }
  }

  Future<void> _resetCooldown() async {
    final updated = _settings.copyWith(lastPromptTimestamp: null);
    await _saveSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cooldown reset! The alarm will trigger next time office Wi-Fi is detected.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm & Trigger Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: Office Wi-Fi Networks
          _buildSectionHeader('OFFICE WI-FI NETWORKS (TRIGGERS)'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'The alarm prompts when the device connects to any of these networks:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _settings.officeSsids.map((ssid) {
                      return Chip(
                        label: Text(ssid, style: const TextStyle(fontWeight: FontWeight.w600)),
                        avatar: const Icon(Icons.wifi, size: 16),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeSsid(ssid),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ssidController,
                          decoration: InputDecoration(
                            hintText: 'Enter Wi-Fi SSID name',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onSubmitted: _addSsid,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _addSsid(_ssidController.text),
                        icon: const Icon(Icons.add),
                        tooltip: 'Add SSID',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addCurrentWifi,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Add Currently Connected Wi-Fi'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section: Alarm & Notification Preferences
          _buildSectionHeader('ALARM & PROMPT BEHAVIOR'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-Prompt on Arrival'),
                  subtitle: const Text('Automatically sound alert when connecting to office Wi-Fi'),
                  value: _settings.autoPromptEnabled,
                  onChanged: (val) => _saveSettings(_settings.copyWith(autoPromptEnabled: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Play Sound Tone'),
                  subtitle: const Text('Audible chime when alarm triggers'),
                  value: _settings.enableSound,
                  onChanged: (val) => _saveSettings(_settings.copyWith(enableSound: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Vibration Pattern'),
                  subtitle: const Text('Distinct alert vibration pulse'),
                  value: _settings.enableVibration,
                  onChanged: (val) => _saveSettings(_settings.copyWith(enableVibration: val)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Cooldown Between Prompts'),
                  subtitle: const Text('Prevent repeating alarms if Wi-Fi drops and reconnects'),
                  trailing: DropdownButton<int>(
                    value: _settings.cooldownHours,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 Hours')),
                      DropdownMenuItem(value: 4, child: Text('4 Hours')),
                      DropdownMenuItem(value: 8, child: Text('8 Hours (Shift)')),
                      DropdownMenuItem(value: 12, child: Text('12 Hours')),
                      DropdownMenuItem(value: 24, child: Text('24 Hours (Daily)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _saveSettings(_settings.copyWith(cooldownHours: val));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Reset & Testing Utilities
          _buildSectionHeader('TESTING & DIAGNOSTICS'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.refresh, color: Colors.blueGrey),
              title: const Text('Reset Cooldown Timer'),
              subtitle: Text(
                _settings.lastPromptTimestamp != null
                    ? 'Last prompt: ${_settings.lastPromptTimestamp.toString().substring(0, 19)}'
                    : 'No prompt triggered yet.',
              ),
              trailing: TextButton(
                onPressed: _resetCooldown,
                child: const Text('Reset'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
