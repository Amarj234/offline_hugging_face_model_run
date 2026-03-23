import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/file_manager.dart';
import 'download_service.dart';

final localModelsProvider = StateNotifierProvider<LocalModelsNotifier, List<File>>((ref) {
  return LocalModelsNotifier();
});

class LocalModelsNotifier extends StateNotifier<List<File>> {
  LocalModelsNotifier() : super([]) {
    refreshModels();
  }

  Future<void> refreshModels() async {
    final models = await FileManager.getLocalModels();
    state = models;
  }

  Future<void> deleteModel(String filePath) async {
    await FileManager.deleteModel(filePath);
    await refreshModels();
  }
}

final selectedModelProvider = StateNotifierProvider<SelectedModelNotifier, File?>((ref) {
  return SelectedModelNotifier(ref);
});

class SelectedModelNotifier extends StateNotifier<File?> {
  final Ref _ref;
  static const _key = 'selected_model_path';

  SelectedModelNotifier(this._ref) : super(null) {
    _loadModel();
  }

  Future<void> _loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path != null && File(path).existsSync()) {
      state = File(path);
    } else {
      // If the saved model doesn't exist anymore, wait for local models to load and select first available
      await _ref.read(localModelsProvider.notifier).refreshModels();
      final models = _ref.read(localModelsProvider);
      if (models.isNotEmpty) {
        selectModel(models.first);
      }
    }
  }

  Future<void> selectModel(File? file) async {
    state = file;
    final prefs = await SharedPreferences.getInstance();
    if (file != null) {
      await prefs.setString(_key, file.path);
    } else {
      await prefs.remove(_key);
    }
  }
}

final downloadServiceProvider = Provider((ref) => DownloadService());

class DownloadProgress {
  final String fileName;
  final String modelId;
  final double progress;
  final bool isPaused;
  final bool isCompleted;
  final bool isFailed;
  final String? error;

  const DownloadProgress({
    required this.fileName,
    required this.modelId,
    this.progress = 0.0,
    this.isPaused = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.error,
  });

  DownloadProgress copyWith({
    double? progress,
    bool? isPaused,
    bool? isCompleted,
    bool? isFailed,
    String? error,
  }) {
    return DownloadProgress(
      fileName: fileName,
      modelId: modelId,
      progress: progress ?? this.progress,
      isPaused: isPaused ?? this.isPaused,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
      error: error ?? this.error,
    );
  }

  String get progressText {
    if (isFailed) return 'Failed';
    if (isCompleted) return 'Done';
    if (isPaused) return 'Paused ${(progress * 100).toStringAsFixed(0)}%';
    return '${(progress * 100).toStringAsFixed(0)}%';
  }
}

final activeDownloadsProvider =
    StateNotifierProvider<ActiveDownloadsNotifier, Map<String, DownloadProgress>>((ref) {
  return ActiveDownloadsNotifier(ref);
});

class ActiveDownloadsNotifier extends StateNotifier<Map<String, DownloadProgress>> {
  final Ref _ref;
  StreamSubscription<DownloadTask>? _subscription;

  ActiveDownloadsNotifier(this._ref) : super({}) {
    _listenToProgress();
  }

  void _listenToProgress() {
    final service = _ref.read(downloadServiceProvider);
    _subscription = service.progressStream.listen((task) {
      if (!mounted) return;
      state = {
        ...state,
        task.fileName: DownloadProgress(
          fileName: task.fileName,
          modelId: task.modelId,
          progress: task.progress,
          isPaused: task.isPaused,
        ),
      };
    });
  }

  Future<void> startDownload(String modelId, String fileName) async {
    final service = _ref.read(downloadServiceProvider);

    state = {
      ...state,
      fileName: DownloadProgress(
        fileName: fileName,
        modelId: modelId,
        progress: 0.0,
      ),
    };

    try {
      await service.downloadModel(modelId, fileName);
      if (!mounted) return;
      
      state = {
        ...state,
        fileName: state[fileName]!.copyWith(isCompleted: true, progress: 1.0),
      };
      
      await _ref.read(localModelsProvider.notifier).refreshModels();
      
      final currentSelected = _ref.read(selectedModelProvider);
      if (currentSelected == null) {
        final models = _ref.read(localModelsProvider);
        final newlyDownloaded = models.firstWhere(
          (f) => f.path.contains(fileName),
          orElse: () => models.firstWhere((f) => true),
        );
        _ref.read(selectedModelProvider.notifier).selectModel(newlyDownloaded);
      }
    } catch (e) {
      if (!mounted) return;
      state = {
        ...state,
        fileName: state[fileName]!.copyWith(isFailed: true, error: e.toString()),
      };
    }
  }

  void cancelDownload(String fileName) {
    final service = _ref.read(downloadServiceProvider);
    service.cancelDownload(fileName);
    state = Map.from(state)..remove(fileName);
  }

  void removeCompleted(String fileName) {
    state = Map.from(state)..remove(fileName);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
