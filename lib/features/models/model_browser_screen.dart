import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hf_api_service.dart';
import 'models_provider.dart';

class ModelBrowserScreen extends ConsumerStatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  ConsumerState<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends ConsumerState<ModelBrowserScreen> {
  final HFAPIService _apiService = HFAPIService();
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
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Browser'),
      ),
      body: Column(
        children: [
          // Active downloads banner
          if (activeDownloads.isNotEmpty)
            _ActiveDownloadsBanner(
              downloads: activeDownloads,
              onCancel: (fileName) {
                ref.read(activeDownloadsProvider.notifier).cancelDownload(fileName);
              },
              onDismiss: (fileName) {
                ref.read(activeDownloadsProvider.notifier).removeCompleted(fileName);
              },
              onSelect: (fileName) async {
                await ref.read(localModelsProvider.notifier).refreshModels();
                if (!context.mounted) return;
                
                final models = ref.read(localModelsProvider);
                final file = models.firstWhere(
                  (f) => f.path.contains(fileName),
                  orElse: () => models.firstWhere((f) => true), 
                );
                ref.read(selectedModelProvider.notifier).state = file;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected model file: $fileName')),
                );
                Navigator.pop(context);
              },
            ),
          // Model list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _models.length,
                    itemBuilder: (context, index) {
                      final model = _models[index];
                      final isDownloaded = localModels.any(
                        (f) => f.path.contains(model.shortId),
                      );
                      // Check if any file of this model is being downloaded
                      final downloading = activeDownloads.values
                          .where((d) => d.modelId == model.id && !d.isCompleted && !d.isFailed)
                          .toList();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                model.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Author: ${model.author}\nDownloads: ${model.downloads}',
                              ),
                              isThreeLine: true,
                              trailing: isDownloaded
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : downloading.isNotEmpty
                                      ? SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                value: downloading.first.progress,
                                                strokeWidth: 3,
                                              ),
                                              Text(
                                                '${(downloading.first.progress * 100).toInt()}%',
                                                style: theme.textTheme.labelSmall,
                                              ),
                                            ],
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.download),
                                          onPressed: () => _showDownloadDialog(model),
                                        ),
                              onTap: isDownloaded
                                  ? () {
                                      final file = localModels.firstWhere(
                                        (f) {
                                          final name = f.path.toLowerCase();
                                          final id = model.shortId.toLowerCase();
                                          return name.contains(id);
                                        },
                                        orElse: () => localModels.first,
                                      );
                                      ref.read(selectedModelProvider.notifier).state = file;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Selected: ${model.name}'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                      Navigator.pop(context);
                                    }
                                  : null,
                            ),
                            // Inline progress bar for downloading models
                            if (downloading.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: downloading.first.progress,
                                        minHeight: 6,
                                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Downloading ${downloading.first.fileName}',
                                          style: theme.textTheme.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          downloading.first.progressText,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select file to download',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final fileName = files[index];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(fileName),
                        trailing: const Icon(Icons.download),
                        onTap: () {
                          ref.read(activeDownloadsProvider.notifier).startDownload(
                            model.id,
                            fileName,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Download started: $fileName'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
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

/// Banner showing all active downloads at the top
class _ActiveDownloadsBanner extends StatelessWidget {
  final Map<String, DownloadProgress> downloads;
  final void Function(String fileName) onCancel;
  final void Function(String fileName) onDismiss;
  final void Function(String fileName) onSelect;

  const _ActiveDownloadsBanner({
    required this.downloads,
    required this.onCancel,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeList = downloads.values.toList();

    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Downloads',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...activeList.map((dl) => _DownloadTile(
                download: dl,
                onCancel: () => onCancel(dl.fileName),
                onDismiss: () => onDismiss(dl.fileName),
                onSelect: () => onSelect(dl.fileName),
              )),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final DownloadProgress download;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final VoidCallback onSelect;

  const _DownloadTile({
    required this.download,
    required this.onCancel,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color iconColor;
    if (download.isCompleted) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (download.isFailed) {
      icon = Icons.error;
      iconColor = Colors.red;
    } else {
      icon = Icons.downloading;
      iconColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  download.fileName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!download.isCompleted && !download.isFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: download.progress,
                        minHeight: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            download.progressText,
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (download.isCompleted)
            TextButton(
              onPressed: onSelect,
              child: const Text('SELECT'),
            ),
          if (download.isCompleted || download.isFailed)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            )
          else
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              onPressed: onCancel,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
