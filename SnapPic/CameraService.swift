// filepath: /Users/student/Documents/snappic/SnapPic/SnapPic/CameraService.swift
//  CameraService.swift
//  SnapPic
//
//  Lightweight AVFoundation wrapper for preview and photo capture.

import Foundation
import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?

    // Simulator detection
    static var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    override init() { super.init() }

    func configure() {
        // If running in Simulator, skip real camera setup and mark session running.
        if Self.isSimulator {
            DispatchQueue.main.async { self.isSessionRunning = true }
            return
        }
        sessionQueue.async { [weak self] in
            self?._configure()
        }
    }

    private func _configure() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
            videoDeviceInput = nil
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            session.commitConfiguration()
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input); videoDeviceInput = input }
        } catch {
            print("Camera input error: \(error)")
        }

        // Output
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if #unavailable(iOS 16.0) {
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        session.commitConfiguration()
        start()
    }

    func start() {
        if Self.isSimulator {
            // Already marked running in configure
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stop() {
        if Self.isSimulator { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode = .off, completion: @escaping (UIImage?) -> Void) {
        if Self.isSimulator {
            // Generate a placeholder image to emulate capture.
            let image = Self.generatePlaceholder()
            completion(image)
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        if #unavailable(iOS 16.0) {
            settings.isHighResolutionPhotoEnabled = true
        }
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate { image in
            DispatchQueue.main.async { completion(image) }
        })
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
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraph
            ]
            let text = "SIM CAPTURE"
            let rect = CGRect(x: 0, y: size.height * 0.33 - 120, width: size.width, height: 200)
            text.draw(in: rect, withAttributes: attrs)
            let sub = stamp
            let subRect = CGRect(x: 0, y: rect.maxY + 10, width: size.width, height: 120)
            sub.draw(in: subRect, withAttributes: subtitleAttrs)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { print("Photo capture error: \(error)") }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(nil); return
        }
        completion(image)
    }
}

import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView { PreviewUIView() }
    func updateUIView(_ uiView: PreviewUIView, context: Context) { uiView.session = session }

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
