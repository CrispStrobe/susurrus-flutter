import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../main.dart' show modelServiceProvider;
import '../services/model_service.dart';

class ModelManagementScreen extends ConsumerStatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  ConsumerState<ModelManagementScreen> createState() =>
      _ModelManagementScreenState();
}

class _ModelManagementScreenState extends ConsumerState<ModelManagementScreen> {
  List<ModelInfo> _whisperModels = [];
  bool _isLoading = true;
  String? _downloadingModel;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    try {
      final modelService = ref.read(modelServiceProvider);
      _whisperModels = await modelService.getWhisperCppModels();
    } catch (e) {
      _showErrorDialog('Failed to load models: $e');
    }

    setState(() => _isLoading = false);
  }

  bool _probing = false;

  Future<void> _probeHf() async {
    setState(() => _probing = true);
    try {
      final added =
          await ref.read(modelServiceProvider).refreshAvailableQuants();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added == 0
              ? 'No new quants discovered on HuggingFace.'
              : 'Discovered $added new quant variant${added == 1 ? "" : "s"}.'),
        ),
      );
      await _loadModels();
    } catch (e) {
      _showErrorDialog('HuggingFace probe failed: $e');
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).modelsTitle),
        actions: [
          IconButton(
            icon: _probing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            tooltip: AppLocalizations.of(context).modelsRefreshFromHf,
            onPressed: _probing ? null : _probeHf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).modelsReloadLocal,
            onPressed: _loadModels,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildModelList(_whisperModels),
    );
  }

  Widget _buildModelList(List<ModelInfo> models) {
    if (models.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildSummaryCard(models),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              return _buildModelCard(model);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<ModelInfo> models) {
    final downloadedCount = models.where((m) => m.isDownloaded).length;
    final totalSize = _calculateTotalSize(models.where((m) => m.isDownloaded));

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.memory,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CrispASR Models',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$downloadedCount of ${models.length} downloaded',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Total size: $totalSize',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(ModelInfo model) {
    final isDownloading = _downloadingModel == model.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              model.isDownloaded ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(
            model.isDownloaded ? Icons.check : Icons.download,
            color: model.isDownloaded
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                model.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (model.backend.isNotEmpty && model.backend != 'whisper')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  model.backend,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            if (model.quantization.isNotEmpty && model.quantization != 'f16')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  model.quantization,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).modelSize(model.size)),
            Text(model.description),
            if (model.isDownloaded)
              Text(
                AppLocalizations.of(context).modelsDownloaded,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (isDownloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).modelsDownloadingPercent(
                        (_downloadProgress * 100).toStringAsFixed(1)),
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _downloadProgress),
                ],
              )
            else
              Text(AppLocalizations.of(context).modelsNotDownloaded),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (model.isDownloaded) ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteModel(model),
                tooltip: AppLocalizations.of(context).modelsDelete,
              ),
            ] else if (!isDownloading) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: Text(AppLocalizations.of(context).modelsDownload),
                onPressed: () => _downloadModel(model),
              ),
            ],
          ],
        ),
        isThreeLine: isDownloading,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.memory, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).modelsNoneAvailable,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context).modelsRetry),
            onPressed: _loadModels,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(ModelInfo model) async {
    setState(() {
      _downloadingModel = model.name;
      _downloadProgress = 0.0;
    });

    try {
      final modelService = ref.read(modelServiceProvider);
      final success = await modelService.downloadWhisperCppModel(
        model.name,
        onProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${model.displayName} downloaded successfully')),
        );
        await _loadModels();
      } else {
        _showErrorDialog('Failed to download ${model.displayName}');
      }
    } catch (e) {
      _showErrorDialog('Download failed: $e');
    } finally {
      setState(() {
        _downloadingModel = null;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _deleteModel(ModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).modelsDelete),
        content: Text(
            AppLocalizations.of(context).modelDeleteConfirm(model.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success =
          await ref.read(modelServiceProvider).deleteModel(model.name);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.displayName} deleted')),
        );
        await _loadModels();
      } else {
        _showErrorDialog('Failed to delete ${model.displayName}');
      }
    } catch (e) {
      _showErrorDialog('Delete failed: $e');
    }
  }

  String _calculateTotalSize(Iterable<ModelInfo> models) {
    final count = models.length;
    if (count == 0) return '0 MB';

    double totalMB = 0;
    for (final model in models) {
      if (model.size.contains('GB')) {
        final gb = double.tryParse(model.size.split(' ')[0]) ?? 0;
        totalMB += gb * 1024;
      } else if (model.size.contains('MB')) {
        final mb = double.tryParse(model.size.split(' ')[0]) ?? 0;
        totalMB += mb;
      }
    }

    if (totalMB > 1024) {
      return '${(totalMB / 1024).toStringAsFixed(1)} GB';
    } else {
      return '${totalMB.toStringAsFixed(0)} MB';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }
}
