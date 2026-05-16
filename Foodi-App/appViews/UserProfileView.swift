import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

struct UserProfileView: View {
    let userId: String

    @State private var username       = ""
    @State private var fullName       = ""
    @State private var bio            = ""
    @State private var profileImageURL: String?
    @State private var followers      = 0
    @State private var following      = 0
    @State private var posts: [Post]  = []
    @State private var isFollowing    = false
    @State private var isLoading      = true

    // Extended profile fields
    @State private var currentGym     = ""
    @State private var currentGymLat: Double? = nil
    @State private var currentGymLon: Double? = nil
    @State private var workoutSplit   = ""
    @State private var trainingDays: [String] = []

    private let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(.gymLinkPink)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        profileHeader
                        statsRow
                            .padding(.top, 20)

                        if Auth.auth().currentUser?.uid != userId {
                            followButton
                                .padding(.top, 16)
                                .padding(.horizontal, 20)
                        }

                        infoSections
                            .padding(.top, 20)

                        postsSection
                            .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(username.isEmpty ? "Profile" : "@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfile()
            loadPosts()
            loadFollowerCounts()
            checkIfFollowing()
        }
    }

    // MARK: - Profile header
    private var profileHeader: some View {
        VStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(Color.gymLinkPink.opacity(0.5), lineWidth: 2))

                if let urlStr = profileImageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "person.fill").font(.system(size: 36)).foregroundColor(Color(white: 0.4)) }
                        .frame(width: 92, height: 92).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            .padding(.top, 24)

            Text(fullName.isEmpty ? username : fullName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            if !username.isEmpty && !fullName.isEmpty {
                Text("@\(username)")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.45))
            }

            if !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(posts.count)", label: "Posts")
            Divider().frame(height: 30).background(Color(white: 0.2))
            statItem(value: "\(followers)", label: "Followers")
            Divider().frame(height: 30).background(Color(white: 0.2))
            statItem(value: "\(following)", label: "Following")
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

    // MARK: - Follow button
    private var followButton: some View {
        Button(action: toggleFollow) {
            Text(isFollowing ? "Following" : "Follow")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFollowing ? Color(white: 0.6) : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isFollowing ? Color(white: 0.14) : Color.gymLinkPink)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isFollowing ? Color(white: 0.25) : Color.clear, lineWidth: 1)
                )
        }
    }

    // MARK: - Info sections (gym / split / schedule)
    @ViewBuilder
    private var infoSections: some View {
        VStack(spacing: 10) {
            if !currentGym.isEmpty {
                profileInfoCard(icon: "mappin.and.ellipse", title: "Currently Training At") {
                    HStack {
                        Text(currentGym)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }

            if !workoutSplit.isEmpty {
                profileInfoCard(icon: "dumbbell.fill", title: "Workout Split") {
                    Text(workoutSplit)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                }
            }

            if !trainingDays.isEmpty {
                profileInfoCard(icon: "calendar", title: "Training Days") {
                    HStack(spacing: 6) {
                        ForEach(allDays, id: \.self) { day in
                            let active = trainingDays.contains(day)
                            Text(String(day.prefix(1)))
                                .font(.system(size: 12, weight: active ? .bold : .regular))
                                .foregroundColor(active ? .white : Color(white: 0.35))
                                .frame(width: 30, height: 30)
                                .background(active ? Color.gymLinkPink : Color(white: 0.15))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func profileInfoCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gymLinkPink)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(white: 0.45))
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
            HStack {
                Text("Posts")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)

            if posts.isEmpty {
                Text("No posts yet")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(posts) { post in
                        NavigationLink { PostDetailView(post: post) } label: {
                            darkPostCard(post: post)
                        }
                        .buttonStyle(.plain)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.5))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Data loading
    private func loadProfile() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snap, _ in
            guard let data = snap?.data() else {
                DispatchQueue.main.async { isLoading = false }
                return
            }
            DispatchQueue.main.async {
                username       = data["username"] as? String ?? ""
                fullName       = data["fullName"] as? String ?? ""
                bio            = data["bio"] as? String ?? ""
                profileImageURL = data["profilePicURL"] as? String
                currentGym     = data["currentGym"] as? String ?? ""
                currentGymLat  = data["currentGymLat"] as? Double
                currentGymLon  = data["currentGymLon"] as? Double
                workoutSplit   = data["workoutSplit"] as? String ?? ""
                trainingDays   = data["trainingDays"] as? [String] ?? []
                isLoading      = false
            }
        }
    }

    private func loadPosts() {
        let db = Firestore.firestore()
        db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snap, _ in
                let fetched = snap?.documents.compactMap { doc -> Post? in
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
                } ?? []
                DispatchQueue.main.async { posts = fetched }
            }
    }

    private func loadFollowerCounts() {
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("followers").getDocuments { snap, _ in
            DispatchQueue.main.async { followers = snap?.count ?? 0 }
        }
        db.collection("users").document(userId).collection("following").getDocuments { snap, _ in
            DispatchQueue.main.async { following = snap?.count ?? 0 }
        }
    }

    private func checkIfFollowing() {
        guard let me = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users").document(userId).collection("followers").document(me)
            .getDocument { snap, _ in
                DispatchQueue.main.async { isFollowing = snap?.exists == true }
            }
    }

    private func toggleFollow() {
        guard let me = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let followerRef = db.collection("users").document(userId).collection("followers").document(me)
        let followingRef = db.collection("users").document(me).collection("following").document(userId)

        if isFollowing {
            followerRef.delete(); followingRef.delete()
            isFollowing = false; followers = max(0, followers - 1)
        } else {
            followerRef.setData([:]) { _ in
                followingRef.setData([:]) { _ in
                    DispatchQueue.main.async { isFollowing = true; followers += 1 }
                    if userId != me {
                        db.collection("users").document(me).getDocument { snap, _ in
                            let fromUsername = snap?.data()?["username"] as? String ?? "Someone"
                            db.collection("users").document(userId).collection("notifications")
                                .addDocument(data: [
                                    "type": "follow",
                                    "fromUserId": me,
                                    "fromUsername": fromUsername,
                                    "timestamp": Timestamp(date: Date()),
                                    "read": false
                                ])
                        }
                    }
                }
            }
        }
    }
}
