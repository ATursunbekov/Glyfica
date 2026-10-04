//
//  PalmView.swift
//  Glyfica
//

import PhotosUI
import SwiftUI
import UIKit

struct PalmFlowContainerView: View {
    var body: some View {
        NavigationStack {
            PalmView()
        }
    }
}

struct PalmView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @StateObject private var viewModel = PalmViewModel()

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraUnavailableAlert = false

    var body: some View {
        NightScreen {
            Group {
                if viewModel.isLoading {
                    analyzingState
                } else if let reading = viewModel.reading {
                    resultContent(reading)
                } else if viewModel.selectedImage != nil {
                    previewContent
                } else {
                    emptyContent
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $viewModel.selectedImage)
                .ignoresSafeArea()
        }
        .alert("Camera unavailable", isPresented: $cameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device can’t take photos. Choose one from your gallery instead.")
        }
    }

    // MARK: - Empty

    private var emptyContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                NightCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Palm reading")
                            .font(GlyficaFont.rounded(20, weight: .bold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Take a clear photo of your open palm — or pick one from your gallery — and we’ll read the main lines.")
                            .font(GlyficaFont.rounded(15))
                            .foregroundStyle(GlyficaColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 10) {
                            GlassPrimaryButton(title: "Take a photo") {
                                openCamera()
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text("Choose from gallery")
                                    .font(GlyficaFont.rounded(16, weight: .bold))
                                    .foregroundStyle(GlyficaColor.gold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        GlyficaColor.surface.opacity(0.88),
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(GlyficaColor.line, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                tipCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Preview

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(GlyficaColor.line, lineWidth: 1)
                        )
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(GlyficaFont.rounded(14))
                        .foregroundStyle(GlyficaColor.danger)
                }

                GlassPrimaryButton(title: "Analyze palm") {
                    Task { await viewModel.analyze(profile: profileStore.profile) }
                }
                .disabled(!viewModel.canAnalyze)
                .opacity(viewModel.canAnalyze ? 1 : 0.5)

                Button("Choose another photo") {
                    viewModel.clearSelection()
                    photoItem = nil
                }
                .font(GlyficaFont.rounded(15, weight: .semibold))
                .foregroundStyle(GlyficaColor.gold)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Loading

    private var analyzingState: some View {
        VStack(spacing: 16) {
            Spacer()
            NightCard {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(GlyficaColor.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reading your palm…")
                            .font(GlyficaFont.rounded(16, weight: .semibold))
                            .foregroundStyle(GlyficaColor.ink)
                        Text("Looking at the main lines and the story they suggest.")
                            .font(GlyficaFont.rounded(14))
                            .foregroundStyle(GlyficaColor.ink2)
                    }
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    // MARK: - Result

    private func resultContent(_ reading: PalmReading) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(GlyficaColor.line, lineWidth: 1)
                        )
                }

                NightCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reading.headline)
                            .font(GlyficaFont.rounded(22, weight: .bold))
                            .foregroundStyle(GlyficaColor.gold)
                        Text(reading.overview)
                            .font(GlyficaFont.rounded(16))
                            .foregroundStyle(GlyficaColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)
                    }
                }

                resultCharts(reading)

                ForEach(reading.sections, id: \.title) { section in
                    NightCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(GlyficaFont.rounded(13, weight: .semibold))
                                .foregroundStyle(GlyficaColor.gold)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text(section.body)
                                .font(GlyficaFont.rounded(15))
                                .foregroundStyle(GlyficaColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                GlassPrimaryButton(title: "New palm reading") {
                    viewModel.startNewReading()
                    photoItem = nil
                }

                Text("For entertainment only. Not medical, financial, or legal advice.")
                    .font(GlyficaFont.rounded(11))
                    .foregroundStyle(GlyficaColor.ink2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private func resultCharts(_ reading: PalmReading) -> some View {
        NightCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Palm profile")
                    .font(GlyficaFont.rounded(13, weight: .semibold))
                    .foregroundStyle(GlyficaColor.gold)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(spacing: 20) {
                    overallRing(reading.overall)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(reading.scores) { score in
                            scoreBar(score)
                        }
                    }
                }
            }
        }
    }

    private func overallRing(_ value: Int) -> some View {
        let progress = CGFloat(value) / 100
        return ZStack {
            Circle()
                .stroke(GlyficaColor.line, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    GlyficaColor.score(value),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(GlyficaFont.rounded(28, weight: .bold))
                    .foregroundStyle(GlyficaColor.ink)
                Text("Overall")
                    .font(GlyficaFont.rounded(11, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink2)
            }
        }
        .frame(width: 104, height: 104)
    }

    private func scoreBar(_ score: PalmScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(score.title)
                    .font(GlyficaFont.rounded(12, weight: .semibold))
                    .foregroundStyle(GlyficaColor.ink2)
                Spacer()
                Text("\(score.value)")
                    .font(GlyficaFont.rounded(12, weight: .bold))
                    .foregroundStyle(GlyficaColor.score(score.value))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(GlyficaColor.line)
                    Capsule()
                        .fill(GlyficaColor.score(score.value))
                        .frame(width: geo.size.width * CGFloat(score.value) / 100)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Shared

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Palm")
                .font(GlyficaFont.rounded(28, weight: .bold))
                .foregroundStyle(GlyficaColor.ink)
            Text("A quick reading from your hand.")
                .font(GlyficaFont.rounded(14))
                .foregroundStyle(GlyficaColor.ink2)
        }
    }

    private var tipCard: some View {
        NightCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("For a clearer reading")
                    .font(GlyficaFont.rounded(13, weight: .semibold))
                    .foregroundStyle(GlyficaColor.gold)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text("Use soft light, open palm facing the camera, fingers relaxed, and keep lines in focus.")
                    .font(GlyficaFont.rounded(14))
                    .foregroundStyle(GlyficaColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableAlert = true
            return
        }
        showCamera = true
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.setSelectedImage(image)
            }
        } catch {
            viewModel.errorMessage = "Couldn’t open that photo."
        }
    }
}
