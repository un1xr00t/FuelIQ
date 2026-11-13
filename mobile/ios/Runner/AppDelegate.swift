import CoreLocation
import CoreImage
import Flutter
import ImageIO
import MapKit
import MLKitTextRecognition
import MLKitTextRecognitionCommon
import MLKitVision
import UIKit
import Vision
import Security

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
      switch call.method {
      case "hasClaudeKey":
        result(Self.claudeKey() != nil)
        return
      case "saveClaudeKey":
        guard let key = call.arguments as? String else {
          result(false)
          return
        }
        result(Self.saveClaudeKey(key))
        return
      case "claudeKey":
        result(Self.claudeKey())
        return
      case "prepareClaudePhoto":
        guard let path = call.arguments as? String else {
          result(nil)
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let photo = Self.prepareClaudePhoto(URL(fileURLWithPath: path))
          DispatchQueue.main.async { result(photo) }
        }
        return
      default:
        break
      }
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

  private static let claudeKeyQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.fueliq.fueliq.claude",
    kSecAttrAccount as String: "anthropic_api_key"
  ]

  private static func claudeKey() -> String? {
    var query = claudeKeyQuery
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func saveClaudeKey(_ key: String) -> Bool {
    let query = claudeKeyQuery as CFDictionary
    if key.isEmpty {
      let status = SecItemDelete(query)
      return status == errSecSuccess || status == errSecItemNotFound
    }
    let value = [kSecValueData as String: Data(key.utf8)]
    let status = SecItemUpdate(query, value as CFDictionary)
    if status == errSecSuccess { return true }
    guard status == errSecItemNotFound else { return false }
    var entry = claudeKeyQuery
    entry[kSecValueData as String] = Data(key.utf8)
    entry[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    return SecItemAdd(entry as CFDictionary, nil) == errSecSuccess
  }

  private static func prepareClaudePhoto(_ url: URL) -> [String: Any]? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, width <= 60_000_000 / height,
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 1600
      ] as CFDictionary),
      let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.94)
    else { return nil }
    var result = photoLocation(properties)
    result["jpeg"] = FlutterStandardTypedData(bytes: jpeg)
    if let exif = properties[kCGImagePropertyExifDictionary] as? [String: Any] {
      result["capturedAt"] = exif[kCGImagePropertyExifDateTimeOriginal as String]
      result["captureOffset"] = exif["OffsetTimeOriginal"]
    }
    return result
  }

  private static func photoLocation(_ properties: [CFString: Any]) -> [String: Any] {
    guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
      let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
      let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
      let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
      let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String,
      ["N", "S"].contains(latRef), ["E", "W"].contains(lonRef),
      (0...90).contains(latitude), (0...180).contains(longitude)
    else { return [:] }
    return [
      "latitude": latRef == "S" ? -latitude : latitude,
      "longitude": lonRef == "W" ? -longitude : longitude
    ]
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
    var metadata = photoLocation(properties)
    if let exif = properties[kCGImagePropertyExifDictionary] as? [String: Any],
      let capture = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
      metadata["capturedAt"] = capture
      metadata["captureOffset"] = exif["OffsetTimeOriginal"]
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    let display = PumpDisplayReader.candidates(in: image)
    let alternateText = recognizeWithMLKit(image)
    do {
      try VNImageRequestHandler(cgImage: image).perform([request])
      let observations = request.results ?? []
      var text = observations.compactMap { observation -> [String: Any]? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let box = observation.boundingBox
        return [
          "text": candidate.string, "confidence": Double(candidate.confidence),
          "x": Double(box.minX), "y": Double(box.minY),
          "width": Double(box.width), "height": Double(box.height)
        ]
      }
      for observation in observations.prefix(80) {
        guard let label = observation.topCandidates(1).first?.string else { continue }
        let box = observation.boundingBox
        let region: CGRect
        if label.range(
            of: #"^price\s+per\s+(?:us\s+)?gal(?:lon)?\b"#,
            options: [.regularExpression, .caseInsensitive]
          ) != nil {
          region = CGRect(
            x: box.midX - box.width * 0.91, y: box.maxY + box.height,
            width: box.width * 1.88, height: box.height * 5.64
          )
        } else if label.lowercased().hasPrefix("minimum octane rating") {
          region = CGRect(
            x: box.midX - box.width * 0.75, y: box.maxY + box.width,
            width: box.width * 1.5, height: box.width * 0.64
          )
        } else {
          continue
        }
        if let price = Self.readPriceDisplay(in: image, region: region) {
          text.append(price)
        }
      }
      return metadata.merging([
        "text": text, "alternateText": alternateText, "display": display
      ]) { _, new in new }
    } catch {
      if !alternateText.isEmpty || !display.isEmpty || !metadata.isEmpty {
        let visionError = error as NSError
        return metadata.merging([
          "text": [], "alternateText": alternateText, "display": display,
          "visionError": "\(visionError.domain) (\(visionError.code))"
        ]) { _, new in new }
      }
      return FlutterError(code: "recognition_failed", message: nil, details: nil)
    }
  }

  private static func recognizeWithMLKit(_ image: CGImage) -> [[String: Any]] {
    let input = VisionImage(image: UIImage(cgImage: image))
    input.orientation = .up
    let recognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions())
    // This method runs on the scanner's background queue.
    guard let result = try? recognizer.results(in: input) else { return [] }
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    return result.blocks.flatMap { block in
      block.lines.map { line in
        let box = line.frame
        return [
          "text": line.text, "confidence": 0.8,
          "x": box.minX / width, "y": 1 - box.maxY / height,
          "width": box.width / width, "height": box.height / height
        ]
      }
    }
  }

  private static func readPriceDisplay(in image: CGImage, region normalized: CGRect) -> [String: Any]? {
    // Keep crop boundaries stable when Vision shifts the label box slightly.
    func aligned(_ fraction: CGFloat) -> CGFloat { (fraction * 200).rounded() / 200 }
    let frame = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    let region = CGRect(
      x: aligned(normalized.minX) * frame.width, y: aligned(normalized.minY) * frame.height,
      width: aligned(normalized.width) * frame.width,
      height: aligned(normalized.height) * frame.height
    ).intersection(frame)
    guard !region.isNull else { return nil }
    let cropped = CIImage(cgImage: image).cropped(to: region)
    guard let crop = CIContext().createCGImage(cropped, from: region) else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    do {
      try VNImageRequestHandler(cgImage: crop).perform([request])
    } catch {
      return nil
    }
    let values = (request.results ?? []).compactMap { observation -> (String, CGRect)? in
      guard let text = observation.topCandidates(1).first?.string,
        text.range(of: #"^\$?\s*\d{1,2}[.,]\s*\d{3}$"#, options: .regularExpression) != nil
      else { return nil }
      return (text.replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: " ", with: ""), observation.boundingBox)
    }
    guard values.count == 1, let (text, box) = values.first else { return nil }
    return [
      "text": "PPG \(text)", "confidence": 0.8,
      "x": (region.minX + box.minX * region.width) / frame.width,
      "y": (region.minY + box.minY * region.height) / frame.height,
      "width": box.width * region.width / frame.width,
      "height": box.height * region.height / frame.height
    ]
  }
}

