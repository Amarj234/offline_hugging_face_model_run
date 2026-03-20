import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hf_api_service.dart';
import 'download_service.dart';
import 'models_provider.dart';

class ModelBrowserScreen extends ConsumerStatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  ConsumerState<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends ConsumerState<ModelBrowserScreen> {
  final HFAPIService _apiService = HFAPIService();
  final DownloadService _downloadService = DownloadService();
  List<HFModelInfo> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    setState(() => _isLoading = true);
    try {
      final models = await _apiService.searchGGUFModels();
      setState(() {
        _models = models;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localModels = ref.watch(localModelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Browser'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _models.length,
              itemBuilder: (context, index) {
                final model = _models[index];
                final isDownloaded = localModels.any((f) => f.path.contains(model.shortId));
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Author: ${model.author}\nDownloads: ${model.downloads}'),
                    isThreeLine: true,
                    trailing: isDownloaded
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _showDownloadDialog(model),
                          ),
                    onTap: isDownloaded ? () {
                      final file = localModels.firstWhere((f) => f.path.contains(model.shortId));
                      ref.read(selectedModelProvider.notifier).state = file;
                      Navigator.pop(context);
                    } : null,
                  ),
                );
              },
            ),
    );
  }

  void _showDownloadDialog(HFModelInfo model) async {
    try {
      final files = await _apiService.getModelFiles(model.id);
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No GGUF files found for this model.')),
          );
        }
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final fileName = files[index];
                return ListTile(
                  title: Text(fileName),
                  trailing: const Icon(Icons.download),
                  onTap: () {
                    _downloadService.downloadModel(model.id, fileName).then((_) {
                       ref.read(localModelsProvider.notifier).refreshModels();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching files: ${e.toString()}')),
        );
      }
    }
  }
}
