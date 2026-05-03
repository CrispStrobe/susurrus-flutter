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
  String get menuSynthesize => 'Synthesize speech';

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
  String get settingsModelsDir => 'Models directory';

  @override
  String get settingsModelsDirDefault => 'Default (in app sandbox)';

  @override
  String get settingsModelsDirPickTitle => 'Pick models directory';

  @override
  String get settingsModelsDirCurrentDefault =>
      'Currently using the default app-sandbox path. Pick a custom directory to share GGUFs with other tools (e.g. an external drive).';

  @override
  String settingsModelsDirCurrent(String path) {
    return 'Current: $path';
  }

  @override
  String get settingsModelsDirPick => 'Pick…';

  @override
  String get settingsModelsDirReset => 'Use default';

  @override
  String settingsModelsDirSet(String path) {
    return 'Models directory set to $path';
  }

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
  String get languageRu => 'Russian';

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
  String get recorderStream => 'Stream';

  @override
  String get recorderStreamTooltip =>
      'Live mic transcribe (Whisper sliding window). Partial text appears as you speak.';

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
  String get outputRenameSpeakerTitle => 'Rename speaker';

  @override
  String outputRenameSpeakerOriginal(String original) {
    return 'Original label: $original';
  }

  @override
  String get outputRenameSpeakerReset => 'Reset to original';

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
  String get settingsStorageBreakdown => 'Storage breakdown';

  @override
  String get settingsStorageBreakdownSubtitle =>
      'See per-backend disk usage and free up space';

  @override
  String get storageTitle => 'Storage breakdown';

  @override
  String get storageRefresh => 'Refresh';

  @override
  String get storageEmpty => 'No model files on disk yet.';

  @override
  String get storageTotalUsed => 'Total on disk';

  @override
  String storageBackendCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count backends',
      one: '1 backend',
    );
    return '$_temp0';
  }

  @override
  String storageFilesCount(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$size • $_temp0';
  }

  @override
  String get storageDeleteAllTooltip => 'Delete all models for this backend';

  @override
  String storageDeleteTitle(String backend) {
    return 'Delete all $backend models?';
  }

  @override
  String storageDeleteMessage(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return 'This will free $size across $_temp0 and cannot be undone.';
  }

  @override
  String get storageDeleteConfirm => 'Delete';

  @override
  String storageDeletedSnack(String size) {
    return 'Freed $size';
  }

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
  String get settingsHfTokenTitle => 'Hugging Face API Token';

  @override
  String get settingsHfTokenSave => 'SAVE';

  @override
  String get settingsHfTokenCancel => 'CANCEL';

  @override
  String get transcriptionNoModelsFound => 'No models found';

  @override
  String get transcriptionRetry => 'Retry';

  @override
  String transcriptionLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String transcriptionSavedTo(String path) {
    return 'Saved $path';
  }

  @override
  String transcriptionSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get transcriptionCopiedToClipboard => 'Copied to clipboard';

  @override
  String get transcriptionShareSheetTitle => 'Share or save';

  @override
  String get transcriptionSharePlainText => 'Share plain text';

  @override
  String get transcriptionCopyToClipboard => 'Copy to clipboard';

  @override
  String get transcriptionSaveAsTxt => 'Save as TXT';

  @override
  String get transcriptionSaveAsSrt => 'Save as SRT';

  @override
  String get transcriptionSaveAsVtt => 'Save as VTT';

  @override
  String get transcriptionSaveAsJson => 'Save as JSON';

  @override
  String get transcriptionDownloadModel => 'Download Model';

  @override
  String get transcriptionDownload => 'DOWNLOAD';

  @override
  String get advancedBestOfSingle => 'Best-of-N: single decode (1)';

  @override
  String advancedBestOfCurrent(int n) {
    return 'Best-of-N: $n decodes';
  }

  @override
  String get advancedBestOfHelper =>
      '1 = single decode (default). >1 runs N independent decodes and picks the highest-scoring result. Whisper consumes this internally; other backends loop externally and pick the highest-mean-confidence transcript. Cost is N× per-call decode time.';

  @override
  String get advancedTemperatureGreedy => 'Decoder temperature: greedy (0.00)';

  @override
  String advancedTemperatureCurrent(String value) {
    return 'Decoder temperature: $value';
  }

  @override
  String get advancedTemperatureHelper =>
      '0.00 = greedy / reproducible. > 0 = stochastic sampling — useful when greedy decoding hallucinates a repetition. Whisper has its own internal fallback ladder; this affects sampling backends (canary, cohere, parakeet, moonshine).';

  @override
  String downloadModelPrompt(String name, String size) {
    return 'The model \"$name\" is not yet downloaded. Would you like to download it now (~$size)?';
  }

  @override
  String get tooltipDeleteRecording => 'Delete recording';

  @override
  String get tooltipUseForTranscription => 'Use for transcription';

  @override
  String get tooltipModelSelectionHelp => 'Model selection help';

  @override
  String get tooltipDownloadModel => 'Download model';

  @override
  String get tooltipDisplayLevel => 'Display level';

  @override
  String get tooltipPauseAutoScroll => 'Pause auto-scroll';

  @override
  String get tooltipResumeAutoScroll => 'Resume auto-scroll';

  @override
  String get labelApiToken => 'API Token';

  @override
  String get streamingRequiresWhisper =>
      'Streaming requires the Whisper engine. Switch backend in Settings.';

  @override
  String get streamingMicUnavailable => 'Microphone unavailable for streaming.';

  @override
  String get streamingEngineNoSession =>
      'Engine returned no streaming session.';

  @override
  String playbackFailed(String error) {
    return 'Playback failed: $error';
  }

  @override
  String synthesizeFailed(String error) {
    return 'Synthesize failed: $error';
  }

  @override
  String logsShowLevel(String level) {
    return 'Show $level and above';
  }

  @override
  String get logsCopyVisible => 'Copy visible';

  @override
  String get logsCopyAll => 'Copy all';

  @override
  String get logsExport => 'Export to file';

  @override
  String get logsShare => 'Share as file';

  @override
  String get diarizationAuto => 'Auto';

  @override
  String get diarizationModelSelectionTitle => 'Diarization Model Selection';

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
  String get batchQueueDropHint => 'Drop audio files here to queue them';

  @override
  String get advancedSection => 'Advanced decoding';

  @override
  String get advancedVadTrim => 'Trim silence (VAD)';

  @override
  String get advancedVadTrimSubtitle =>
      'Skip leading and trailing silence via Silero VAD. Faster on meetings / long recordings with silent padding.';

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

  @override
  String get advancedRestorePunctuation => 'Restore punctuation (FireRedPunc)';

  @override
  String get advancedRestorePunctuationSubtitle =>
      'Capitalize and punctuate raw output. Useful for CTC backends (wav2vec2, fastconformer-ctc, firered-asr). Requires fireredpunc-*.gguf in Model Management.';

  @override
  String get advancedSourceLanguage => 'Source language (override autodetect)';

  @override
  String get advancedSourceLanguageAuto => 'Auto / use main picker';

  @override
  String get advancedSourceLanguageHelper =>
      'Pin the source language when whisper\'s autodetect is unreliable on noisy audio. Empty = fall back to the main language dropdown / autodetect.';

  @override
  String get advancedTargetLanguage => 'Translate to (target language)';

  @override
  String get advancedTargetLanguageNone => 'No translation (verbatim)';

  @override
  String get advancedTargetLanguageHelper =>
      'Visible only for translation-capable backends (Canary, Voxtral, Qwen3, Cohere, Whisper). Leave at \"No translation\" for verbatim transcription.';

  @override
  String get advancedAskPrompt => 'Ask the audio (Q&A mode)';

  @override
  String get advancedAskPromptHint =>
      'e.g. \"Summarize\" or \"What\'s the speaker\'s tone?\"';

  @override
  String get advancedAskPromptHelper =>
      'Voxtral / Qwen3-ASR only. When set, the LLM ANSWERS your question instead of producing a verbatim transcript. Leave empty for normal transcription.';

  @override
  String get synthTitle => 'Synthesize';

  @override
  String get synthModelLabel => 'TTS model';

  @override
  String get synthVoiceLabel => 'Voice / voicepack';

  @override
  String get synthCodecLabel => 'Codec / tokenizer';

  @override
  String get synthTextHint => 'Type text to synthesise…';

  @override
  String get synthRunButton => 'Synthesize';

  @override
  String get synthPlayButton => 'Play';

  @override
  String get synthStopButton => 'Stop';

  @override
  String get synthShareButton => 'Save / share WAV';

  @override
  String get synthNoTtsModelsDownloaded =>
      'No TTS models downloaded yet. Open Models → Models tab → switch to \"TTS\" to fetch one.';

  @override
  String synthMissingDependency(String name) {
    return 'Missing required companion file: $name';
  }
}