// Reads bright seven-segment digits using the decimal dot as a position anchor.
private enum PumpDisplayReader {
  private struct Dot {
    let x: Int
    let y: Int
    let size: Int
  }

  private static let digits = [119, 36, 93, 109, 46, 107, 123, 37, 127, 111]
  private static let samples: [(Double, Double)] = [
    (0, 0.06), (-0.29, 0.27), (0.29, 0.27), (0, 0.51),
    (-0.29, 0.74), (0.29, 0.74), (0, 0.95), (0, 0.27), (0, 0.74)
  ]

  static func candidates(in image: CGImage) -> [[String: Any]] {
    let scale = 600.0 / Double(max(image.width, image.height))
    let width = Int(Double(image.width) * scale)
    let height = Int(Double(image.height) * scale)
    guard width >= 100, height >= 100,
      let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2),
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
      ), let data = context.data else { return [] }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = UnsafeBufferPointer(
      start: data.assumingMemoryBound(to: UInt8.self), count: width * height
    )
    let dots = decimalDots(pixels, width: width, height: height)
    var pairs: [[String: Any]] = []
    var rows: [Int: [Int: [Int: Double]]] = [:]
    for (upperIndex, upper) in dots.enumerated() {
      for (lowerIndex, lower) in dots.enumerated() {
        let gap = lower.y - upper.y
        guard gap > upper.size * 6, gap < upper.size * 17,
          lower.x < upper.x, upper.x - lower.x < upper.size * 13,
          lower.size <= upper.size + 1, lower.size * 2 >= upper.size else { continue }
        let totals = rows[upperIndex]?[2] ??
          readRow(pixels, width: width, height: height, dot: upper, decimals: 2)
        rows[upperIndex, default: [:]][2] = totals
        guard !totals.isEmpty else { continue }
        let gallons = rows[lowerIndex]?[3] ??
          readRow(pixels, width: width, height: height, dot: lower, decimals: 3)
        rows[lowerIndex, default: [:]][3] = gallons
        if !gallons.isEmpty {
          pairs.append([
            "totals": totals.map { ["value": $0.key, "score": $0.value] },
            "gallons": gallons.map { ["value": $0.key, "score": $0.value] }
          ])
        }
      }
    }
    return pairs
  }

  private static func decimalDots(
    _ pixels: UnsafeBufferPointer<UInt8>, width: Int, height: Int
  ) -> [Dot] {
    var dots: [Dot] = []
    // Multiple thresholds handle both dim digits and reflections.
    for threshold: UInt8 in [65, 80, 95, 110, 130, 150, 175, 200, 225] {
      var visited = [Bool](repeating: false, count: pixels.count)
      for start in pixels.indices where !visited[start] && pixels[start] >= threshold {
        visited[start] = true
        var queue = [start]
        var cursor = 0
        var minX = start % width, maxX = minX
        var minY = start / width, maxY = minY
        while cursor < queue.count {
          let index = queue[cursor]
          cursor += 1
          let x = index % width, y = index / width
          minX = min(minX, x)
          maxX = max(maxX, x)
          minY = min(minY, y)
          maxY = max(maxY, y)
          for next in [
            x > 0 ? index - 1 : index,
            x + 1 < width ? index + 1 : index,
            y > 0 ? index - width : index,
            y + 1 < height ? index + width : index
          ] where !visited[next] && pixels[next] >= threshold {
            visited[next] = true
            queue.append(next)
          }
        }
        let w = maxX - minX + 1, h = maxY - minY + 1
        let size = max(w, h)
        let x = (minX + maxX + 1) / 2, y = (minY + maxY + 1) / 2
        guard size >= 4, size <= 15, abs(w - h) <= 2,
          queue.count * 3 >= w * h * 2,
          x > size * 5, x + size * 6 < width, y > size * 7,
          y + size < height, Int(pixels[y * width + x]) - Int(pixels[(y + size) * width + x]) > 20 else { continue }
        if !dots.contains(where: { abs($0.x - x) <= 2 && abs($0.y - y) <= 2 }) {
          dots.append(Dot(x: x, y: y, size: size))
          if dots.count > 48 { return [] }
        }
      }
    }
    return dots
  }

  private static func readRow(
    _ pixels: UnsafeBufferPointer<UInt8>, width: Int, height: Int, dot: Dot, decimals: Int
  ) -> [Int: Double] {
    var readings: [Int: Double] = [:]
    for digitHeight in stride(from: max(18, dot.size * 6), through: dot.size * 14, by: 2) {
      let h = Double(digitHeight)
      for spacing in stride(from: Int(h * 0.44), through: Int(h * 0.77), by: 2) {
        let pitch = Double(spacing)
        for slant in [-0.10, -0.06, -0.02, 0.02, 0.06] {
          for offset in [-0.13, -0.05, 0.03, 0.11] {
            var fits: [(digit: Int, score: Double)] = []
            for column in -3..<decimals {
              let center = Double(dot.x) + (Double(column) + 0.5 + offset) * pitch
              let top = Double(dot.y) - h
              guard center - pitch - h * 0.1 >= 0, center + pitch + h * 0.1 < Double(width),
                top >= 0, dot.y < height else {
                fits.append((0, 0))
                continue
              }
              let levels = samples.map { px, py in
                let y = Int((top + py * h).rounded())
                let spread = px == 0 ? 0.13 : 0.055
                return [-spread, 0, spread].map { dx in
                  let x = Int((center + slant * h * (py - 1) + (px + dx) * pitch).rounded())
                  return Double(pixels[y * width + x])
                }.sorted()[1]
              }
              let contrast = (0..<7).map { segment in
                let background = segment < 3 ? levels[7] :
                  segment == 3 ? min(levels[7], levels[8]) : levels[8]
                return levels[segment] - background
              }
              let ranked = digits.enumerated().map { digit, mask in
                let score = contrast.enumerated().reduce(0.0) { sum, item in
                  let (segment, light) = item
                  return sum + min(1, mask & (1 << segment) != 0 ?
                    (light - 14) / 45 : (40 - light) / 28)
                } / 7
                return (digit, score)
              }.sorted { $0.1 > $1.1 }
              fits.append((ranked[0].0, ranked[0].1 + 0.6 * (ranked[0].1 - ranked[1].1)))
            }
            for leading in 1...3 {
              let digits = fits.suffix(leading + decimals)
              guard digits.allSatisfy({ $0.score >= 0.60 }),
                leading == 1 || digits.first?.digit != 0 else { continue }
              let value = digits.reduce(0) { $0 * 10 + $1.digit }
              let score = digits.reduce(0.0) { $0 + $1.score } / Double(digits.count)
              if value > 0, score >= 0.80 {
                readings[value] = max(readings[value] ?? 0, score)
              }
            }
          }
        }
      }
    }
    return readings
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
