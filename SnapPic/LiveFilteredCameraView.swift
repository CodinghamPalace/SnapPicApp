import SwiftUI
import AVFoundation
import CoreImage
import MetalKit
import ImageIO

struct LiveFilteredCameraView: UIViewRepresentable {
    @ObservedObject var camera: CameraService
    var filter: (CIImage) -> CIImage

    func makeCoordinator() -> Coordinator { Coordinator(camera: camera) }

    func makeUIView(context: Context) -> MTKCIView {
        let view = MTKCIView()
        view.configure()
        view.filter = filter
        view.isMirrored = camera.isFront
        camera.frameHandler = { [weak view] image, _ in view?.enqueue(image) }
        return view
    }

    func updateUIView(_ uiView: MTKCIView, context: Context) {
        uiView.filter = filter
        uiView.isMirrored = camera.isFront
        camera.frameHandler = { [weak uiView] image, _ in uiView?.enqueue(image) }
    }

    static func dismantleUIView(_ uiView: MTKCIView, coordinator: Coordinator) {
        coordinator.camera?.frameHandler = nil
        uiView.teardown()
    }

    final class Coordinator {
        weak var camera: CameraService?
        init(camera: CameraService) { self.camera = camera }
    }

    final class MTKCIView: MTKView {
        private(set) var ciContext: CIContext!
        private var colorSpace = CGColorSpaceCreateDeviceRGB()
        var latestImage: CIImage?
        var filter: (CIImage) -> CIImage = { $0 }
        var isMirrored: Bool = false

        func configure() {
            device = MTLCreateSystemDefaultDevice()
            framebufferOnly = false
            enableSetNeedsDisplay = true
            isPaused = false
            colorPixelFormat = .bgra8Unorm
            if let device { ciContext = CIContext(mtlDevice: device) }
            preferredFramesPerSecond = 60
            isPaused = false
        }

        func enqueue(_ image: CIImage) {
            latestImage = image
            DispatchQueue.main.async { [weak self] in self?.draw() }
        }

        func teardown() {
            latestImage = nil
        }

        override func draw(_ rect: CGRect) {
            guard let drawable = currentDrawable, let baseImage = latestImage, let ciContext else { return }

            var output = filter(baseImage)
            if isMirrored {
                output = output.oriented(.upMirrored)
            }

            let viewSize = drawableSize
            let viewWidth = CGFloat(viewSize.width)
            let viewHeight = CGFloat(viewSize.height)
            guard viewWidth > 0, viewHeight > 0 else { return }

            let scale = max(viewWidth / output.extent.width, viewHeight / output.extent.height)
            let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let dx = -scaled.extent.origin.x - (scaled.extent.width - viewWidth) / 2
            let dy = -scaled.extent.origin.y - (scaled.extent.height - viewHeight) / 2
            let centered = scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))

            let bounds = CGRect(origin: .zero, size: CGSize(width: viewWidth, height: viewHeight))
            ciContext.render(centered, to: drawable.texture, commandBuffer: nil, bounds: bounds, colorSpace: colorSpace)
            drawable.present()
        }
    }
}
