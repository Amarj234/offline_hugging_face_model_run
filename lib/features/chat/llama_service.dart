import 'dart:async';
import 'package:flutter_llama/flutter_llama.dart';
import '../../core/constants.dart';

class LlamaService {
  final FlutterLlama _llama = FlutterLlama.instance;
  final StreamController<String> _responseController = StreamController<String>.broadcast();
  Stream<String> get responseStream => _responseController.stream;
  bool _isModelLoaded = false;
  String? _currentModelPath;

  bool get isModelLoaded => _isModelLoaded;

  Future<bool> loadModel(String path, {int? threads}) async {
    // Skip reload if same model is already loaded
    if (_isModelLoaded && _currentModelPath == path) {
      return true;
    }

    // Unload previous model if a different one was loaded
    if (_isModelLoaded) {
      await _llama.unloadModel();
      _isModelLoaded = false;
      _currentModelPath = null;
    }

    final success = await _llama.loadModel(
      LlamaConfig(
        modelPath: path,
        nThreads: threads ?? 4,
        nGpuLayers: 0,
        contextSize: 2048,
        batchSize: 512,
        useGpu: true,
      ),
    );

    _isModelLoaded = success;
    if (success) {
      _currentModelPath = path;
    }
    return success;
  }

  Future<void> stop() async {
    await _llama.stopGeneration();
  }

  Future<void> generateResponse(
    String prompt, {
    double? temperature,
    int? maxTokens,
    double? topP,
  }) async {
    final params = GenerationParams(
      prompt: prompt,
      temperature: temperature ?? AppConstants.defaultTemperature,
      maxTokens: maxTokens ?? AppConstants.defaultMaxTokens,
      topP: topP ?? AppConstants.defaultTopP,
    );

    String accumulated = '';
    await for (final token in _llama.generateStream(params)) {
      accumulated += token;
      _responseController.add(accumulated);
    }
  }

  Future<void> dispose() async {
    if (_isModelLoaded) {
      await _llama.unloadModel();
      _isModelLoaded = false;
      _currentModelPath = null;
    }
    await _responseController.close();
  }
}
