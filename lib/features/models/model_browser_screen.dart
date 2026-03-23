import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  final HFAPIService _apiService = HFAPIService();
  List<HFModelInfo> _searchResults = [];
  bool _isSearching = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchModels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchModels(query: query);
    });
  }

  Future<void> _fetchModels({String query = ''}) async {
    setState(() => _isSearching = true);
    try {
      final models = await _apiService.searchGGUFModels(query: query);
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
        surfaceTintColor: Colors.transparent,
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
          color: isDark ? AppTheme.background : const Color(0xFFF8FAFC),
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.background, Color(0xFF161B22)],
              )
            : null,
        ),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 125),
            if (activeDownloads.isNotEmpty)
              _ActiveDownloadsBanner(
                downloads: activeDownloads,
                onCancel: (fileName) => ref.read(activeDownloadsProvider.notifier).cancelDownload(fileName),
                onDismiss: (fileName) => ref.read(activeDownloadsProvider.notifier).removeCompleted(fileName),
                onSelect: (fileName) async {
                  await ref.read(localModelsProvider.notifier).refreshModels();
                  if (!context.mounted) return;
                  final models = ref.read(localModelsProvider);
                  final file = models.firstWhere((f) => f.path.contains(fileName), orElse: () => models.first);
                  ref.read(selectedModelProvider.notifier).selectModel(file);
                  Navigator.pop(context);
                },
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _LocalModelsList(
                    models: localModels,
                    onSelect: (file) {
                      ref.read(selectedModelProvider.notifier).selectModel(file);
                      Navigator.pop(context);
                    },
                    onDelete: _showDeleteConfirm,
                  ),
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search Hugging Face...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentPrimary),
                            suffixIcon: _searchController.text.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded), 
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchModels();
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _DiscoverModelsList(
                          isLoading: _isSearching,
                          models: _searchResults,
                          localModels: localModels,
                          activeDownloads: activeDownloads,
                          onDownload: _showDownloadDialog,
                          onSelect: (model) {
                            final file = localModels.firstWhere(
                              (f) => f.path.toLowerCase().contains(model.shortId.toLowerCase()),
                              orElse: () => localModels.first,
                            );
                            ref.read(selectedModelProvider.notifier).selectModel(file);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP', style: TextStyle(color: AppTheme.textSecondary))),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No compatible GGUF versions found.')));
        return;
      }
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          builder: (context) => _QuantizationBottomSheet(model: model, files: files),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')));
    }
  }
}

class _QuantizationBottomSheet extends ConsumerWidget {
  final HFModelInfo model;
  final List<String> files;
  const _QuantizationBottomSheet({required this.model, required this.files});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.surface : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            height: 5, width: 45,
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'QUALITIES',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 2,
                    color: AppTheme.accentPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select Quantization',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: textColor.withOpacity(0.05)),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final fileName = files[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentPrimary.withOpacity(0.1),
                    child: const Icon(Icons.file_download_outlined, color: AppTheme.accentPrimary, size: 20),
                  ),
                  title: Text(
                    fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.3)),
                  onTap: () {
                    ref.read(activeDownloadsProvider.notifier).startDownload(model.id, fileName);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModelsList extends StatelessWidget {
  final List<File> models;
  final Function(File) onSelect;
  final Function(File) onDelete;
  const _LocalModelsList({required this.models, required this.onSelect, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('No local models found', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: models.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final file = models[index];
        final name = file.path.split('/').last;
        final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(backgroundColor: AppTheme.accentPrimary.withOpacity(0.1), child: const Icon(Icons.psychology_rounded, color: AppTheme.accentPrimary)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$sizeMb MB • GGUF', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => onDelete(file)),
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

  const _DiscoverModelsList({required this.isLoading, required this.models, required this.localModels, required this.activeDownloads, required this.onDownload, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (models.isEmpty) return const Center(child: Text('No models found for your search.', style: TextStyle(color: AppTheme.textSecondary)));

    return ListView.builder(
      itemCount: models.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final model = models[index];
        final isDownloaded = localModels.any((f) => f.path.toLowerCase().contains(model.shortId.toLowerCase()));
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('by ${model.author}', style: const TextStyle(color: AppTheme.accentPrimary, fontSize: 12)),
            trailing: isDownloaded ? const Icon(Icons.check_circle_rounded, color: Colors.green) : const Icon(Icons.download_for_offline_rounded, color: AppTheme.accentPrimary),
            onTap: isDownloaded ? () => onSelect(model) : () => onDownload(model),
          ),
        );
      },
    );
  }
}

class _ActiveDownloadsBanner extends StatelessWidget {
  final Map<String, DownloadProgress> downloads;
  final void Function(String) onCancel;
  final void Function(String) onDismiss;
  final void Function(String) onSelect;
  const _ActiveDownloadsBanner({required this.downloads, required this.onCancel, required this.onDismiss, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.accentPrimary.withOpacity(0.05), border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.1)), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: downloads.values.map((dl) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(dl.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: LinearProgressIndicator(value: dl.progress, color: AppTheme.accentPrimary, backgroundColor: Colors.white10),
          trailing: dl.isCompleted ? TextButton(onPressed: () => onSelect(dl.fileName), child: const Text('USE')) : IconButton(icon: const Icon(Icons.close), onPressed: () => onCancel(dl.fileName)),
        )).toList(),
      ),
    );
  }
}
