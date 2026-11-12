import AVFoundation
import AVKit
import CoreTransferable
import Flutter
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Adapted from Journal Intelligence V2's inline photo picker.
@available(iOS 17.0, *)
final class FuelPhotoPicker: NSObject, UISheetPresentationControllerDelegate {
  private var pendingResult: FlutterResult?
  private var pendingSelection: [PhotosPickerItem] = []
  private var pickerController: UIHostingController<FuelInlinePhotosPicker>?
  private var actionBarController: UIHostingController<PickerActionBar>?

  func presentPicker(
    presenter: UIViewController,
    result: @escaping FlutterResult
  ) {
    guard pendingResult == nil else {
      result(FlutterError(code: "picker_active", message: "Photo picker is already open.", details: nil))
      return
    }
    pendingResult = result
    let picker = makePicker(cameraVisible: false)
    let hosting = UIHostingController(rootView: picker)
    hosting.modalPresentationStyle = .pageSheet
    if let sheet = hosting.sheetPresentationController {
      sheet.detents = [.medium(), .large()]
      sheet.selectedDetentIdentifier = .medium
      sheet.prefersGrabberVisible = false
      sheet.preferredCornerRadius = 34
      sheet.prefersScrollingExpandsWhenScrolledToEdge = true
      sheet.delegate = self
    }
    pickerController = hosting
    presenter.present(hosting, animated: true) { [weak self] in
      self?.installActionBar(on: hosting)
    }
  }

  private func makePicker(cameraVisible: Bool) -> FuelInlinePhotosPicker {
    FuelInlinePhotosPicker(
      selectionLimit: 1,
      cameraVisible: cameraVisible,
      onSelectionChange: { [weak self] items in self?.updateSelection(items) },
      onCameraBack: { [weak self] in self?.showLibrary() },
      onPhotoCaptured: { [weak self] url in self?.finishCapturedPhoto(url) }
    )
  }

  private func installActionBar(on hosting: UIHostingController<FuelInlinePhotosPicker>) {
    guard pendingResult != nil else { return }
    actionBarController?.willMove(toParent: nil)
    actionBarController?.view.removeFromSuperview()
    actionBarController?.removeFromParent()
    let actionBar = UIHostingController(rootView: makeActionBar(count: pendingSelection.count))
    actionBar.view.backgroundColor = .clear
    actionBar.view.translatesAutoresizingMaskIntoConstraints = false
    hosting.addChild(actionBar)
    hosting.view.addSubview(actionBar.view)
    NSLayoutConstraint.activate([
      actionBar.view.heightAnchor.constraint(equalToConstant: 56),
      actionBar.view.leadingAnchor.constraint(equalTo: hosting.view.leadingAnchor, constant: 24),
      actionBar.view.trailingAnchor.constraint(equalTo: hosting.view.trailingAnchor, constant: -24),
      actionBar.view.bottomAnchor.constraint(
        equalTo: hosting.view.safeAreaLayoutGuide.bottomAnchor,
        constant: -22
      ),
    ])
    actionBar.didMove(toParent: hosting)
    actionBarController = actionBar
  }

  private func makeActionBar(count: Int) -> PickerActionBar {
    PickerActionBar(
      count: count,
      onCancel: { [weak self] in self?.finish(nil) },
      onCamera: { [weak self] in self?.showCamera() },
      onAdd: { [weak self] in self?.importSelection() }
    )
  }

  private func showCamera() {
    guard pendingResult != nil else { return }
    actionBarController?.willMove(toParent: nil)
    actionBarController?.view.removeFromSuperview()
    actionBarController?.removeFromParent()
    actionBarController = nil
    pickerController?.rootView = makePicker(cameraVisible: true)
  }

  private func showLibrary() {
    guard pendingResult != nil, let pickerController else { return }
    pickerController.rootView = makePicker(cameraVisible: false)
    DispatchQueue.main.async { [weak self, weak pickerController] in
      guard let self, let pickerController else { return }
      self.installActionBar(on: pickerController)
    }
  }

