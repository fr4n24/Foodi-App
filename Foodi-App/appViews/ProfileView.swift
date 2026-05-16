import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import MapKit

private let workoutSplits = ["PPL", "Upper/Lower", "Full Body", "Bro Split", "5x5", "Push/Pull", "Custom"]
private let weekDays      = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentUser: User? = AuthManager.shared.getCurrentUser()

    // Profile data
    @State private var username      = ""
    @State private var fullName      = ""
    @State private var bio           = ""
    @State private var profileImageURL: URL?
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var posts: [Post] = []
    @State private var isLoadingProfile = false
    @State private var errorMessage  = ""

    // Extended fields
    @State private var currentGym    = ""
    @State private var currentGymLat: Double? = nil
    @State private var currentGymLon: Double? = nil
    @State private var workoutSplit  = ""
    @State private var trainingDays: [String] = []
    @State private var workoutTimes: [String] = []
    @State private var savedGyms: [GymDetail] = []

    @State private var workoutStreak  = 0

    // Edit sheet state
    @State private var showEditSheet  = false
    @State private var showGymPicker  = false
    @State private var editFullName   = ""
    @State private var editBio        = ""
    @State private var editGym        = ""
    @State private var editGymLat: Double? = nil
    @State private var editGymLon: Double? = nil
    @State private var editSplit      = ""
    @State private var editDays: [String] = []
    @State private var editTimes: [String] = []
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var isUpdating     = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoadingProfile {
                    ProgressView().tint(.gymLinkPink)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            profileHeader
                            statsRow.padding(.top, 20)
                            infoSections.padding(.top, 16)
                            postsSection.padding(.top, 20)
                            savedGymsSection.padding(.top, 20)
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sign Out") { _ = AuthManager.shared.signOut() }
                        .foregroundColor(Color(white: 0.45))
                        .font(.system(size: 14))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        editFullName = fullName
                        editBio      = bio
                        editGym      = currentGym
                        editGymLat   = currentGymLat
                        editGymLon   = currentGymLon
                        editSplit    = workoutSplit
                        editDays     = trainingDays
                        editTimes    = workoutTimes
                        selectedImage = nil
                        showEditSheet = true
                    }
                    .foregroundColor(.gymLinkPink)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showEditSheet) { editSheet }
            .onAppear { loadUserProfile(); loadSavedGyms() }
        }
    }

    // MARK: - Profile header
    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(Color.gymLinkPink.opacity(0.5), lineWidth: 2))

                if let url = profileImageURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { avatarPlaceholder }
                        .frame(width: 96, height: 96).clipShape(Circle())
                } else {
                    avatarPlaceholder
                }
            }
            .padding(.top, 24)

            Text(fullName.isEmpty ? username : fullName)
                .font(.system(size: 22, weight: .bold)).foregroundColor(.white)

            if !username.isEmpty {
                Text("@\(username)")
                    .font(.subheadline).foregroundColor(Color(white: 0.45))
            }

            if !bio.isEmpty {
                Text(bio)
                    .font(.subheadline).foregroundColor(Color(white: 0.55))
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
            }

            if workoutStreak >= 2 {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(workoutStreak)-day streak")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.1))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(red: 1.0, green: 0.5, blue: 0.1).opacity(0.12))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 38)).foregroundColor(Color(white: 0.38))
    }

    // MARK: - Stats row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(posts.count)", label: "Posts")
            Divider().frame(height: 28).background(Color(white: 0.2))
            statItem(value: "\(followersCount)", label: "Followers")
            Divider().frame(height: 28).background(Color(white: 0.2))
            statItem(value: "\(followingCount)", label: "Following")
        }
        .padding(.vertical, 14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(Color(white: 0.45))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Info sections
    @ViewBuilder
    private var infoSections: some View {
        VStack(spacing: 10) {
            // Current gym
            profileCard(icon: "mappin.and.ellipse", title: "Currently Training At") {
                if currentGym.isEmpty {
                    Text("Not set — tap Edit to add")
                        .font(.subheadline).foregroundColor(Color(white: 0.35))
                } else {
                    Text(currentGym)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
            }

            // Workout split
            profileCard(icon: "dumbbell.fill", title: "Workout Split") {
                if workoutSplit.isEmpty {
                    Text("Not set — tap Edit to add")
                        .font(.subheadline).foregroundColor(Color(white: 0.35))
                } else {
                    Text(workoutSplit)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.gymLinkPink)
                }
            }

            // Training days
            profileCard(icon: "calendar", title: "Training Days") {
                HStack(spacing: 6) {
                    ForEach(weekDays, id: \.self) { day in
                        let active = trainingDays.contains(day)
                        Text(String(day.prefix(1)))
                            .font(.system(size: 12, weight: active ? .bold : .regular))
                            .foregroundColor(active ? .white : Color(white: 0.32))
                            .frame(width: 30, height: 30)
                            .background(active ? Color.gymLinkPink : Color(white: 0.14))
                            .clipShape(Circle())
                    }
                    if trainingDays.isEmpty {
                        Text("Not set — tap Edit to add")
                            .font(.caption).foregroundColor(Color(white: 0.35))
                    }
                }
            }

            // Workout times
            profileCard(icon: "clock.fill", title: "Workout Times") {
                if workoutTimes.isEmpty {
                    Text("Not set — tap Edit to add")
                        .font(.subheadline).foregroundColor(Color(white: 0.35))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(workoutTimes, id: \.self) { slot in
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gymLinkPink)
                                Text(slot)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func profileCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundColor(.gymLinkPink)
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(white: 0.45))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(14)
    }

    // MARK: - Posts section
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Posts")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 20)

            if posts.isEmpty {
                Text("No posts yet")
                    .font(.subheadline).foregroundColor(Color(white: 0.35))
                    .frame(maxWidth: .infinity).padding(.top, 8)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(posts) { post in
                        NavigationLink { PostDetailView(post: post) } label: {
                            darkPostCard(post: post)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let uid = currentUser?.uid, post.authorId == uid {
                                Button(role: .destructive) {
                                    PostManager.shared.deletePost(post) { _ in loadUserPosts(uid: uid) }
                                } label: { Label("Delete Post", systemImage: "trash") }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func darkPostCard(post: Post) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let urlStr = post.imageURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                    placeholder: { Color(white: 0.1) }
                    .frame(height: 160).clipped().cornerRadius(12)
            }
            Text(post.title)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.subheadline).foregroundColor(Color(white: 0.5)).lineLimit(2)
            }
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Saved gyms section
    private var savedGymsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Gyms")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 20)

            if savedGyms.isEmpty {
                Text("No saved gyms yet")
                    .font(.subheadline).foregroundColor(Color(white: 0.35))
                    .frame(maxWidth: .infinity).padding(.top, 8)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(savedGyms, id: \.name) { gym in
                        NavigationLink { GymProfileView(gym: gym) } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gymLinkPink.opacity(0.15))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.gymLinkPink)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(gym.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    Text(gym.address).font(.caption).foregroundColor(Color(white: 0.45)).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Color(white: 0.25))
                            }
                            .padding(14)
                            .background(Color(white: 0.09))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Edit sheet
    private var editSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Profile photo
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let img = selectedImage {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 90, height: 90).clipShape(Circle())
                                } else if let url = profileImageURL {
                                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                        placeholder: { Color(white: 0.15) }
                                        .frame(width: 90, height: 90).clipShape(Circle())
                                } else {
                                    Circle().fill(Color(white: 0.15)).frame(width: 90, height: 90)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(Color(white: 0.4)).font(.system(size: 32)))
                                }
                            }
                            .overlay(Circle().stroke(Color.gymLinkPink.opacity(0.5), lineWidth: 2))

                            Button { showImagePicker = true } label: {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 26)).foregroundColor(.gymLinkPink)
                                    .background(Circle().fill(Color.black).padding(2))
                            }
                        }
                        .frame(width: 90, height: 90)
                        .padding(.top, 16)

                        // Name & bio
                        editSection(title: "ABOUT") {
                            editField(icon: "person.fill", placeholder: "Full name", text: $editFullName)
                            editField(icon: "text.quote", placeholder: "Bio", text: $editBio, multiline: true)
                        }

                        // Current gym
                        editSection(title: "CURRENT GYM") {
                            Button { showGymPicker = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.and.ellipse").foregroundColor(.gymLinkPink).frame(width: 22)
                                    Text(editGym.isEmpty ? "Pick a gym from the map" : editGym)
                                        .foregroundColor(editGym.isEmpty ? Color(white: 0.38) : .white)
                                    Spacer()
                                    if !editGym.isEmpty {
                                        Button { editGym = ""; editGymLat = nil; editGymLon = nil } label: {
                                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundColor(Color(white: 0.38))
                                        }
                                    } else {
                                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Color(white: 0.28))
                                    }
                                }
                                .padding(14)
                                .background(Color(white: 0.11))
                                .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }

                        // Workout split
                        editSection(title: "WORKOUT SPLIT") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(workoutSplits, id: \.self) { s in
                                        PostChip(label: s, isSelected: editSplit == s) { editSplit = s }
                                    }
                                }
                                .padding(.horizontal, 1).padding(.vertical, 2)
                            }
                        }

                        // Training days
                        editSection(title: "TRAINING DAYS") {
                            HStack(spacing: 8) {
                                ForEach(weekDays, id: \.self) { day in
                                    let on = editDays.contains(day)
                                    Button {
                                        if on { editDays.removeAll { $0 == day } } else { editDays.append(day) }
                                    } label: {
                                        Text(String(day.prefix(1)))
                                            .font(.system(size: 13, weight: on ? .bold : .regular))
                                            .foregroundColor(on ? .white : Color(white: 0.38))
                                            .frame(width: 36, height: 36)
                                            .background(on ? Color.gymLinkPink : Color(white: 0.14))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Workout times
                        editSection(title: "WORKOUT TIMES") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("When do you usually train?")
                                    .font(.caption)
                                    .foregroundColor(Color(white: 0.42))
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(WorkoutTimeSlots.all, id: \.self) { slot in
                                        let on = editTimes.contains(slot)
                                        Button {
                                            if on { editTimes.removeAll { $0 == slot } } else { editTimes.append(slot) }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(on ? .gymLinkPink : Color(white: 0.3))
                                                Text(slot)
                                                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                                                    .foregroundColor(on ? .white : Color(white: 0.5))
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                Spacer()
                                            }
                                            .padding(10)
                                            .background(on ? Color.gymLinkPink.opacity(0.15) : Color(white: 0.11))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(on ? Color.gymLinkPink.opacity(0.4) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .animation(.easeInOut(duration: 0.12), value: on)
                                    }
                                }
                            }
                        }

                        // Save
                        Button(action: saveProfile) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gymLinkPink)
                                    .frame(height: 52)
                                    .shadow(color: Color.gymLinkPink.opacity(0.4), radius: 10, y: 4)
                                if isUpdating {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save Changes")
                                        .font(.headline).foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isUpdating)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showEditSheet = false }
                        .foregroundColor(.gymLinkPink)
                }
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(image: $selectedImage) }
            .fullScreenCover(isPresented: $showGymPicker) {
                MapWidgetView { detail in
                    editGym    = detail.name
                    editGymLat = detail.coordinate.latitude
                    editGymLon = detail.coordinate.longitude
                    showGymPicker = false
                }
            }
        }
    }

    private func editSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .padding(.leading, 2)
            content()
        }
    }

    private func editField(icon: String, placeholder: String, text: Binding<String>, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gymLinkPink)
                .frame(width: 22)
                .padding(.top, multiline ? 2 : 0)
            if multiline {
                TextField(placeholder, text: text, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: text)
                    .foregroundColor(.white)
            }
        }
        .padding(14)
        .background(Color(white: 0.11))
        .cornerRadius(14)
    }

    // MARK: - Data loading
    private func loadUserProfile() {
        guard let uid = currentUser?.uid else { return }
        isLoadingProfile = true
        db.collection("users").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else {
                DispatchQueue.main.async { isLoadingProfile = false }
                return
            }
            DispatchQueue.main.async {
                fullName     = data["fullName"] as? String ?? ""
                bio          = data["bio"] as? String ?? ""
                username     = data["username"] as? String ?? ""
                currentGym   = data["currentGym"] as? String ?? ""
                currentGymLat = data["currentGymLat"] as? Double
                currentGymLon = data["currentGymLon"] as? Double
                workoutSplit = data["workoutSplit"] as? String ?? ""
                trainingDays = data["trainingDays"] as? [String] ?? []
                workoutTimes = data["workoutTimes"] as? [String] ?? []
                if let s = data["profilePicURL"] as? String, !s.isEmpty, let url = URL(string: s) {
                    profileImageURL = url
                }
                let metrics = data["metrics"] as? [String: Any]
                let streakA = metrics?["currentStreak"] as? Int ?? 0
                let streakB = data["workoutStreak"] as? Int ?? 0
                workoutStreak = max(streakA, streakB)
            }
            // Followers
            let followRef = self.db.collection("users").document(uid)
            followRef.collection("followers").getDocuments { snap, _ in
                DispatchQueue.main.async { followersCount = snap?.count ?? 0 }
            }
            followRef.collection("following").getDocuments { snap, _ in
                DispatchQueue.main.async { followingCount = snap?.count ?? 0 }
                self.loadUserPosts(uid: uid)
            }
        }
    }

    private func loadUserPosts(uid: String) {
        db.collection("posts")
            .whereField("authorId", isEqualTo: uid)
            .getDocuments { snap, error in
                if let error { print("loadUserPosts error:", error.localizedDescription) }
                let fetched = (snap?.documents.compactMap { doc -> Post? in
                    let d = doc.data()
                    return Post(id: doc.documentID,
                                title: d["title"] as? String ?? "",
                                content: d["content"] as? String ?? "",
                                imageURL: d["imageURL"] as? String,
                                author: d["author"] as? String ?? "",
                                authorId: d["authorId"] as? String ?? "",
                                gym: d["gym"] as? String,
                                rating: d["rating"] as? Double ?? 0,
                                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date())
                } ?? []).sorted { $0.timestamp > $1.timestamp }
                DispatchQueue.main.async {
                    posts = fetched
                    isLoadingProfile = false
                }
            }
    }

    private func loadSavedGyms() {
        SavedManager.shared.fetchSaveds { list in
            DispatchQueue.main.async { savedGyms = list }
        }
    }

    // MARK: - Save profile
    private func saveProfile() {
        guard let uid = currentUser?.uid else { return }
        isUpdating = true

        func persist(imageURL: String?) {
            var patch: [String: Any] = [
                "fullName":     editFullName,
                "bio":          editBio,
                "currentGym":   editGym,
                "workoutSplit": editSplit,
                "trainingDays": editDays,
                "workoutTimes": editTimes
            ]
            if let lat = editGymLat { patch["currentGymLat"] = lat }
            if let lon = editGymLon { patch["currentGymLon"] = lon }
            if let url = imageURL   { patch["profilePicURL"] = url }

            print("[ProfileSave] Writing to Firestore, imageURL: \(imageURL ?? "nil")")
            db.collection("users").document(uid).setData(patch, merge: true) { err in
                if let err = err { print("[ProfileSave] Firestore write error: \(err)") }
                else { print("[ProfileSave] Firestore write succeeded") }
                DispatchQueue.main.async {
                    isUpdating    = false
                    fullName      = editFullName
                    bio           = editBio
                    currentGym    = editGym
                    currentGymLat = editGymLat
                    currentGymLon = editGymLon
                    workoutSplit  = editSplit
                    trainingDays  = editDays
                    workoutTimes  = editTimes
                    if let url = imageURL { profileImageURL = URL(string: url) }
                    showEditSheet = false
                }
            }
        }

        if let img = selectedImage, let data = img.jpegData(compressionQuality: 0.8) {
            print("[ProfileSave] Starting upload for uid: \(uid), dataSize: \(data.count)")
            let ref = Storage.storage().reference().child("profilePictures/\(uid).jpg")
            let task = ref.putData(data, metadata: nil)

            task.observe(.success) { _ in
                print("[ProfileSave] Upload succeeded, fetching downloadURL")
                ref.downloadURL { url, urlErr in
                    if let urlErr = urlErr {
                        print("[ProfileSave] downloadURL error: \(urlErr)")
                        DispatchQueue.main.async { isUpdating = false }
                        return
                    }
                    guard let url = url else {
                        print("[ProfileSave] downloadURL returned nil with no error")
                        DispatchQueue.main.async { isUpdating = false }
                        return
                    }
                    print("[ProfileSave] Got downloadURL: \(url), calling persist")
                    persist(imageURL: url.absoluteString)
                }
            }

            task.observe(.failure) { snapshot in
                let err = snapshot.error as NSError?
                print("[ProfileSave] Upload failed — domain: \(err?.domain ?? "nil"), code: \(err?.code ?? -1), msg: \(err?.localizedDescription ?? "nil")")
                guard let err = err,
                      err.domain == "com.google.HTTPStatus",
                      err.code == 400 else {
                    DispatchQueue.main.async { isUpdating = false }
                    return
                }
                print("[ProfileSave] Already-finalized 400 — fetching downloadURL anyway")
                ref.downloadURL { url, urlErr in
                    if let urlErr = urlErr {
                        print("[ProfileSave] downloadURL (after 400) error: \(urlErr)")
                        DispatchQueue.main.async { isUpdating = false }
                        return
                    }
                    guard let url = url else {
                        print("[ProfileSave] downloadURL (after 400) returned nil")
                        DispatchQueue.main.async { isUpdating = false }
                        return
                    }
                    print("[ProfileSave] Got downloadURL after 400: \(url), calling persist")
                    persist(imageURL: url.absoluteString)
                }
            }
        } else {
            print("[ProfileSave] No image selected, persisting profile only")
            persist(imageURL: nil)
        }
    }

    private func handleSignOut() {
        _ = AuthManager.shared.signOut()
    }
}

// MARK: - UIKit Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.delegate = context.coordinator; p.allowsEditing = true; return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.presentationMode.wrappedValue.dismiss() }
    }
}
