// GymLink-App/appViews/PostView.swift

import SwiftUI
import PhotosUI
import MapKit
import FirebaseStorage
import FirebaseAuth

// MARK: - Post category
enum PostCategory: String, CaseIterable {
    case workout  = "workout"
    case meal     = "meal"
    case progress = "progress"
    case other    = "other"

    var navigationTitle: String {
        switch self {
        case .workout:  return "Share Your Workout"
        case .meal:     return "Share Your Meal"
        case .progress: return "Share Your Progress"
        case .other:    return "Share Something"
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .workout:  return "Workout title"
        case .meal:     return "Meal name"
        case .progress: return "Name your milestone"
        case .other:    return "Post title"
        }
    }

    var descriptionPlaceholder: String {
        switch self {
        case .workout:  return "Describe your session..."
        case .meal:     return "What did you eat? How was it?"
        case .progress: return "Tell your story..."
        case .other:    return "What's on your mind?"
        }
    }

    var icon: String {
        switch self {
        case .workout:  return "dumbbell.fill"
        case .meal:     return "fork.knife"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .other:    return "pencil"
        }
    }

    var subtitle: String {
        switch self {
        case .workout:  return "Log a training session"
        case .meal:     return "Show what you're eating"
        case .progress: return "Share your gains"
        case .other:    return "Something else"
        }
    }
}

// MARK: - PostView
struct PostView: View {
    var category: PostCategory = .workout

    @Environment(\.dismiss) private var dismiss

    // Shared
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isSubmitting = false
    @State private var errorMessage = ""

    // Workout-specific
    @State private var gymTag = ""
    @State private var gymLat: Double? = nil
    @State private var gymLon: Double? = nil
    @State private var showGymPicker = false
    @State private var rating: Double = 3.0
    @State private var selectedWorkoutType = WorkoutTypes.all[0]

    // Meal-specific
    @State private var selectedMealType = MealTypes.all[0]
    @State private var mealCalories = ""
    @State private var mealProtein  = ""
    @State private var mealCarbs    = ""
    @State private var mealFat      = ""

    // Workout progression
    @State private var showPRSection  = false
    @State private var prExercise     = ""
    @State private var prPrev         = ""
    @State private var prNew          = ""
    @State private var prUnit         = "lbs"
    private let prUnits = ["lbs", "kg", "reps", "km", "min", "sec"]

    // Progress-specific
    @State private var selectedProgressType = ProgressTypes.all[0]
    @State private var timePeriod = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        categoryHeader
                        photoPicker

                        switch category {
                        case .workout:  workoutFields
                        case .meal:     mealFields
                        case .progress: progressFields
                        case .other:    otherFields
                        }

