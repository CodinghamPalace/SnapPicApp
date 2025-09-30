//
//  CaptureView.swift
//  SnapPic
//

import SwiftUI
import PhotosUI
import CoreImage
import CoreImage.CIFilterBuiltins

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
    private static let ciContext = CIContext()

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
            PhotoStripEditorView(option: option, images: filteredImages)
        }
        .alert("Fill all slots", isPresented: $showIncompleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please capture or pick a photo for each slot before proceeding.")
        }
    }

    private var filteredImages: [UIImage] {
        images.compactMap { img in
            guard let img else { return nil }
            return applyFilter(selectedFilter, to: img)
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
                LiveFilteredCameraView(camera: camera, filter: liveFilterClosure(for: selectedFilter))
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
        guard let inputCI = CIImage(image: image) else { return image }
        let closure = filterClosure(for: kind)
        let outputCI = closure(inputCI)
        guard let cg = Self.ciContext.createCGImage(outputCI, from: outputCI.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    private func filterClosure(for kind: FilterKind) -> (CIImage) -> CIImage {
        switch kind {
        case .none:
            return { $0 }
        case .mono:
            let noir = CIFilter.photoEffectNoir()
            return { input in noir.inputImage = input; return (noir.outputImage ?? input).cropped(to: input.extent) }
        case .warm:
            let temp = CIFilter.temperatureAndTint(); let vib = CIFilter.vibrance()
            return { input in
                temp.inputImage = input; temp.neutral = SIMD2<Float>(6500, 0); temp.targetNeutral = SIMD2<Float>(7500, 0)
                let warmed = temp.outputImage ?? input
                vib.inputImage = warmed; vib.amount = 0.3
                return (vib.outputImage ?? warmed).cropped(to: input.extent)
            }
        case .cool:
            let temp = CIFilter.temperatureAndTint(); let sat = CIFilter.colorControls()
            return { input in
                temp.inputImage = input; temp.neutral = SIMD2<Float>(6500, 0); temp.targetNeutral = SIMD2<Float>(5000, 0)
                let cooled = temp.outputImage ?? input
                sat.inputImage = cooled; sat.saturation = 0.9
                return (sat.outputImage ?? cooled).cropped(to: input.extent)
            }
        case .instant:
            let f = CIFilter.photoEffectInstant()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .fade:
            let f = CIFilter.photoEffectFade()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .chrome:
            let f = CIFilter.photoEffectChrome()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .transfer:
            let f = CIFilter.photoEffectTransfer()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .process:
            let f = CIFilter.photoEffectProcess()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .sepia:
            let f = CIFilter.sepiaTone(); f.intensity = 0.9
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .monoHigh:
            let mono = CIFilter.photoEffectMono(); let cc = CIFilter.colorControls(); cc.contrast = 1.2
            return { input in mono.inputImage = input; let m = mono.outputImage ?? input; cc.inputImage = m; return (cc.outputImage ?? m).cropped(to: input.extent) }
        case .vignette:
            let vig = CIFilter.vignette(); vig.intensity = 0.9; vig.radius = 2.0
            return { input in vig.inputImage = input; return (vig.outputImage ?? input).cropped(to: input.extent) }
        case .lomo:
            let cc = CIFilter.colorControls(); cc.saturation = 1.25; cc.contrast = 1.1
            let vig = CIFilter.vignette(); vig.intensity = 1.0; vig.radius = 2.5
            return { input in cc.inputImage = input; let a = cc.outputImage ?? input; vig.inputImage = a; return (vig.outputImage ?? a).cropped(to: input.extent) }
        case .duotone:
            let mono = CIFilter.colorControls(); mono.saturation = 0
            let duo = CIFilter.falseColor()
            duo.color0 = CIColor(red: 0.10, green: 0.14, blue: 0.22) // shadows
            duo.color1 = CIColor(red: 1.00, green: 0.85, blue: 0.60) // highlights
            return { input in mono.inputImage = input; let m = mono.outputImage ?? input; duo.inputImage = m; return (duo.outputImage ?? m).cropped(to: input.extent) }
        case .posterize:
            let f = CIFilter.colorPosterize(); f.levels = 6.0
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .comic:
            let f = CIFilter.comicEffect()
            return { input in f.inputImage = input; return (f.outputImage ?? input).cropped(to: input.extent) }
        case .bloom:
            let bloom = CIFilter.bloom(); bloom.intensity = 0.8; bloom.radius = 10.0
            return { input in bloom.inputImage = input; let b = bloom.outputImage ?? input; return b.composited(over: input).cropped(to: input.extent) }
        case .halftone:
            let dot = CIFilter.dotScreen(); dot.width = 6.0; dot.sharpness = 0.7; dot.angle = 0.0
            return { input in dot.inputImage = input; dot.center = CGPoint(x: input.extent.midX, y: input.extent.midY); return (dot.outputImage ?? input).cropped(to: input.extent) }
        }
    }

    private func liveFilterClosure(for kind: FilterKind) -> (CIImage) -> CIImage {
        filterClosure(for: kind)
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
        case none
        case mono
        case monoHigh
        case sepia
        case warm
        case cool
        case instant
        case fade
        case chrome
        case transfer
        case process
        case vignette
        case lomo
        case duotone
        case posterize
        case comic
        case bloom
        case halftone

        var label: String {
            switch self {
                case .none: return "None"
                case .mono: return "Mono"
                case .monoHigh: return "Mono (High Contrast)"
                case .sepia: return "Sepia"
                case .warm: return "Warm"
                case .cool: return "Cool"
                case .instant: return "Instant"
                case .fade: return "Fade"
                case .chrome: return "Chrome"
                case .transfer: return "Transfer"
                case .process: return "Process"
                case .vignette: return "Vignette"
                case .lomo: return "Lomo"
                case .duotone: return "Duotone"
                case .posterize: return "Posterize"
                case .comic: return "Comic"
                case .bloom: return "Bloom"
                case .halftone: return "Halftone"
            }
        }
    }
}

#Preview {
    NavigationStack {
        CaptureView(option: .init(title: "Layout A", poses: 4, assetName: "Layout A"))
    }
}

