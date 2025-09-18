//  CaptureView.swift
//  SnapPic
//  Simple placeholder capture screen (simulator friendly)

import SwiftUI
import PhotosUI

struct CaptureView: View {
    let option: LayoutOption
    @State private var images: [UIImage?]
    @State private var currentIndex: Int = 0
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedFilter: FilterKind = .none

    init(option: LayoutOption) { self.option = option; _images = State(initialValue: Array(repeating: nil, count: option.poses)) }

    var body: some View {
        VStack(spacing: 0) {
            slots
                .padding(8)
                .frame(maxHeight: .infinity)
                .background(Color.black.opacity(0.9))
            controlBar
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.95).ignoresSafeArea())
        }
        .navigationTitle(option.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoPickerItem) { oldItem, newItem in
            guard let newItem else { return }
            Task { await loadPicked(newItem) }
        }
    }

    // Simple vertical slots list
    private var slots: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                ForEach(0..<option.poses, id: \.self) { idx in
                    ZStack {
                        if let img = images[idx] {
                            Image(uiImage: applyFilter(selectedFilter, to: img))
                                .resizable().scaledToFill().clipped()
                        } else if idx == currentIndex {
                            ZStack {
                                LinearGradient(colors: [.gray.opacity(0.25), .black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                VStack(spacing: 6) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("Slot \(idx+1)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Capture or Pick Photo")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.55))
                                }
                            }
                        } else {
                            Color.gray.opacity(0.18)
                            Text("Slot \(idx+1)")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.caption)
                        }
                    }
                    .frame(height: max(90, geo.size.height / CGFloat(option.poses) - 4))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { currentIndex = idx }
                }
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 22) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) { controlButton(icon: "photo.on.rectangle") }
            Button(action: simulateCapture) { controlButton(icon: "circle") }
                .disabled(currentIndex >= images.count)
            Menu {
                ForEach(FilterKind.allCases, id: \.self) { kind in
                    Button(kind.label) { selectedFilter = kind }
                }
            } label: { controlButton(icon: selectedFilter == .none ? "slider.horizontal.3" : "wand.and.stars") }
            Spacer()
            Button(action: advanceOrFinish) {
                Image(systemName: currentIndex + 1 >= images.count ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private func controlButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(.white)
            .frame(width: 54, height: 54)
            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func simulateCapture() { if currentIndex < images.count { images[currentIndex] = placeholder() } }
    private func advanceOrFinish() { currentIndex + 1 < images.count ? (currentIndex += 1) : print("Finished: \(images.compactMap { $0 }.count)/\(images.count)") }

    private func loadPicked(_ item: PhotosPickerItem) async {
        do { if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data), currentIndex < images.count { images[currentIndex] = ui } } catch { print("Pick error: \(error)") }
    }

    private func placeholder() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        return renderer.image { ctx in
            let colors: [UIColor] = [.systemBlue, .systemPink, .systemTeal, .systemOrange, .systemGreen, .systemPurple]
            (colors.randomElement() ?? .systemGray).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 82, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: paragraph]
            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 42, weight: .semibold), .foregroundColor: UIColor.white.withAlphaComponent(0.85), .paragraphStyle: paragraph]
            ("CAPTURE" as NSString).draw(in: CGRect(x: 0, y: size.height * 0.33 - 120, width: size.width, height: 200), withAttributes: attrs)
            (stamp as NSString).draw(in: CGRect(x: 0, y: size.height * 0.33 + 90, width: size.width, height: 100), withAttributes: subAttrs)
        }
    }

    private func applyFilter(_ kind: FilterKind, to image: UIImage) -> UIImage {
        guard kind != .none, let cg = image.cgImage else { return image }
        let overlay: UIColor = (kind == .warm ? .systemOrange : kind == .cool ? .systemTeal : .black)
        let size = CGSize(width: cg.width, height: cg.height)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation).draw(in: CGRect(origin: .zero, size: size))
            overlay.withAlphaComponent(kind == .mono ? 0.65 : 0.25).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            if kind == .mono { ctx.cgContext.setBlendMode(.luminosity) }
        }
    }

    enum FilterKind: CaseIterable { case none, warm, cool, mono; var label: String { switch self { case .none: return "None"; case .warm: return "Warm"; case .cool: return "Cool"; case .mono: return "Mono" } } }
}

#Preview { NavigationStack { CaptureView(option: .init(title: "Layout A", poses: 4, assetName: "Layout A")) } }
