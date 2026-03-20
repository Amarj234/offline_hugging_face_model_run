import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hf_api_service.dart';
import 'models_provider.dart';
import '../../core/theme.dart';

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
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Search Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localModels = ref.watch(localModelsProvider);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('EXPLORE MODELS'),
        backgroundColor: (isDark ? AppTheme.background : Colors.white).withOpacity(0.8),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          indicatorColor: AppTheme.accentPrimary,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          labelColor: AppTheme.accentPrimary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: [
            const Tab(text: 'LOCAL', icon: Icon(Icons.storage_rounded, size: 20)),
            Tab(
              text: 'DISCOVER',
              icon: Badge(
                isLabelVisible: _searchResults.isNotEmpty,
                backgroundColor: AppTheme.accentSecondary,
                child: const Icon(Icons.language_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.background, Color(0xFF161B33)],
              )
            : null,
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 104), // Space for AppBar + TabBar
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
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.accentPrimary,
                      content: Text('Activated: $fileName'),
                    ),
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
      ),
    );
  }

  void _showDeleteConfirm(File file) {
    final fileName = file.path.split('/').last;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Model?'),
        content: Text('Remove "$fileName" safely? This action cannot be undone.', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('KEEP', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(localModelsProvider.notifier).deleteModel(file.path);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
            const SnackBar(content: Text('No compatible GGUF versions found.')),
          );
        }
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Select Quantization Version',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final fileName = files[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.file_present_rounded, color: AppTheme.accentPrimary),
                          ),
                          title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.download_rounded, color: AppTheme.accentPrimary),
                          onTap: () {
                            ref.read(activeDownloadsProvider.notifier).startDownload(
                                  model.id,
                                  fileName,
                                );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppTheme.accentPrimary,
                                content: Text('Download initialized: $fileName'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: ${e.toString()}')),
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
            Icon(Icons.auto_awesome_motion_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('No models downloaded', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Switch to Discover to find your first AI model!', style: TextStyle(color: Colors.white24, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: models.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (context, index) {
        final file = models[index];
        final name = file.path.split('/').last;
        final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accentPrimary, AppTheme.accentSecondary]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$sizeMb MB • GGUF', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.accentPrimary),
            const SizedBox(height: 24),
            Text('Searching HuggingFace...', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 1)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: models.length,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (context, index) {
        final model = models[index];
        final isDownloaded = localModels.any(
          (f) => f.path.toLowerCase().contains(model.shortId.toLowerCase()),
        );
        final downloading = activeDownloads.values
            .where((d) => d.modelId == model.id && !d.isCompleted && !d.isFailed)
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('by ${model.author}', style: const TextStyle(color: AppTheme.accentPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${model.downloads} downloads', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                trailing: isDownloaded
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
                        child: const Text('READY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    : downloading.isNotEmpty
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentPrimary))
                        : IconButton(
                            icon: const Icon(Icons.download_for_offline_rounded, color: AppTheme.accentPrimary, size: 28),
                            onPressed: () => onDownload(model),
                          ),
                onTap: isDownloaded ? () => onSelect(model) : null,
              ),
              if (downloading.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloading.first.progress,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      color: AppTheme.accentPrimary,
                      minHeight: 6,
                    ),
                  ),
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
    final activeList = downloads.values.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_outlined, color: AppTheme.accentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'LIVE DOWNLOADS',
                style: TextStyle(
                  color: AppTheme.accentPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeList.map((dl) => _DownloadTile(
                download: dl,
                onCancel: () => onCancel(dl.fileName),
                onDismiss: () => onDismiss(dl.fileName),
                onSelect: () => onSelect(dl.fileName),
              )),
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
    bool isError = download.isFailed;
    bool isDone = download.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  download.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDone)
                TextButton(
                  onPressed: onSelect,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    backgroundColor: AppTheme.accentPrimary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('SELECT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              IconButton(
                icon: Icon(
                  isDone || isError ? Icons.close_rounded : Icons.cancel_rounded,
                  size: 18,
                  color: isError ? Colors.redAccent : AppTheme.textSecondary,
                ),
                onPressed: isDone || isError ? onDismiss : onCancel,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (!isDone && !isError)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: download.progress,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.05),
                color: AppTheme.accentPrimary,
              ),
            ),
          if (isError)
            const Text('Download failed. Check connection.', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
        ],
      ),
    );
  }
}
