// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Susurrus';

  @override
  String get appTagline => 'Audio-Transkription mit Sprecher-Diarisierung';

  @override
  String get menuHistory => 'Verlauf';

  @override
  String get menuSettings => 'Einstellungen';

  @override
  String get menuModels => 'Modelle';

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
  String get diarizationTitle => 'Sprecher-Diarisierung';

  @override
  String get diarizationSubtitle =>
      'Verschiedene Sprecher in Aufnahmen identifizieren';

  @override
  String get diarizationModel => 'Diarisierungs-Modell';

  @override
  String get minSpeakers => 'Min. Sprecher';

  @override
  String get maxSpeakers => 'Max. Sprecher';

  @override
  String get auto => 'Auto';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsEngineSection => 'Transkriptions-Engine';

  @override
  String get settingsEnginePreferred => 'Bevorzugte Engine';

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
  String get settingsDiarization => 'Sprecher-Diarisierung';

  @override
  String get settingsEnableDiarizationByDefault => 'Standardmäßig aktivieren';

  @override
  String get settingsEnableDiarizationByDefaultSubtitle =>
      'Diarisierung für neue Transkriptionen automatisch aktivieren';

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
  String get settingsOpenLogViewer => 'Protokoll-Ansicht öffnen';

  @override
  String get settingsSystemInfo => 'Systeminformation';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsAboutSusurrus => 'Über Susurrus';

  @override
  String get settingsAboutSusurrusSubtitle =>
      'Anbieter, Kontakt, Haftungsausschluss, Lizenzen';

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
      'Susurrus verarbeitet alle Audio-Daten ausschließlich lokal auf Ihrem Gerät. Weder Audio noch Transkripte oder Aufnahmen werden an Server übertragen. Modell-Downloads laden GGUF-Gewichte direkt von HuggingFace über HTTPS; darüber hinaus verlässt nichts das Gerät.';

  @override
  String get aboutDisclaimerText =>
      'Diese Software wird „wie besehen“ zur Verfügung gestellt, ohne jegliche ausdrückliche oder stillschweigende Gewährleistung, insbesondere der Marktgängigkeit, Eignung für einen bestimmten Zweck oder der Nichtverletzung von Rechten Dritter. In keinem Fall haften die Autor:innen für Ansprüche, Schäden oder sonstige Haftungen, die sich aus oder im Zusammenhang mit der Software oder deren Nutzung ergeben.';

  @override
  String get aboutLicenseText =>
      'Susurrus ist freie Software und wird unter der GNU Affero General Public License v3.0 (AGPL-3.0) veröffentlicht. Sie dürfen es unter den Bedingungen dieser Lizenz weitergeben und verändern. Insbesondere gilt: Wenn Sie eine veränderte Version von Susurrus als Netzwerk-Dienst betreiben, müssen Sie den zugehörigen Quellcode Ihren Nutzer:innen zugänglich machen.';

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
  String get logsCopyVisible => 'Sichtbare kopieren';

  @override
  String get logsCopyAll => 'Alle kopieren';

  @override
  String get logsExport => 'In Datei exportieren';

  @override
  String get logsShare => 'Als Datei teilen';

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
}
