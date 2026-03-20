import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hf_api_service.dart';
import 'models_provider.dart';

class ModelBrowserScreen extends ConsumerStatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  ConsumerState<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends ConsumerState<ModelBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HFAPIService _apiService = HFAPIService();
  List<HFModelInfo> _searchResults = [];
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchModels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    setState(() => _isSearching = true);
    try {
      final models = await _apiService.searchGGUFModels();
      if (mounted) {
        setState(() {
          _searchResults = models;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'LOCAL', icon: Icon(Icons.storage)),
            Tab(
              text: 'DISCOVER',
              icon: Badge(
                isLabelVisible: _searchResults.isNotEmpty,
                child: const Icon(Icons.public),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Global active downloads banner
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
                  SnackBar(content: Text('Selected: $fileName')),
                );
                Navigator.pop(context);
              },
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: LOCAL MODELS
                _LocalModelsList(
                  models: localModels,
                  onSelect: (file) {
                    ref.read(selectedModelProvider.notifier).state = file;
                    Navigator.pop(context);
                  },
                  onDelete: (file) {
                    _showDeleteConfirm(file);
                  },
                ),

                // TAB 2: DISCOVER
                _DiscoverModelsList(
                  isLoading: _isSearching,
                  models: _searchResults,
                  localModels: localModels,
                  activeDownloads: activeDownloads,
                  onDownload: (model) => _showDownloadDialog(model),
                  onSelect: (model) {
                    final file = localModels.firstWhere(
                      (f) {
                        final name = f.path.toLowerCase();
                        final id = model.shortId.toLowerCase();
                        return name.contains(id);
                      },
                      orElse: () => localModels.first,
                    );
                    ref.read(selectedModelProvider.notifier).state = file;
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(File file) {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model?'),
        content: Text('Are you sure you want to delete "$fileName"? This will free up storage space.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              ref.read(localModelsProvider.notifier).deleteModel(file.path);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
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

class _LocalModelsList extends StatelessWidget {
  final List<File> models;
  final Function(File) onSelect;
  final Function(File) onDelete;

  const _LocalModelsList({
    required this.models,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No downloaded models found'),
            const SizedBox(height: 8),
            const Text('Go to DISCOVER to find and download models',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: models.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final file = models[index];
        final name = file.path.split('/').last;
        final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.description),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Size: $sizeMb MB\nFormat: GGUF'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => onDelete(file),
            ),
            onTap: () => onSelect(file),
          ),
        );
      },
    );
  }
}

class _DiscoverModelsList extends StatelessWidget {
  final bool isLoading;
  final List<HFModelInfo> models;
  final List<File> localModels;
  final Map<String, DownloadProgress> activeDownloads;
  final Function(HFModelInfo) onDownload;
  final Function(HFModelInfo) onSelect;

  const _DiscoverModelsList({
    required this.isLoading,
    required this.models,
    required this.localModels,
    required this.activeDownloads,
    required this.onDownload,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        final isDownloaded = localModels.any(
          (f) => f.path.toLowerCase().contains(model.shortId.toLowerCase()),
        );
        final downloading = activeDownloads.values
            .where((d) => d.modelId == model.id && !d.isCompleted && !d.isFailed)
            .toList();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(
                title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Author: ${model.author}\nDownloads: ${model.downloads}'),
                isThreeLine: true,
                trailing: isDownloaded
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : downloading.isNotEmpty
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(value: downloading.first.progress, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => onDownload(model),
                          ),
                onTap: isDownloaded ? () => onSelect(model) : null,
              ),
              if (downloading.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: LinearProgressIndicator(value: downloading.first.progress),
                ),
            ],
          ),
        );
      },
    );
  }
}

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
                    child: LinearProgressIndicator(value: download.progress, minHeight: 4),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
