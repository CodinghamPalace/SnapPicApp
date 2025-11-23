import Foundation
import UIKit

struct QRSharePayload {
    let url: URL
    let createdAt: Date
    let id: UUID
}

enum QRShareServiceError: LocalizedError {
    case imageEncodingFailed
    case qrGenerationFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Unable to prepare image data."
        case .qrGenerationFailed:
            return "Unable to generate QR code for the share link."
        }
    }
}

protocol QRShareServicing {
    func createShare(for image: UIImage) async throws -> QRSharePayload
}

struct QRShareService: QRShareServicing {
    func createShare(for image: UIImage) async throws -> QRSharePayload {
        let id = UUID()
        guard image.pngData() != nil else { throw QRShareServiceError.imageEncodingFailed }
        let hostedURL = URL(string: "https://snap.pic/share/\(id.uuidString)")!
        return QRSharePayload(url: hostedURL, createdAt: Date(), id: id)
    }
}

enum QRCodeImageGenerator {
    static func makeImage(from string: String, scale: CGFloat = 10) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
