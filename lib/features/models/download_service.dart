import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/utils/file_manager.dart';

class DownloadTask {
  final String modelId;
  final String fileName;
  final String url;
  double progress = 0;
  bool isPaused = false;
  CancelToken? cancelToken;

  DownloadTask({
    required this.modelId,
    required this.fileName,
    required this.url,
  });
}

class DownloadService {
  final Dio _dio = Dio();
  final Map<String, DownloadTask> _tasks = {};
  final _progressController = StreamController<DownloadTask>.broadcast();

  Stream<DownloadTask> get progressStream => _progressController.stream;

  Future<void> downloadModel(String modelId, String fileName) async {
    final url = 'https://huggingface.co/$modelId/resolve/main/$fileName?download=true';
    final savePath = await FileManager.getModelPath(fileName);
    
    final task = DownloadTask(
      modelId: modelId,
      fileName: fileName,
      url: url,
    );
    _tasks[fileName] = task;
    task.cancelToken = CancelToken();

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            task.progress = count / total;
            _progressController.add(task);
          }
        },
        cancelToken: task.cancelToken,
      );
      _tasks.remove(fileName);
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        // Handle cancel
      } else {
        rethrow;
      }
    }
  }

  void pauseDownload(String fileName) {
    _tasks[fileName]?.cancelToken?.cancel('paused');
    _tasks[fileName]?.isPaused = true;
    _progressController.add(_tasks[fileName]!);
  }

  void resumeDownload(String modelId, String fileName) {
    _tasks[fileName]?.isPaused = false;
    downloadModel(modelId, fileName);
  }

  void cancelDownload(String fileName) {
    _tasks[fileName]?.cancelToken?.cancel('cancelled');
    _tasks.remove(fileName);
  }

  DownloadTask? getTask(String fileName) => _tasks[fileName];
}
