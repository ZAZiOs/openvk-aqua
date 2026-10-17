import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
  private var backgroundChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. Configure audio session for background playback
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
      try audioSession.setActive(true)
    } catch {
      print("[AppDelegate] Error setting AVAudioSession category: \(error)")
    }

    // 2. Configure background fetch interval
    application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    // 3. Setup MethodChannel on controller if available
    if let controller = window?.rootViewController as? FlutterViewController {
      setupBackgroundChannel(messenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundSyncPlugin")
    setupBackgroundChannel(messenger: registrar.messenger())
  }

  private func setupBackgroundChannel(messenger: FlutterBinaryMessenger) {
    if backgroundChannel != nil { return }
    let channel = FlutterMethodChannel(name: "oss.zazios.ovkaqua/background_service", binaryMessenger: messenger)
    backgroundChannel = channel

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "beginBackgroundTask":
        self.beginBackgroundExecution()
        result(true)
      case "endBackgroundTask":
        self.endBackgroundExecution()
        result(true)
      case "startService", "stopService", "isServiceRunning":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginBackgroundExecution() {
    endBackgroundExecution()
    backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "OpenVkBackgroundSync") { [weak self] in
      self?.endBackgroundExecution()
    }
  }

  private func endBackgroundExecution() {
    if backgroundTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskId)
      backgroundTaskId = .invalid
    }
  }

  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if let channel = backgroundChannel {
      channel.invokeMethod("onBackgroundFetch", arguments: nil) { _ in
        completionHandler(.newData)
      }
    } else {
      completionHandler(.noData)
    }
  }
}
