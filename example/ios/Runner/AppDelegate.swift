import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "local_voice_example/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(
          code: "storage_unavailable",
          message: "Private model storage is unavailable.",
          details: nil
        ))
        return
      }
      do {
        let root = try self.modelRoot()
        switch call.method {
        case "getModelRoot":
          result(root.path)
        case "availableBytes":
          let values = try root.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
          )
          guard let bytes = values.volumeAvailableCapacityForImportantUsage else {
            throw StorageError.capacityUnavailable
          }
          result(bytes)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(
          code: "storage_unavailable",
          message: "Private model storage is unavailable.",
          details: nil
        ))
      }
    }
  }

  private func modelRoot() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    var root = support.appendingPathComponent("LocalVoiceModels", isDirectory: true)
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
    let verified = try root.resourceValues(forKeys: [.isExcludedFromBackupKey])
    guard verified.isExcludedFromBackup == true else {
      throw StorageError.backupExclusionFailed
    }
    return root
  }
}

private enum StorageError: Error {
  case backupExclusionFailed
  case capacityUnavailable
}
