//  PhotoStripEditorView.swift
//  SnapPic
//  Preview and edit the composed photo strip, then export/share.

import SwiftUI
import PhotosUI
import Photos
import UIKit

struct PhotoStripEditorView: View {
    let option: LayoutOption
    let images: [UIImage]

    @State private var borderColor: Color = .white
    @State private var backgroundColor: Color = Color(white: 0.98)
    @State private var spacing: CGFloat = 22
    @State private var cornerRadius: CGFloat = 14
    @State private var shadow: Bool = false
    @State private var showBorderPicker = false
    @State private var pendingBorderColor: Color = .white
    @State private var stickerStyle: StickerStyle = .none
    @State private var showStickerPicker = false

    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var shareSheetState: ShareSheetState = .idle
    @State private var sharePayload: QRSharePayload?
    @State private var shareError: String?
    @State private var isShareSheetPresented = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Photo Strip Preview").font(.title2).bold()
                    Text("Layout: \(option.title) (\(option.poses) photos)")
                        .font(.footnote).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.blue.opacity(0.18), in: Capsule())
                    stripPreview
                        .padding(16)
                        .background(borderColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .padding(12)
                        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.horizontal)
                        .shadow(radius: shadow ? 10 : 0)
                }
                .padding(.vertical)
            }
            toolbar
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBorderPicker) {
            borderPickerSheet
        }
        .sheet(isPresented: $showStickerPicker) {
            stickerPickerSheet
        }
        .sheet(isPresented: $isShareSheetPresented) {
            QRShareSheet(state: $shareSheetState, payload: sharePayload, errorMessage: $shareError) {
                isShareSheetPresented = false
            } retryAction: {
                Task { await startShareFlow() }
            }
        }
        .alert("Save to Photos", isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveMessage)
        }
    }

    // MARK: - Preview
    private var stripPreview: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width - 32)
            VStack {
                composedStripView(width: width)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: previewHeight(for: max(1, UIScreen.main.bounds.width - 64)))
    }

    private func composedStripView(width: CGFloat) -> some View {
        let columnCount = option.title == "Layout D" || option.assetName == "Layout D" ? 2 : 1
        let rows = Int(ceil(Double(images.count) / Double(columnCount)))
        let itemAspect: CGFloat = 3/2
        let safeWidth = max(1, width)
        let itemHeight = (safeWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount) / itemAspect

        let strip = VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { c in
                        let idx = r * columnCount + c
                        if idx < images.count {
                            Image(uiImage: images[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: (safeWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount), height: max(1, itemHeight))
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }

        return strip
            .overlay(alignment: .center) {
                StickerOverlayCanvas(style: stickerStyle)
            }
    }

    private func previewHeight(for width: CGFloat) -> CGFloat {
        let columnCount = option.title == "Layout D" || option.assetName == "Layout D" ? 2 : 1
        let rows = Int(ceil(Double(images.count) / Double(columnCount)))
        let contentWidth = max(1, width - 32)
        let itemAspect: CGFloat = 3/2
        let itemWidth = (contentWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount)
        let itemHeight = itemWidth / itemAspect
        let base = CGFloat(rows) * itemHeight + CGFloat(max(0, rows - 1)) * spacing + 32
        return max(120, base.isFinite ? base : 240)
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        GeometryReader { geo in
            let count: CGFloat = 5
            let tileSpacing: CGFloat = 10
            let contentWidth = max(1, geo.size.width)
            let tileWidth = max(60, (contentWidth - tileSpacing * (count - 1)) / count)
            HStack(spacing: tileSpacing) {
                // Border (use asset image)
                Button {
                    pendingBorderColor = borderColor
                    showBorderPicker = true
                } label: { toolbarButton(title: "Border", assetName: "border_color_icon", width: tileWidth) }

                // Style (use asset image)
                Menu {
                    Button("Tighter") { spacing = max(6, spacing - 6) }
                    Button("Looser") { spacing = min(40, spacing + 6) }
                    Divider()
                    Button("Rounder") { cornerRadius = min(28, cornerRadius + 4) }
                    Button("Sharper") { cornerRadius = max(0, cornerRadius - 4) }
                    Toggle("Shadow", isOn: $shadow)
                    Divider()
                    backgroundColorButton(Palette.white, label: "BG • White")
                    backgroundColorButton(Palette.paper, label: "BG • Paper")
                    backgroundColorButton(Palette.black, label: "BG • Black")
                    backgroundColorButton(Palette.sunset, label: "BG • Sunset")
                    Divider()
                    Button("Sticker Overlay") { showStickerPicker = true }
                } label: { toolbarButton(title: "Style", assetName: "style_button_icon", width: tileWidth) }

                // Share (use asset image)
                Button { Task { await startShareFlow() } } label: { toolbarButton(title: "Share", assetName: "qr_code_icon", width: tileWidth) }

                // New photo (keep SF Symbol)
                Button { dismiss() } label: { toolbarButton(title: "New photo", system: "camera", width: tileWidth) }

                // Save (keep SF Symbol)
                Button { Task { await saveToPhotosAsync() } } label: { toolbarButton(title: "Save", system: "square.and.arrow.down.fill", width: tileWidth) }
            }
        }
        .frame(height: 62)
    }

    private func toolbarButton(title: String, system: String, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: system).font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .foregroundStyle(.primary)
        .frame(width: width, height: 52)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func toolbarButton(title: String, assetName: String, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(height: 18)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
        .foregroundStyle(.primary)
        .frame(width: width, height: 52)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func backgroundColorButton(_ color: Color, label: String) -> some View {
        Button(label) { backgroundColor = color }
    }

    // MARK: - Export / Share / Save
    private func renderStripImage(scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: stripRenderContent)
        renderer.scale = scale
        return renderer.uiImage
    }

    private let qrShareService: QRShareServicing = QRShareService()

    private func startShareFlow() async {
        await MainActor.run {
            shareSheetState = .preparing
            shareError = nil
            isShareSheetPresented = true
        }

        let renderer = ImageRenderer(content: stripRenderContent)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else {
            await MainActor.run {
                shareSheetState = .error
                shareError = "Unable to render the photo strip."
            }
            return
        }

        do {
            let payload = try await qrShareService.createShare(for: uiImage)
            await MainActor.run {
                sharePayload = payload
                shareSheetState = .ready
            }
        } catch {
            await MainActor.run {
                shareSheetState = .error
                shareError = error.localizedDescription
            }
        }
    }

    private func saveToPhotosAsync() async {
        guard let ui = renderStripImage() else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            await MainActor.run {
                saveMessage = "Photos access denied. Enable in Settings to save."
                showSaveAlert = true
            }
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: ui)
            }
            await MainActor.run {
                saveMessage = "Saved to Photos."
                showSaveAlert = true
            }
        } catch {
            await MainActor.run {
                saveMessage = "Save failed: \(error.localizedDescription)"
                showSaveAlert = true
            }
        }
    }

    private var stripRenderContent: some View {
        VStack { composedStripView(width: 1200).padding(16).background(backgroundColor) }
            .frame(maxWidth: .infinity, alignment: .center)
            .background(backgroundColor)
    }
}