  private func finishCapturedPhoto(_ url: URL) {
    guard pendingResult != nil else {
      try? FileManager.default.removeItem(at: url)
      return
    }
    finish(url.path)
  }

  private func updateSelection(_ items: [PhotosPickerItem]) {
    pendingSelection = items
    actionBarController?.rootView = makeActionBar(count: items.count)
    if let actionBarView = actionBarController?.view {
      pickerController?.view.bringSubviewToFront(actionBarView)
    }
  }

  private func importSelection() {
    guard let item = pendingSelection.first else { return }
    finish(nil, importing: item)
  }

  private func finish(_ path: String?, importing item: PhotosPickerItem? = nil) {
    guard let result = pendingResult, let pickerController else { return }
    pendingResult = nil
    clearPickerReferences()
    pickerController.dismiss(animated: true) {
      guard let item else {
        result(path)
        return
      }
      Task { @MainActor in
        do {
          guard let photo = try await item.loadTransferable(type: ImportedFuelPhoto.self) else {
            result(FlutterError(code: "photo_unavailable", message: "Photo could not be loaded.", details: nil))
            return
          }
          result(photo.url.path)
        } catch {
          result(FlutterError(code: "photo_import_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let result = pendingResult else { return }
    pendingResult = nil
    clearPickerReferences()
    result(nil)
  }

  private func clearPickerReferences() {
    pendingSelection = []
    pickerController = nil
    actionBarController = nil
  }
}

@available(iOS 17.0, *)
private struct FuelInlinePhotosPicker: View {
  let selectionLimit: Int
  let cameraVisible: Bool
  let onSelectionChange: ([PhotosPickerItem]) -> Void
  let onCameraBack: () -> Void
  let onPhotoCaptured: (URL) -> Void
  @State private var selection: [PhotosPickerItem] = []

  var body: some View {
    Group {
      if cameraVisible {
        FuelInlineCamera(
          onBack: onCameraBack,
          onPhotoCaptured: onPhotoCaptured
        )
      } else {
        PhotosPicker(
          selection: $selection,
          maxSelectionCount: selectionLimit,
          selectionBehavior: .continuousAndOrdered,
          matching: .images,
          preferredItemEncoding: .current
        ) {
          Color.clear
        }
        .photosPickerStyle(.inline)
        .photosPickerAccessoryVisibility(.hidden, edges: .all)
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: selection) { _, items in
          onSelectionChange(items)
        }
      }
    }
  }
}

@available(iOS 17.0, *)
private struct PickerActionBar: View {
  let count: Int
  let onCancel: () -> Void
  let onCamera: () -> Void
  let onAdd: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      Button(action: onCancel) {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
          .background {
            PickerGlassBackground(
              shape: Circle(),
              tint: Color(red: 16 / 255, green: 16 / 255, blue: 27 / 255),
              opacity: 0.65
            )
          }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Cancel")

      Spacer(minLength: 0)

      if count > 0 {
        Button(action: onAdd) {
          Text(count == 1 ? "Add 1 photo" : "Add \(count) photos")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background {
              PickerGlassBackground(
                shape: Capsule(),
                tint: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255),
                opacity: 0.56
              )
            }
        }
        .buttonStyle(.plain)
      } else {
        Button(action: onCamera) {
          Image(systemName: "camera.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
              PickerGlassBackground(
                shape: Circle(),
                tint: Color(red: 16 / 255, green: 16 / 255, blue: 27 / 255),
                opacity: 0.65
              )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Camera")
      }
    }
  }
}

@available(iOS 17.0, *)
private struct FuelInlineCamera: View {
  let onBack: () -> Void
  let onPhotoCaptured: (URL) -> Void

  @StateObject private var camera = InlineCameraController()
  @State private var showsMoreControls = false

  var body: some View {
    ZStack {
      Color.black
      InlineCameraPreview(session: camera.session)
        .ignoresSafeArea()

      if camera.permissionDenied || camera.unavailable {
        VStack(spacing: 10) {
          Image(systemName: "camera.fill")
            .font(.system(size: 28, weight: .semibold))
          Text(camera.unavailable ? "Camera unavailable" : "Camera access is off")
            .font(.system(size: 17, weight: .semibold))
          Text(camera.unavailable
            ? "Go back to choose a photo from your library."
            : "Enable Camera in Settings to take a photo.")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(28)
      }

      VStack {
        Spacer()
        HStack(alignment: .bottom) {
          cameraControl(systemName: "chevron.left", action: onBack)
            .accessibilityLabel("Back to Photos")
          Spacer()
          Button {
            camera.capturePhoto(onPhotoCaptured)
          } label: {
            ZStack {
              Circle()
                .fill(.black.opacity(0.34))
                .frame(width: 76, height: 76)
              Circle()
                .stroke(.white.opacity(0.42), lineWidth: 2)
                .frame(width: 70, height: 70)
              Circle()
                .fill(.white)
                .frame(width: 60, height: 60)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Take photo")
          .disabled(!camera.ready || camera.capturing)
          Spacer()
          if showsMoreControls {
            VStack(spacing: 10) {
              cameraControl(
                systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill",
                action: camera.toggleFlash
              )
              .accessibilityLabel(camera.flashEnabled ? "Turn flash off" : "Turn flash on")
              cameraControl(systemName: "arrow.triangle.2.circlepath.camera.fill") {
                camera.flipCamera()
              }
              .accessibilityLabel("Flip camera")
              cameraControl(systemName: "xmark") {
                withAnimation(.easeOut(duration: 0.18)) {
                  showsMoreControls = false
                }
              }
              .accessibilityLabel("Hide camera controls")
            }
          } else {
            cameraControl(systemName: "ellipsis") {
              withAnimation(.easeOut(duration: 0.18)) {
                showsMoreControls = true
              }
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
      }
    }
    .modifier(CameraCaptureControl(camera: camera, onPhotoCaptured: onPhotoCaptured))
    .onAppear { camera.start() }
    .onDisappear { camera.stop() }
  }

  private func cameraControl(
    systemName: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 48, height: 48)
        .background {
          PickerGlassBackground(
            shape: Circle(),
            tint: .black,
            opacity: 0.62
          )
        }
    }
    .buttonStyle(.plain)
  }
}

@available(iOS 17.0, *)
private final class InlineCameraController: NSObject, ObservableObject,
  AVCapturePhotoCaptureDelegate
{
  let session = AVCaptureSession()

  @Published private(set) var ready = false
  @Published private(set) var capturing = false
  @Published private(set) var permissionDenied = false
  @Published private(set) var unavailable = false
  private var isVisible = false
  @Published private(set) var flashEnabled = false

  private let sessionQueue = DispatchQueue(label: "fueliq.camera.session")
  private let photoOutput = AVCapturePhotoOutput()
  private var position: AVCaptureDevice.Position = .back
  private var completion: ((URL) -> Void)?

  func start() {
    isVisible = true
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureAndStart()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          guard let self, self.isVisible else { return }
          if granted {
            self.configureAndStart()
          } else {
            self.permissionDenied = true
          }
        }
      }
    default:
      permissionDenied = true
    }
  }

  func stop() {
    isVisible = false
    ready = false
    sessionQueue.async { [weak self] in
      guard let self, self.session.isRunning else { return }
      self.session.stopRunning()
    }
  }

  func toggleFlash() {
    flashEnabled.toggle()
  }

  func flipCamera() {
    position = position == .back ? .front : .back
    sessionQueue.async { [weak self] in
      guard let self else { return }
      self.session.beginConfiguration()
      self.replaceVideoInput()
      self.session.commitConfiguration()
    }
  }

  func capturePhoto(_ completion: @escaping (URL) -> Void) {
    guard ready, !capturing else { return }
    capturing = true
    self.completion = completion
    let settings = AVCapturePhotoSettings()
    if let device = currentVideoDevice, device.hasFlash {
      settings.flashMode = flashEnabled ? .on : .off
    }
    photoOutput.capturePhoto(with: settings, delegate: self)
  }

  private var currentVideoDevice: AVCaptureDevice? {
    (session.inputs.first as? AVCaptureDeviceInput)?.device
  }

  private func configureAndStart() {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      if self.session.inputs.isEmpty {
        self.session.beginConfiguration()
        self.session.sessionPreset = .photo
        self.replaceVideoInput()
        if self.session.canAddOutput(self.photoOutput) {
          self.session.addOutput(self.photoOutput)
        }
        self.session.commitConfiguration()
      }
      guard !self.session.inputs.isEmpty,
            self.session.outputs.contains(self.photoOutput) else {
        DispatchQueue.main.async { self.unavailable = true }
        return
      }
      if !self.session.isRunning { self.session.startRunning() }
      DispatchQueue.main.async { self.ready = self.isVisible }
    }
  }

  private func replaceVideoInput() {
    let oldInput = session.inputs.first as? AVCaptureDeviceInput
    if let oldInput { session.removeInput(oldInput) }
    guard
      let device = AVCaptureDevice.default(
        .builtInWideAngleCamera,
        for: .video,
        position: position
      ),
      let input = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else {
      if let oldInput, session.canAddInput(oldInput) { session.addInput(oldInput) }
      return
    }
    session.addInput(input)
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    guard error == nil, let data = photo.fileDataRepresentation() else {
      DispatchQueue.main.async { self.capturing = false }
      return
    }
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("fueliq-camera-\(UUID().uuidString).jpg")
    do {
      try data.write(to: url, options: .atomic)
      DispatchQueue.main.async {
        self.capturing = false
        let completion = self.completion
        self.completion = nil
        if self.isVisible, let completion {
          completion(url)
        } else {
          try? FileManager.default.removeItem(at: url)
        }
      }
    } catch {
      DispatchQueue.main.async { self.capturing = false }
    }
  }
}

@available(iOS 17.0, *)
private struct InlineCameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> CameraPreviewView {
    let view = CameraPreviewView()
    view.previewLayer.session = session
    view.previewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ uiView: CameraPreviewView, context: Context) {
    uiView.previewLayer.session = session
  }
}

@available(iOS 17.0, *)
private final class CameraPreviewView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }
}

@available(iOS 17.0, *)
private struct PickerGlassBackground<GlassShape: Shape>: View {
  let shape: GlassShape
  let tint: Color
  let opacity: Double

  var body: some View {
    shape
      .fill(.ultraThinMaterial)
      .overlay {
        shape.fill(tint.opacity(opacity))
      }
      .overlay {
        shape.stroke(.white.opacity(0.18), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.28), radius: 15, y: 7)
  }
}

@available(iOS 17.0, *)
private struct ImportedFuelPhoto: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .image) { received in
      let originalName = received.file.lastPathComponent.isEmpty
        ? "photo"
        : received.file.lastPathComponent
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("fueliq-photo-\(UUID().uuidString)-\(originalName)")
      try FileManager.default.copyItem(at: received.file, to: destination)
      return ImportedFuelPhoto(url: destination)
    }
  }
}

@available(iOS 17.0, *)
private struct CameraCaptureControl: ViewModifier {
  @ObservedObject var camera: InlineCameraController
  let onPhotoCaptured: (URL) -> Void

  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content.onCameraCaptureEvent(isEnabled: camera.ready && !camera.capturing) { event in
        guard event.phase == .ended else { return }
        camera.capturePhoto(onPhotoCaptured)
      }
    } else {
      content
    }
  }
}