                        postButton

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gymLinkPink)
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Category header
    private var categoryHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 58, height: 58)
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.gymLinkPink)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(category.navigationTitle)
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text(category.subtitle)
                    .font(.subheadline).foregroundColor(Color(white: 0.5))
            }
            Spacer()
        }
    }

    // MARK: - Photo picker
    private var photoPicker: some View {
        Group {
            if let data = selectedImageData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: category == .progress ? 260 : 200)
                        .clipped()
                        .cornerRadius(18)

                    Button {
                        selectedImageData = nil
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .padding(10)
                }
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.gymLinkPink)
                        Text(category == .progress ? "Add a progress photo" : "Add a photo")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.gymLinkPink)
                        Text("Optional")
                            .font(.caption).foregroundColor(Color(white: 0.38))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: category == .progress ? 190 : 150)
                    .background(Color(white: 0.09))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                Color.gymLinkPink.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                            )
                    )
                }
                .onChange(of: selectedPhoto) {
                    Task {
                        if let item = selectedPhoto,
                           let data = try? await item.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dark input card
    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(Color(white: 0.11))
            .cornerRadius(14)
    }

    // MARK: - Workout fields
    @ViewBuilder
    private var workoutFields: some View {
        VStack(spacing: 12) {
            inputCard {
                TextField(category.titlePlaceholder, text: $title)
                    .foregroundColor(.white)
                    .font(.headline)
            }

            // Gym picker
            Button { showGymPicker = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.gymLinkPink)
                        .frame(width: 20)
                    Text(gymTag.isEmpty ? "Tag a gym (optional)" : gymTag)
                        .foregroundColor(gymTag.isEmpty ? Color(white: 0.4) : .white)
                        .font(.subheadline)
                    Spacer()
                    if !gymTag.isEmpty {
                        Button {
                            gymTag = ""
                            gymLat = nil
                            gymLon = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.38))
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.3))
                    }
                }
                .padding(14)
                .background(Color(white: 0.11))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showGymPicker) {
                GymPickerSheet { detail in
                    gymTag = detail.name
                    gymLat = detail.coordinate.latitude
                    gymLon = detail.coordinate.longitude
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }

            // Workout type chips
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Workout Type")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(WorkoutTypes.all, id: \.self) { type in
                            PostChip(label: type, isSelected: selectedWorkoutType == type) {
                                selectedWorkoutType = type
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
            }

            inputCard {
                TextField(category.descriptionPlaceholder, text: $description, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .foregroundColor(.white)
            }

            // PR / Progression toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPRSection.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showPRSection ? "chevron.up" : "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                    Text(showPRSection ? "Hide PR Logger" : "Log a PR / Progression")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                    Spacer()
                }
                .padding(14)
                .background(Color.gymLinkPink.opacity(0.1))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gymLinkPink.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showPRSection {
                VStack(spacing: 10) {
                    inputCard {
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.gymLinkPink)
                                .frame(width: 20)
                            TextField("Exercise (e.g. Bench Press)", text: $prExercise)
                                .foregroundColor(.white)
                        }
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Previous")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(white: 0.4))
                            TextField("185", text: $prPrev)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(white: 0.11))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Image(systemName: "arrow.right")
                            .foregroundColor(Color(white: 0.35))
                            .padding(.top, 18)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("New")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(white: 0.4))
                            TextField("195", text: $prNew)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(white: 0.11))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }

                    HStack {
                        Text("Unit").foregroundColor(Color(white: 0.55))
                        Spacer()
                        Picker("Unit", selection: $prUnit) {
                            ForEach(prUnits, id: \.self) { Text($0) }
                        }
                        .tint(.gymLinkPink)
                    }
                    .padding(12)
                    .background(Color(white: 0.11))
                    .cornerRadius(12)

                    if let prev = Double(prPrev), let newVal = Double(prNew), newVal > prev {
                        let delta = newVal - prev
                        let sign = delta >= 0 ? "+" : ""
                        let fmt = delta.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(delta))" : String(format: "%.1f", delta)
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundColor(.gymLinkPink).font(.system(size: 12))
                            Text("\(sign)\(fmt) \(prUnit) improvement")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.gymLinkPink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.gymLinkPink.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Star rating — only shown once a gym is tagged
            if !gymTag.isEmpty {
                VStack(spacing: 10) {
                    Text("Rate \(gymTag)")
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundColor(Color(white: 0.48))
                    HStack(spacing: 10) {
                        ForEach(1..<6) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(star <= Int(rating) ? .gymLinkPink : Color(white: 0.28))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                        rating = Double(star)
                                    }
                                }
                        }
                    }
                    Text("\(Int(rating)) / 5")
                        .font(.caption).foregroundColor(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(white: 0.11))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Meal fields
    @ViewBuilder
    private var mealFields: some View {
        VStack(spacing: 12) {
            inputCard {
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gymLinkPink)
                        .frame(width: 20)
                    TextField(category.titlePlaceholder, text: $title)
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Meal Type")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealTypes.all, id: \.self) { type in
                            PostChip(label: type, isSelected: selectedMealType == type) {
                                selectedMealType = type
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
            }

            // Macros
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Macros (optional)")
                HStack(spacing: 8) {
                    macroInput("Calories", unit: "kcal", text: $mealCalories, color: .gymLinkPink)
                    macroInput("Protein",  unit: "g",    text: $mealProtein,  color: Color(red: 0.35, green: 0.72, blue: 1.0))
                    macroInput("Carbs",    unit: "g",    text: $mealCarbs,    color: Color(red: 1.0, green: 0.76, blue: 0.2))
                    macroInput("Fat",      unit: "g",    text: $mealFat,      color: Color(red: 1.0, green: 0.46, blue: 0.3))
                }
            }

            inputCard {
                TextField(category.descriptionPlaceholder, text: $description, axis: .vertical)
                    .lineLimit(5, reservesSpace: true)
                    .foregroundColor(.white)
            }
        }
    }

    private func macroInput(_ label: String, unit: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .semibold))
                .frame(height: 36)
                .background(Color(white: 0.11))
                .cornerRadius(10)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(Color(white: 0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress fields
    @ViewBuilder
    private var progressFields: some View {
        VStack(spacing: 12) {
            inputCard {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.gymLinkPink)
                        .frame(width: 20)
                    TextField(category.titlePlaceholder, text: $title)
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Progress Type")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProgressTypes.all, id: \.self) { type in
                            PostChip(label: type, isSelected: selectedProgressType == type) {
                                selectedProgressType = type
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
            }

            inputCard {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundColor(.gymLinkPink)
                        .frame(width: 20)
                    TextField("Time period (e.g. 3 months)", text: $timePeriod)
                        .foregroundColor(.white)
                }
            }

            inputCard {
                TextField(category.descriptionPlaceholder, text: $description, axis: .vertical)
                    .lineLimit(5, reservesSpace: true)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Other fields
    @ViewBuilder
    private var otherFields: some View {
        VStack(spacing: 12) {
            inputCard {
                TextField(category.titlePlaceholder, text: $title)
                    .foregroundColor(.white)
                    .font(.headline)
            }

            inputCard {
                TextField(category.descriptionPlaceholder, text: $description, axis: .vertical)
                    .lineLimit(6, reservesSpace: true)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Post button
    private var postButton: some View {
        Button(action: submitPost) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(canPost ? Color.gymLinkPink : Color(white: 0.18))
                    .frame(height: 54)
                    .shadow(color: canPost ? Color.gymLinkPink.opacity(0.4) : .clear,
                            radius: 12, x: 0, y: 4)

                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text("Post")
                            .font(.headline)
                    }
                    .foregroundColor(canPost ? .white : Color(white: 0.38))
                }
            }
        }
        .disabled(!canPost || isSubmitting)
        .animation(.easeInOut(duration: 0.2), value: canPost)
    }

    private var canPost: Bool { !title.isEmpty && !description.isEmpty }

    // MARK: - Section label helper
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote).fontWeight(.semibold)
            .foregroundColor(Color(white: 0.48))
            .padding(.leading, 2)
    }

    // MARK: - Submit
    private func submitPost() {
        guard canPost else { return }
        isSubmitting = true
        errorMessage = ""
        if let imageData = selectedImageData {
            uploadImageAndSavePost(imageData: imageData)
        } else {
            savePostToFirestore(imageURL: nil)
        }
    }

    private func uploadImageAndSavePost(imageData: Data) {
        guard let original = UIImage(data: imageData) else {
            errorMessage = "Invalid image data."
            isSubmitting = false
            return
        }
        let resized = original.resized(toMax: 1400)
        guard let compressed = resized.jpegData(compressionQuality: 0.75) else {
            errorMessage = "Failed to compress image."
            isSubmitting = false
            return
        }
        let imageID = UUID().uuidString
        let storageRef = Storage.storage().reference().child("postImages/\(imageID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let uploadTask = storageRef.putData(compressed, metadata: metadata)
        uploadTask.observe(.success) { _ in
            storageRef.downloadURL { url, error in
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                        isSubmitting = false
                    }
                    return
                }
                savePostToFirestore(imageURL: url?.absoluteString)
            }
        }
        uploadTask.observe(.failure) { snap in
            DispatchQueue.main.async {
                errorMessage = snap.error?.localizedDescription ?? "Upload failed."
                isSubmitting = false
            }
        }
    }

    private func savePostToFirestore(imageURL: String?) {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be logged in to post."
            isSubmitting = false
            return
        }

        let subtype: String
        switch category {
        case .workout:  subtype = selectedWorkoutType
        case .meal:     subtype = selectedMealType
        case .progress: subtype = selectedProgressType
        case .other:    subtype = ""
        }

        PostManager.shared.addPost(
            title: title,
            content: description,
            imageURL: imageURL,
            gym: gymTag.isEmpty ? nil : gymTag,
            rating: gymTag.isEmpty ? nil : rating,
            gymLat: gymLat,
            gymLon: gymLon,
            category: category.rawValue,
            foodType: subtype,
            mealCalories: Int(mealCalories),
            mealProtein: Int(mealProtein),
            mealCarbs: Int(mealCarbs),
            mealFat: Int(mealFat),
            exerciseName: prExercise.trimmingCharacters(in: .whitespaces).isEmpty ? nil : prExercise.trimmingCharacters(in: .whitespaces),
            previousValue: Double(prPrev),
            newValue: Double(prNew),
            progressionUnit: showPRSection && !prExercise.isEmpty ? prUnit : nil
        ) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    print("Post saved for user \(user.uid)")
                    dismiss()
                case .failure(let error):
                    errorMessage = "Failed to save post: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Gym picker sheet (simple search list, no map)

