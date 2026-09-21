import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ExampleStorageChannel.register(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

private enum ExampleStorageChannel {
  static let name = "local_voice_example/storage"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      do {
        let root = try modelRoot()
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
        result(
          FlutterError(
            code: "storage_unavailable",
            message: "Private model storage is unavailable.",
            details: nil
          )
        )
      }
    }
  }

  static func modelRoot() throws -> URL {
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
