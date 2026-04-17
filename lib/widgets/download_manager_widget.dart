// lib/widgets/download_manager_widget.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../services/model_service.dart';

class DownloadManagerWidget extends ConsumerStatefulWidget {
  const DownloadManagerWidget({super.key});

  @override
  ConsumerState<DownloadManagerWidget> createState() => _DownloadManagerWidgetState();
}

class _DownloadManagerWidgetState extends ConsumerState<DownloadManagerWidget>
    with TickerProviderStateMixin {
  final ModelService _modelService = ModelService();
  
  List<ModelInfo> _whisperModels = [];
  List<ModelInfo> _coreMLModels = [];
  StorageInfo? _storageInfo;
  
  // Download tracking
  final Map<String, DownloadProgress> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  final Map<String, String> _downloadErrors = {};

  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadModels();
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);

    try {
      final whisperModels = await _modelService.getWhisperCppModels();
      final coreMLModels = await _modelService.getCoreMLModels();

      setState(() {
        _whisperModels = whisperModels;
        _coreMLModels = coreMLModels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load models: $e');
    }
  }

  Future<void> _loadStorageInfo() async {
    try {
      final storageInfo = await _modelService.getStorageInfo();
      setState(() => _storageInfo = storageInfo);
    } catch (e) {
      print('Failed to load storage info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Download Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadModels();
              _loadStorageInfo();
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear All Models'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: ListTile(
                  leading: Icon(Icons.cancel),
                  title: Text('Cancel All Downloads'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'storage_info',
                child: ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Storage Information'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.memory),
              text: 'Whisper.cpp (${_whisperModels.length})',
            ),
            Tab(
              icon: const Icon(Icons.apple),
              text: 'CoreML (${_coreMLModels.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Storage summary
                if (_storageInfo != null) _buildStorageSummary(),
                
                // Model lists
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildModelList(_whisperModels, ModelType.whisperCpp),
                      _buildModelList(_coreMLModels, ModelType.coreML),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStorageSummary() {
    final storage = _storageInfo!;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Usage',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total: ${storage.formattedTotal}'),
                      Text('Whisper.cpp: ${storage.formattedWhisperCpp}'),
                      Text('CoreML: ${storage.formattedCoreML}'),
                    ],
                  ),
                ),
                if (storage.totalBytes > 0)
                  CircularPercentIndicator(
                    radius: 30.0,
                    lineWidth: 6.0,
                    percent: (storage.totalBytes / (2 * 1024 * 1024 * 1024)).clamp(0.0, 1.0),
                    center: const Icon(Icons.storage),
                    progressColor: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelList(List<ModelInfo> models, ModelType modelType) {
    if (models.isEmpty) {
      return _buildEmptyState(modelType);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return _buildModelCard(model, modelType);
      },
    );
  }

  Widget _buildModelCard(ModelInfo model, ModelType modelType) {
    final downloadKey = '${modelType.name}_${model.name}';
    final progress = _downloadProgress[downloadKey];
    final status = _downloadStatus[downloadKey];
    final error = _downloadErrors[downloadKey];
    final isDownloading = progress != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        model.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Size: ${model.size}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildModelStatus(model, isDownloading),
              ],
            ),

            const SizedBox(height: 12),

            // Progress indicator (if downloading)
            if (isDownloading) ...[
              LinearPercentIndicator(
                lineHeight: 8.0,
                percent: progress.progress.clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade300,
                progressColor: Theme.of(context).primaryColor,
                animation: true,
                animationDuration: 100,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status ?? 'Downloading...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${(progress.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            // Error message (if any)
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                if (model.isDownloaded) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Downloaded'),
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    onPressed: () => _deleteModel(model, modelType),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ] else if (isDownloading) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    onPressed: () => _cancelDownload(model, modelType),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                    onPressed: () => _downloadModel(model, modelType),
                  ),
                  if (error != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      onPressed: () => _downloadModel(model, modelType),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatus(ModelInfo model, bool isDownloading) {
    if (model.isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
            const SizedBox(width: 4),
            Text(
              'Downloaded',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Downloading',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Not Downloaded',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(ModelType modelType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            modelType == ModelType.coreML ? Icons.apple : Icons.memory,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${modelType.name} models available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            modelType == ModelType.coreML && !Platform.isIOS
                ? 'CoreML models are only available on iOS'
                : 'Failed to load model list',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadModel(ModelInfo model, ModelType modelType) async {
    final downloadKey = '${modelType.name}_${model.name}';
    
    setState(() {
      _downloadProgress[downloadKey] = DownloadProgress(0.0);
      _downloadStatus[downloadKey] = 'Starting download...';
      _downloadErrors.remove(downloadKey);
    });

    try {
      final success = await _performDownload(model, modelType, downloadKey);
      
      if (success) {
        setState(() {
          _downloadProgress.remove(downloadKey);
          _downloadStatus.remove(downloadKey);
        });
        await _loadModels();
        await _loadStorageInfo();
        _showSuccessSnackBar('${model.displayName} downloaded successfully');
      } else {
        setState(() {
          _downloadProgress.remove(downloadKey);
          _downloadStatus.remove(downloadKey);
          _downloadErrors[downloadKey] = 'Download failed';
        });
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(downloadKey);
        _downloadStatus.remove(downloadKey);
        _downloadErrors[downloadKey] = e.toString();
      });
      _showErrorSnackBar('Download failed: $e');
    }
  }

  Future<bool> _performDownload(ModelInfo model, ModelType modelType, String downloadKey) async {
    if (modelType == ModelType.coreML) {
      return await _modelService.downloadCoreMLModel(
        model.name,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[downloadKey] = DownloadProgress(progress);
          });
        },
        onStatusChange: (status) {
          setState(() {
            _downloadStatus[downloadKey] = status;
          });
        },
      );
    } else {
      return await _modelService.downloadWhisperCppModel(
        model.name,
        onProgress: (progress) {
          setState(() {
            _downloadProgress[downloadKey] = DownloadProgress(progress);
          });
        },
        onStatusChange: (status) {
          setState(() {
            _downloadStatus[downloadKey] = status;
          });
        },
      );
    }
  }

  Future<void> _cancelDownload(ModelInfo model, ModelType modelType) async {
    final downloadKey = '${modelType.name}_${model.name}';
    
    try {
      await _modelService.cancelDownload(model.name, modelType: modelType);
      
      setState(() {
        _downloadProgress.remove(downloadKey);
        _downloadStatus.remove(downloadKey);
        _downloadErrors.remove(downloadKey);
      });
      
      _showInfoSnackBar('Download cancelled');
    } catch (e) {
      _showErrorSnackBar('Failed to cancel download: $e');
    }
  }

  Future<void> _deleteModel(ModelInfo model, ModelType modelType) async {
    final confirmed = await _showDeleteConfirmation(model.displayName);
    if (!confirmed) return;

    try {
      final success = await _modelService.deleteModel(model.name, modelType: modelType);
      
      if (success) {
        await _loadModels();
        await _loadStorageInfo();
        _showSuccessSnackBar('${model.displayName} deleted');
      } else {
        _showErrorSnackBar('Failed to delete ${model.displayName}');
      }
    } catch (e) {
      _showErrorSnackBar('Delete failed: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(String modelName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete $modelName?'),
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
    ) ?? false;
  }

  void _handleAppBarAction(String action) {
    switch (action) {
      case 'clear_all':
        _clearAllModels();
        break;
      case 'cancel_all':
        _cancelAllDownloads();
        break;
      case 'storage_info':
        _showStorageInfo();
        break;
    }
  }

  Future<void> _clearAllModels() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Models'),
        content: const Text('This will delete all downloaded models. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _modelService.clearAllModels();
        setState(() {
          _downloadProgress.clear();
          _downloadStatus.clear();
          _downloadErrors.clear();
        });
        await _loadModels();
        await _loadStorageInfo();
        _showSuccessSnackBar('All models cleared');
      } catch (e) {
        _showErrorSnackBar('Failed to clear models: $e');
      }
    }
  }

  void _cancelAllDownloads() {
    for (final key in _downloadProgress.keys.toList()) {
      final parts = key.split('_');
      if (parts.length >= 2) {
        final modelType = parts[0] == 'coreML' ? ModelType.coreML : ModelType.whisperCpp;
        final modelName = parts.sublist(1).join('_');
        _modelService.cancelDownload(modelName, modelType: modelType);
      }
    }
    
    setState(() {
      _downloadProgress.clear();
      _downloadStatus.clear();
      _downloadErrors.clear();
    });
    
    _showInfoSnackBar('All downloads cancelled');
  }

  void _showStorageInfo() {
    if (_storageInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Storage Used: ${_storageInfo!.formattedTotal}'),
            const SizedBox(height: 8),
            Text('Whisper.cpp Models: ${_storageInfo!.formattedWhisperCpp}'),
            Text('CoreML Models: ${_storageInfo!.formattedCoreML}'),
            const SizedBox(height: 16),
            const Text(
              'Note: Storage calculations are approximate and may not include all system overhead.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class DownloadProgress {
  final double progress;
  final DateTime timestamp;

  DownloadProgress(this.progress) : timestamp = DateTime.now();
}