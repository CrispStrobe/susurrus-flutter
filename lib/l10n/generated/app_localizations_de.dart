// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'CrisperWeaver';

  @override
  String get appTagline => 'Audio-Transkription mit Sprecher-Unterscheidung';

  @override
  String get menuHistory => 'Verlauf';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuModels => 'Modelle';

  @override
  String get menuSynthesize => 'Sprache erzeugen';

  @override
  String get menuTranslate => 'Text übersetzen';

  @override
  String get menuLogs => 'Protokoll';

  @override
  String get menuAbout => 'Über';

  @override
  String get engineReady => 'Engine bereit';

  @override
  String get engineStarting => 'Engine wird gestartet…';

  @override
  String get audioInput => 'Audio-Eingabe';

  @override
  String get noFileSelected => 'Keine Datei ausgewählt';

  @override
  String get browse => 'Durchsuchen';

  @override
  String get urlInputLabel => 'Oder Audio-URL eingeben';

  @override
  String get urlInputHint => 'https://example.com/audio.mp3';

  @override
  String get advancedOptions => 'Erweiterte Optionen';

  @override
  String get language => 'Sprache';

  @override
  String get languageAuto => 'Automatisch erkennen';

  @override
  String get model => 'Modell';

  @override
  String get transcribe => 'Transkribieren';

  @override
  String get transcribing => 'Transkribiere…';

  @override
  String get stop => 'Stopp';

  @override
  String get clear => 'Löschen';

  @override
  String get transcriptionOutput => 'Transkriptions-Ausgabe';

  @override
  String get noTranscriptionYet => 'Noch keine Transkription';

  @override
  String get noTranscriptionHint =>
      'Audio-Datei wählen und Transkription starten';

  @override
  String get searchTranscription => 'Transkription durchsuchen…';

  @override
  String get noResultsFound => 'Keine Treffer';

  @override
  String get noResultsHint => 'Anderen Suchbegriff probieren';

  @override
  String get tabSegments => 'Segmente';

  @override
  String get tabFullText => 'Volltext';

  @override
  String get sharePlain => 'Als Text teilen';

  @override
  String get copyClipboard => 'In Zwischenablage kopieren';

  @override
  String get saveAsTxt => 'Als .txt speichern';

  @override
  String get saveAsSrt => 'Als .srt speichern';

  @override
  String get saveAsVtt => 'Als .vtt speichern';

  @override
  String get saveAsJson => 'Als .json speichern';

  @override
  String get copied => 'Kopiert';

  @override
  String get perfRtf => 'RTF';

  @override
  String get perfAudio => 'Audio';

  @override
  String get perfWall => 'Zeit';

  @override
  String get perfWords => 'Wörter';

  @override
  String get perfWps => 'W/s';

  @override
  String get perfEngine => 'Engine';

  @override
  String get perfModel => 'Modell';

  @override
  String get perfFasterThanRealtime => 'schneller als Echtzeit';

  @override
  String get perfSlowerThanRealtime => 'langsamer als Echtzeit';

  @override
  String get diarizationTitle => 'Sprecher-Unterscheidung';

  @override
  String get diarizationSubtitle =>
      'Verschiedene Sprecher in Aufnahmen identifizieren';

  @override
  String get diarizationModel => 'Unterscheidungs-Modell';

  @override
  String get minSpeakers => 'Min. Sprecher';

  @override
  String get maxSpeakers => 'Max. Sprecher';

  @override
  String get auto => 'Auto';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAppLanguage => 'App-Sprache';

  @override
  String get settingsInterfaceLanguage => 'Oberflächen-Sprache';

  @override
  String get settingsSystemDefault => 'Systemvorgabe';

  @override
  String get settingsEngineSection => 'Transkriptions-Engine';

  @override
  String get settingsEnginePreferred => 'Bevorzugte Engine';

  @override
  String get settingsSelectEngine => 'Engine wählen';

  @override
  String settingsEngineSwitched(String engine) {
    return 'Gewechselt zu $engine';
  }

  @override
  String get settingsEngineSwitchFailed => 'Engine-Wechsel fehlgeschlagen';

  @override
  String settingsAudioQualityCurrent(int percent) {
    return 'Aufnahmequalität: $percent%';
  }

  @override
  String get settingsCacheCleared => 'Cache erfolgreich geleert';

  @override
  String get settingsHfToken => 'HuggingFace-API-Token';

  @override
  String get settingsHfTokenNotSet =>
      'Nicht gesetzt (erforderlich für gated-Modelle)';

  @override
  String get settingsModelsDir => 'Modellverzeichnis';

  @override
  String get settingsModelsDirDefault => 'Standard (App-Sandbox)';

  @override
  String get settingsModelsDirPickTitle => 'Modellverzeichnis wählen';

  @override
  String get settingsModelsDirCurrentDefault =>
      'Aktuell wird der Standard-Sandbox-Pfad verwendet. Wähle ein eigenes Verzeichnis, um GGUFs mit anderen Tools zu teilen (z. B. von einer externen Festplatte).';

  @override
  String settingsModelsDirCurrent(String path) {
    return 'Aktuell: $path';
  }

  @override
  String get settingsModelsDirPick => 'Wählen …';

  @override
  String get settingsModelsDirReset => 'Standard verwenden';

  @override
  String settingsModelsDirSet(String path) {
    return 'Modellverzeichnis gesetzt auf $path';
  }

  @override
  String get languageEn => 'Englisch';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEs => 'Spanisch';

  @override
  String get languageFr => 'Französisch';

  @override
  String get languageIt => 'Italienisch';

  @override
  String get languagePt => 'Portugiesisch';

  @override
  String get languageZh => 'Chinesisch';

  @override
  String get languageJa => 'Japanisch';

  @override
  String get languageKo => 'Koreanisch';

  @override
  String get languageRu => 'Russisch';

  @override
  String modelSize(String size) {
    return 'Größe: $size';
  }

  @override
  String modelDeleteConfirm(String name) {
    return 'Möchten Sie $name wirklich löschen?';
  }

  @override
  String get historyCopy => 'Kopieren';

  @override
  String get historyExportSrt => 'SRT exportieren';

  @override
  String get historyExportTxt => 'TXT exportieren';

  @override
  String get historyExportJson => 'JSON exportieren';

  @override
  String get historyDelete => 'Löschen';

  @override
  String historyFailedToLoad(String error) {
    return 'Verlauf konnte nicht geladen werden: $error';
  }

  @override
  String historySaved(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String historyExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get recorderDeleteTitle => 'Aufnahme löschen';

  @override
  String get recorderDeleteBody =>
      'Möchten Sie diese Aufnahme wirklich löschen?';

  @override
  String get recorderQueuedForTranscription =>
      'Aufnahme zur Transkription eingereiht.';

  @override
  String get recorderStream => 'Stream';

  @override
  String get recorderStreamTooltip =>
      'Live-Mikrofon-Transkription (Whisper-Schiebefenster). Teil-Text erscheint beim Sprechen.';

  @override
  String get outputShowTimestamps => 'Zeitstempel anzeigen';

  @override
  String get outputShowSpeakers => 'Sprecher anzeigen';

  @override
  String get outputShowConfidence => 'Konfidenz anzeigen';

  @override
  String get outputCopyAll => 'Alle kopieren';

  @override
  String get outputExport => 'Exportieren';

  @override
  String get outputPlay => 'Abspielen';

  @override
  String get outputCopy => 'Kopieren';

  @override
  String get outputEdit => 'Bearbeiten';

  @override
  String get outputPlaySegment => 'Segment abspielen';

  @override
  String get outputCopyText => 'Text kopieren';

  @override
  String get outputEditSegment => 'Segment bearbeiten';

  @override
  String get outputEditNotImplemented =>
      'Segment-Bearbeitung noch nicht implementiert';

  @override
  String get outputRenameSpeakerTitle => 'Sprecher umbenennen';

  @override
  String outputRenameSpeakerOriginal(String original) {
    return 'Originale Bezeichnung: $original';
  }

  @override
  String get outputRenameSpeakerReset => 'Auf Original zurücksetzen';

  @override
  String get outputExportNotImplemented =>
      'Export-Funktion noch nicht implementiert';

  @override
  String get outputSegmentCopied => 'Segment in Zwischenablage kopiert';

  @override
  String get outputAllCopied =>
      'Gesamte Transkription in Zwischenablage kopiert';

  @override
  String outputPlayingSegment(String time) {
    return 'Segment wird abgespielt: $time';
  }

  @override
  String get settingsHfTokenSubtitle =>
      'Erforderlich für gesperrte oder private Repositories.';

  @override
  String get settingsLoading => 'Lade…';

  @override
  String get transcribeLanguageLabel => 'Sprache';

  @override
  String transcribeStarting(String model) {
    return 'Download startet: $model';
  }

  @override
  String transcribeUnsupportedFile(String name) {
    return 'Nicht unterstützter Dateityp: $name';
  }

  @override
  String transcribeLoadedFile(String name) {
    return 'Geladen: $name';
  }

  @override
  String aboutEmail(String email) {
    return 'E-Mail: $email';
  }

  @override
  String aboutPhone(String phone) {
    return 'Telefon: $phone';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsTranscription => 'Transkription';

  @override
  String get settingsDefaultModel => 'Standard-Modell';

  @override
  String get settingsDefaultLanguage => 'Standard-Sprache';

  @override
  String get settingsAutoDetectLanguage => 'Sprache automatisch erkennen';

  @override
  String get settingsAutoDetectLanguageSubtitle =>
      'Audio-Sprache automatisch ermitteln';

  @override
  String get settingsWordTimestamps => 'Wort-Zeitstempel';

  @override
  String get settingsWordTimestampsSubtitle =>
      'Zeitstempel für einzelne Wörter erzeugen';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAudioQuality => 'Audio-Qualität';

  @override
  String get settingsKeepAudioFiles => 'Audio-Dateien behalten';

  @override
  String get settingsKeepAudioFilesSubtitle =>
      'Heruntergeladene/aufgenommene Dateien nach der Transkription behalten';

  @override
  String get settingsDiarization => 'Sprecher-Unterscheidung';

  @override
  String get settingsEnableDiarizationByDefault => 'Standardmäßig aktivieren';

  @override
  String get settingsEnableDiarizationByDefaultSubtitle =>
      'Unterscheidung für neue Transkriptionen automatisch aktivieren';

  @override
  String get settingsStorage => 'Speicher';

  @override
  String get settingsClearCache => 'Cache leeren';

  @override
  String get settingsClearCacheSubtitle =>
      'Temporäre Dateien und Cache entfernen';

  @override
  String get settingsManageModels => 'Modelle verwalten';

  @override
  String get settingsManageModelsSubtitle =>
      'Transkriptions-Modelle laden, aktualisieren oder löschen';

  @override
  String get settingsStorageBreakdown => 'Speicheraufteilung';

  @override
  String get settingsStorageBreakdownSubtitle =>
      'Speicherverbrauch pro Backend ansehen und freigeben';

  @override
  String get storageTitle => 'Speicheraufteilung';

  @override
  String get storageRefresh => 'Aktualisieren';

  @override
  String get storageEmpty => 'Noch keine Modelldateien auf der Festplatte.';

  @override
  String get storageTotalUsed => 'Gesamt belegt';

  @override
  String storageBackendCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Backends',
      one: '1 Backend',
    );
    return '$_temp0';
  }

  @override
  String storageFilesCount(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return '$size • $_temp0';
  }

  @override
  String get storageDeleteAllTooltip => 'Alle Modelle dieses Backends löschen';

  @override
  String storageDeleteTitle(String backend) {
    return 'Alle Modelle von $backend löschen?';
  }

  @override
  String storageDeleteMessage(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dateien',
      one: '1 Datei',
    );
    return 'Dadurch werden $size aus $_temp0 freigegeben. Diese Aktion lässt sich nicht rückgängig machen.';
  }

  @override
  String get storageDeleteConfirm => 'Löschen';

  @override
  String storageDeletedSnack(String size) {
    return '$size freigegeben';
  }

  @override
  String get settingsDebugging => 'Debugging & Entwicklung';

  @override
  String get settingsLogLevel => 'Protokoll-Ebene';

  @override
  String settingsLogLevelCurrent(String level) {
    return 'Aktuell: $level';
  }

  @override
  String get settingsMirrorLogs => 'Protokoll in Datei schreiben';

  @override
  String get settingsMirrorLogsSubtitle =>
      'Schreibt nach logs/session.log im App-Dokumentverzeichnis';

  @override
  String get settingsSkipChecksum => 'Prüfsummen-Validierung überspringen';

  @override
  String get settingsSkipChecksumSubtitle =>
      'Heruntergeladene Modelle auch bei SHA-1-Abweichung akzeptieren';

  @override
  String get settingsGroupBatchByBackend => 'Stapel nach Backend gruppieren';

  @override
  String get settingsGroupBatchByBackendSubtitle =>
      'Sortiert wartende Dateien so um, dass aufeinanderfolgende Jobs dieselbe Modell-Sitzung wiederverwenden';

  @override
  String get settingsOpenLogViewer => 'Protokoll-Ansicht öffnen';

  @override
  String get settingsSystemInfo => 'Systeminformation';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsAboutCrisperWeaver => 'Über CrisperWeaver';

  @override
  String get settingsAboutCrisperWeaverSubtitle =>
      'Anbieter, Kontakt, Haftungsausschluss, Lizenzen';

  @override
  String get settingsHfTokenTitle => 'Hugging Face API-Token';

  @override
  String get settingsHfTokenSave => 'SPEICHERN';

  @override
  String get settingsHfTokenCancel => 'ABBRECHEN';

  @override
  String get transcriptionNoModelsFound => 'Keine Modelle gefunden';

  @override
  String get transcriptionRetry => 'Erneut versuchen';

  @override
  String transcriptionLoadFailed(String error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String transcriptionSavedTo(String path) {
    return 'Gespeichert: $path';
  }

  @override
  String transcriptionSaveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get transcriptionCopiedToClipboard => 'In Zwischenablage kopiert';

  @override
  String get transcriptionShareSheetTitle => 'Teilen oder speichern';

  @override
  String get transcriptionSharePlainText => 'Als Text teilen';

  @override
  String get transcriptionCopyToClipboard => 'In Zwischenablage kopieren';

  @override
  String get transcriptionSaveAsTxt => 'Als TXT speichern';

  @override
  String get transcriptionSaveAsSrt => 'Als SRT speichern';

  @override
  String get transcriptionSaveAsVtt => 'Als VTT speichern';

  @override
  String get transcriptionSaveAsJson => 'Als JSON speichern';

  @override
  String get transcriptionDownloadModel => 'Modell herunterladen';

  @override
  String get transcriptionDownload => 'HERUNTERLADEN';

  @override
  String get advancedBestOfSingle => 'Best-of-N: einzelner Decode (1)';

  @override
  String advancedBestOfCurrent(int n) {
    return 'Best-of-N: $n Decodes';
  }

  @override
  String get advancedBestOfHelper =>
      '1 = einzelner Decode (Standard). >1 führt N unabhängige Decodes aus und wählt das beste Ergebnis. Whisper verarbeitet dies intern; andere Backends laufen extern in einer Schleife und wählen das Transkript mit der höchsten mittleren Konfidenz. Kosten: N× pro-Aufruf Decode-Zeit.';

  @override
  String get advancedTemperatureGreedy => 'Decoder-Temperatur: greedy (0,00)';

  @override
  String advancedTemperatureCurrent(String value) {
    return 'Decoder-Temperatur: $value';
  }

  @override
  String get advancedTemperatureHelper =>
      '0,00 = greedy / reproduzierbar. > 0 = stochastisches Sampling — hilfreich, wenn greedy in einer halluzinierten Wiederholung hängenbleibt. Whisper hat eine eigene interne Fallback-Leiter; dieser Wert betrifft Sampling-Backends (canary, cohere, parakeet, moonshine).';

  @override
  String downloadModelPrompt(String name, String size) {
    return 'Das Modell „$name\" ist noch nicht heruntergeladen. Jetzt herunterladen (~$size)?';
  }

  @override
  String get tooltipDeleteRecording => 'Aufnahme löschen';

  @override
  String get tooltipUseForTranscription => 'Für Transkription verwenden';

  @override
  String get tooltipModelSelectionHelp => 'Hilfe zur Modellauswahl';

  @override
  String get tooltipDownloadModel => 'Modell herunterladen';

  @override
  String get tooltipDisplayLevel => 'Anzeige-Stufe';

  @override
  String get tooltipPauseAutoScroll => 'Auto-Scroll pausieren';

  @override
  String get tooltipResumeAutoScroll => 'Auto-Scroll fortsetzen';

  @override
  String get labelApiToken => 'API-Token';

  @override
  String get streamingRequiresWhisper =>
      'Streaming benötigt die Whisper-Engine. Backend in den Einstellungen wechseln.';

  @override
  String get streamingMicUnavailable =>
      'Mikrofon für Streaming nicht verfügbar.';

  @override
  String get streamingEngineNoSession =>
      'Engine liefert keine Streaming-Sitzung.';

  @override
  String playbackFailed(String error) {
    return 'Wiedergabe fehlgeschlagen: $error';
  }

  @override
  String synthesizeFailed(String error) {
    return 'Synthese fehlgeschlagen: $error';
  }

  @override
  String logsShowLevel(String level) {
    return '$level und darüber anzeigen';
  }

  @override
  String get logsCopyVisible => 'Sichtbare kopieren';

  @override
  String get logsCopyAll => 'Alle kopieren';

  @override
  String get logsExport => 'In Datei exportieren';

  @override
  String get logsShare => 'Als Datei teilen';

  @override
  String get diarizationAuto => 'Auto';

  @override
  String get diarizationModelSelectionTitle => 'Diarisierung: Modellauswahl';

  @override
  String get aboutServiceProvider => 'Anbieter';

  @override
  String get aboutContact => 'Kontakt';

  @override
  String get aboutPrivacy => 'Datenschutz';

  @override
  String get aboutDisclaimer => 'Haftungsausschluss';

  @override
  String get aboutLicense => 'Lizenz';

  @override
  String get aboutOpenSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get aboutPrivacyText =>
      'CrisperWeaver verarbeitet alle Audio-Daten ausschließlich lokal auf Ihrem Gerät. Weder Audio noch Transkripte oder Aufnahmen werden an Server übertragen. Modell-Downloads laden GGUF-Gewichte direkt von HuggingFace über HTTPS; darüber hinaus verlässt nichts das Gerät.';

  @override
  String get aboutDisclaimerText =>
      'Diese Software wird „wie besehen“ zur Verfügung gestellt, ohne jegliche ausdrückliche oder stillschweigende Gewährleistung, insbesondere der Marktgängigkeit, Eignung für einen bestimmten Zweck oder der Nichtverletzung von Rechten Dritter. In keinem Fall haften die Autor:innen für Ansprüche, Schäden oder sonstige Haftungen, die sich aus oder im Zusammenhang mit der Software oder deren Nutzung ergeben.';

  @override
  String get aboutLicenseText =>
      'CrisperWeaver ist freie Software und wird unter der GNU Affero General Public License v3.0 (AGPL-3.0) veröffentlicht. Sie dürfen es unter den Bedingungen dieser Lizenz weitergeben und verändern. Insbesondere gilt: Wenn Sie eine veränderte Version von CrisperWeaver als Netzwerk-Dienst betreiben, müssen Sie den zugehörigen Quellcode Ihren Nutzer:innen zugänglich machen.';

  @override
  String get historyTitle => 'Transkriptions-Verlauf';

  @override
  String get historyEmpty => 'Noch keine Transkriptionen';

  @override
  String get historyEmptyHint =>
      'Eine Transkription ausführen – sie erscheint hier.';

  @override
  String get historyRefresh => 'Aktualisieren';

  @override
  String get historyClearAll => 'Alle löschen';

  @override
  String get historyClearAllPrompt =>
      'Alle gespeicherten Transkriptionen von diesem Gerät entfernen. Das kann nicht rückgängig gemacht werden.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get logsTitle => 'Protokoll';

  @override
  String get logsFilterHint => 'Nach Nachricht, Tag oder Fehler filtern…';

  @override
  String get modelsTitle => 'Modell-Verwaltung';

  @override
  String get modelsNoneAvailable => 'Keine Modelle verfügbar';

  @override
  String get modelsRetry => 'Erneut versuchen';

  @override
  String get modelsDownload => 'Laden';

  @override
  String get modelsDelete => 'Modell löschen';

  @override
  String get modelsDownloaded => 'Geladen';

  @override
  String get modelsNotDownloaded => 'Nicht geladen';

  @override
  String modelsDownloadingPercent(String percent) {
    return 'Lade… $percent%';
  }

  @override
  String get error => 'Fehler';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Speichern';

  @override
  String get done => 'Fertig';

  @override
  String get settingsSaved => 'Einstellungen gespeichert';

  @override
  String get settingsDefaultBackend => 'Standard-Backend';

  @override
  String get settingsSelectBackend => 'Standard-Backend wählen';

  @override
  String settingsSelectModel(String backend) {
    return 'Standard-Modell wählen ($backend)';
  }

  @override
  String get settingsSelectLanguage => 'Standard-Sprache wählen';

  @override
  String get settingsSelectInterfaceLanguage => 'Oberflächen-Sprache wählen';

  @override
  String settingsNoModelsForBackend(String backend) {
    return 'Keine Modelle für Backend „$backend“ bekannt. Modell-Verwaltung → Cloud-Download-Symbol öffnen, um HuggingFace zu durchsuchen.';
  }

  @override
  String get modelFilterHint => 'Modelle filtern (Name / Quant)';

  @override
  String get modelAnyBackend => 'Beliebiges Backend';

  @override
  String get modelNoMatch => 'Keine Modelle entsprechen diesem Filter.';

  @override
  String get modelsRefreshFromHf => 'Quants von HuggingFace aktualisieren';

  @override
  String get modelsReloadLocal => 'Lokalen Zustand neu laden';

  @override
  String get modelsProbedCountZero =>
      'Keine neuen Quants auf HuggingFace gefunden.';

  @override
  String modelsProbedCount(int count, String plural) {
    return '$count neue Quant-Variante$plural gefunden.';
  }

  @override
  String get batchQueueTitle => 'Stapel-Warteschlange';

  @override
  String batchQueueSummary(int queued, int running, int done, int errored) {
    return '$queued wartend · $running läuft · $done fertig · $errored fehlgeschlagen';
  }

  @override
  String get batchClearCompleted => 'Fertige entfernen';

  @override
  String get batchRemove => 'Aus Warteschlange entfernen';

  @override
  String batchEnqueueAdded(int count) {
    return '$count Datei(en) zur Warteschlange hinzugefügt.';
  }

  @override
  String get batchRunAll => 'Alle transkribieren';

  @override
  String get batchStop => 'Stapel stoppen';

  @override
  String get batchQueueDropHint =>
      'Audio-Dateien hier ablegen, um sie in die Warteschlange zu stellen';

  @override
  String get advancedSection => 'Erweiterte Decodierung';

  @override
  String get advancedVadTrim => 'Stille schneiden (VAD)';

  @override
  String get advancedVadTrimSubtitle =>
      'Stille am Anfang und Ende via Silero-VAD überspringen. Schneller bei Meetings / langen Aufnahmen mit Stille-Padding.';

  @override
  String get advancedTranslate => 'Ins Englische übersetzen';

  @override
  String get advancedTranslateSubtitle =>
      'Nur Whisper — erzwingt englische Ausgabe unabhängig von der Quellsprache.';

  @override
  String get advancedBeamSearch => 'Beam-Search';

  @override
  String get advancedBeamSearchSubtitle =>
      'Langsamer, meist genauer. Standard ist greedy.';

  @override
  String get advancedInitialPrompt => 'Initial-Prompt (Vokabular / Kontext)';

  @override
  String get advancedInitialPromptHint =>
      'z. B. „CrispASR, Flutter, Riverpod, Sprecher-Unterscheidung“';

  @override
  String get advancedRestorePunctuation =>
      'Interpunktion wiederherstellen (FireRedPunc)';

  @override
  String get advancedRestorePunctuationSubtitle =>
      'Großschreibung und Satzzeichen für Roh-Transkripte. Nützlich für CTC-Backends (wav2vec2, fastconformer-ctc, firered-asr). Benötigt fireredpunc-*.gguf in der Modellverwaltung.';

  @override
  String get advancedSourceLanguage =>
      'Quellsprache (Autoerkennung überschreiben)';

  @override
  String get advancedSourceLanguageAuto => 'Auto / Hauptauswahl verwenden';

  @override
  String get advancedSourceLanguageHelper =>
      'Quellsprache festlegen, wenn Whispers Autoerkennung bei verrauschtem Audio unzuverlässig ist. Leer = Hauptsprachen-Auswahl / Autoerkennung verwenden.';

  @override
  String get advancedTargetLanguage => 'Übersetzen in (Zielsprache)';

  @override
  String get advancedTargetLanguageNone => 'Keine Übersetzung (wörtlich)';

  @override
  String get advancedTargetLanguageHelper =>
      'Nur sichtbar für übersetzungsfähige Backends (Canary, Voxtral, Qwen3, Cohere, Whisper). „Keine Übersetzung\" für wortgetreue Transkription.';

  @override
  String get advancedAskPrompt => 'Audio fragen (Q&A-Modus)';

  @override
  String get advancedAskPromptHint =>
      'z. B. „Zusammenfassen\" oder „Wie klingt der Sprecher?\"';

  @override
  String get advancedAskPromptHelper =>
      'Nur Voxtral / Qwen3-ASR. Wenn gesetzt, ANTWORTET das LLM auf deine Frage, statt eine wortgetreue Transkription zu liefern. Leer lassen für normale Transkription.';

  @override
  String get synthTitle => 'Synthese';

  @override
  String get synthModelLabel => 'TTS-Modell';

  @override
  String get synthVoiceLabel => 'Stimme / Voicepack';

  @override
  String get synthCodecLabel => 'Codec / Tokenizer';

  @override
  String get synthTextHint => 'Text zum Synthetisieren eingeben…';

  @override
  String get synthRunButton => 'Synthetisieren';

  @override
  String get synthPlayButton => 'Abspielen';

  @override
  String get synthStopButton => 'Stopp';

  @override
  String get synthShareButton => 'WAV speichern / teilen';

  @override
  String get synthNoTtsModelsDownloaded =>
      'Noch keine TTS-Modelle geladen. Öffne Modelle → Tab „TTS“, um eines herunterzuladen.';

  @override
  String synthMissingDependency(String name) {
    return 'Fehlende Begleitdatei: $name';
  }

  @override
  String get advancedVadBackend => 'VAD-Backend';

  @override
  String get advancedVadBackendHelper =>
      'Silero ist eingebettet (~885 KB). FireRed / MarbleNet / Whisper-VAD müssen über die Modellverwaltung geladen werden; fehlt die Datei, fällt CrisperWeaver auf Silero zurück.';

  @override
  String get advancedVadBackendSilero => 'Silero (eingebettet, Standard)';

  @override
  String get advancedVadBackendFirered => 'FireRedVAD (F1 97,57 %, ~3 MB)';

  @override
  String get advancedVadBackendMarblenet => 'MarbleNet (klein, mehrsprachig)';

  @override
  String get advancedVadBackendWhisperEncDec =>
      'Whisper-VAD-EncDec (experimentell, EN)';

  @override
  String advancedVadThreshold(String value) {
    return 'VAD-Schwelle: $value';
  }

  @override
  String get advancedVadThresholdHelper =>
      'Höher = weniger / kürzere erkannte Sprechabschnitte. CrispASR-Standard: 0,50.';

  @override
  String advancedVadMinSpeech(int ms) {
    return 'Mindest-Sprechdauer: $ms ms';
  }

  @override
  String get advancedVadMinSpeechHelper =>
      'Kürzester gesprochener Abschnitt, der als Sprachsegment erhalten bleibt.';

  @override
  String advancedVadMinSilence(int ms) {
    return 'Mindest-Stilledauer: $ms ms';
  }

  @override
  String get advancedVadMinSilenceHelper =>
      'Kürzeste Stille, die ein Segment vom nächsten trennt.';

  @override
  String advancedVadSpeechPad(int ms) {
    return 'Sprachpolsterung: $ms ms';
  }

  @override
  String get advancedVadSpeechPadHelper =>
      'Zusätzlicher Kontext links und rechts jedes Sprachsegments.';

  @override
  String get advancedLidMethod => 'Sprach-Erkennungsmethode';

  @override
  String get advancedLidMethodHelper =>
      'Nur aktiv, wenn das Modell keine eingebaute Spracherkennung hat und Auto gewählt wurde. Whisper nutzt ein vorhandenes ggml-*.bin; Silero benötigt eine eigene GGUF (16 MB, 95 Sprachen).';

  @override
  String get advancedLidMethodWhisper =>
      'Whisper-Encoder (nutzt vorhandenes Modell)';

  @override
  String get advancedLidMethodSilero => 'Silero (95 Sprachen, ~16 MB GGUF)';

  @override
  String get advancedDiarizeMethod => 'Diarisierungs-Methode';

  @override
  String get advancedDiarizeMethodHelper =>
      'Nur wirksam bei aktiver Diarisierung. VAD-Turns ist mono-freundlich; Pyannote benötigt eine eigene GGUF; Energie / Kreuzkorrelation benötigen Stereo.';

  @override
  String get advancedDiarizeVadTurns => 'VAD-Turns (Mono, ohne Zusatzmodell)';

  @override
  String get advancedDiarizePyannote => 'Pyannote v3 (ML, GGUF nötig)';

  @override
  String get advancedDiarizeEnergy => 'Stereo L/R-Energie';

  @override
  String get advancedDiarizeXcorr => 'Stereo-Kreuzkorrelation';

  @override
  String get advancedTdrz => 'Tinydiarize-Sprecherwechsel (nur Whisper)';

  @override
  String get advancedTdrzSubtitle =>
      'Fügt [SPEAKER_TURN]-Marker per Whisper .en.tdrz-Finetune ein. Keine Wirkung auf Session-Backends.';

  @override
  String get advancedTokenTimestamps => 'Token-genaue Zeitstempel';

  @override
  String get advancedTokenTimestampsSubtitle =>
      'DTW-ausgerichtete Pro-Token-Zeiten. Langsamer als Wortzeitstempel; nützlich für feinkörnige Untertitel-Tools.';

  @override
  String get advancedPuncFamily => 'Interpunktionsmodell';

  @override
  String get advancedPuncFamilyHelper =>
      'Nur sichtbar, wenn Interpunktion wiederherstellen aktiviert ist. Wahl zwischen FireRedPunc (ZH+EN) und fullstop-punc (EN/DE/FR/IT). Fällt automatisch auf das vorhandene Modell zurück.';

  @override
  String get advancedPuncFamilyFirered => 'FireRedPunc (Chinesisch + Englisch)';

  @override
  String get advancedPuncFamilyFullstop =>
      'Fullstop-punc multilingual (EN/DE/FR/IT)';

  @override
  String get transcriptionSaveAsCsv => 'Als CSV speichern';

  @override
  String get transcriptionSaveAsLrc => 'Als LRC speichern (Lyrics)';

  @override
  String get transcriptionSaveAsWts => 'Als WTS speichern (Debug)';

  @override
  String get synthAdvancedSection => 'Erweiterte Synthese';

  @override
  String get synthRefText => 'Referenz-Transkript (Stimmen-Klonen)';

  @override
  String get synthRefTextHelper =>
      'Erforderlich, wenn eine WAV-Stimme mit qwen3-tts Base oder vibevoice-1.5b für Laufzeit-Klonen kombiniert wird. Leer lassen bei vorgebackenen GGUF-Stimmen.';

  @override
  String get synthInstruct => 'Stimm-Beschreibung (nur qwen3-tts VoiceDesign)';

  @override
  String get synthInstructHelper =>
      'Natursprachliche Beschreibung der gewünschten Stimme („warmer weiblicher Erzähler, leichter britischer Akzent“). Wird bei anderen Backends ignoriert.';

  @override
  String get synthTrimSilence => 'Stille beschneiden';

  @override
  String get synthTrimSilenceSubtitle =>
      'Entfernt Stille unter -72 dBFS am Anfang und Ende der synthetisierten PCM.';

  @override
  String synthSpeed(String value) {
    return 'Geschwindigkeit: $value×';
  }

  @override
  String get synthSpeedHelper =>
      'Wiedergabe-Geschwindigkeit (0,25× – 4,00×). Nearest-Neighbor-Resample, ohne Tonhöhenkorrektur.';

  @override
  String get translateTitle => 'Text übersetzen';

  @override
  String get translateModelLabel => 'Übersetzungs-Modell';

  @override
  String get translateSourceLang => 'Von';

  @override
  String get translateTargetLang => 'Nach';

  @override
  String get translateSwap => 'Quell- und Zielsprache tauschen';

  @override
  String get translateInputLabel => 'Quelltext';

  @override
  String get translateInputHint =>
      'Text zum Übersetzen eingeben oder einfügen…';

  @override
  String get translateOutputLabel => 'Übersetzung';

  @override
  String get translateRunButton => 'Übersetzen';

  @override
  String get translateNoModelsDownloaded =>
      'Keine Übersetzungs-Modelle geladen. Öffne Modelle, wechsle auf den Filter „Übersetzen“ und lade M2M-100, WMT21 (en→X / X→en) oder MADLAD-400 herunter.';

  @override
  String get translateAdvanced => 'Erweitert';

  @override
  String translateMaxTokens(int n) {
    return 'Max. Ausgabetoken: $n';
  }

  @override
  String get translateMaxTokensHelper =>
      'Obergrenze für die Länge der Übersetzung. CrispASR-Standard ist 200; höher für lange Passagen, niedriger für schnellere Antworten.';

  @override
  String get advancedPerfHeader => 'Leistung';

  @override
  String get advancedLidUseGpu => 'Sprach-Erkennung auf der GPU';

  @override
  String get advancedLidUseGpuSubtitle =>
      'Leitet die Spracherkennung an Metal / CUDA / Vulkan weiter, falls verfügbar. ASR-Backends nutzen ihre eigene GPU-Initialisierung beim Laden.';

  @override
  String get advancedLidFlashAttn => 'Sprach-Erkennung mit Flash-Attention';

  @override
  String get advancedLidFlashAttnSubtitle =>
      'Schnellerer Attention-Kernel im LID-Encoder. Nur abschalten, wenn ein Flash-Attention-Korrektheits-Bug auf deinem Build vermutet wird.';

  @override
  String advancedNThreads(int n) {
    return 'CPU-Threads: $n';
  }

  @override
  String get advancedNThreadsHelper =>
      'Thread-Anzahl für Spracherkennung und andere Helfer-Pässe. Standard ist 4.';

  @override
  String get synthCustomVoice => 'Eigene Stimme (WAV-Referenz)';

  @override
  String get synthCustomVoiceHelper =>
      'Wählt eine WAV-Datei für Laufzeit-Klonen. Kombiniere mit dem Referenz-Transkript bei qwen3-tts Base / vibevoice-1.5b. Übersteuert das Voicepack-Auswahlmenü, wenn gesetzt.';

  @override
  String get synthCustomVoicePick => 'Referenz-WAV auswählen…';

  @override
  String get synthCustomVoiceReplace => 'Referenz-WAV ersetzen…';

  @override
  String get synthCustomVoiceClear => 'Eigene Stimme entfernen';

  @override
  String get recorderStreamSession => 'Stream (Session)';

  @override
  String get recorderStreamSessionTooltip =>
      'Live-Transkription über den aktiven Backend-Streamer (kyutai-stt / moonshine-streaming / voxtral4b). Fällt auf Whisper-Sliding-Window zurück, wenn das Backend keinen Streaming-Pfad bietet.';

  @override
  String streamingNotAvailableForBackend(String backend) {
    return 'Das aktive Backend ($backend) hat keinen Streaming-Pfad. Wechsle zu whisper, kyutai-stt, moonshine-streaming oder voxtral4b.';
  }

  @override
  String get voiceBakeTitle => 'Stimme backen (WAV → GGUF)';

  @override
  String get voiceBakeOpenTooltip =>
      'Erzeugt aus einer WAV-Referenz eine Chatterbox-Stimme';

  @override
  String get voiceBakeIntro =>
      'Ruft CrispASRs bake-chatterbox-voice-from-wav.py auf und wandelt eine WAV-Referenz in ein Voicepack-GGUF um. Benötigt Python 3 mit den Paketen chatterbox-tts und gguf.';

  @override
  String get voiceBakeWavLabel => 'Referenz-WAV';

  @override
  String get voiceBakeWavPick => 'WAV auswählen…';

  @override
  String get voiceBakeOutputName => 'Ausgabe-Dateiname';

  @override
  String get voiceBakeOutputNameHelper =>
      'Wird im Modellverzeichnis neben den anderen Voicepacks abgelegt. Endung .gguf verwenden.';

  @override
  String voiceBakeExaggeration(String value) {
    return 'Übertreibung: $value';
  }

  @override
  String get voiceBakeExaggerationHelper =>
      'Standard-Emotionswert (0,0 – 1,0). Upstream-Vorgabe ist 0,5.';

  @override
  String get voiceBakePythonLabel => 'Python-Interpreter';

  @override
  String get voiceBakePythonHelper =>
      'Standard ist `python3` aus PATH. Überschreibe, wenn deine chatterbox-tts/gguf-Installation in einem venv liegt.';

  @override
  String get voiceBakeScriptLabel => 'Pfad des Bake-Skripts';

  @override
  String get voiceBakeScriptHelper =>
      'Standard ist ../CrispASR/models/bake-chatterbox-voice-from-wav.py. Anpassen, wenn dein CrispASR-Checkout woanders liegt.';

  @override
  String get voiceBakeRun => 'Stimme backen';

  @override
  String get voiceBakeRunning => 'Backe…';

  @override
  String voiceBakeSuccess(String path) {
    return 'Stimme gebacken → $path';
  }

  @override
  String voiceBakeFailure(String error) {
    return 'Backen fehlgeschlagen: $error';
  }

  @override
  String get voiceBakeMissingInputs =>
      'Wähle erst eine Referenz-WAV und einen Ausgabe-Dateinamen.';

  @override
  String get advancedAsrUseGpu => 'ASR auf der GPU';

  @override
  String get advancedAsrUseGpuSubtitle =>
      'Leitet die ASR-Initialisierung an Metal / CUDA / Vulkan weiter, sofern unterstützt. Wird beim nächsten Modell-Laden aktiv. Backends ohne Laufzeit-GPU-Steuerung behalten ihre Compile-Time-Vorgabe.';

  @override
  String get advancedAsrFlashAttn => 'ASR mit Flash-Attention';

  @override
  String get advancedAsrFlashAttnSubtitle =>
      'Verwendet den Flash-Attention-Kernel im ASR-Compute-Graph. Whisper unterstützt das nativ; andere Backends akzeptieren den Schalter, ihr Compute-Graph wird aber noch nicht darauf verzweigt. Wird beim nächsten Modell-Laden aktiv.';

  @override
  String advancedAsrNGpuLayers(int n) {
    return 'GPU-Schichten (LLM): $n';
  }

  @override
  String get advancedAsrNGpuLayersAuto => 'GPU-Schichten (LLM): auto (max.)';

  @override
  String get advancedAsrNGpuLayersHelper =>
      'Obergrenze für GPU-Schichten bei LLM-Backends (orpheus / voxtral / qwen3 / granite / chatterbox). 0 = LLM auf der CPU; 1+ = harte Grenze; auto = so viele wie passen. Wird beim nächsten Modell-Laden aktiv.';

  @override
  String get settingsServerSection => 'Lokaler HTTP-Server (OpenAI-kompatibel)';

  @override
  String get settingsServerEnable => 'Server starten';

  @override
  String settingsServerRunningAt(String url) {
    return 'Lauscht auf $url';
  }

  @override
  String get settingsServerStopped =>
      'Gestoppt. Aktivieren, um die CrisperWeaver-Services auf einem lokalen Port bereitzustellen.';

  @override
  String settingsServerStartFailed(String error) {
    return 'Server konnte nicht starten: $error';
  }

  @override
  String get settingsServerEndpoints => 'Endpunkte';

  @override
  String get settingsServerEndpointsHelp =>
      'POST /v1/audio/transcriptions (Multipart-Upload, file=audio) · POST /v1/audio/speech (JSON: model, input, voice, speed) · POST /v1/translations (JSON: model, text, src, tgt) · GET /health. Bindet nur an 127.0.0.1 — keine Authentifizierung.';

  @override
  String synthTemperature(String value) {
    return 'Temperatur: $value';
  }

  @override
  String get synthTemperatureHelper =>
      'Sampling-Temperatur (gemeinsam für Orpheus / Chatterbox / Canary). 0,0 = greedy / reproduzierbar. Höher = mehr Variation.';

  @override
  String synthTtsSteps(int n) {
    return 'Diffusionsschritte: $n';
  }

  @override
  String get synthTtsStepsHelper =>
      'Anzahl der CFM-Euler-Schritte im Chatterbox-Mel-Decoder (Standard 10). Höher = glatterer Klang, aber höhere Latenz.';

  @override
  String synthCfgWeight(String value) {
    return 'CFG-Gewicht: $value';
  }

  @override
  String get synthCfgWeightHelper =>
      'Classifier-Free-Guidance-Gewicht (Chatterbox). 0 deaktiviert CFG; 0,5 ist die Standardvorgabe; ≥1 verstärkt den konditionalen Pfad.';

  @override
  String synthExaggeration(String value) {
    return 'Übertreibung: $value';
  }

  @override
  String get synthExaggerationHelper =>
      'Emotionswert (Chatterbox). 0,5 ist die Standardvorgabe; höher für dramatischere Ausführung, niedriger für monoton.';

  @override
  String synthTopP(String value) {
    return 'Top-p: $value';
  }

  @override
  String get synthTopPHelper =>
      'Top-p-Nucleus-Sampling-Schwelle (Chatterbox). 1,0 deaktiviert Top-p; kleinere Werte schneiden den unwahrscheinlichen Schwanz ab.';
}
