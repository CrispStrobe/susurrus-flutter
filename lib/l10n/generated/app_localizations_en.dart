// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CrisperWeaver';

  @override
  String get appTagline => 'Audio transcription with speaker diarization';

  @override
  String get menuHistory => 'History';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuModels => 'Models';

  @override
  String get menuLogs => 'Logs';

  @override
  String get menuAbout => 'About';

  @override
  String get engineReady => 'Engine ready';

  @override
  String get engineStarting => 'Engine starting…';

  @override
  String get audioInput => 'Audio input';

  @override
  String get noFileSelected => 'No file selected';

  @override
  String get browse => 'Browse';

  @override
  String get urlInputLabel => 'Or enter audio URL';

  @override
  String get urlInputHint => 'https://example.com/audio.mp3';

  @override
  String get advancedOptions => 'Advanced options';

  @override
  String get language => 'Language';

  @override
  String get languageAuto => 'Auto-detect';

  @override
  String get model => 'Model';

  @override
  String get transcribe => 'Transcribe';

  @override
  String get transcribing => 'Transcribing…';

  @override
  String get stop => 'Stop';

  @override
  String get clear => 'Clear';

  @override
  String get transcriptionOutput => 'Transcription output';

  @override
  String get noTranscriptionYet => 'No transcription yet';

  @override
  String get noTranscriptionHint =>
      'Select an audio file and start transcription';

  @override
  String get searchTranscription => 'Search transcription…';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get noResultsHint => 'Try a different search term';

  @override
  String get tabSegments => 'Segments';

  @override
  String get tabFullText => 'Full Text';

  @override
  String get sharePlain => 'Share plain text';

  @override
  String get copyClipboard => 'Copy to clipboard';

  @override
  String get saveAsTxt => 'Save as .txt';

  @override
  String get saveAsSrt => 'Save as .srt';

  @override
  String get saveAsVtt => 'Save as .vtt';

  @override
  String get saveAsJson => 'Save as .json';

  @override
  String get copied => 'Copied';

  @override
  String get perfRtf => 'RTF';

  @override
  String get perfAudio => 'Audio';

  @override
  String get perfWall => 'Wall';

  @override
  String get perfWords => 'Words';

  @override
  String get perfWps => 'WPS';

  @override
  String get perfEngine => 'Engine';

  @override
  String get perfModel => 'Model';

  @override
  String get perfFasterThanRealtime => 'faster than real-time';

  @override
  String get perfSlowerThanRealtime => 'slower than real-time';

  @override
  String get diarizationTitle => 'Speaker diarization';

  @override
  String get diarizationSubtitle =>
      'Identify different speakers in audio recordings';

  @override
  String get diarizationModel => 'Diarization model';

  @override
  String get minSpeakers => 'Min. speakers';

  @override
  String get maxSpeakers => 'Max. speakers';

  @override
  String get auto => 'Auto';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsInterfaceLanguage => 'Interface language';

  @override
  String get settingsSystemDefault => 'System default';

  @override
  String get settingsEngineSection => 'Transcription engine';

  @override
  String get settingsEnginePreferred => 'Preferred engine';

  @override
  String get settingsSelectEngine => 'Select engine';

  @override
  String settingsEngineSwitched(String engine) {
    return 'Switched to $engine';
  }

  @override
  String get settingsEngineSwitchFailed => 'Engine switch failed';

  @override
  String settingsAudioQualityCurrent(int percent) {
    return 'Recording quality: $percent%';
  }

  @override
  String get settingsCacheCleared => 'Cache cleared successfully';

  @override
  String get settingsHfToken => 'HuggingFace API token';

  @override
  String get settingsHfTokenNotSet => 'Not set (required for gated models)';

  @override
  String get languageEn => 'English';

  @override
  String get languageDe => 'German';

  @override
  String get languageEs => 'Spanish';

  @override
  String get languageFr => 'French';

  @override
  String get languageIt => 'Italian';

  @override
  String get languagePt => 'Portuguese';

  @override
  String get languageZh => 'Chinese';

  @override
  String get languageJa => 'Japanese';

  @override
  String get languageKo => 'Korean';

  @override
  String modelSize(String size) {
    return 'Size: $size';
  }

  @override
  String modelDeleteConfirm(String name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get historyCopy => 'Copy';

  @override
  String get historyExportSrt => 'Export SRT';

  @override
  String get historyExportTxt => 'Export TXT';

  @override
  String get historyExportJson => 'Export JSON';

  @override
  String get historyDelete => 'Delete';

  @override
  String historyFailedToLoad(String error) {
    return 'Failed to load history: $error';
  }

  @override
  String historySaved(String path) {
    return 'Saved $path';
  }

  @override
  String historyExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get recorderDeleteTitle => 'Delete recording';

  @override
  String get recorderDeleteBody =>
      'Are you sure you want to delete this recording?';

  @override
  String get recorderQueuedForTranscription =>
      'Recording queued for transcription.';

  @override
  String get outputShowTimestamps => 'Show timestamps';

  @override
  String get outputShowSpeakers => 'Show speakers';

  @override
  String get outputShowConfidence => 'Show confidence';

  @override
  String get outputCopyAll => 'Copy all';

  @override
  String get outputExport => 'Export';

  @override
  String get outputPlay => 'Play';

  @override
  String get outputCopy => 'Copy';

  @override
  String get outputEdit => 'Edit';

  @override
  String get outputPlaySegment => 'Play segment';

  @override
  String get outputCopyText => 'Copy text';

  @override
  String get outputEditSegment => 'Edit segment';

  @override
  String get outputEditNotImplemented => 'Segment editing not yet implemented';

  @override
  String get outputExportNotImplemented =>
      'Export functionality not yet implemented';

  @override
  String get outputSegmentCopied => 'Segment copied to clipboard';

  @override
  String get outputAllCopied => 'All transcription copied to clipboard';

  @override
  String outputPlayingSegment(String time) {
    return 'Playing segment: $time';
  }

  @override
  String get settingsHfTokenSubtitle =>
      'Required for gated or private repositories.';

  @override
  String get settingsLoading => 'Loading…';

  @override
  String get transcribeLanguageLabel => 'Language';

  @override
  String transcribeStarting(String model) {
    return 'Starting download: $model';
  }

  @override
  String transcribeUnsupportedFile(String name) {
    return 'Unsupported file type: $name';
  }

  @override
  String transcribeLoadedFile(String name) {
    return 'Loaded $name';
  }

  @override
  String aboutEmail(String email) {
    return 'Email: $email';
  }

  @override
  String aboutPhone(String phone) {
    return 'Phone: $phone';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsTranscription => 'Transcription';

  @override
  String get settingsDefaultModel => 'Default model';

  @override
  String get settingsDefaultLanguage => 'Default language';

  @override
  String get settingsAutoDetectLanguage => 'Auto-detect language';

  @override
  String get settingsAutoDetectLanguageSubtitle =>
      'Automatically detect audio language';

  @override
  String get settingsWordTimestamps => 'Word timestamps';

  @override
  String get settingsWordTimestampsSubtitle =>
      'Generate timestamps for individual words';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAudioQuality => 'Audio quality';

  @override
  String get settingsKeepAudioFiles => 'Keep audio files';

  @override
  String get settingsKeepAudioFilesSubtitle =>
      'Keep downloaded / recorded audio files after transcription';

  @override
  String get settingsDiarization => 'Speaker diarization';

  @override
  String get settingsEnableDiarizationByDefault => 'Enable by default';

  @override
  String get settingsEnableDiarizationByDefaultSubtitle =>
      'Automatically enable diarization for new transcriptions';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsClearCacheSubtitle => 'Clear temporary files and cache';

  @override
  String get settingsManageModels => 'Manage models';

  @override
  String get settingsManageModelsSubtitle =>
      'Download, update, or delete transcription models';

  @override
  String get settingsDebugging => 'Debugging & development';

  @override
  String get settingsLogLevel => 'Log level';

  @override
  String settingsLogLevelCurrent(String level) {
    return 'Currently $level';
  }

  @override
  String get settingsMirrorLogs => 'Mirror logs to file';

  @override
  String get settingsMirrorLogsSubtitle =>
      'Writes to logs/session.log in the app documents directory';

  @override
  String get settingsSkipChecksum => 'Skip checksum verification';

  @override
  String get settingsSkipChecksumSubtitle =>
      'Accept downloaded models even if SHA-1 does not match';

  @override
  String get settingsOpenLogViewer => 'Open log viewer';

  @override
  String get settingsSystemInfo => 'System information';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsAboutCrisperWeaver => 'About CrisperWeaver';

  @override
  String get settingsAboutCrisperWeaverSubtitle =>
      'Author, contact, disclaimer, licenses';

  @override
  String get aboutServiceProvider => 'Service Provider';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutPrivacy => 'Privacy';

  @override
  String get aboutDisclaimer => 'Disclaimer';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutOpenSourceLicenses => 'Open-source licenses';

  @override
  String get aboutPrivacyText =>
      'CrisperWeaver processes all audio locally on your device. No audio data, transcripts, or recordings are sent to any server. Model downloads fetch GGUF weights directly from HuggingFace over HTTPS; nothing else leaves the device.';

  @override
  String get aboutDisclaimerText =>
      'This software is provided \"as is\", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors be liable for any claim, damages or other liability arising from, out of or in connection with the software or its use.';

  @override
  String get aboutLicenseText =>
      'CrisperWeaver is free software, licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). You may redistribute and modify it under the terms of that license. In particular, if you run a modified version of CrisperWeaver as a network service, you must make your source code available to its users.';

  @override
  String get historyTitle => 'Transcription history';

  @override
  String get historyEmpty => 'No transcriptions yet';

  @override
  String get historyEmptyHint =>
      'Run a transcription and it will show up here.';

  @override
  String get historyRefresh => 'Refresh';

  @override
  String get historyClearAll => 'Clear all';

  @override
  String get historyClearAllPrompt =>
      'Remove every saved transcription from this device. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsFilterHint => 'Filter by message, tag, or error…';

  @override
  String get logsCopyVisible => 'Copy visible';

  @override
  String get logsCopyAll => 'Copy all';

  @override
  String get logsExport => 'Export to file';

  @override
  String get logsShare => 'Share as file';

  @override
  String get modelsTitle => 'Model management';

  @override
  String get modelsNoneAvailable => 'No models available';

  @override
  String get modelsRetry => 'Retry';

  @override
  String get modelsDownload => 'Download';

  @override
  String get modelsDelete => 'Delete model';

  @override
  String get modelsDownloaded => 'Downloaded';

  @override
  String get modelsNotDownloaded => 'Not downloaded';

  @override
  String modelsDownloadingPercent(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsDefaultBackend => 'Default backend';

  @override
  String get settingsSelectBackend => 'Select default backend';

  @override
  String settingsSelectModel(String backend) {
    return 'Select default model ($backend)';
  }

  @override
  String get settingsSelectLanguage => 'Select default language';

  @override
  String get settingsSelectInterfaceLanguage => 'Select interface language';

  @override
  String settingsNoModelsForBackend(String backend) {
    return 'No models known for backend \"$backend\". Use the model manager → cloud-download icon to probe HuggingFace.';
  }

  @override
  String get modelFilterHint => 'Filter models (name / quant)';

  @override
  String get modelAnyBackend => 'Any backend';

  @override
  String get modelNoMatch => 'No models match this filter.';

  @override
  String get modelsRefreshFromHf => 'Refresh quants from HuggingFace';

  @override
  String get modelsReloadLocal => 'Reload local state';

  @override
  String get modelsProbedCountZero =>
      'No new quants discovered on HuggingFace.';

  @override
  String modelsProbedCount(int count, String plural) {
    return 'Discovered $count new quant variant$plural.';
  }

  @override
  String get batchQueueTitle => 'Batch queue';

  @override
  String batchQueueSummary(int queued, int running, int done, int errored) {
    return '$queued queued · $running running · $done done · $errored failed';
  }

  @override
  String get batchClearCompleted => 'Clear done';

  @override
  String get batchRemove => 'Remove from queue';

  @override
  String batchEnqueueAdded(int count) {
    return '$count file(s) added to queue.';
  }

  @override
  String get batchRunAll => 'Transcribe all';

  @override
  String get batchStop => 'Stop batch';

  @override
  String get advancedSection => 'Advanced decoding';

  @override
  String get advancedTranslate => 'Translate to English';

  @override
  String get advancedTranslateSubtitle =>
      'Whisper only — forces output to English regardless of source.';

  @override
  String get advancedBeamSearch => 'Beam search';

  @override
  String get advancedBeamSearchSubtitle =>
      'Slower, usually more accurate. Default is greedy.';

  @override
  String get advancedInitialPrompt => 'Initial prompt (vocabulary / context)';

  @override
  String get advancedInitialPromptHint =>
      'e.g. \"CrispASR, Flutter, Riverpod, Sprecher-Unterscheidung\"';
}
