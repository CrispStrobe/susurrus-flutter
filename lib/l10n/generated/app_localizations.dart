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