struct GymPickerSheet: View {
    var onSelect: (GymDetail) -> Void

    @StateObject private var locationMgr = LocationManager()
    @State private var searchText = ""
    @State private var results: [GymResult] = []
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    private let gymManager = GymSearchManager()

    private var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: locationMgr.location?.coordinate ?? CLLocationCoordinate2D(latitude: 34.2411, longitude: -119.0434),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.gymLinkPink)
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 36))
                                .foregroundColor(Color(white: 0.25))
                            Text("No gyms found nearby")
                                .font(.subheadline)
                                .foregroundColor(Color(white: 0.35))
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(results) { gym in
                                    Button {
                                        onSelect(GymDetail(item: gym.item))
                                        dismiss()
                                    } label: {
                                        gymRow(gym)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Tag a Gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gymLinkPink)
                }
            }
        }
        .onAppear { loadNearby() }
        .onChange(of: locationMgr.location) {
            guard !hasLoaded else { return }
            loadNearby()
        }
    }

    @State private var hasLoaded = false

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gymLinkPink)
                .font(.system(size: 14))
            TextField("Search gyms...", text: $searchText)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .onChange(of: searchText) { doSearch() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(Color(white: 0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }

    private func gymRow(_ gym: GymResult) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gymLinkPink.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(.gymLinkPink)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(gym.item.name ?? "Gym")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let addr = gym.item.placemark.title {
                    Text(addr)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.38))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.gymLinkPink.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.08))
    }

    private func loadNearby() {
        hasLoaded = true
        isLoading = true
        gymManager.searchGyms(query: nil, region: defaultRegion) { found in
            DispatchQueue.main.async { results = found; isLoading = false }
        }
    }

    private func doSearch() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { loadNearby(); return }
        isLoading = true
        gymManager.searchGyms(query: q, region: defaultRegion) { found in
            DispatchQueue.main.async { results = found; isLoading = false }
        }
    }
}

// MARK: - Chip view
struct PostChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gymLinkPink : Color(white: 0.15))
                .foregroundColor(isSelected ? .white : Color(white: 0.62))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color(white: 0.22),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
