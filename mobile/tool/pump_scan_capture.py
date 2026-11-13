"""Run FuelIQ's Apple Vision and display reader on local photos on macOS."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("photos", nargs="+", type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / "ios/Runner/AppDelegate.swift"
    app = source.read_text()
    start = app.index("  private static func recognizePhoto(")
    end = app.index("private final class StationLocationRequest", start)
    scanner = app[start:end].replace("private static func recognizePhoto", "static func recognizePhoto", 1)
    # ML Kit's framework targets iOS. Replay iPhone ML Kit rows separately.
    start = scanner.index("  private static func recognizeWithMLKit(")
    end = scanner.index("  private static func readPriceDisplay(", start)
    scanner = scanner[:start] + """
  private static func recognizeWithMLKit(_ image: CGImage) -> [[String: Any]] { [] }
""" + scanner[end:]
    driver = """
import Foundation
import CoreImage
import ImageIO
import Vision
struct FlutterError { let code: String; let message: String?; let details: String? }
enum Scanner {
""" + scanner + """
let scans = CommandLine.arguments.dropFirst().map { path -> [String: Any] in
  let result = Scanner.recognizePhoto(at: URL(fileURLWithPath: path))
  if let error = result as? FlutterError { return ["error": error.code] }
  return result as? [String: Any] ?? ["error": "unexpected_response"]
}
let data = try JSONSerialization.data(withJSONObject: scans, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(data)
"""
    with tempfile.TemporaryDirectory(prefix="fueliq-ocr-") as directory:
        folder = Path(directory)
        swift = folder / "scan.swift"
        swift.write_text(driver)
        executable = folder / "scan"
        subprocess.run(
            ["swiftc", "-O", "-module-cache-path", str(folder / "modules"),
             str(swift), "-o", str(executable)],
            check=True,
        )
        subprocess.run([str(executable), *(str(photo) for photo in args.photos)], check=True)


if __name__ == "__main__":
    main()
