//  PhotoStripEditorView.swift
//  SnapPic
//  Preview and edit the composed photo strip, then export/share.

import SwiftUI
import PhotosUI
import Photos

struct PhotoStripEditorView: View {
    let option: LayoutOption
    let images: [UIImage]

    @State private var borderColor: Color = .white
    @State private var backgroundColor: Color = Color(white: 0.98)
    @State private var spacing: CGFloat = 22
    @State private var cornerRadius: CGFloat = 14
    @State private var shadow: Bool = false

    @State private var isSharing = false
    @State private var exportImage: UIImage?
    @State private var showSaveAlert = false
    @State private var saveMessage = ""

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
                        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .sheet(isPresented: $isSharing) {
            if let img = exportImage { ShareSheet(activityItems: [img]) }
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

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { c in
                        let idx = r * columnCount + c
                        if idx < images.count {
                            Image(uiImage: images[idx])
                                .resizable()
                                .scaledToFill()
                                .frame(width: (safeWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount), height: max(1, itemHeight))
                                .clipped()
                                .background(borderColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
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
                // Border
                Menu {
                    colorPickerButton(.white, label: "White")
                    colorPickerButton(.black, label: "Black")
                    colorPickerButton(.gray.opacity(0.3), label: "Gray")
                    colorPickerButton(.blue.opacity(0.25), label: "Blue")
                    colorPickerButton(.pink.opacity(0.25), label: "Pink")
                } label: { toolbarButton(title: "Border", system: "circle.lefthalf.filled", width: tileWidth) }

                // Style
                Menu {
                    Button("Tighter") { spacing = max(6, spacing - 6) }
                    Button("Looser") { spacing = min(40, spacing + 6) }
                    Divider()
                    Button("Rounder") { cornerRadius = min(28, cornerRadius + 4) }
                    Button("Sharper") { cornerRadius = max(0, cornerRadius - 4) }
                    Toggle("Shadow", isOn: $shadow)
                    Divider()
                    backgroundColorButton(.white, label: "BG • White")
                    backgroundColorButton(Color(white: 0.98), label: "BG • Paper")
                    backgroundColorButton(.black, label: "BG • Black")
                    backgroundColorButton(LinearGradient(gradient: Gradient(colors: [.pink.opacity(0.2), .blue.opacity(0.2)]), startPoint: .top, endPoint: .bottom).resolvedColor, label: "BG • Sunset")
                } label: { toolbarButton(title: "Style", system: "slider.horizontal.3", width: tileWidth) }

                // Share
                Button { share() } label: { toolbarButton(title: "Share", system: "square.and.arrow.up", width: tileWidth) }

                // New photo
                Button { dismiss() } label: { toolbarButton(title: "New photo", system: "camera", width: tileWidth) }

                // Save
                Button { saveToPhotos() } label: { toolbarButton(title: "Save", system: "square.and.arrow.down.fill", width: tileWidth) }
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

    private func colorPickerButton(_ color: Color, label: String) -> some View {
        Button(label) { borderColor = color }
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

    private func share() {
        if let ui = renderStripImage() { self.exportImage = ui; self.isSharing = true }
    }

    private func saveToPhotos() {
        guard let ui = renderStripImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: ui)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success { self.saveMessage = "Saved to Photos." } else { self.saveMessage = "Save failed: \(error?.localizedDescription ?? "Unknown error")" }
                        self.showSaveAlert = true
                    }
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.saveMessage = "Photos access denied. Enable in Settings to save."
                    self.showSaveAlert = true
                }
            case .notDetermined:
                DispatchQueue.main.async {
                    self.saveMessage = "Photos permission not determined. Try again."
                    self.showSaveAlert = true
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.saveMessage = "Unable to save due to unknown permission status."
                    self.showSaveAlert = true
                }
            }
        }
    }

    private var stripRenderContent: some View {
        VStack { composedStripView(width: 1200).padding(16).background(backgroundColor) }
            .frame(maxWidth: .infinity, alignment: .center)
            .background(backgroundColor)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension LinearGradient {
    var resolvedColor: Color {
        let img = UIImage.gradientImage(with: self, size: CGSize(width: 4, height: 4))
        return Color(uiColor: UIColor(patternImage: img))
    }
}

private extension UIImage {
    static func gradientImage(with gradient: LinearGradient, size: CGSize) -> UIImage {
        let hosting = UIHostingController(rootView: gradient)
        hosting.view.bounds = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
    }
}

#Preview {
    let imgs = ["Layout A", "Layout B", "Layout C", "Layout D"].compactMap { UIImage(named: $0) }
    NavigationStack { PhotoStripEditorView(option: .init(title: "Layout A", poses: 4, assetName: "Layout A"), images: imgs) }
}
