// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Susurrus';

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
  String get settingsEngineSection => 'Transcription engine';

  @override
  String get settingsEnginePreferred => 'Preferred engine';

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
  String get settingsAboutSusurrus => 'About Susurrus';

  @override
  String get settingsAboutSusurrusSubtitle =>
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
      'Susurrus processes all audio locally on your device. No audio data, transcripts, or recordings are sent to any server. Model downloads fetch GGUF weights directly from HuggingFace over HTTPS; nothing else leaves the device.';

  @override
  String get aboutDisclaimerText =>
      'This software is provided \"as is\", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors be liable for any claim, damages or other liability arising from, out of or in connection with the software or its use.';

  @override
  String get aboutLicenseText =>
      'Susurrus is free software, licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). You may redistribute and modify it under the terms of that license. In particular, if you run a modified version of Susurrus as a network service, you must make your source code available to its users.';

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
}
