//
//  ImageCropCoordinator.swift
//  Orbit
//
//  Coordinates cropping flow for multiple selected images.
//

import SwiftUI

struct ImageCropCoordinator: View {
    let images: [UIImage]
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var currentIndex: Int = 0
    @State private var croppedImages: [UIImage] = []
    @State private var showCancelAlert: Bool = false

    var body: some View {
        ZStack {
            if currentIndex < images.count {
                ImageCropView(
                    image: images[currentIndex],
                    onCrop: { croppedImage in
                        handleCrop(croppedImage)
                    },
                    onCancel: {
                        showCancelAlert = true
                    }
                )
            }

            // Photo counter overlay
            if images.count > 1 {
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) of \(images.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.bottom, 100)
                }
            }
        }
        .alert("Cancel Cropping?", isPresented: $showCancelAlert) {
            Button("Continue Cropping", role: .cancel) { }
            Button("Discard All", role: .destructive) {
                onCancel()
            }
        } message: {
            Text("Your cropped photos will be discarded.")
        }
    }

    private func handleCrop(_ croppedImage: UIImage) {
        croppedImages.append(croppedImage)

        if currentIndex + 1 < images.count {
            // Move to next image
            withAnimation {
                currentIndex += 1
            }
        } else {
            // All done
            onComplete(croppedImages)
        }
    }
}

#Preview {
    ImageCropCoordinator(
        images: [UIImage(systemName: "photo")!],
        onComplete: { _ in },
        onCancel: { }
    )
}
