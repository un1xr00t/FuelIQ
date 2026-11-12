import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var photoPicker: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let pickerChannel = FlutterMethodChannel(
      name: "fueliq/photo_picker",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pickerChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickPhoto" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard #available(iOS 17.0, *) else {
        result(FlutterError(code: "inline_picker_unsupported", message: nil, details: nil))
        return
      }
      guard let self, var presenter = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?.rootViewController else {
        result(FlutterError(code: "picker_unavailable", message: nil, details: nil))
        return
      }
      while let presented = presenter.presentedViewController { presenter = presented }
      let picker = self.photoPicker as? FuelPhotoPicker ?? FuelPhotoPicker()
      self.photoPicker = picker
      picker.presentPicker(presenter: presenter, result: result)
    }
    let channel = FlutterMethodChannel(
      name: "fueliq/fuel_photo",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String else {
        result(FlutterError(code: "invalid_image", message: nil, details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let response = Self.recognizePhoto(at: URL(fileURLWithPath: path))
        DispatchQueue.main.async { result(response) }
      }
    }
  }

  private static func recognizePhoto(at url: URL) -> Any {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(source) as String?,
          ["public.jpeg", "public.png", "public.heic", "public.heif"].contains(type),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 60_000_000 / height,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3200
          ] as CFDictionary) else {
      return FlutterError(code: "invalid_image", message: nil, details: nil)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
      return (request.results ?? []).compactMap { observation -> [String: Any]? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        return [
          "text": candidate.string, "confidence": Double(candidate.confidence),
          "x": Double(box.minX), "y": Double(box.minY),
          "width": Double(box.width), "height": Double(box.height)
        ]
      }
    } catch {
      return FlutterError(code: "recognition_failed", message: nil, details: nil)
    }
  }
}
