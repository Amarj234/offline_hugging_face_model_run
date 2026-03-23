import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llama_service.dart';
import 'prompt_template.dart';
import '../models/models_provider.dart';
import '../settings/settings_provider.dart';
import '../../core/constants.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'],
      isUser: map['isUser'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoading;

  ChatState({
    required this.messages, 
    this.isGenerating = false,
    this.isModelLoading = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages, 
    bool? isGenerating,
    bool? isModelLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isModelLoading: isModelLoading ?? this.isModelLoading,
    );
  }
}

final llamaServiceProvider = Provider((ref) => LlamaService());

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final llamaService = ref.watch(llamaServiceProvider);
  return ChatNotifier(llamaService, ref);
});

class ChatNotifier extends StateNotifier<ChatState> {
  final LlamaService _llamaService;
  final Ref _ref;
  static const String _historyKey = 'chat_history';

  ChatNotifier(this._llamaService, this._ref) : super(ChatState(messages: [])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      final messages = decoded.map((m) => ChatMessage.fromMap(m)).toList();
      state = state.copyWith(messages: messages);
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = json.encode(state.messages.map((m) => m.toMap()).toList());
    await prefs.setString(_historyKey, historyJson);
  }

  Future<void> stopGeneration() async {
    await _llamaService.stop();
    state = state.copyWith(isGenerating: false);
  }

  void _updateAssistantMessage(String text) {
    if (!mounted) return;
    state = state.copyWith(
      messages: [
        ...state.messages.sublist(0, state.messages.length - 1),
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      ],
    );
  }

  Future<void> sendMessage(String text) async {
    // Stop any previous generation
    await _llamaService.stop();

    // Add user message
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isGenerating: true,
    );

    // Add placeholder assistant message
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: '', isUser: false, timestamp: DateTime.now())],
    );

    final selectedModel = _ref.read(selectedModelProvider);
    if (selectedModel == null) {
      _updateAssistantMessage('Error: No model selected. Please download and select a model first.');
      state = state.copyWith(isGenerating: false);
      return;
    }

    final settings = _ref.read(settingsProvider);
    final template = PromptTemplate(PromptTemplate.detectFormat(selectedModel.path));

    try {
      // Load model
      state = state.copyWith(isModelLoading: true);
      final loaded = await _llamaService.loadModel(
        selectedModel.path,
        contextSize: 512,
        batchSize: 64,
        threads: 2,
      );
      state = state.copyWith(isModelLoading: false);
      
      if (!loaded) {
        _updateAssistantMessage('Error: Failed to load model. The file may be corrupted.');
        state = state.copyWith(isGenerating: false);
        return;
      }

      // Generate with a 90-second timeout
      bool didTimeout = false;
      final timeoutTimer = Timer(const Duration(seconds: 90), () {
        didTimeout = true;
        _llamaService.stop();
      });

      String responseText;
      try {
        final formattedPrompt = template.formatPrompt(text);
        responseText = await _llamaService.generateResponse(
          formattedPrompt,
          temperature: settings.temperature,
          maxTokens: 128,
          topP: settings.topP,
          stopSequences: template.stopSequences,
        );
      } finally {
        timeoutTimer.cancel();
      }

      if (!mounted) return;

      if (didTimeout) {
        _updateAssistantMessage(
          '⏱️ Model too slow for this device.\n\n'
          'The current model is too heavy for your phone.\n\n'
          'To fix this:\n'
          '1. Go to Models (📁 icon)\n'
          '2. Search for "TinyLlama"\n'
          '3. Download a smaller GGUF file\n'
          '4. Select it and try again',
        );
      } else {
        // Update the assistant message with the actual response
        _updateAssistantMessage(responseText);
      }
    } catch (e) {
      if (!mounted) return;
      _updateAssistantMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        state = state.copyWith(isGenerating: false, isModelLoading: false);
        _saveHistory();
      }
    }
  }

  Future<void> clearChat() async {
    await stopGeneration();
    state = ChatState(messages: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<void> downloadRecommendedModel() async {
    final downloadsNotifier = _ref.read(activeDownloadsProvider.notifier);
    await downloadsNotifier.startDownload(
      AppConstants.recommendedModelId,
      AppConstants.recommendedModelFile,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
