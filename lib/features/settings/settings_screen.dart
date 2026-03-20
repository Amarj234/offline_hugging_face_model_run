import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Inference Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Temperature'),
            subtitle: Text(settings.temperature.toStringAsFixed(2)),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.temperature,
                min: 0.1,
                max: 2.0,
                onChanged: (value) => ref.read(settingsProvider.notifier).setTemperature(value),
              ),
            ),
          ),
          ListTile(
            title: const Text('Max Tokens'),
            subtitle: Text(settings.maxTokens.toString()),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.maxTokens.toDouble(),
                min: 128,
                max: 4096,
                divisions: 31,
                onChanged: (value) => ref.read(settingsProvider.notifier).setMaxTokens(value.toInt()),
              ),
            ),
          ),
          ListTile(
            title: const Text('Top P'),
            subtitle: Text(settings.topP.toStringAsFixed(2)),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.topP,
                min: 0.1,
                max: 1.0,
                onChanged: (value) => ref.read(settingsProvider.notifier).setTopP(value),
              ),
            ),
          ),
          const Divider(),
          const Text('App Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (value) => ref.read(settingsProvider.notifier).setDarkMode(value),
          ),
        ],
      ),
    );
  }
}
