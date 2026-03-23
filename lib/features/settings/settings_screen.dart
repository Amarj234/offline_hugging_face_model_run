import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _SectionHeader(title: 'Inference Parameters'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SliderTile(
                title: 'Temperature',
                value: settings.temperature,
                min: 0.1, max: 2.0,
                subtitle: settings.temperature.toStringAsFixed(2),
                onChanged: (v) => ref.read(settingsProvider.notifier).setTemperature(v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SliderTile(
                title: 'Max Tokens',
                value: settings.maxTokens.toDouble(),
                min: 128, max: 4096,
                divisions: 31,
                subtitle: settings.maxTokens.toString(),
                onChanged: (v) => ref.read(settingsProvider.notifier).setMaxTokens(v.toInt()),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _SliderTile(
                title: 'Top P',
                value: settings.topP,
                min: 0.1, max: 1.0,
                subtitle: settings.topP.toStringAsFixed(2),
                onChanged: (v) => ref.read(settingsProvider.notifier).setTopP(v),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionHeader(title: 'App Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              SwitchListTile(
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: settings.darkMode,
                activeColor: AppTheme.accentPrimary,
                onChanged: (v) => ref.read(settingsProvider.notifier).setDarkMode(v),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Settings are applied to the next session. High token counts may lead to longer generation times.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5, color: AppTheme.accentPrimary),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final Function(double) onChanged;

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppTheme.accentPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            Slider(
              value: value,
              min: min, max: max,
              divisions: divisions,
              activeColor: AppTheme.accentPrimary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
