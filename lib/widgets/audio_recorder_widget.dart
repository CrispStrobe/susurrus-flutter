import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../services/settings_service.dart';

class AudioRecorderWidget extends ConsumerStatefulWidget {
  const AudioRecorderWidget({super.key});

  @override
  ConsumerState<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends ConsumerState<AudioRecorderWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  List<double> _amplitudes = [];
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Audio Recorder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recording controls
            Row(
              children: [
                // Record/Stop button
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: FloatingActionButton(
                        heroTag: "record_button",
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                        backgroundColor: _isRecording ? Colors.red : Colors.blue,
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(width: 16),
                
                // Pause/Resume button (only show when recording)
                if (_isRecording) ...[
                  IconButton(
                    onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    iconSize: 32,
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Duration display
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDuration(_recordingDuration),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: _isRecording ? Colors.red : null,
                        ),
                      ),
                      if (_isRecording)
                        Text(
                          _isPaused ? 'Paused' : 'Recording...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isPaused ? Colors.orange : Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Recording visualizer
            if (_isRecording) ...[
              const SizedBox(height: 16),
              _buildAudioVisualizer(),
            ],
            
            // Recorded file info
            if (_recordingPath != null && !_isRecording) ...[
              const SizedBox(height: 16),
              _buildRecordedFileInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioVisualizer() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: CustomPaint(
        painter: AudioVisualizerPainter(
          isRecording: _isRecording && !_isPaused,
          animationValue: _pulseController.value,
          amplitudes: _amplitudes,
        ),
      ),
    );
  }

  Widget _buildRecordedFileInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recording completed',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Duration: ${_formatDuration(_recordingDuration)}',
                  style: TextStyle(color: Colors.green.shade600),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                onPressed: _isPlaying ? _stopPlayback : _playRecording,
                tooltip: _isPlaying ? 'Stop playback' : 'Play recording',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteRecording,
                tooltip: 'Delete recording',
              ),
              IconButton(
                icon: const Icon(Icons.upload),
                onPressed: _useRecording,
                tooltip: 'Use for transcription',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    final audioService = ref.read(audioServiceProvider);
    final settingsService = ref.read(settingsServiceProvider);
    
    try {
      final path = await audioService.startRecording(settingsService: settingsService);
      if (path != null) {
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingDuration = Duration.zero;
          _recordingPath = path;
          _amplitudes = [];
        });
        
        // Start animation
        _pulseController.repeat(reverse: true);
        
        // Start timer
        _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (_isRecording && !_isPaused) {
            final amp = await audioService.getAmplitude();
            if (mounted) {
              setState(() {
                _recordingDuration += const Duration(milliseconds: 100);
                _amplitudes.add(amp);
                if (_amplitudes.length > 100) _amplitudes.removeAt(0);
              });
            }
          }
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    final audioService = ref.read(audioServiceProvider);
    
    try {
      final path = await audioService.stopRecording();
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingPath = path;
      });
      
      _timer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
    } catch (e) {
      _showErrorDialog('Failed to stop recording: $e');
    }
  }

  void _pauseRecording() {
    setState(() {
      _isPaused = true;
    });
    _pulseController.stop();
  }

  void _resumeRecording() {
    setState(() {
      _isPaused = false;
    });
    _pulseController.repeat(reverse: true);
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    
    final audioService = ref.read(audioServiceProvider);
    try {
      setState(() => _isPlaying = true);
      await audioService.playAudio(File(_recordingPath!));
      if (mounted) setState(() => _isPlaying = false);
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
      _showErrorDialog('Failed to play recording: $e');
    }
  }

  Future<void> _stopPlayback() async {
    final audioService = ref.read(audioServiceProvider);
    try {
      await audioService.stopPlayback();
      if (mounted) setState(() => _isPlaying = false);
    } catch (_) {}
  }

  void _deleteRecording() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this recording?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performDeleteRecording();
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _performDeleteRecording() {
    if (_recordingPath != null) {
      try {
        File(_recordingPath!).deleteSync();
        setState(() {
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      } catch (e) {
        _showErrorDialog('Failed to delete recording: $e');
      }
    }
  }

  void _useRecording() {
    if (_recordingPath == null) return;
    _stopPlayback();
    ref.read(selectedAudioPathProvider.notifier).state = _recordingPath;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording queued for transcription.')),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final milliseconds = (duration.inMilliseconds % 1000) ~/ 10;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
             '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
             '${seconds.toString().padLeft(2, '0')}.'
             '${milliseconds.toString().padLeft(2, '0')}';
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

class AudioVisualizerPainter extends CustomPainter {
  final bool isRecording;
  final double animationValue;
  final List<double> amplitudes;
  
  AudioVisualizerPainter({
    required this.isRecording,
    required this.animationValue,
    required this.amplitudes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;
    
    final paint = Paint()
      ..color = isRecording ? Colors.red.withOpacity(0.6) : Colors.grey.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    final spacing = size.width / amplitudes.length;
    final centerY = size.height / 2;
    
    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * spacing;
      final amplitude = amplitudes[i];
      final height = (amplitude * size.height).clamp(4.0, size.height - 4);
      
      final rect = Rect.fromCenter(
        center: Offset(x, centerY),
        width: spacing * 0.8,
        height: height,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AudioVisualizerPainter oldDelegate) {
    return oldDelegate.isRecording != isRecording || 
           oldDelegate.amplitudes.length != amplitudes.length ||
           isRecording;
  }
}