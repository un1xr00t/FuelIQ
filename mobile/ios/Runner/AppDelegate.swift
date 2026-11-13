import CoreLocation
import Flutter
import ImageIO
import MapKit
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var photoPicker: AnyObject?
  private let stationLocation = StationLocationRequest()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let locationChannel = FlutterMethodChannel(
      name: "fueliq/station_location",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    locationChannel.setMethodCallHandler { [stationLocation] call, result in
      if call.method == "openTopTierFinder",
        let url = URL(string: "https://stationfinder.toptiergas.com/")
      {
        UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
        return
      }
      if call.method == "openStationInMaps" {
        guard let station = call.arguments as? [String: Any],
          let name = station["name"] as? String,
          let latitude = station["latitude"] as? Double,
          let longitude = station["longitude"] as? Double
        else {
          result(false)
          return
        }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else {
          result(false)
          return
        }
        let address = station["address"] as? String ?? ""
        let placemark = MKPlacemark(
          coordinate: coordinate,
          addressDictionary: address.isEmpty ? nil : ["Street": address]
        )
        let destination = MKMapItem(placemark: placemark)
        destination.name = name
        result(destination.openInMaps(launchOptions: nil))
        return
      }
      guard call.method == "currentLocation" else {
        result(FlutterMethodNotImplemented)
        return
      }
      stationLocation.request(result)
    }
    let pickerChannel = FlutterMethodChannel(
      name: "fueliq/photo_picker",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pickerChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickPhoto" || call.method == "pickFuelPhotos" else {
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
      picker.presentPicker(
        presenter: presenter,
        allowsMultiple: call.method == "pickFuelPhotos",
        result: result
      )
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

private final class StationLocationRequest: NSObject, CLLocationManagerDelegate {
  private lazy var manager: CLLocationManager = {
    let manager = CLLocationManager()
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.delegate = self
    return manager
  }()
  private var pending: FlutterResult?
  private var timeout: DispatchWorkItem?
  private var requestingFix = false

  func request(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    pending = result
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else {
      locationManagerDidChangeAuthorization(manager)
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    guard pending != nil else { return }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      guard !requestingFix else { return }
      requestingFix = true
      let timeout = DispatchWorkItem { [weak self] in self?.fail("unavailable") }
      self.timeout = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
      manager.requestLocation()
    case .denied: fail("denied")
    case .restricted: fail("restricted")
    case .notDetermined: break
    @unknown default: fail("unavailable")
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last,
          CLLocationCoordinate2DIsValid(location.coordinate),
          location.horizontalAccuracy >= 0,
          abs(location.timestamp.timeIntervalSinceNow) <= 60 else {
      fail("unavailable")
      return
    }
    complete([
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if manager.authorizationStatus == .denied {
      fail("denied")
    } else {
      fail("unavailable")
    }
  }

  private func fail(_ code: String) {
    complete(FlutterError(code: code, message: nil, details: nil))
  }

  private func complete(_ value: Any) {
    guard let result = pending else { return }
    timeout?.cancel()
    timeout = nil
    pending = nil
    requestingFix = false
    manager.stopUpdatingLocation()
    result(value)
  }
}
