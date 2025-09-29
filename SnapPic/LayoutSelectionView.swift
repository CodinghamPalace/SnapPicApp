//  LayoutSelectionView.swift
//  SnapPic
//
//  Created by Student
//
//  Layout selection screen using assets: Layout A, Layout B, Layout C, Layout D.

import SwiftUI

struct LayoutOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let poses: Int
    let assetName: String

    init(title: String, poses: Int, assetName: String) {
        self.title = title
        self.poses = poses
        self.assetName = assetName
    }
}

struct LayoutSelectionView: View {
    @State private var selected: LayoutOption? = nil
    // Navigate to capture screen when true
    @State private var goToCapture: Bool = false
    @EnvironmentObject private var auth: AuthViewModel

    private let options: [LayoutOption] = [
        .init(title: "Layout A", poses: 4, assetName: "Layout A"),
        .init(title: "Layout B", poses: 3, assetName: "Layout B"),
        .init(title: "Layout C", poses: 2, assetName: "Layout C"),
        .init(title: "Layout D", poses: 6, assetName: "Layout D")
    ]

    // Grid spacing tuned for balance; adapts on compact width.
    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 24), GridItem(.flexible(), spacing: 24)]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        header
                        LazyVGrid(columns: columns, alignment: .center, spacing: 48) {
                            ForEach(options) { option in
                                card(option, availableWidth: geo.size.width)
                            }
                        }
                        buttonsRow
                    }
                    .padding(.horizontal, horizontalPadding(for: geo.size.width))
                    .padding(.top, 32)
                    .padding(.bottom, 60)
                }
                .background(background)
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Layout Selection")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $goToCapture) {
                if let sel = selected { CaptureView(option: sel) } else { EmptyView() }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 14) {
            Text("Choose your layout")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Select a layout for your photo session. You can choose from different styles and poses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Card
    private func card(_ option: LayoutOption, availableWidth: CGFloat) -> some View {
        let isSelected = option == selected
        let idealCardWidth = (availableWidth - horizontalPadding(for: availableWidth) * 2 - 24) / 2
        let clampedHeight = max(220, min(idealCardWidth * 1.22, 340))
        return Button {
            if selected?.id != option.id { impact() }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selected = option }
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: 0xE7DAFF).opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: isSelected ? Color.blue.opacity(0.25) : Color.black.opacity(0.06), radius: 10, y: 6)
                    Image(option.assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                }
                .frame(height: clampedHeight * 0.72)
                .padding(.horizontal, 14)
                .padding(.top, 16)

                VStack(spacing: 6) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(poseLabel(option.poses))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            .frame(height: clampedHeight)
            .scaleEffect(isSelected ? 1.035 : 1.0)
            .animation(.easeInOut(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.title), \(poseLabel(option.poses))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Buttons Row
    private var buttonsRow: some View {
        HStack(spacing: 16) {
            continueButton
            signOutButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Continue Button
    private var continueButton: some View {
        Button(action: continueAction) {
            Text("Continue")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .background(
            Capsule()
                .fill(Color.white.opacity(0.6))
                .overlay(
                    Capsule().stroke(Color.primary.opacity(selected == nil ? 0.35 : 0.9), lineWidth: 1.4)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 4, y: 2)
        )
        .disabled(selected == nil)
        .opacity(selected == nil ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.2), value: selected == nil)
    }

    // MARK: - Sign Out Button
    private var signOutButton: some View {
        Button(action: { auth.signOut() }) {
            Text("Sign Out")
                .font(.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .background(
            Capsule()
                .fill(Color.white.opacity(0.6))
                .overlay(
                    Capsule().stroke(Color.red.opacity(0.9), lineWidth: 1.4)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 4, y: 2)
        )
        .accessibilityLabel("Sign out")
    }

    // MARK: - Helpers
    private func poseLabel(_ poses: Int) -> String { poses == 1 ? "1 Pose" : "\(poses) Poses" }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 380 ? 16 : width < 520 ? 22 : 28
    }

    private func impact() {
#if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color.white, Color(#colorLiteral(red: 0.89, green: 0.94, blue: 1, alpha: 1)), Color.white], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.blue.opacity(0.25), Color.clear], center: .center, startRadius: 10, endRadius: 500)
                .blur(radius: 60)
                .opacity(0.7)
        }
    }

    private func continueAction() {
        guard let _ = selected else { return }
        goToCapture = true
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview { LayoutSelectionView().environmentObject(AuthViewModel()) }
