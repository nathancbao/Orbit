//
//  ProfileSetupView.swift
//  Orbit
//
//  PROFILE SETUP FLOW
//  Multi-step form for creating/editing user profiles.
//
//  STEPS:
//  0. Basic Info (name, age, location, bio)
//  1. Personality (slider traits)
//  2. Interests (predefined + custom)
//  3. Social Preferences (group size, frequency, times)
//  4. Photos (optional, up to 6)
//
//  STRUCTURE:
//  - ProfileSetupView: Main container with progress bar and navigation
//  - BasicInfoStep, PersonalityStep, etc.: Individual step views
//  - Helper views: InterestChip, RadioButton, FlowLayout, etc.
//
//  DATA FLOW:
//  - ProfileViewModel holds all form data
//  - Each step reads/writes to the viewModel
//  - On completion, calls onProfileComplete with Profile and photos
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Main Profile Setup View
struct ProfileSetupView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var currentStep = 0

    let onProfileComplete: (Profile, [UIImage]) -> Void

    // Initialize with optional existing profile data
    init(
        initialProfile: Profile? = nil,
        initialPhotos: [UIImage] = [],
        onProfileComplete: @escaping (Profile, [UIImage]) -> Void
    ) {
        if let profile = initialProfile {
            _viewModel = StateObject(wrappedValue: ProfileViewModel(profile: profile, photos: initialPhotos))
        } else {
            _viewModel = StateObject(wrappedValue: ProfileViewModel())
        }
        self.onProfileComplete = onProfileComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            .padding(.horizontal)

            // Step content - using Group instead of TabView to prevent swipe bypassing validation
            Group {
                switch currentStep {
                case 0:
                    BasicInfoStep(viewModel: viewModel)
                case 1:
                    PersonalityStep(viewModel: viewModel)
                case 2:
                    InterestsStep(viewModel: viewModel)
                case 3:
                    SocialPreferencesStep(viewModel: viewModel)
                case 4:
                    PhotoUploadStep(viewModel: viewModel)
                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut, value: currentStep)

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Navigation buttons
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }

                Button {
                    if currentStep == 4 {
                        Task {
                            await viewModel.saveProfile()
                        }
                    } else {
                        currentStep += 1
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(currentStep == 4 ? "Complete" : "Next")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(nextButtonColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!isCurrentStepValid || viewModel.isLoading)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onChange(of: viewModel.profileSaved) { _, saved in
            if saved {
                let photos = viewModel.selectedPhotos.compactMap { $0.image }
                onProfileComplete(viewModel.buildProfile(), photos)
            }
        }
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return viewModel.isBasicInfoValid
        case 1: return true // Personality sliders always have valid values
        case 2: return viewModel.isInterestsValid
        case 3: return viewModel.isSocialPreferencesValid
        case 4: return true // Photos are optional
        default: return false
        }
    }

    private var nextButtonColor: Color {
        isCurrentStepValid ? .blue : .gray
    }
}

// MARK: - Basic Info Step
struct BasicInfoStep: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Tell us about yourself")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                    TextField("Your name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .font(.headline)
                    TextField("Your age", value: $viewModel.age, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("City")
                        .font(.headline)
                    TextField("Your city", text: $viewModel.city)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.addressCity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("State")
                        .font(.headline)
                    TextField("Your state", text: $viewModel.state)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.addressState)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Bio")
                        .font(.headline)
                    TextEditor(text: $viewModel.bio)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3))
                        )
                        .onChange(of: viewModel.bio) { _, newValue in
                            if newValue.count > Constants.Validation.maxBioLength {
                                viewModel.bio = String(newValue.prefix(Constants.Validation.maxBioLength))
                            }
                        }
                    Text("\(viewModel.bio.count)/\(Constants.Validation.maxBioLength)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Personality Step
struct PersonalityStep: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Your personality")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Move the sliders to describe yourself")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Introvert")
                        Spacer()
                        Text("Extrovert")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Slider(value: $viewModel.introvertExtrovert, in: 0...1)
                        .tint(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Spontaneous")
                        Spacer()
                        Text("Planner")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Slider(value: $viewModel.spontaneousPlanner, in: 0...1)
                        .tint(.blue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active")
                        Spacer()
                        Text("Relaxed")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Slider(value: $viewModel.activeRelaxed, in: 0...1)
                        .tint(.blue)
                }
            }
            .padding()
        }
    }
}

