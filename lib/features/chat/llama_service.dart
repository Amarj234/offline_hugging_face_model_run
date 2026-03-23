import 'dart:async';
import 'package:flutter_llama/flutter_llama.dart';
import '../../core/constants.dart';

class LlamaService {
  final FlutterLlama _llama = FlutterLlama.instance;
  bool _isModelLoaded = false;
  String? _currentModelPath;

  bool get isModelLoaded => _isModelLoaded;

  Future<bool> loadModel(String path, {int? threads, int? contextSize, int? batchSize}) async {
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
        nThreads: threads ?? 2,
        nGpuLayers: 0,
        contextSize: contextSize ?? 512,
        batchSize: batchSize ?? 64,
        useGpu: false,
        verbose: true,
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

  /// Generate a response and return the text directly.
  /// Returns the generated text, or an error message string.
  Future<String> generateResponse(
    String prompt, {
    double? temperature,
    int? maxTokens,
    double? topP,
    List<String>? stopSequences,
  }) async {
    final params = GenerationParams(
      prompt: prompt,
      temperature: temperature ?? AppConstants.defaultTemperature,
      maxTokens: maxTokens ?? AppConstants.defaultMaxTokens,
      topP: topP ?? AppConstants.defaultTopP,
      stopSequences: stopSequences ?? [],
    );

    try {
      final result = await _llama.generate(params);
      
      if (result.text.isNotEmpty) {
        return result.text;
      } else {
        return '(No response generated. Try a different prompt or a smaller model.)';
      }
    } catch (e) {
      return 'Error generating response: ${e.toString()}';
    }
  }

  Future<void> dispose() async {
    if (_isModelLoaded) {
      await _llama.unloadModel();
      _isModelLoaded = false;
      _currentModelPath = null;
    }
  }
}
