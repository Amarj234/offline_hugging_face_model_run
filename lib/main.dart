import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: LlamaChatApp(),
    ),
  );
}

class LlamaChatApp extends ConsumerWidget {
  const LlamaChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Llama Chat App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ChatScreen(),
    );
  }
}
