import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Configure audio session
    configureAudioSession()
    
    // Register plugins
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Register CoreML Whisper plugin
    if #available(iOS 13.0, *) {
        CoreMLWhisperPlugin.register(with: registrar(forPlugin: "CoreMLWhisperPlugin")!)
    }
    
    // Register Audio Processing plugin
    AudioProcessingPlugin.register(with: registrar(forPlugin: "AudioProcessingPlugin")!)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try audioSession.setActive(true)
    } catch {
      print("Failed to configure audio session: \(error)")
    }
  }
  
  override func applicationWillResignActive(_ application: UIApplication) {
    // Pause any ongoing transcription when app goes to background
    super.applicationWillResignActive(application)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Resume audio session when app becomes active
    configureAudioSession()
    super.applicationDidBecomeActive(application)
  }
}