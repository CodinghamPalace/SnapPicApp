//
//  CaptureView.swift
//  SnapPic
//

import SwiftUI
import PhotosUI

struct CaptureView: View {
    let option: LayoutOption
    @State private var images: [UIImage?]
    @State private var currentIndex: Int = 0
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedFilter: FilterKind = .none
    @State private var goToEditor = false
    @State private var showIncompleteAlert = false
    @StateObject private var camera = CameraService()
    @State private var isCountingDown = false
    @State private var countdown = 5
    @State private var isCapturing = false
    @State private var countdownTask: Task<Void, Never>? = nil

    init(option: LayoutOption) {
        self.option = option
        _images = State(initialValue: Array(repeating: nil, count: option.poses))
    }

    private var isLayoutDGrid: Bool {
        option.title == "Layout D" || option.assetName == "Layout D"
    }

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
        .onAppear { camera.configure() }
        .onDisappear { cancelCountdown(); camera.stop() }
        .onChange(of: photoPickerItem) { oldItem, newItem in
            guard let newItem else { return }
            Task { await loadPicked(newItem) }
        }
        .navigationDestination(isPresented: $goToEditor) {
            PhotoStripEditorView(option: option, images: images.compactMap { $0 })
        }
        .alert("Fill all slots", isPresented: $showIncompleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please capture or pick a photo for each slot before proceeding.")
        }
    }

    private var slots: some View {
        GeometryReader { geo in
            Group {
                if isLayoutDGrid {
                    let rows: CGFloat = 3
                    let spacing: CGFloat = 6
                    let totalRowSpacing = spacing * (rows - 1)
                    let cellHeight = max(90, (geo.size.height - totalRowSpacing) / rows)
                    let columns = [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)]
                    LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                        ForEach(0..<images.count, id: \.self) { idx in
                            slotView(idx)
                                .frame(height: cellHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture { currentIndex = idx }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(0..<images.count, id: \.self) { idx in
                            slotView(idx)
                                .frame(height: max(90, geo.size.height / CGFloat(images.count) - 4))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture { currentIndex = idx }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func slotView(_ idx: Int) -> some View {
        ZStack {
            if let img = images[idx] {
                Image(uiImage: applyFilter(selectedFilter, to: img))
                    .resizable().scaledToFill().clipped()
            } else if idx == currentIndex {
                CameraPreviewView(session: camera.session, mirror: camera.isFront)
                    .overlay {
                        if isCountingDown {
                            ZStack {
                                Color.black.opacity(0.25)
                                Text("\(countdown)")
                                    .font(.system(size: 64, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 6)
                            }
                            .transition(.opacity)
                        }
                    }
            } else {
                Color.gray.opacity(0.18)
                Text("Slot \(idx+1)")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.caption)
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 22) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                controlButton(icon: "photo.on.rectangle")
            }

            Button(action: startCountdownSequence) {
                controlButton(icon: isCountingDown || isCapturing ? "hourglass" : "circle")
            }
            .disabled(currentIndex >= images.count || isCountingDown || isCapturing)

            Button(action: { camera.switchCamera() }) {
                controlButton(icon: "arrow.triangle.2.circlepath.camera")
            }
            .disabled(isCountingDown || isCapturing)

            Menu {
                ForEach(FilterKind.allCases, id: \.self) { kind in
                    Button(kind.label) { selectedFilter = kind }
                }
            } label: {
                controlButton(icon: selectedFilter == .none ? "slider.horizontal.3" : "wand.and.stars")
            }

            Spacer()

            Button(action: advanceOrFinish) {
                Image(systemName: currentIndex + 1 >= images.count ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
            .disabled(isCountingDown || isCapturing)
        }
    }

    private func startCountdownSequence() {
        guard !isCountingDown, !isCapturing, currentIndex < images.count else { return }
        runCountdownThenCapture(then: {
            autoContinueIfNeeded()
        })
    }

    private func runCountdownThenCapture(then completion: @escaping () -> Void) {
        isCountingDown = true
        countdown = 5
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            for t in stride(from: 5, through: 1, by: -1) {
                countdown = t
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            isCountingDown = false
            isCapturing = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            camera.capturePhoto { image in
                if let image { images[currentIndex] = image }
                isCapturing = false
                completion()
            }
        }
    }

    private func autoContinueIfNeeded() {
        if currentIndex + 1 < images.count {
            currentIndex += 1
            while currentIndex < images.count, images[currentIndex] != nil {
                currentIndex += 1
            }
            if currentIndex < images.count {
                runCountdownThenCapture(then: { autoContinueIfNeeded() })
            } else {
                goToEditor = true
            }
        } else {
            if !images.contains(where: { $0 == nil }) {
                goToEditor = true
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data),
               currentIndex < images.count {
                images[currentIndex] = ui
            }
        } catch {
            print("Pick error: \(error)")
        }
    }

    private func applyFilter(_ kind: FilterKind, to image: UIImage) -> UIImage {
        guard kind != .none, let cg = image.cgImage else { return image }
        let overlay: UIColor = (kind == .warm ? .systemOrange : kind == .cool ? .systemTeal : .black)
        let size = CGSize(width: cg.width, height: cg.height)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
                .draw(in: CGRect(origin: .zero, size: size))
            overlay.withAlphaComponent(kind == .mono ? 0.65 : 0.25).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            if kind == .mono { ctx.cgContext.setBlendMode(.luminosity) }
        }
    }

    // MARK: - Missing Additions

    @ViewBuilder
    private func controlButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
    }

    private func advanceOrFinish() {
        if images.contains(where: { $0 == nil }) {
            showIncompleteAlert = true
        } else {
            goToEditor = true
        }
    }

    enum FilterKind: CaseIterable {
        case none, warm, cool, mono

        var label: String {
            switch self {
                case .none: return "None"
                case .warm: return "Warm"
                case .cool: return "Cool"
                case .mono: return "Mono"
            }
        }
    }
}

#Preview {
    NavigationStack {
        CaptureView(option: .init(title: "Layout A", poses: 4, assetName: "Layout A"))
    }
}

