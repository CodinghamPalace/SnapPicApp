//  CameraService.swift
//  SnapPic
//
//  AVFoundation camera wrapper for live preview + photo capture with reliable delegate retention.

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import CoreImage
import MetalKit

final class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var activePosition: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoDelegate: VideoOutputDelegate?
    // Latest live frame callback (CIImage in camera orientation space)
    var frameHandler: ((CIImage, CMTime) -> Void)?

    // Retain delegates until completion to avoid premature deallocation
    private var inFlightPhotoDelegates: [PhotoCaptureDelegate] = []

    // Simulator detection
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var isFront: Bool { activePosition == .front }

    override init() {
        super.init()
    }

    // MARK: - Lifecycle
    func configure() {
        if Self.isSimulator {
            DispatchQueue.main.async { self.isSessionRunning = true }
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.configure() } else { DispatchQueue.main.async { self.isSessionRunning = false } }
            }
            return
        case .denied, .restricted:
            DispatchQueue.main.async { self.isSessionRunning = false }
            return
        case .authorized:
            break
        @unknown default:
            return
        }
        sessionQueue.async { [weak self] in self?._configure() }
    }

    private func _configure() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        if let input = videoDeviceInput { session.removeInput(input) }
        let position = activePosition
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) ??
                     AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        if let device {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input); videoDeviceInput = input }
            } catch {
                print("Camera input error: \(error)")
            }
        }

        // Photo output
        if session.canAddOutput(photoOutput) && !session.outputs.contains(photoOutput) { session.addOutput(photoOutput) }
        if #unavailable(iOS 16.0) { photoOutput.isHighResolutionCaptureEnabled = true }

        // Video data output for live preview processing
        if !session.outputs.contains(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        }
        let vDelegate = VideoOutputDelegate { [weak self] image, time in
            guard let self else { return }
            self.frameHandler?(image, time)
        }
        videoDelegate = vDelegate
        videoOutput.setSampleBufferDelegate(vDelegate, queue: videoOutputQueue)
        if let conn = videoOutput.connection(with: .video), let vo = Self.currentVideoOrientation() {
            conn.videoOrientation = vo
            conn.isVideoMirrored = (activePosition == .front)
        }

        session.commitConfiguration()
        start()
    }

    func switchCamera() {
        guard !Self.isSimulator else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.activePosition = (self.activePosition == .back) ? .front : .back
            self._configure()
        }
    }

    func start() {
        guard !Self.isSimulator else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stop() {
        guard !Self.isSimulator else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    // MARK: - Capture
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode = .off, completion: @escaping (UIImage?) -> Void) {
        if Self.isSimulator {
            completion(Self.generatePlaceholder())
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        if #unavailable(iOS 16.0) { settings.isHighResolutionPhotoEnabled = true }
        if let conn = photoOutput.connection(with: .video), let vo = Self.currentVideoOrientation() { conn.videoOrientation = vo }
        let delegate = PhotoCaptureDelegate { [weak self] del, image in
            DispatchQueue.main.async { completion(image) }
            self?.removeInFlightDelegate(del)
        }
        addInFlightDelegate(delegate)
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func addInFlightDelegate(_ delegate: PhotoCaptureDelegate) { inFlightPhotoDelegates.append(delegate) }
    private func removeInFlightDelegate(_ delegate: PhotoCaptureDelegate) { inFlightPhotoDelegates.removeAll { $0 === delegate } }

    // MARK: - Helpers
    private static func currentVideoOrientation() -> AVCaptureVideoOrientation? {
        var orientation: UIInterfaceOrientation? = nil
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene { orientation = scene.interfaceOrientation }
        switch orientation ?? .portrait {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        @unknown default: return .portrait
        }
    }

    private static func generatePlaceholder() -> UIImage? {
        let size = CGSize(width: 1080, height: 1440)
        let renderer = UIGraphicsImageRenderer(size: size)
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let colors: [UIColor] = [.systemBlue, .systemTeal, .systemPink, .systemOrange, .systemGreen, .systemPurple]
        let bg = colors.randomElement() ?? .systemGray
        return renderer.image { ctx in
            bg.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraph
            ]
            ("SIM CAPTURE" as NSString).draw(in: CGRect(x: 0, y: size.height * 0.33 - 120, width: size.width, height: 200), withAttributes: titleAttrs)
            (stamp as NSString).draw(in: CGRect(x: 0, y: size.height * 0.33 + 10, width: size.width, height: 140), withAttributes: subAttrs)
        }
    }
}

// MARK: - Capture delegate retained until completion
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onComplete: (PhotoCaptureDelegate, UIImage?) -> Void
    init(onComplete: @escaping (PhotoCaptureDelegate, UIImage?) -> Void) { self.onComplete = onComplete }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print("Photo capture error: \(error)") }
        let image: UIImage?
        if let data = photo.fileDataRepresentation() { image = UIImage(data: data) } else { image = nil }
        onComplete(self, image)
    }
}

