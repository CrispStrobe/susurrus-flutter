// lib/screens/model_management_screen.dart (FIXED)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/model_service.dart';

class ModelManagementScreen extends ConsumerStatefulWidget {
  const ModelManagementScreen({super.key});

  @override
  ConsumerState<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends ConsumerState<ModelManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ModelService _modelService = ModelService();

  List<ModelInfo> _whisperModels = [];
  List<ModelInfo> _coreMLModels = [];
  bool _isLoading = true;
  String? _downloadingModel;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: Platform.isIOS ? 2 : 1,
      vsync: this,
    );
    _loadModels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    try {
      _whisperModels = await _modelService.getWhisperCppModels();

      if (Platform.isIOS) {
        _coreMLModels = await _modelService.getCoreMLModels();
      }
    } catch (e) {
      _showErrorDialog('Failed to load models: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadModels),
        ],
        bottom: Platform.isIOS
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Whisper.cpp'),
                  Tab(text: 'CoreML'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Platform.isIOS
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildModelList(_whisperModels, ModelType.whisperCpp),
                    _buildModelList(_coreMLModels, ModelType.coreML),
                  ],
                )
              : _buildModelList(_whisperModels, ModelType.whisperCpp),
    );
  }

  Widget _buildModelList(List<ModelInfo> models, ModelType modelType) {
    if (models.isEmpty) {
      return _buildEmptyState(modelType);
    }

    return Column(
      children: [
        _buildSummaryCard(models, modelType),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              return _buildModelCard(model, modelType);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(List<ModelInfo> models, ModelType modelType) {
    final downloadedCount = models.where((m) => m.isDownloaded).length;
    final totalSize = _calculateTotalSize(models.where((m) => m.isDownloaded));

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              modelType == ModelType.coreML ? Icons.apple : Icons.memory,
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelType == ModelType.coreML ? 'CoreML Models' : 'Whisper.cpp Models',
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

  Widget _buildModelCard(ModelInfo model, ModelType modelType) {
    final isDownloading = _downloadingModel == model.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: model.isDownloaded
              ? Colors.green.shade100
              : Colors.grey.shade200,
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
            Text('Size: ${model.size}'),
            Text(model.description),
            if (model.isDownloaded)
              Text(
                'Downloaded',
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
                    'Downloading... ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _downloadProgress),
                ],
              )
            else
              const Text('Not downloaded'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (model.isDownloaded) ...[
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteModel(model, modelType),
                tooltip: 'Delete model',
              ),
            ] else if (!isDownloading) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                onPressed: () => _downloadModel(model, modelType),
              ),
            ],
          ],
        ),
        isThreeLine: isDownloading,
      ),
    );
  }

  Widget _buildEmptyState(ModelType modelType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.memory, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No models available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            modelType == ModelType.coreML
                ? 'CoreML models not supported on this device'
                : 'Failed to load model list',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            onPressed: _loadModels,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(ModelInfo model, ModelType modelType) async {
    setState(() {
      _downloadingModel = model.name;
      _downloadProgress = 0.0;
    });

    try {
      bool success = false;

      if (modelType == ModelType.coreML) {
        success = await _modelService.downloadCoreMLModel(
          model.name,
          onProgress: (progress) {
            setState(() => _downloadProgress = progress);
          },
        );
      } else {
        success = await _modelService.downloadWhisperCppModel(
          model.name,
          onProgress: (progress) {
            setState(() => _downloadProgress = progress);
          },
        );
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.displayName} downloaded successfully')),
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

  Future<void> _deleteModel(ModelInfo model, ModelType modelType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${model.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _modelService.deleteModel(model.name, modelType: modelType);
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
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}