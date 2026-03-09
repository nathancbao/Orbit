import SwiftUI
import CoreImage.CIFilterBuiltins

struct FriendShareView: View {
    let userId: Int
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var friendLink: String {
        "https://orbit-app-486204.wl.r.appspot.com/friend/\(userId)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // QR Code
                if let qrImage = generateQRCode(from: friendLink) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                }

                VStack(spacing: 8) {
                    Text("Add \(userName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Scan this QR code or share the link below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Copy Link
                Button {
                    UIPasteboard.general.string = friendLink
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy Link")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(OrbitTheme.gradientFill)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 40)

                // Share
                ShareLink(item: URL(string: friendLink)!) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(OrbitTheme.gradient)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(OrbitTheme.purple.opacity(0.1))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Share Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    // MARK: - QR Code (CoreImage)

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 10.0
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