// MARK: - Video output delegate
private final class VideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let handler: (CIImage, CMTime) -> Void
    init(handler: @escaping (CIImage, CMTime) -> Void) { self.handler = handler }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ci = CIImage(cvPixelBuffer: pb)
        handler(ci, time)
    }
}

// (frameHandler stored directly on CameraService)

// MARK: - SwiftUI Preview layer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var mirror: Bool = false

    func makeUIView(context: Context) -> PreviewUIView { PreviewUIView() }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.session = session
        if let conn = uiView.previewLayer.connection {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = mirror
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var session: AVCaptureSession? {
            get { previewLayer.session }
            set {
                previewLayer.session = newValue
                previewLayer.videoGravity = .resizeAspectFill
            }
        }
    }
}

// MARK: - Live filtered preview using MTKView + Core Image
struct LiveFilteredCameraView: UIViewRepresentable {
    let camera: CameraService
    var filter: (CIImage) -> CIImage

    func makeUIView(context: Context) -> MTKCIView {
        let view = MTKCIView()
        view.setup()
        // Subscribe to frames
        camera.frameHandler = { [weak view] ci, _ in
            view?.enqueue(ci)
        }
        return view
    }

    func updateUIView(_ uiView: MTKCIView, context: Context) {
        uiView.filter = filter
        uiView.isMirrored = camera.isFront
    }

    final class MTKCIView: MTKView {
        private(set) var ciContext: CIContext!
        var latestImage: CIImage?
        var filter: (CIImage) -> CIImage = { $0 }
        var isMirrored: Bool = false

        func setup() {
            device = MTLCreateSystemDefaultDevice()
            framebufferOnly = false
            enableSetNeedsDisplay = false
            isPaused = true
            colorPixelFormat = .bgra8Unorm
            ciContext = CIContext(mtlDevice: device!)
            preferredFramesPerSecond = 60
        }

        func enqueue(_ image: CIImage) {
            latestImage = image
            setNeedsDisplay()
        }

        override func draw(_ rect: CGRect) {
            guard let currentDrawable = currentDrawable, let image = latestImage else { return }
            var output = filter(image)
            // Aspect fill to view size
            let viewSize = drawableSize
            let scale = max(viewSize.width / output.extent.width, viewSize.height / output.extent.height)
            let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            var x = (viewSize.width - scaled.extent.width) / 2
            var y = (viewSize.height - scaled.extent.height) / 2
            var renderImage = scaled
            if isMirrored {
                renderImage = renderImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1)).transformed(by: CGAffineTransform(translationX: renderImage.extent.width, y: 0))
            }
            let dest = CIRenderDestination(width: Int(viewSize.width), height: Int(viewSize.height), pixelFormat: colorPixelFormat, commandBuffer: nil, mtlTexture: currentDrawable.texture, options: nil)
            do {
                try ciContext.startTask(toRender: renderImage, from: CGRect(x: -x, y: -y, width: viewSize.width, height: viewSize.height), to: dest)
            } catch {
                // Fallback basic render
                ciContext.render(renderImage, to: currentDrawable.texture, commandBuffer: nil, bounds: CGRect(x: -x, y: -y, width: viewSize.width, height: viewSize.height), colorSpace: CGColorSpaceCreateDeviceRGB())
            }
            currentDrawable.present()
        }
    }
}
