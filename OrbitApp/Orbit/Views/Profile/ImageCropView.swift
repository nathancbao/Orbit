//
//  ImageCropView.swift
//  Orbit
//
//  Interactive square image cropping view.
//

import SwiftUI

struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageDisplaySize: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    private let cropPadding: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            let cropSize = min(geometry.size.width, geometry.size.height) - (cropPadding * 2)

            ZStack {
                Color.black.ignoresSafeArea()

                // Image with gestures
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(cropGesture(cropSize: cropSize, containerSize: geometry.size))
                    .background(
                        GeometryReader { imageGeometry in
                            Color.clear.onAppear {
                                imageDisplaySize = imageGeometry.size
                            }
                        }
                    )

                // Crop overlay
                CropOverlayView(cropSize: cropSize)
            }
            .onAppear {
                containerSize = geometry.size
                initializeScale(cropSize: cropSize, containerSize: geometry.size)
            }
        }
        .overlay(alignment: .top) {
            // Header title
            Text("Move and Scale")
                .foregroundColor(.white)
                .font(.headline)
                .padding(.top, 60)
        }
        .overlay(alignment: .bottom) {
            // Bottom buttons
            HStack(spacing: 20) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    if let cropped = performCrop() {
                        onCrop(cropped)
                    }
                } label: {
                    Text("Done")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }

    // MARK: - Gesture Handling

    private func cropGesture(cropSize: CGFloat, containerSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let newScale = lastScale * value.magnification
                    let minScale = calculateMinScale(cropSize: cropSize, containerSize: containerSize)
                    scale = max(minScale, min(newScale, 5.0)) // Max 5x zoom
                }
                .onEnded { _ in
                    lastScale = scale
                    withAnimation(.easeOut(duration: 0.2)) {
                        constrainOffset(cropSize: cropSize, containerSize: containerSize)
                    }
                },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        constrainOffset(cropSize: cropSize, containerSize: containerSize)
                    }
                    lastOffset = offset
                }
        )
    }

    // MARK: - Scale and Offset Calculations

    private func initializeScale(cropSize: CGFloat, containerSize: CGSize) {
        let minScale = calculateMinScale(cropSize: cropSize, containerSize: containerSize)
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }

    private func calculateMinScale(cropSize: CGFloat, containerSize: CGSize) -> CGFloat {
        let imageAspect = image.size.width / image.size.height

        // Calculate how the image fits in the container (scaledToFit behavior)
        var displayWidth: CGFloat
        var displayHeight: CGFloat

        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider than container
            displayWidth = containerSize.width
            displayHeight = containerSize.width / imageAspect
        } else {
            // Image is taller than container
            displayHeight = containerSize.height
            displayWidth = containerSize.height * imageAspect
        }

        // Minimum scale needed to cover the crop square
        let minScaleForWidth = cropSize / displayWidth
        let minScaleForHeight = cropSize / displayHeight

        return max(minScaleForWidth, minScaleForHeight)
    }

    private func constrainOffset(cropSize: CGFloat, containerSize: CGSize) {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        var displayWidth: CGFloat
        var displayHeight: CGFloat

        if imageAspect > containerAspect {
            displayWidth = containerSize.width
            displayHeight = containerSize.width / imageAspect
        } else {
            displayHeight = containerSize.height
            displayWidth = containerSize.height * imageAspect
        }

        let scaledWidth = displayWidth * scale
        let scaledHeight = displayHeight * scale

        // Maximum offset allowed while keeping crop area covered
        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)

        offset.width = min(maxOffsetX, max(-maxOffsetX, offset.width))
        offset.height = min(maxOffsetY, max(-maxOffsetY, offset.height))
        lastOffset = offset
    }

    // MARK: - Crop Logic

    private func performCrop() -> UIImage? {
        // Normalize image orientation first
        let normalizedImage = normalizeImageOrientation(image)

        guard let cgImage = normalizedImage.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let imageAspect = imageWidth / imageHeight

        // We need to figure out what portion of the original image is visible in the crop square
        // The crop square is centered in the view
        // The image is scaled by 'scale' and offset by 'offset'

        // Calculate the displayed size of the image at scale 1.0
        // Use stored container size instead of deprecated UIScreen.main
        let referenceWidth = containerSize.width
        let referenceHeight = containerSize.height
        let containerAspect = referenceWidth / referenceHeight

        let displayWidth: CGFloat
        if imageAspect > containerAspect {
            displayWidth = referenceWidth
        } else {
            displayWidth = referenceHeight * imageAspect
        }

        let cropSize = min(referenceWidth, referenceHeight) - (cropPadding * 2)

        // The crop square is centered at (0, 0) in the coordinate system
        // The image center is at offset from (0, 0)
        // So the crop rect center in image coordinates is at -offset

        // Scale factor from display to original image
        let scaleToOriginal = imageWidth / (displayWidth * scale)

        // Size of crop square in original image coordinates
        let cropSizeInOriginal = cropSize * scaleToOriginal

        // Center of crop in original image coordinates
        // The crop is at center of screen, image is offset from center
        let cropCenterX = (imageWidth / 2) - (offset.width * scaleToOriginal)
        let cropCenterY = (imageHeight / 2) - (offset.height * scaleToOriginal)

        // Crop rect in original image coordinates
        let cropRect = CGRect(
            x: cropCenterX - (cropSizeInOriginal / 2),
            y: cropCenterY - (cropSizeInOriginal / 2),
            width: cropSizeInOriginal,
            height: cropSizeInOriginal
        )

        // Clamp to image bounds
        let clampedRect = CGRect(
            x: max(0, cropRect.origin.x),
            y: max(0, cropRect.origin.y),
            width: min(cropRect.width, imageWidth - max(0, cropRect.origin.x)),
            height: min(cropRect.height, imageHeight - max(0, cropRect.origin.y))
        )

        // Perform the crop
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else { return nil }

        return UIImage(cgImage: croppedCGImage)
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
}

// MARK: - Crop Overlay

struct CropOverlayView: View {
    let cropSize: CGFloat

    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.6)

            // Clear square hole
            Rectangle()
                .frame(width: cropSize, height: cropSize)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .overlay {
            // White border around crop area
            Rectangle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: cropSize, height: cropSize)
        }
    }
}

#Preview {
    ImageCropView(
        image: UIImage(systemName: "photo.fill")!,
        onCrop: { _ in },
        onCancel: { }
    )
}
