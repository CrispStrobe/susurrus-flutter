import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CrisperWeaver'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Audio transcription with speaker diarization'**
  String get appTagline;

  /// No description provided for @menuHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get menuHistory;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get menuModels;

  /// No description provided for @menuSynthesize.
  ///
  /// In en, this message translates to:
  /// **'Synthesize speech'**
  String get menuSynthesize;

  /// No description provided for @menuLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get menuLogs;

  /// No description provided for @menuAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get menuAbout;

  /// No description provided for @engineReady.
  ///
  /// In en, this message translates to:
  /// **'Engine ready'**
  String get engineReady;

  /// No description provided for @engineStarting.
  ///
  /// In en, this message translates to:
  /// **'Engine starting…'**
  String get engineStarting;

  /// No description provided for @audioInput.
  ///
  /// In en, this message translates to:
  /// **'Audio input'**
  String get audioInput;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @urlInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Or enter audio URL'**
  String get urlInputLabel;

  /// No description provided for @urlInputHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/audio.mp3'**
  String get urlInputHint;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get advancedOptions;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect'**
  String get languageAuto;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @transcribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// No description provided for @transcribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get transcribing;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @transcriptionOutput.
  ///
  /// In en, this message translates to:
  /// **'Transcription output'**
  String get transcriptionOutput;

  /// No description provided for @noTranscriptionYet.
  ///
  /// In en, this message translates to:
  /// **'No transcription yet'**
  String get noTranscriptionYet;

  /// No description provided for @noTranscriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Select an audio file and start transcription'**
  String get noTranscriptionHint;

  /// No description provided for @searchTranscription.
  ///
  /// In en, this message translates to:
  /// **'Search transcription…'**
  String get searchTranscription;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @noResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get noResultsHint;

  /// No description provided for @tabSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get tabSegments;

  /// No description provided for @tabFullText.
  ///
  /// In en, this message translates to:
  /// **'Full Text'**
  String get tabFullText;

  /// No description provided for @sharePlain.
  ///
  /// In en, this message translates to:
  /// **'Share plain text'**
  String get sharePlain;

  /// No description provided for @copyClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyClipboard;

  /// No description provided for @saveAsTxt.
  ///
  /// In en, this message translates to:
  /// **'Save as .txt'**
  String get saveAsTxt;

  /// No description provided for @saveAsSrt.
  ///
  /// In en, this message translates to:
  /// **'Save as .srt'**
  String get saveAsSrt;

  /// No description provided for @saveAsVtt.
  ///
  /// In en, this message translates to:
  /// **'Save as .vtt'**
  String get saveAsVtt;

  /// No description provided for @saveAsJson.
  ///
  /// In en, this message translates to:
  /// **'Save as .json'**
  String get saveAsJson;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @perfRtf.
  ///
  /// In en, this message translates to:
  /// **'RTF'**
  String get perfRtf;

  /// No description provided for @perfAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get perfAudio;

  /// No description provided for @perfWall.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get perfWall;

  /// No description provided for @perfWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get perfWords;

  /// No description provided for @perfWps.
  ///
  /// In en, this message translates to:
  /// **'WPS'**
  String get perfWps;

  /// No description provided for @perfEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get perfEngine;

  /// No description provided for @perfModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get perfModel;

  /// No description provided for @perfFasterThanRealtime.
  ///
  /// In en, this message translates to:
  /// **'faster than real-time'**
  String get perfFasterThanRealtime;

  /// No description provided for @perfSlowerThanRealtime.
  ///
  /// In en, this message translates to:
  /// **'slower than real-time'**
  String get perfSlowerThanRealtime;

  /// No description provided for @diarizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Speaker diarization'**
  String get diarizationTitle;

  /// No description provided for @diarizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Identify different speakers in audio recordings'**
  String get diarizationSubtitle;

  /// No description provided for @diarizationModel.
  ///
  /// In en, this message translates to:
  /// **'Diarization model'**
  String get diarizationModel;

  /// No description provided for @minSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Min. speakers'**
  String get minSpeakers;

  /// No description provided for @maxSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Max. speakers'**
  String get maxSpeakers;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsAppLanguage;

  /// No description provided for @settingsInterfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get settingsInterfaceLanguage;

  /// No description provided for @settingsSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsSystemDefault;

  /// No description provided for @settingsEngineSection.
  ///
  /// In en, this message translates to:
  /// **'Transcription engine'**
  String get settingsEngineSection;

  /// No description provided for @settingsEnginePreferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred engine'**
  String get settingsEnginePreferred;

  /// No description provided for @settingsSelectEngine.
  ///
  /// In en, this message translates to:
  /// **'Select engine'**
  String get settingsSelectEngine;

  /// No description provided for @settingsEngineSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to {engine}'**
  String settingsEngineSwitched(String engine);

  /// No description provided for @settingsEngineSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Engine switch failed'**
  String get settingsEngineSwitchFailed;

  /// No description provided for @settingsAudioQualityCurrent.
  ///
  /// In en, this message translates to:
  /// **'Recording quality: {percent}%'**
  String settingsAudioQualityCurrent(int percent);

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get settingsCacheCleared;

  /// No description provided for @settingsHfToken.
  ///
  /// In en, this message translates to:
  /// **'HuggingFace API token'**
  String get settingsHfToken;

  /// No description provided for @settingsHfTokenNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set (required for gated models)'**
  String get settingsHfTokenNotSet;

  /// No description provided for @settingsModelsDir.
  ///
  /// In en, this message translates to:
  /// **'Models directory'**
  String get settingsModelsDir;

  /// No description provided for @settingsModelsDirDefault.
  ///
  /// In en, this message translates to:
  /// **'Default (in app sandbox)'**
  String get settingsModelsDirDefault;

  /// No description provided for @settingsModelsDirPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick models directory'**
  String get settingsModelsDirPickTitle;

  /// No description provided for @settingsModelsDirCurrentDefault.
  ///
  /// In en, this message translates to:
  /// **'Currently using the default app-sandbox path. Pick a custom directory to share GGUFs with other tools (e.g. an external drive).'**
  String get settingsModelsDirCurrentDefault;

  /// No description provided for @settingsModelsDirCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {path}'**
  String settingsModelsDirCurrent(String path);

  /// No description provided for @settingsModelsDirPick.
  ///
  /// In en, this message translates to:
  /// **'Pick…'**
  String get settingsModelsDirPick;

  /// No description provided for @settingsModelsDirReset.
  ///
  /// In en, this message translates to:
  /// **'Use default'**
  String get settingsModelsDirReset;

  /// No description provided for @settingsModelsDirSet.
  ///
  /// In en, this message translates to:
  /// **'Models directory set to {path}'**
  String settingsModelsDirSet(String path);

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageDe.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageDe;

  /// No description provided for @languageEs.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageEs;

  /// No description provided for @languageFr.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFr;

  /// No description provided for @languageIt.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageIt;

  /// No description provided for @languagePt.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePt;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageZh;

  /// No description provided for @languageJa.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJa;

  /// No description provided for @languageKo.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKo;

  /// No description provided for @modelSize.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String modelSize(String size);

  /// No description provided for @modelDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String modelDeleteConfirm(String name);

  /// No description provided for @historyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get historyCopy;

  /// No description provided for @historyExportSrt.
  ///
  /// In en, this message translates to:
  /// **'Export SRT'**
  String get historyExportSrt;

  /// No description provided for @historyExportTxt.
  ///
  /// In en, this message translates to:
  /// **'Export TXT'**
  String get historyExportTxt;

  /// No description provided for @historyExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get historyExportJson;

  /// No description provided for @historyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get historyDelete;

  /// No description provided for @historyFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load history: {error}'**
  String historyFailedToLoad(String error);

  /// No description provided for @historySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {path}'**
  String historySaved(String path);

  /// No description provided for @historyExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String historyExportFailed(String error);

  /// No description provided for @recorderDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get recorderDeleteTitle;

  /// No description provided for @recorderDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this recording?'**
  String get recorderDeleteBody;

  /// No description provided for @recorderQueuedForTranscription.
  ///
  /// In en, this message translates to:
  /// **'Recording queued for transcription.'**
  String get recorderQueuedForTranscription;

  /// No description provided for @recorderStream.
  ///
  /// In en, this message translates to:
  /// **'Stream'**
  String get recorderStream;

  /// No description provided for @recorderStreamTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live mic transcribe (Whisper sliding window). Partial text appears as you speak.'**
  String get recorderStreamTooltip;

  /// No description provided for @outputShowTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Show timestamps'**
  String get outputShowTimestamps;

  /// No description provided for @outputShowSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Show speakers'**
  String get outputShowSpeakers;

  /// No description provided for @outputShowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Show confidence'**
  String get outputShowConfidence;

  /// No description provided for @outputCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get outputCopyAll;

  /// No description provided for @outputExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get outputExport;

  /// No description provided for @outputPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get outputPlay;

  /// No description provided for @outputCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get outputCopy;

  /// No description provided for @outputEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get outputEdit;

  /// No description provided for @outputPlaySegment.
  ///
  /// In en, this message translates to:
  /// **'Play segment'**
  String get outputPlaySegment;

  /// No description provided for @outputCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get outputCopyText;

  /// No description provided for @outputEditSegment.
  ///
  /// In en, this message translates to:
  /// **'Edit segment'**
  String get outputEditSegment;

  /// No description provided for @outputEditNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Segment editing not yet implemented'**
  String get outputEditNotImplemented;

  /// No description provided for @outputRenameSpeakerTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename speaker'**
  String get outputRenameSpeakerTitle;

  /// No description provided for @outputRenameSpeakerOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original label: {original}'**
  String outputRenameSpeakerOriginal(String original);

  /// No description provided for @outputRenameSpeakerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to original'**
  String get outputRenameSpeakerReset;

  /// No description provided for @outputExportNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Export functionality not yet implemented'**
  String get outputExportNotImplemented;

  /// No description provided for @outputSegmentCopied.
  ///
  /// In en, this message translates to:
  /// **'Segment copied to clipboard'**
  String get outputSegmentCopied;

  /// No description provided for @outputAllCopied.
  ///
  /// In en, this message translates to:
  /// **'All transcription copied to clipboard'**
  String get outputAllCopied;

  /// No description provided for @outputPlayingSegment.
  ///
  /// In en, this message translates to:
  /// **'Playing segment: {time}'**
  String outputPlayingSegment(String time);

  /// No description provided for @settingsHfTokenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required for gated or private repositories.'**
  String get settingsHfTokenSubtitle;

  /// No description provided for @settingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get settingsLoading;

  /// No description provided for @transcribeLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get transcribeLanguageLabel;

  /// No description provided for @transcribeStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting download: {model}'**
  String transcribeStarting(String model);

  /// No description provided for @transcribeUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file type: {name}'**
  String transcribeUnsupportedFile(String name);

  /// No description provided for @transcribeLoadedFile.
  ///
  /// In en, this message translates to:
  /// **'Loaded {name}'**
  String transcribeLoadedFile(String name);

  /// No description provided for @aboutEmail.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String aboutEmail(String email);

  /// No description provided for @aboutPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String aboutPhone(String phone);

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @settingsTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscription;

  /// No description provided for @settingsDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get settingsDefaultModel;

  /// No description provided for @settingsDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default language'**
  String get settingsDefaultLanguage;

  /// No description provided for @settingsAutoDetectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect language'**
  String get settingsAutoDetectLanguage;

  /// No description provided for @settingsAutoDetectLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect audio language'**
  String get settingsAutoDetectLanguageSubtitle;

  /// No description provided for @settingsWordTimestamps.
  ///
  /// In en, this message translates to:
  /// **'Word timestamps'**
  String get settingsWordTimestamps;

  /// No description provided for @settingsWordTimestampsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate timestamps for individual words'**
  String get settingsWordTimestampsSubtitle;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsAudioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio quality'**
  String get settingsAudioQuality;

  /// No description provided for @settingsKeepAudioFiles.
  ///
  /// In en, this message translates to:
  /// **'Keep audio files'**
  String get settingsKeepAudioFiles;

  /// No description provided for @settingsKeepAudioFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep downloaded / recorded audio files after transcription'**
  String get settingsKeepAudioFilesSubtitle;

  /// No description provided for @settingsDiarization.
  ///
  /// In en, this message translates to:
  /// **'Speaker diarization'**
  String get settingsDiarization;

  /// No description provided for @settingsEnableDiarizationByDefault.
  ///
  /// In en, this message translates to:
  /// **'Enable by default'**
  String get settingsEnableDiarizationByDefault;

  /// No description provided for @settingsEnableDiarizationByDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically enable diarization for new transcriptions'**
  String get settingsEnableDiarizationByDefaultSubtitle;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCache;

  /// No description provided for @settingsClearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear temporary files and cache'**
  String get settingsClearCacheSubtitle;

  /// No description provided for @settingsManageModels.
  ///
  /// In en, this message translates to:
  /// **'Manage models'**
  String get settingsManageModels;

  /// No description provided for @settingsManageModelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download, update, or delete transcription models'**
  String get settingsManageModelsSubtitle;

  /// No description provided for @settingsStorageBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Storage breakdown'**
  String get settingsStorageBreakdown;

  /// No description provided for @settingsStorageBreakdownSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See per-backend disk usage and free up space'**
  String get settingsStorageBreakdownSubtitle;

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage breakdown'**
  String get storageTitle;

  /// No description provided for @storageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get storageRefresh;

  /// No description provided for @storageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No model files on disk yet.'**
  String get storageEmpty;

  /// No description provided for @storageTotalUsed.
  ///
  /// In en, this message translates to:
  /// **'Total on disk'**
  String get storageTotalUsed;

  /// No description provided for @storageBackendCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 backend} other{{count} backends}}'**
  String storageBackendCount(int count);

  /// No description provided for @storageFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{size} • {count, plural, one{1 file} other{{count} files}}'**
  String storageFilesCount(String size, int count);

  /// No description provided for @storageDeleteAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete all models for this backend'**
  String get storageDeleteAllTooltip;

  /// No description provided for @storageDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all {backend} models?'**
  String storageDeleteTitle(String backend);

  /// No description provided for @storageDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will free {size} across {count, plural, one{1 file} other{{count} files}} and cannot be undone.'**
  String storageDeleteMessage(String size, int count);

  /// No description provided for @storageDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get storageDeleteConfirm;

  /// No description provided for @storageDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Freed {size}'**
  String storageDeletedSnack(String size);

  /// No description provided for @settingsDebugging.
  ///
  /// In en, this message translates to:
  /// **'Debugging & development'**
  String get settingsDebugging;

  /// No description provided for @settingsLogLevel.
  ///
  /// In en, this message translates to:
  /// **'Log level'**
  String get settingsLogLevel;

  /// No description provided for @settingsLogLevelCurrent.
  ///
  /// In en, this message translates to:
  /// **'Currently {level}'**
  String settingsLogLevelCurrent(String level);

  /// No description provided for @settingsMirrorLogs.
  ///
  /// In en, this message translates to:
  /// **'Mirror logs to file'**
  String get settingsMirrorLogs;

  /// No description provided for @settingsMirrorLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes to logs/session.log in the app documents directory'**
  String get settingsMirrorLogsSubtitle;

  /// No description provided for @settingsSkipChecksum.
  ///
  /// In en, this message translates to:
  /// **'Skip checksum verification'**
  String get settingsSkipChecksum;

  /// No description provided for @settingsSkipChecksumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accept downloaded models even if SHA-1 does not match'**
  String get settingsSkipChecksumSubtitle;

  /// No description provided for @settingsOpenLogViewer.
  ///
  /// In en, this message translates to:
  /// **'Open log viewer'**
  String get settingsOpenLogViewer;

  /// No description provided for @settingsSystemInfo.
  ///
  /// In en, this message translates to:
  /// **'System information'**
  String get settingsSystemInfo;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsAboutCrisperWeaver.
  ///
  /// In en, this message translates to:
  /// **'About CrisperWeaver'**
  String get settingsAboutCrisperWeaver;

  /// No description provided for @settingsAboutCrisperWeaverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Author, contact, disclaimer, licenses'**
  String get settingsAboutCrisperWeaverSubtitle;

  /// No description provided for @settingsHfTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Hugging Face API Token'**
  String get settingsHfTokenTitle;

  /// No description provided for @settingsHfTokenSave.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get settingsHfTokenSave;

  /// No description provided for @settingsHfTokenCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get settingsHfTokenCancel;

  /// No description provided for @transcriptionNoModelsFound.
  ///
  /// In en, this message translates to:
  /// **'No models found'**
  String get transcriptionNoModelsFound;

  /// No description provided for @transcriptionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get transcriptionRetry;

  /// No description provided for @transcriptionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String transcriptionLoadFailed(String error);

  /// No description provided for @transcriptionSavedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved {path}'**
  String transcriptionSavedTo(String path);

  /// No description provided for @transcriptionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String transcriptionSaveFailed(String error);

  /// No description provided for @transcriptionCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get transcriptionCopiedToClipboard;

  /// No description provided for @transcriptionShareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share or save'**
  String get transcriptionShareSheetTitle;

  /// No description provided for @transcriptionSharePlainText.
  ///
  /// In en, this message translates to:
  /// **'Share plain text'**
  String get transcriptionSharePlainText;

  /// No description provided for @transcriptionCopyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get transcriptionCopyToClipboard;

  /// No description provided for @transcriptionSaveAsTxt.
  ///
  /// In en, this message translates to:
  /// **'Save as TXT'**
  String get transcriptionSaveAsTxt;

  /// No description provided for @transcriptionSaveAsSrt.
  ///
  /// In en, this message translates to:
  /// **'Save as SRT'**
  String get transcriptionSaveAsSrt;

  /// No description provided for @transcriptionSaveAsVtt.
  ///
  /// In en, this message translates to:
  /// **'Save as VTT'**
  String get transcriptionSaveAsVtt;

  /// No description provided for @transcriptionSaveAsJson.
  ///
  /// In en, this message translates to:
  /// **'Save as JSON'**
  String get transcriptionSaveAsJson;

  /// No description provided for @transcriptionDownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download Model'**
  String get transcriptionDownloadModel;

  /// No description provided for @transcriptionDownload.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD'**
  String get transcriptionDownload;

  /// No description provided for @advancedTemperatureGreedy.
  ///
  /// In en, this message translates to:
  /// **'Decoder temperature: greedy (0.00)'**
  String get advancedTemperatureGreedy;

  /// No description provided for @advancedTemperatureCurrent.
  ///
  /// In en, this message translates to:
  /// **'Decoder temperature: {value}'**
  String advancedTemperatureCurrent(String value);

  /// No description provided for @advancedTemperatureHelper.
  ///
  /// In en, this message translates to:
  /// **'0.00 = greedy / reproducible. > 0 = stochastic sampling — useful when greedy decoding hallucinates a repetition. Whisper has its own internal fallback ladder; this affects sampling backends (canary, cohere, parakeet, moonshine).'**
  String get advancedTemperatureHelper;

  /// No description provided for @downloadModelPrompt.
  ///
  /// In en, this message translates to:
  /// **'The model \"{name}\" is not yet downloaded. Would you like to download it now (~{size})?'**
  String downloadModelPrompt(String name, String size);

  /// No description provided for @tooltipDeleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete recording'**
  String get tooltipDeleteRecording;

  /// No description provided for @tooltipUseForTranscription.
  ///
  /// In en, this message translates to:
  /// **'Use for transcription'**
  String get tooltipUseForTranscription;

  /// No description provided for @tooltipModelSelectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Model selection help'**
  String get tooltipModelSelectionHelp;

  /// No description provided for @tooltipDownloadModel.
  ///
  /// In en, this message translates to:
  /// **'Download model'**
  String get tooltipDownloadModel;

  /// No description provided for @tooltipDisplayLevel.
  ///
  /// In en, this message translates to:
  /// **'Display level'**
  String get tooltipDisplayLevel;

  /// No description provided for @tooltipPauseAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Pause auto-scroll'**
  String get tooltipPauseAutoScroll;

  /// No description provided for @tooltipResumeAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Resume auto-scroll'**
  String get tooltipResumeAutoScroll;

  /// No description provided for @labelApiToken.
  ///
  /// In en, this message translates to:
  /// **'API Token'**
  String get labelApiToken;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String playbackFailed(String error);

  /// No description provided for @synthesizeFailed.
  ///
  /// In en, this message translates to:
  /// **'Synthesize failed: {error}'**
  String synthesizeFailed(String error);

  /// No description provided for @logsShowLevel.
  ///
  /// In en, this message translates to:
  /// **'Show {level} and above'**
  String logsShowLevel(String level);

  /// No description provided for @logsCopyVisible.
  ///
  /// In en, this message translates to:
  /// **'Copy visible'**
  String get logsCopyVisible;

  /// No description provided for @logsCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get logsCopyAll;

  /// No description provided for @logsExport.
  ///
  /// In en, this message translates to:
  /// **'Export to file'**
  String get logsExport;

  /// No description provided for @logsShare.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get logsShare;

  /// No description provided for @diarizationAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get diarizationAuto;

  /// No description provided for @diarizationModelSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Diarization Model Selection'**
  String get diarizationModelSelectionTitle;

  /// No description provided for @aboutServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Service Provider'**
  String get aboutServiceProvider;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutContact;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacy;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get aboutDisclaimer;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutPrivacyText.
  ///
  /// In en, this message translates to:
  /// **'CrisperWeaver processes all audio locally on your device. No audio data, transcripts, or recordings are sent to any server. Model downloads fetch GGUF weights directly from HuggingFace over HTTPS; nothing else leaves the device.'**
  String get aboutPrivacyText;

  /// No description provided for @aboutDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'This software is provided \"as is\", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors be liable for any claim, damages or other liability arising from, out of or in connection with the software or its use.'**
  String get aboutDisclaimerText;

  /// No description provided for @aboutLicenseText.
  ///
  /// In en, this message translates to:
  /// **'CrisperWeaver is free software, licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). You may redistribute and modify it under the terms of that license. In particular, if you run a modified version of CrisperWeaver as a network service, you must make your source code available to its users.'**
  String get aboutLicenseText;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcription history'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transcriptions yet'**
  String get historyEmpty;

  /// No description provided for @historyEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Run a transcription and it will show up here.'**
  String get historyEmptyHint;

  /// No description provided for @historyRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get historyRefresh;

  /// No description provided for @historyClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get historyClearAll;

  /// No description provided for @historyClearAllPrompt.
  ///
  /// In en, this message translates to:
  /// **'Remove every saved transcription from this device. This cannot be undone.'**
  String get historyClearAllPrompt;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by message, tag, or error…'**
  String get logsFilterHint;

  /// No description provided for @modelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Model management'**
  String get modelsTitle;

  /// No description provided for @modelsNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get modelsNoneAvailable;

  /// No description provided for @modelsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get modelsRetry;

  /// No description provided for @modelsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get modelsDownload;

  /// No description provided for @modelsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete model'**
  String get modelsDelete;

  /// No description provided for @modelsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get modelsDownloaded;

  /// No description provided for @modelsNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get modelsNotDownloaded;

  /// No description provided for @modelsDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String modelsDownloadingPercent(String percent);

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsDefaultBackend.
  ///
  /// In en, this message translates to:
  /// **'Default backend'**
  String get settingsDefaultBackend;

  /// No description provided for @settingsSelectBackend.
  ///
  /// In en, this message translates to:
  /// **'Select default backend'**
  String get settingsSelectBackend;

  /// No description provided for @settingsSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select default model ({backend})'**
  String settingsSelectModel(String backend);

  /// No description provided for @settingsSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select default language'**
  String get settingsSelectLanguage;

  /// No description provided for @settingsSelectInterfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select interface language'**
  String get settingsSelectInterfaceLanguage;

  /// No description provided for @settingsNoModelsForBackend.
  ///
  /// In en, this message translates to:
  /// **'No models known for backend \"{backend}\". Use the model manager → cloud-download icon to probe HuggingFace.'**
  String settingsNoModelsForBackend(String backend);

  /// No description provided for @modelFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter models (name / quant)'**
  String get modelFilterHint;

  /// No description provided for @modelAnyBackend.
  ///
  /// In en, this message translates to:
  /// **'Any backend'**
  String get modelAnyBackend;

  /// No description provided for @modelNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No models match this filter.'**
  String get modelNoMatch;

  /// No description provided for @modelsRefreshFromHf.
  ///
  /// In en, this message translates to:
  /// **'Refresh quants from HuggingFace'**
  String get modelsRefreshFromHf;

  /// No description provided for @modelsReloadLocal.
  ///
  /// In en, this message translates to:
  /// **'Reload local state'**
  String get modelsReloadLocal;

  /// No description provided for @modelsProbedCountZero.
  ///
  /// In en, this message translates to:
  /// **'No new quants discovered on HuggingFace.'**
  String get modelsProbedCountZero;

  /// No description provided for @modelsProbedCount.
  ///
  /// In en, this message translates to:
  /// **'Discovered {count} new quant variant{plural}.'**
  String modelsProbedCount(int count, String plural);

  /// No description provided for @batchQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch queue'**
  String get batchQueueTitle;

  /// No description provided for @batchQueueSummary.
  ///
  /// In en, this message translates to:
  /// **'{queued} queued · {running} running · {done} done · {errored} failed'**
  String batchQueueSummary(int queued, int running, int done, int errored);

  /// No description provided for @batchClearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear done'**
  String get batchClearCompleted;

  /// No description provided for @batchRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get batchRemove;

  /// No description provided for @batchEnqueueAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} file(s) added to queue.'**
  String batchEnqueueAdded(int count);

  /// No description provided for @batchRunAll.
  ///
  /// In en, this message translates to:
  /// **'Transcribe all'**
  String get batchRunAll;

  /// No description provided for @batchStop.
  ///
  /// In en, this message translates to:
  /// **'Stop batch'**
  String get batchStop;

  /// No description provided for @batchQueueDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop audio files here to queue them'**
  String get batchQueueDropHint;

  /// No description provided for @advancedSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced decoding'**
  String get advancedSection;

  /// No description provided for @advancedVadTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim silence (VAD)'**
  String get advancedVadTrim;

  /// No description provided for @advancedVadTrimSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip leading and trailing silence via Silero VAD. Faster on meetings / long recordings with silent padding.'**
  String get advancedVadTrimSubtitle;

  /// No description provided for @advancedTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate to English'**
  String get advancedTranslate;

  /// No description provided for @advancedTranslateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper only — forces output to English regardless of source.'**
  String get advancedTranslateSubtitle;

  /// No description provided for @advancedBeamSearch.
  ///
  /// In en, this message translates to:
  /// **'Beam search'**
  String get advancedBeamSearch;

  /// No description provided for @advancedBeamSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Slower, usually more accurate. Default is greedy.'**
  String get advancedBeamSearchSubtitle;

  /// No description provided for @advancedInitialPrompt.
  ///
  /// In en, this message translates to:
  /// **'Initial prompt (vocabulary / context)'**
  String get advancedInitialPrompt;

  /// No description provided for @advancedInitialPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"CrispASR, Flutter, Riverpod, Sprecher-Unterscheidung\"'**
  String get advancedInitialPromptHint;

  /// No description provided for @advancedRestorePunctuation.
  ///
  /// In en, this message translates to:
  /// **'Restore punctuation (FireRedPunc)'**
  String get advancedRestorePunctuation;

  /// No description provided for @advancedRestorePunctuationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Capitalize and punctuate raw output. Useful for CTC backends (wav2vec2, fastconformer-ctc, firered-asr). Requires fireredpunc-*.gguf in Model Management.'**
  String get advancedRestorePunctuationSubtitle;

  /// No description provided for @advancedTargetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translate to (target language)'**
  String get advancedTargetLanguage;

  /// No description provided for @advancedTargetLanguageHelper.
  ///
  /// In en, this message translates to:
  /// **'Visible only for translation-capable backends (Canary, Voxtral, Qwen3, Cohere, Whisper). Leave at \"No translation\" for verbatim transcription.'**
  String get advancedTargetLanguageHelper;

  /// No description provided for @advancedAskPrompt.
  ///
  /// In en, this message translates to:
  /// **'Ask the audio (Q&A mode)'**
  String get advancedAskPrompt;

  /// No description provided for @advancedAskPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Summarize\" or \"What\'s the speaker\'s tone?\"'**
  String get advancedAskPromptHint;

  /// No description provided for @advancedAskPromptHelper.
  ///
  /// In en, this message translates to:
  /// **'Voxtral / Qwen3-ASR only. When set, the LLM ANSWERS your question instead of producing a verbatim transcript. Leave empty for normal transcription.'**
  String get advancedAskPromptHelper;

  /// No description provided for @synthTitle.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get synthTitle;

  /// No description provided for @synthModelLabel.
  ///
  /// In en, this message translates to:
  /// **'TTS model'**
  String get synthModelLabel;

  /// No description provided for @synthVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice / voicepack'**
  String get synthVoiceLabel;

  /// No description provided for @synthCodecLabel.
  ///
  /// In en, this message translates to:
  /// **'Codec / tokenizer'**
  String get synthCodecLabel;

  /// No description provided for @synthTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type text to synthesise…'**
  String get synthTextHint;

  /// No description provided for @synthRunButton.
  ///
  /// In en, this message translates to:
  /// **'Synthesize'**
  String get synthRunButton;

  /// No description provided for @synthPlayButton.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get synthPlayButton;

  /// No description provided for @synthStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get synthStopButton;

  /// No description provided for @synthShareButton.
  ///
  /// In en, this message translates to:
  /// **'Save / share WAV'**
  String get synthShareButton;

  /// No description provided for @synthNoTtsModelsDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No TTS models downloaded yet. Open Models → Models tab → switch to \"TTS\" to fetch one.'**
  String get synthNoTtsModelsDownloaded;

  /// No description provided for @synthMissingDependency.
  ///
  /// In en, this message translates to:
  /// **'Missing required companion file: {name}'**
  String synthMissingDependency(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