// MARK: - Interests Step
struct InterestsStep: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var customInterest: String = ""
    @FocusState private var isCustomFieldFocused: Bool

    let availableInterests = [
        "Hiking", "Gaming", "Movies", "Music", "Cooking",
        "Reading", "Sports", "Travel", "Photography", "Art",
        "Fitness", "Coffee", "Board Games", "Tech", "Food",
        "Dancing", "Yoga", "Camping", "Concerts", "Comedy"
    ]

    // Custom interests are ones not in the predefined list
    var customInterests: [String] {
        viewModel.selectedInterests.filter { !availableInterests.contains($0) }.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you into?")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Select \(Constants.Validation.minInterests)-\(Constants.Validation.maxInterests) interests (\(viewModel.selectedInterests.count) selected)")
                        .foregroundColor(.secondary)
                }

                // Custom interest input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your own")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Type an interest...", text: $customInterest)
                            .textFieldStyle(.roundedBorder)
                            .focused($isCustomFieldFocused)
                            .onSubmit {
                                addCustomInterest()
                            }

                        Button {
                            addCustomInterest()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(canAddCustomInterest ? .blue : .gray)
                        }
                        .disabled(!canAddCustomInterest)
                    }
                }

                // Show custom interests first (if any)
                if !customInterests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your interests")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(customInterests, id: \.self) { interest in
                                InterestChip(
                                    title: interest,
                                    isSelected: true,
                                    isCustom: true
                                ) {
                                    toggleInterest(interest)
                                }
                            }
                        }
                    }
                }

                // Predefined interests
                VStack(alignment: .leading, spacing: 8) {
                    Text("Popular interests")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(availableInterests, id: \.self) { interest in
                            InterestChip(
                                title: interest,
                                isSelected: viewModel.selectedInterests.contains(interest)
                            ) {
                                toggleInterest(interest)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var canAddCustomInterest: Bool {
        let trimmed = customInterest.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty &&
               !viewModel.selectedInterests.contains(trimmed) &&
               viewModel.selectedInterests.count < Constants.Validation.maxInterests
    }

    private func addCustomInterest() {
        let trimmed = customInterest.trimmingCharacters(in: .whitespaces)
        guard canAddCustomInterest else { return }

        viewModel.selectedInterests.insert(trimmed)
        customInterest = ""
        isCustomFieldFocused = false
    }

    private func toggleInterest(_ interest: String) {
        if viewModel.selectedInterests.contains(interest) {
            viewModel.selectedInterests.remove(interest)
        } else if viewModel.selectedInterests.count < Constants.Validation.maxInterests {
            viewModel.selectedInterests.insert(interest)
        }
    }
}

struct InterestChip: View {
    let title: String
    let isSelected: Bool
    var isCustom: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                if isCustom && isSelected {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? (isCustom ? Color.purple : Color.blue) : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Social Preferences Step
struct SocialPreferencesStep: View {
    @ObservedObject var viewModel: ProfileViewModel

    let groupSizes = ["One-on-one", "Small groups (3-5)", "Medium groups (6-10)", "Large groups (10+)"]
    let frequencies = ["Weekly", "Bi-weekly", "Monthly", "Flexible"]
    let times = ["Mornings", "Afternoons", "Evenings", "Weekends"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Social preferences")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred group size")
                        .font(.headline)

                    ForEach(groupSizes, id: \.self) { size in
                        RadioButton(
                            title: size,
                            isSelected: viewModel.groupSize == size
                        ) {
                            viewModel.groupSize = size
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How often do you want to hang out?")
                        .font(.headline)

                    ForEach(frequencies, id: \.self) { freq in
                        RadioButton(
                            title: freq,
                            isSelected: viewModel.meetingFrequency == freq
                        ) {
                            viewModel.meetingFrequency = freq
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred times (select at least one)")
                        .font(.headline)

                    FlowLayout(spacing: 8) {
                        ForEach(times, id: \.self) { time in
                            InterestChip(
                                title: time,
                                isSelected: viewModel.preferredTimes.contains(time)
                            ) {
                                if viewModel.preferredTimes.contains(time) {
                                    viewModel.preferredTimes.remove(time)
                                } else {
                                    viewModel.preferredTimes.insert(time)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Photo Upload Step
struct PhotoUploadStep: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingFileImporter = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your photos")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add up to \(Constants.Validation.maxPhotos) photos (optional)")
                        .foregroundColor(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    // Show existing photos
                    ForEach(viewModel.selectedPhotos) { photo in
                        PhotoThumbnail(photo: photo) {
                            removePhoto(photo)
                        }
                    }

                    // Add photo button if under limit
                    if viewModel.selectedPhotos.count < Constants.Validation.maxPhotos {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: Constants.Validation.maxPhotos - viewModel.selectedPhotos.count,
                            matching: .images
                        ) {
                            AddPhotoButton(label: "Library")
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            Task {
                                await loadPhotos(from: newItems)
                                selectedItems = []
                            }
                        }

                        // Import from Files button
                        Button {
                            showingFileImporter = true
                        } label: {
                            AddPhotoButton(label: "Files", icon: "folder")
                        }
                    }
                }

                Text("Photos help others get to know you better")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                loadPhotosFromFiles(urls: urls)
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if viewModel.selectedPhotos.count >= Constants.Validation.maxPhotos {
                break
            }

            var photoItem = PhotoItem()
            photoItem.isLoading = true
            viewModel.selectedPhotos.append(photoItem)
            let index = viewModel.selectedPhotos.count - 1

            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                viewModel.selectedPhotos[index].image = image
                viewModel.selectedPhotos[index].isLoading = false
            } else {
                // Remove failed photo
                viewModel.selectedPhotos.remove(at: index)
            }
        }
    }

    private func loadPhotosFromFiles(urls: [URL]) {
        for url in urls {
            if viewModel.selectedPhotos.count >= Constants.Validation.maxPhotos {
                break
            }

            // Need to start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                continue
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                var photoItem = PhotoItem()
                photoItem.image = image
                viewModel.selectedPhotos.append(photoItem)
            }
        }
    }

    private func removePhoto(_ photo: PhotoItem) {
        viewModel.selectedPhotos.removeAll { $0.id == photo.id }
    }
}

struct PhotoThumbnail: View {
    let photo: PhotoItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if photo.isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(ProgressView())
            } else if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .cornerRadius(12)
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(4)
        }
    }
}

struct AddPhotoButton: View {
    var label: String = "Add"
    var icon: String = "plus"

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title)
                        .foregroundColor(.blue)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

#Preview {
    ProfileSetupView(onProfileComplete: { _, _ in })
}
