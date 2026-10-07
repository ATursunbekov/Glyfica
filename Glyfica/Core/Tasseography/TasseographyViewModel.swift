//
//  TasseographyViewModel.swift
//  Glyfica
//

import Combine
import Foundation
import UIKit

@MainActor
final class TasseographyViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published private(set) var reading: TasseographyReading?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var canAnalyze: Bool {
        selectedImage != nil && !isLoading
    }

    func setSelectedImage(_ image: UIImage?) {
        selectedImage = image
        reading = nil
        errorMessage = nil
    }

    func clearSelection() {
        selectedImage = nil
        reading = nil
        errorMessage = nil
    }

    func startNewReading() {
        selectedImage = nil
        reading = nil
        errorMessage = nil
    }

    func analyze(profile: BirthProfile?) async {
        guard let image = selectedImage else { return }
        guard let payload = Self.compressedJPEGBase64(from: image) else {
            errorMessage = "Couldn’t prepare that photo. Try another one."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            reading = try await ReadingService.fetchTasseographyReading(
                imageBase64: payload.base64,
                mimeType: "image/jpeg",
                profile: profile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func compressedJPEGBase64(
        from image: UIImage,
        maxDimension: CGFloat = 1024,
        quality: CGFloat = 0.72
    ) -> (base64: String, byteCount: Int)? {
        let scaled = scale(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: quality) else { return nil }
        return (data.base64EncodedString(), data.count)
    }

    private static func scale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
