// Thin Dart wrapper around the `crisperweaver/ios_helpers`
// MethodChannel registered in ios/Runner/AppDelegate.swift.
//
// Currently only one helper:
//   • [excludeFromBackup] — set `NSURLIsExcludedFromBackupKey` on a
//     directory so iCloud doesn't upload its contents. Used by the
//     batch persistence service for the in-flight checkpoint dir
//     under `<app-docs>/batch/`, where the data is ephemeral
//     (deleted on successful job completion) and uploading it to
//     iCloud is wasted user bandwidth.
//
// Every method is a no-op on non-iOS platforms — desktop and
// Android don't have an iCloud equivalent that needs opting out of,
// so callers can fire-and-forget without an `if (Platform.isIOS)`
// gate.

import 'dart:io';

import 'package:flutter/services.dart';

import 'log_service.dart';

const MethodChannel _channel = MethodChannel('crisperweaver/ios_helpers');

/// Flag [dir] (typically a directory path) as excluded from iCloud
/// backup. No-op on every non-iOS platform. Failures are logged at
/// debug + swallowed — the absence of the exclusion flag isn't a
/// correctness issue, just a polish item, so we don't want to fail
/// loud paths like batch persistence init on its absence.
Future<void> excludeFromBackup(String dir) async {
  if (!Platform.isIOS) return;
  try {
    await _channel.invokeMethod<bool>(
      'excludeFromBackup',
      <String, Object?>{'path': dir},
    );
    Log.instance.d('ios-helpers', 'excluded from backup',
        fields: {'path': dir});
  } on PlatformException catch (e) {
    Log.instance
        .d('ios-helpers', 'excludeFromBackup failed: ${e.message}',
            fields: {'path': dir, 'code': e.code});
  } catch (e) {
    Log.instance
        .d('ios-helpers', 'excludeFromBackup threw: $e', fields: {'path': dir});
  }
}
