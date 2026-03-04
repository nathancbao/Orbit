import SwiftUI
import PhotosUI

// MARK: - Quick Profile Setup View
// Single-screen profile creation (<30 seconds).
// Collects: name, college year, 3–10 interests, optional photo.
// Extended: bio, gender, MBTI, links, gallery photos.
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
    @State private var photoWasChanged = false
    @State private var showPhotoPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Extended profile fields
    @State private var bio: String = ""
    @State private var selectedGender: String = ""
    @State private var selectedMBTI: String = ""
    @State private var link1: String = ""
    @State private var link2: String = ""
    @State private var link3: String = ""
    @State private var galleryImages: [UIImage] = []
    @State private var galleryURLs: [String] = []
    @State private var showGalleryPicker = false
    @State private var galleryIndicesToRemove: Set<Int> = []
    @State private var newGalleryImages: [UIImage] = []

    init(onComplete: @escaping (Profile, UIImage?) -> Void,
         onCancel: (() -> Void)? = nil,
         initialProfile: Profile? = nil) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.initialProfile = initialProfile
        _name = State(initialValue: initialProfile?.name ?? "")
        _selectedYear = State(initialValue: initialProfile?.collegeYear ?? "freshman")
        _selectedInterests = State(initialValue: Set(initialProfile?.interests ?? []))
        _bio = State(initialValue: initialProfile?.bio ?? "")
        _selectedGender = State(initialValue: initialProfile?.gender ?? "")
        _selectedMBTI = State(initialValue: initialProfile?.mbti ?? "")
        let existingLinks = initialProfile?.links ?? []
        _link1 = State(initialValue: existingLinks.indices.contains(0) ? existingLinks[0] : "")
        _link2 = State(initialValue: existingLinks.indices.contains(1) ? existingLinks[1] : "")
        _link3 = State(initialValue: existingLinks.indices.contains(2) ? existingLinks[2] : "")
        _galleryURLs = State(initialValue: initialProfile?.galleryPhotos ?? [])
    }

    private let availableInterests = [
        "Hiking", "Gaming", "Movies", "Music", "Cooking",
        "Reading", "Sports", "Travel", "Photography", "Art",
        "Fitness", "Coffee", "Board Games", "Tech", "Food",
        "Dancing", "Yoga", "Camping", "Concerts", "Comedy"
    ]

    private var customInterests: [String] {
        selectedInterests
            .filter { !availableInterests.contains($0) }
            .sorted()
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedInterests.count >= Constants.Validation.minInterests
    }

    private var linksArray: [String] {
        [link1, link2, link3]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var totalGalleryCount: Int {
        let remaining = galleryURLs.indices.filter { !galleryIndicesToRemove.contains($0) }.count
        return remaining + newGalleryImages.count
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text(initialProfile != nil ? "Edit Profile" : "Set Up Your Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                        if initialProfile == nil {
                            Text("Takes about 30 seconds — the more you share, the better your matches.")
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

                        // Interest chips grid (custom interests shown first)
                        InterestChipGrid(
                            interests: customInterests + availableInterests,
                            selected: $selectedInterests,
                            maxCount: Constants.Validation.maxInterests
                        )
                    }

                    // Bio
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("bio")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(bio.count)/\(Constants.Validation.maxBioLength)")
                                .font(.caption)
                                .foregroundColor(
                                    bio.count > Constants.Validation.maxBioLength ? .red : .secondary
                                )
                        }
                        TextField("tell people about yourself...", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > Constants.Validation.maxBioLength {
                                    bio = String(newValue.prefix(Constants.Validation.maxBioLength))
                                }
                            }
                    }

                    // Gender
                    VStack(alignment: .leading, spacing: 10) {
                        Text("gender")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(Profile.genderOptions, id: \.self) { option in
                                YearChip(
                                    label: Profile.displayGender(option),
                                    isSelected: selectedGender == option,
                                    action: {
                                        selectedGender = selectedGender == option ? "" : option
                                    }
                                )
                            }
                        }
                    }

                    // MBTI
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("mbti")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if !selectedMBTI.isEmpty {
                                Button("clear") {
                                    selectedMBTI = ""
                                }
                                .font(.caption)
                                .foregroundStyle(OrbitTheme.gradient)
                            }
                        }
                        ForEach(Profile.mbtiGroupOrder, id: \.self) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 8) {
                                    ForEach(Profile.mbtiTypes[group] ?? [], id: \.self) { mbti in
                                        YearChip(
                                            label: mbti,
                                            isSelected: selectedMBTI == mbti,
                                            action: {
                                                selectedMBTI = selectedMBTI == mbti ? "" : mbti
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // Links
                    VStack(alignment: .leading, spacing: 8) {
                        Text("links")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(0..<3, id: \.self) { index in
                            let binding: Binding<String> = index == 0 ? $link1 : (index == 1 ? $link2 : $link3)
                            TextField("https://...", text: binding)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }

                    // Gallery Photos
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("gallery photos")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(totalGalleryCount)/\(Constants.Validation.maxGalleryPhotos)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Existing gallery photos from server
                                ForEach(Array(galleryURLs.enumerated()), id: \.offset) { index, urlString in
                                    if !galleryIndicesToRemove.contains(index) {
                                        ZStack(alignment: .topTrailing) {
                                            AsyncImage(url: URL(string: urlString)) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Color(.systemGray5)
                                            }
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                            Button {
                                                galleryIndicesToRemove.insert(index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }

                                // New gallery images (not yet uploaded)
                                ForEach(Array(newGalleryImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                        Button {
                                            newGalleryImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.6)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }

                                // Add button
                                if totalGalleryCount < Constants.Validation.maxGalleryPhotos {
                                    Button { showGalleryPicker = true } label: {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title2)
                                                    .foregroundStyle(OrbitTheme.gradient)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showPhotoPicker, onDismiss: {
            if profilePhoto != nil { photoWasChanged = true }
        }) {
            ImagePickerView(selectedImage: $profilePhoto)
        }
        .sheet(isPresented: $showGalleryPicker) {
            GalleryImagePickerView { image in
                if let image = image, totalGalleryCount < Constants.Validation.maxGalleryPhotos {
                    newGalleryImages.append(image)
                }
            }
        }
        .task {
            // Load existing profile photo from URL when editing
            if profilePhoto == nil,
               let urlString = initialProfile?.photo,
               let url = URL(string: urlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        profilePhoto = image
                    }
                } catch {}
            }
        }
        .navigationBarBackButtonHidden(onCancel != nil)
        .toolbar {
            if let onCancel = onCancel {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Cancel")
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
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
            photo: initialProfile?.photo,
            trustScore: nil,
            email: nil,
            galleryPhotos: initialProfile?.galleryPhotos ?? [],
            bio: bio,
            links: linksArray,
            gender: selectedGender,
            mbti: selectedMBTI,
            matchScore: nil
        )

        Task {
            do {
                // Save profile text data first
                _ = try await ProfileService.shared.updateProfile(profile)

                // Handle gallery removals (in reverse order to keep indices valid)
                let sortedRemovals = galleryIndicesToRemove.sorted(by: >)
                for index in sortedRemovals {
                    _ = try await ProfileService.shared.deleteGalleryPhoto(at: index)
                }

                // Upload new gallery photos
                for image in newGalleryImages {
                    _ = try await ProfileService.shared.uploadGalleryPhoto(image)
                }

                // Only upload profile photo if the user picked a new one
                var finalProfile = profile
                if photoWasChanged, let photo = profilePhoto {
                    let photoResponse = try await ProfileService.shared.uploadPhoto(photo)
                    finalProfile.photo = photoResponse.profile.photo
                }

                // Refresh profile to get updated gallery URLs
                let refreshed = try await ProfileService.shared.getProfile()
                finalProfile.galleryPhotos = refreshed.galleryPhotos

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

// MARK: - Gallery Image Picker

struct GalleryImagePickerView: View {
    let onImagePicked: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: UIImage?
    @State private var showCrop = false

    var body: some View {
        PhotoLibraryPicker(selectedImage: $pickedImage)
            .onChange(of: pickedImage) { _, img in
                if img != nil { showCrop = true }
            }
            .fullScreenCover(isPresented: $showCrop) {
                if let img = pickedImage {
                    CropView(image: img) { cropped in
                        onImagePicked(cropped)
                        dismiss()
                    } onCancel: {
                        pickedImage = nil
                        showCrop = false
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

// MARK: - Profile Image Picker (with crop)

struct ImagePickerView: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: UIImage?
    @State private var showCrop = false

    var body: some View {
        PhotoLibraryPicker(selectedImage: $pickedImage)
            .onChange(of: pickedImage) { _, img in
                if img != nil { showCrop = true }
            }
            .fullScreenCover(isPresented: $showCrop) {
                if let img = pickedImage {
                    CropView(image: img) { cropped in
                        selectedImage = cropped
                        dismiss()
                    } onCancel: {
                        pickedImage = nil
                        showCrop = false
                    }
                }
            }
    }
}

// MARK: - Photo Library Picker (PHPicker wrapper)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = object as? UIImage
                }
            }
        }
    }
}

// MARK: - Zoomable Crop View

struct CropView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let cropSize = min(geo.size.width, geo.size.height) - 40

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { value in
                                    scale = max(1.0, lastScale * value)
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    lastOffset = offset
                                }
                        )
                    )

                // Dark overlay with square cutout
                CropOverlay(cropSize: cropSize)
                    .allowsHitTesting(false)

                // Controls
                VStack {
                    HStack {
                        Button("Cancel") { onCancel() }
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                        Button("Done") {
                            let cropped = performCrop(
                                viewSize: geo.size,
                                cropSize: cropSize
                            )
                            onCrop(cropped)
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                    }
                    Spacer()
                    Text("Pinch to zoom, drag to adjust")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 30)
                }
            }
        }
    }

    private func performCrop(viewSize: CGSize, cropSize: CGFloat) -> UIImage {
        let imgSize = image.size
        // Determine how the image is displayed (scaledToFit)
        let viewFit: CGSize
        let imgAspect = imgSize.width / imgSize.height
        let viewAspect = viewSize.width / viewSize.height
        if imgAspect > viewAspect {
            let w = viewSize.width
            viewFit = CGSize(width: w, height: w / imgAspect)
        } else {
            let h = viewSize.height
            viewFit = CGSize(width: h * imgAspect, height: h)
        }

        // Scaled display size
        let displayW = viewFit.width * scale
        let displayH = viewFit.height * scale

        // The crop square center is at the view center
        let cropOriginX = (viewSize.width - cropSize) / 2
        let cropOriginY = (viewSize.height - cropSize) / 2

        // Image display origin (accounting for offset)
        let imgDisplayX = (viewSize.width - displayW) / 2 + offset.width
        let imgDisplayY = (viewSize.height - displayH) / 2 + offset.height

        // Crop rect in display coordinates
        let relX = (cropOriginX - imgDisplayX) / displayW
        let relY = (cropOriginY - imgDisplayY) / displayH
        let relW = cropSize / displayW
        let relH = cropSize / displayH

        // Convert to pixel coordinates
        let pixelX = relX * imgSize.width
        let pixelY = relY * imgSize.height
        let pixelW = relW * imgSize.width
        let pixelH = relH * imgSize.height

        let cropRect = CGRect(x: pixelX, y: pixelY, width: pixelW, height: pixelH)
            .intersection(CGRect(origin: .zero, size: imgSize))

        guard !cropRect.isEmpty,
              let cgCropped = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cgCropped, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Crop Overlay (dark surround with square hole)

struct CropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let cropOrigin = CGPoint(
                x: (geo.size.width - cropSize) / 2,
                y: (geo.size.height - cropSize) / 2
            )
            let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: cropSize, height: cropSize))

            Canvas { context, _ in
                context.fill(Path(rect), with: .color(.black.opacity(0.55)))
                context.blendMode = .destinationOut
                context.fill(
                    Path(roundedRect: cropRect, cornerRadius: 4),
                    with: .color(.white)
                )
            }
            .compositingGroup()

            // Border around crop area
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                .frame(width: cropSize, height: cropSize)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

#Preview {
    QuickProfileSetupView(onComplete: { _, _ in }, onCancel: nil)
}
