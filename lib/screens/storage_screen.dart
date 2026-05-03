import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../main.dart' show modelServiceProvider;
import '../services/log_service.dart';
import '../services/model_service.dart';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  late Future<List<BackendStorage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<BackendStorage>> _load() {
    return ref.read(modelServiceProvider).getStorageByBackend();
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.storageTitle),
        actions: [
          IconButton(
            tooltip: l.storageRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<BackendStorage>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final groups = snap.data ?? const <BackendStorage>[];
          if (groups.isEmpty) {
            return Center(child: Text(l.storageEmpty));
          }
          final total = groups.fold<int>(0, (a, g) => a + g.bytes);
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              itemCount: groups.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _buildHeader(context, total, groups.length);
                }
                final g = groups[i - 1];
                return _BackendTile(
                  group: g,
                  onDelete: () => _confirmDelete(g),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalBytes, int backendCount) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.storage,
                color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.storageTotalUsed,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(_formatBytes(totalBytes),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(l.storageBackendCount(backendCount),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BackendStorage g) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.storageDeleteTitle(g.backend)),
        content: Text(l.storageDeleteMessage(g.formattedSize, g.fileCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.storageDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final freed = await ref
          .read(modelServiceProvider)
          .deleteBackendModels(g.backend);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.storageDeletedSnack(_formatBytes(freed)))),
      );
      _refresh();
    } catch (e, st) {
      Log.instance.w('storage', 'delete backend failed',
          error: e, stack: st, fields: {'backend': g.backend});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _BackendTile extends StatelessWidget {
  final BackendStorage group;
  final VoidCallback onDelete;

  const _BackendTile({required this.group, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isOther = group.backend == '(other)';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            group.backend.isEmpty ? '?' : group.backend[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          group.backend,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(l.storageFilesCount(group.formattedSize, group.fileCount)),
        trailing: isOther
            ? null
            : IconButton(
                tooltip: l.storageDeleteAllTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
      ),
    );
  }
}
