import SwiftUI
import PhotosUI

// MARK: - Quick Profile Setup View
// Single-screen profile creation (<30 seconds).
// Collects: name, college year, 3–10 interests, optional photo.
// Includes a disclaimer about account permanence tied to school email.

struct QuickProfileSetupView: View {
    let onComplete: (Profile, UIImage?) -> Void
    let onCancel: (() -> Void)?
    var initialProfile: Profile? = nil

    @State private var name: String = ""
    @State private var selectedYear: String = "freshman"
    @State private var selectedInterests: Set<String> = []
    @State private var customInterestText: String = ""
    @State private var profilePhoto: UIImage?
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(onComplete: @escaping (Profile, UIImage?) -> Void,
         onCancel: (() -> Void)? = nil,
         initialProfile: Profile? = nil) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.initialProfile = initialProfile
        _name = State(initialValue: initialProfile?.name ?? "")
        _selectedYear = State(initialValue: initialProfile?.collegeYear ?? "freshman")
        _selectedInterests = State(initialValue: Set(initialProfile?.interests ?? []))
    }

    private let availableInterests = [
        "Hiking", "Gaming", "Movies", "Music", "Cooking",
        "Reading", "Sports", "Travel", "Photography", "Art",
        "Fitness", "Coffee", "Board Games", "Tech", "Food",
        "Dancing", "Yoga", "Camping", "Concerts", "Comedy"
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedInterests.count >= Constants.Validation.minInterests
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack {
                TopWavyLines().frame(height: 150)
                Spacer()
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                BottomWavyLines().frame(height: 160)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    if let onCancel = onCancel {
                        HStack {
                            Button(action: onCancel) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark")
                                    Text("Cancel")
                                }
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 4)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(initialProfile != nil ? "edit your profile" : "let's set up your profile")
                            .font(.title2)
                            .fontWeight(.bold)
                        if initialProfile == nil {
                            Text("takes about 30 seconds ✨")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Photo (optional)
                    HStack {
                        Spacer()
                        Button(action: { showPhotoPicker = true }) {
                            ZStack {
                                if let photo = profilePhoto {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(
                                            OrbitTheme.gradient.opacity(0.2)
                                        )
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: "camera")
                                                    .font(.title3)
                                                    .foregroundStyle(OrbitTheme.gradient)
                                                Text("optional")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        )
                                }
                            }
                        }
                        Spacer()
                    }

                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("your name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("what should people call you?", text: $name)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }

                    // College Year
                    VStack(alignment: .leading, spacing: 10) {
                        Text("college year")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(Profile.collegeYears, id: \.self) { year in
                                YearChip(
                                    label: Profile.displayYear(year),
                                    isSelected: selectedYear == year,
                                    action: { selectedYear = year }
                                )
                            }
                        }
                    }

                    // Interests
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("interests")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(selectedInterests.count)/\(Constants.Validation.maxInterests)")
                                .font(.caption)
                                .foregroundColor(
                                    selectedInterests.count < Constants.Validation.minInterests
                                    ? .orange : .secondary
                                )
                        }

                        // Custom interest input
                        HStack {
                            TextField("add your own...", text: $customInterestText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            Button(action: addCustomInterest) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(OrbitTheme.gradient)
                            }
                            .disabled(customInterestText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        // Interest chips grid
                        InterestChipGrid(
                            interests: availableInterests,
                            selected: $selectedInterests,
                            maxCount: Constants.Validation.maxInterests
                        )
                    }

                    // Disclaimer
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(OrbitTheme.gradient)
                        Text("Your account is permanently tied to your school email. Choose your profile and behavior wisely.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // Let's Go button
                    Button(action: save) {
                        ZStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("let's go →")
                                    .font(.system(size: 16, weight: .semibold))
                                    .tracking(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isValid
                            ? AnyShapeStyle(OrbitTheme.gradientFill)
                            : AnyShapeStyle(Color.gray.opacity(0.3))
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(!isValid || isSaving)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePickerView(selectedImage: $profilePhoto)
        }
    }


    private func addCustomInterest() {
        let trimmed = customInterestText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, selectedInterests.count < Constants.Validation.maxInterests else { return }
        selectedInterests.insert(trimmed)
        customInterestText = ""
    }

    private func save() {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil

        let profile = Profile(
            name: name.trimmingCharacters(in: .whitespaces),
            collegeYear: selectedYear,
            interests: Array(selectedInterests),
            photo: nil,  // photo URL is set after upload
            trustScore: nil,
            email: nil,
            matchScore: nil
        )

        Task {
            do {
                // Save profile text data first
                _ = try await ProfileService.shared.updateProfile(profile)

                // Upload photo if provided
                var photoURL: String?
                if let photo = profilePhoto {
                    let photoResponse = try await ProfileService.shared.uploadPhoto(photo)
                    photoURL = photoResponse.profile.photo
                }

                var finalProfile = profile
                finalProfile.photo = photoURL

                await MainActor.run {
                    isSaving = false
                    onComplete(finalProfile, profilePhoto)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Year Chip

struct YearChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected
                    ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.25))
                    : AnyShapeStyle(Color(.systemGray6))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                            ? AnyShapeStyle(OrbitTheme.gradient)
                            : AnyShapeStyle(Color.clear),
                            lineWidth: 1.5
                        )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Interest Chip Grid

struct InterestChipGrid: View {
    let interests: [String]
    @Binding var selected: Set<String>
    let maxCount: Int

    var body: some View {
        // Flow layout using LazyVGrid as approximation
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
            ForEach(interests, id: \.self) { interest in
                let isSelected = selected.contains(interest)
                Button(action: {
                    if isSelected {
                        selected.remove(interest)
                    } else if selected.count < maxCount {
                        selected.insert(interest)
                    }
                }) {
                    Text(interest)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected
                            ? AnyShapeStyle(OrbitTheme.gradient.opacity(0.2))
                            : AnyShapeStyle(Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected
                                    ? AnyShapeStyle(OrbitTheme.gradient)
                                    : AnyShapeStyle(Color.clear),
                                    lineWidth: 1.5
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Simple Image Picker (no crop required)

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.selectedImage = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.selectedImage = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    QuickProfileSetupView(onComplete: { _, _ in }, onCancel: nil)
}
