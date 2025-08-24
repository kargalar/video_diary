import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  static const route = '/settings';
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final state = vm.state;
    final timeOfDay = TimeOfDay(hour: state.reminderHour, minute: state.reminderMinute);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Kayıt Klasörü'),
            subtitle: Text(state.storageDirectory ?? 'Seçilmedi'),
            trailing: ElevatedButton(onPressed: vm.pickDirectory, child: const Text('Seç')),
          ),
          const SizedBox(height: 12),
          SwitchListTile(secondary: const Icon(Icons.dark_mode), title: const Text('Karanlık Tema'), value: state.darkMode, onChanged: (v) => vm.setDarkMode(v)),
          SwitchListTile(secondary: const Icon(Icons.screen_rotation), title: const Text('Yatay Kayıt'), value: state.landscape, onChanged: (v) => vm.setLandscape(v)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('Günlük Hatırlatma Saati'),
            subtitle: Text(timeOfDay.format(context)),
            trailing: ElevatedButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: timeOfDay);
                if (picked != null) {
                  try {
                    await vm.setReminder(picked.hour, picked.minute);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatırlatma ayarlandı')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bildirim planlanamadı: $e')));
                    }
                  }
                }
              },
              child: const Text('Ayarla'),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Uygulama, seçtiğiniz saatlerde günlük video kaydı için bildirim gönderir.'),
        ],
      ),
    );
  }
}
