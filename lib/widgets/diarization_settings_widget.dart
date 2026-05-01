import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class DiarizationSettingsWidget extends StatefulWidget {
  final bool enabled;
  final void Function(bool enabled) onChanged;

  const DiarizationSettingsWidget({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<DiarizationSettingsWidget> createState() =>
      _DiarizationSettingsWidgetState();
}

class _DiarizationSettingsWidgetState extends State<DiarizationSettingsWidget> {
  int? _minSpeakers;
  int? _maxSpeakers;
  String _diarizationModel = 'Default';

  final List<String> _availableModels = [
    'Default',
    'English',
    'Chinese',
    'German',
    'Spanish',
    'Japanese',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with enable/disable toggle
            Row(
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).diarizationTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch(
                  value: widget.enabled,
                  onChanged: widget.onChanged,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              AppLocalizations.of(context).diarizationSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),

            if (widget.enabled) ...[
              const SizedBox(height: 16),
              _buildDiarizationSettings(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiarizationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Diarization model selection
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).diarizationModel),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _diarizationModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _availableModels.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Text(model),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _diarizationModel = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: _showModelHelp,
              tooltip: 'Model selection help',
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Speaker count settings
        Row(
          children: [
            // Minimum speakers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).minSpeakers),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    initialValue: _minSpeakers,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Auto'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Auto'),
                      ),
                      ...List.generate(10, (i) => i + 1).map((count) {
                        return DropdownMenuItem<int?>(
                          value: count,
                          child: Text(count.toString()),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _minSpeakers = value;
                        // Ensure max >= min
                        if (_maxSpeakers != null &&
                            value != null &&
                            _maxSpeakers! < value) {
                          _maxSpeakers = value;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Maximum speakers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).maxSpeakers),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    initialValue: _maxSpeakers,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Auto'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Auto'),
                      ),
                      ...List.generate(10, (i) => i + 1).map((count) {
                        return DropdownMenuItem<int?>(
                          value: count,
                          child: Text(count.toString()),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _maxSpeakers = value;
                        // Ensure min <= max
                        if (_minSpeakers != null &&
                            value != null &&
                            _minSpeakers! > value) {
                          _minSpeakers = value;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tips and information
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tips for better results',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Use clean audio with minimal background noise\n'
                '• Recordings where speakers don\'t talk over each other work better\n'
                '• Choose language-specific models for non-English content\n'
                '• Set min/max speakers if you know how many to expect',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Performance note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diarization may take longer than standard transcription',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showModelHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diarization Model Selection'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose the appropriate diarization model for your audio:\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Default: General purpose diarization model'),
              Text('• English: Optimized for English conversations'),
              Text('• Chinese: Optimized for Mandarin Chinese conversations'),
              Text('• German: Optimized for German conversations'),
              Text('• Spanish: Optimized for Spanish conversations'),
              Text('• Japanese: Optimized for Japanese conversations'),
              SizedBox(height: 12),
              Text(
                'Language-specific models may provide better results for their respective languages, '
                'especially for phone calls and naturalistic conversations.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
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

  // Getters for accessing current settings
  String get diarizationModel => _diarizationModel;
  int? get minSpeakers => _minSpeakers;
  int? get maxSpeakers => _maxSpeakers;
}