private extension PhotoStripEditorView {
    var borderPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ColorPicker("Border Color", selection: $pendingBorderColor, supportsOpacity: false)
                    .padding()
                Spacer()
            }
            .navigationTitle("Border")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showBorderPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        borderColor = pendingBorderColor
                        showBorderPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    var stickerPickerSheet: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            StickerPickerPanel(selection: $stickerStyle) {
                showStickerPicker = false
            }
        }
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.hidden)
    }
}

private struct StickerPickerPanel: View {
    @Binding var selection: StickerStyle
    let dismiss: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Sticker Overlay")
                    .font(.title3)
                    .bold()
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.05), in: Circle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(StickerStyle.allCases) { style in
                    StickerOptionButton(style: style, isSelected: selection == style) {
                        selection = style
                        dismiss()
                    }
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 32)
    }
}

private struct StickerOptionButton: View {
    let style: StickerStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(style.title)
                .font(.headline)
                .foregroundStyle(style.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(style.buttonGradient)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.black.opacity(0.25) : Color.white.opacity(0.7), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: isSelected ? 10 : 5, x: 0, y: isSelected ? 6 : 3)
        }
        .buttonStyle(.plain)
    }
}

private struct StickerOverlayCanvas: View {
    let style: StickerStyle

    var body: some View {
        if style.hasStickers {
            GeometryReader { geo in
                ForEach(style.stickerSpecs) { spec in
                    Image(spec.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * spec.widthFactor)
                        .rotationEffect(.degrees(spec.rotation))
                        .opacity(spec.opacity)
                        .position(x: geo.size.width * spec.position.x, y: geo.size.height * spec.position.y)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 6)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct StickerSpec: Identifiable {
    let id = UUID()
    let imageName: String
    let position: CGPoint
    let widthFactor: CGFloat
    let rotation: Double
    let opacity: Double

    init(imageName: String, position: CGPoint, widthFactor: CGFloat, rotation: Double = 0, opacity: Double = 1) {
        self.imageName = imageName
        self.position = position
        self.widthFactor = widthFactor
        self.rotation = rotation
        self.opacity = opacity
    }
}

private enum StickerStyle: String, CaseIterable, Identifiable {
    case none
    case miffy
    case mofussand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Remove Stickers"
        case .miffy: return "Miffy"
        case .mofussand: return "Mofussand"
        }
    }

    var titleColor: Color {
        switch self {
        case .none: return .primary
        default: return .black
        }
    }

    var buttonGradient: LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [Color.white, Color(white: 0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .miffy:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.8, blue: 0.9), Color(red: 1.0, green: 0.64, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mofussand:
            return LinearGradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.72), Color(red: 1.0, green: 0.86, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var stickerSpecs: [StickerSpec] {
        switch self {
        case .none:
            return []
        case .miffy:
            return [
                StickerSpec(imageName: "bunny1", position: CGPoint(x: 0.1, y: 0.1), widthFactor: 0.22, rotation: -6),
                StickerSpec(imageName: "bunny2", position: CGPoint(x: 0.9, y: 0.9), widthFactor: 0.2, rotation: 4)
            ]
        case .mofussand:
            return [
                StickerSpec(imageName: "cat1", position: CGPoint(x: 0.1, y: 0.1), widthFactor: 0.24, rotation: -8),
                StickerSpec(imageName: "cat2", position: CGPoint(x: 0.9, y: 0.9), widthFactor: 0.22, rotation: 5)
            ]
        }
    }

    var hasStickers: Bool { !stickerSpecs.isEmpty }
}

private enum ShareSheetState {
    case idle
    case preparing
    case ready
    case error
}

private struct QRShareSheet: View {
    @Binding var state: ShareSheetState
    let payload: QRSharePayload?
    @Binding var errorMessage: String?
    let dismissAction: () -> Void
    let retryAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Text("QR Code Overlay")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Button(action: dismissAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                content
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 32)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .preparing:
            VStack(spacing: 16) {
                ProgressView()
                Text("Preparing your photo...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        case .ready:
            if let payload {
                VStack(spacing: 20) {
                    Text("Scan this code to view and download your photo!")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    if let qrImage = QRCodeImageGenerator.makeImage(from: payload.url.absoluteString, scale: 8) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    Text("Code ID: \(payload.id.uuidString.prefix(8))…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        case .error:
            VStack(spacing: 16) {
                Text("Something went wrong")
                    .font(.headline)
                Text(errorMessage ?? "Unknown error")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        case .idle:
            EmptyView()
        }
    }
}

private enum Palette {
    static let white = Color(white: 0.97)
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.89)
    static let black = Color(red: 0.1, green: 0.1, blue: 0.12)
    static let sunset = ColorGradient.colors([Color(red: 1.0, green: 0.82, blue: 0.72), Color(red: 0.89, green: 0.74, blue: 0.98)])
}

private enum ColorGradient {
    static func colors(_ colors: [Color]) -> Color {
        let image = UIImage.gradientImage(colors: colors, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 1, y: 1), size: CGSize(width: 8, height: 8))
        return Color(uiColor: UIColor(patternImage: image))
    }
}

private extension UIImage {
    static func gradientImage(colors: [Color], startPoint: CGPoint, endPoint: CGPoint, size: CGSize) -> UIImage {
        let cgColors = colors.map { UIColor($0).cgColor } as CFArray
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else { return }
            let start = CGPoint(x: startPoint.x * size.width, y: startPoint.y * size.height)
            let finish = CGPoint(x: endPoint.x * size.width, y: endPoint.y * size.height)
            ctx.cgContext.drawLinearGradient(gradient, start: start, end: finish, options: [])
        }
    }
}

#Preview {
    let imgs = ["Layout A", "Layout B", "Layout C", "Layout D"].compactMap { UIImage(named: $0) }
    NavigationStack { PhotoStripEditorView(option: .init(title: "Layout A", poses: 4, assetName: "Layout A"), images: imgs) }
}
