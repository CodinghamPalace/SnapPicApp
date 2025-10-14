import SwiftUI
import AVFoundation
import CoreImage

struct LiveFilteredCameraView: UIViewRepresentable {
    @ObservedObject var camera: CameraService
    let filter: (CIImage) -> CIImage

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        camera.previewLayer.frame = view.bounds
        camera.previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        camera.previewLayer.frame = uiView.bounds
        // If you want, apply live filter here. This requires more code for live filtering,
        // but for now, just showing camera feed is fine.
    }
}
