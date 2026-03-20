import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class Settings {
  final double temperature;
  final int maxTokens;
  final double topP;
  final bool darkMode;

  Settings({
    required this.temperature,
    required this.maxTokens,
    required this.topP,
    required this.darkMode,
  });

  Settings copyWith({
    double? temperature,
    int? maxTokens,
    double? topP,
    bool? darkMode,
  }) {
    return Settings(
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<Settings> {
  SettingsNotifier()
      : super(Settings(
          temperature: AppConstants.defaultTemperature,
          maxTokens: AppConstants.defaultMaxTokens,
          topP: AppConstants.defaultTopP,
          darkMode: true,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      temperature: prefs.getDouble(AppConstants.keyTemperature) ?? AppConstants.defaultTemperature,
      maxTokens: prefs.getInt(AppConstants.keyMaxTokens) ?? AppConstants.defaultMaxTokens,
      topP: prefs.getDouble(AppConstants.keyTopP) ?? AppConstants.defaultTopP,
      darkMode: prefs.getBool(AppConstants.keyDarkMode) ?? true,
    );
  }

  Future<void> setTemperature(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyTemperature, value);
    state = state.copyWith(temperature: value);
  }

  Future<void> setMaxTokens(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyMaxTokens, value);
    state = state.copyWith(maxTokens: value);
  }

  Future<void> setTopP(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keyTopP, value);
    state = state.copyWith(topP: value);
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyDarkMode, value);
    state = state.copyWith(darkMode: value);
  }
}
