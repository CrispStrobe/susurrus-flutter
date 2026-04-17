import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel { trace, debug, info, warn, error }

extension LogLevelX on LogLevel {
  /// Lower means more verbose.
  int get rank => LogLevel.values.indexOf(this);
  String get tag {
    switch (this) {
      case LogLevel.trace:
        return 'TRC';
      case LogLevel.debug:
        return 'DBG';
      case LogLevel.info:
        return 'INF';
      case LogLevel.warn:
        return 'WRN';
      case LogLevel.error:
        return 'ERR';
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stack;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stack,
  });

  String format({bool includeStack = false}) {
    final ts = timestamp.toIso8601String();
    final errPart = error != null ? ' :: $error' : '';
    final stackPart =
        (includeStack && stack != null) ? '\n$stack' : '';
    return '$ts ${level.tag} [$tag] $message$errPart$stackPart';
  }

  @override
  String toString() => format();
}

/// Process-wide ring-buffered logger.
///
/// The logger is intentionally a singleton — all services, engines, and
/// screens write through `Log.i('tag', 'message')`. It keeps the last N
/// entries in memory for the in-app Logs screen, and (when enabled) mirrors
/// every entry to `logs/session.log` inside the app documents directory.
class Log {
  Log._();
  static final Log _instance = Log._();
  static Log get instance => _instance;

  final Queue<LogEntry> _buffer = Queue<LogEntry>();
  final StreamController<LogEntry> _stream =
      StreamController<LogEntry>.broadcast();

  int _capacity = 2000;
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  bool _fileSink = false;
  File? _sinkFile;
  IOSink? _sink;

  /// Stream of newly-emitted entries.
  Stream<LogEntry> get stream => _stream.stream;

  /// A snapshot of the in-memory buffer (oldest first).
  List<LogEntry> snapshot() => _buffer.toList(growable: false);

  LogLevel get minLevel => _minLevel;
  bool get fileSinkEnabled => _fileSink;
  int get capacity => _capacity;
  File? get sinkFile => _sinkFile;

  void setMinLevel(LogLevel level) {
    _minLevel = level;
    // Re-emit as an info line so the UI can show the change.
    _emit(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      tag: 'log',
      message: 'Log level set to ${level.tag}',
    ));
  }

  void setCapacity(int size) {
    _capacity = size.clamp(100, 100000);
    while (_buffer.length > _capacity) {
      _buffer.removeFirst();
    }
  }

  Future<void> enableFileSink(bool enable) async {
    if (enable == _fileSink) return;
    if (enable) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final logsDir = Directory(p.join(dir.path, 'logs'));
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }
        _sinkFile = File(p.join(logsDir.path, 'session.log'));
        _sink = _sinkFile!.openWrite(mode: FileMode.append);
        _fileSink = true;
        _emit(LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.info,
          tag: 'log',
          message: 'File sink enabled: ${_sinkFile!.path}',
        ));
      } catch (e, st) {
        _emit(LogEntry(
          timestamp: DateTime.now(),
          level: LogLevel.error,
          tag: 'log',
          message: 'Failed to open log sink',
          error: e,
          stack: st,
        ));
        _fileSink = false;
        _sink = null;
        _sinkFile = null;
      }
    } else {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;
      _fileSink = false;
    }
  }

  Future<void> clear({bool alsoDisk = true}) async {
    _buffer.clear();
    if (alsoDisk && _sinkFile != null && await _sinkFile!.exists()) {
      await _sink?.flush();
      await _sink?.close();
      await _sinkFile!.writeAsString('');
      _sink = _sinkFile!.openWrite(mode: FileMode.append);
    }
    _emit(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      tag: 'log',
      message: 'Log cleared',
    ));
  }

  void t(String tag, String message, {Object? error, StackTrace? stack}) =>
      log(LogLevel.trace, tag, message, error: error, stack: stack);
  void d(String tag, String message, {Object? error, StackTrace? stack}) =>
      log(LogLevel.debug, tag, message, error: error, stack: stack);
  void i(String tag, String message, {Object? error, StackTrace? stack}) =>
      log(LogLevel.info, tag, message, error: error, stack: stack);
  void w(String tag, String message, {Object? error, StackTrace? stack}) =>
      log(LogLevel.warn, tag, message, error: error, stack: stack);
  void e(String tag, String message, {Object? error, StackTrace? stack}) =>
      log(LogLevel.error, tag, message, error: error, stack: stack);

  void log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stack,
  }) {
    if (level.rank < _minLevel.rank) return;
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stack: stack,
    );
    _emit(entry);
  }

  void _emit(LogEntry entry) {
    _buffer.add(entry);
    while (_buffer.length > _capacity) {
      _buffer.removeFirst();
    }
    _stream.add(entry);
    // Mirror to console in debug.
    if (kDebugMode) {
      debugPrint(entry.format());
    }
    // Mirror to file sink when enabled.
    final sink = _sink;
    if (sink != null) {
      try {
        sink.writeln(entry.format(includeStack: entry.stack != null));
      } catch (_) {
        // Swallow — don't crash the app over a log failure.
      }
    }
  }

  String dumpAll() {
    final buf = StringBuffer();
    for (final e in _buffer) {
      buf.writeln(e.format(includeStack: e.stack != null));
    }
    return buf.toString();
  }

  /// Dumps the current buffer to a timestamped file and returns its path.
  Future<String> exportToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(dir.path, 'logs'));
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    final stamp =
        DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
    final file = File(p.join(logsDir.path, 'crisperweaver-$stamp.log'));
    await file.writeAsString(dumpAll(), encoding: utf8);
    return file.path;
  }
}
