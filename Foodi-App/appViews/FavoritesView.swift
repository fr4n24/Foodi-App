// GymLink-App/appViews/FavoritesView.swift

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

// MARK: - Models

struct CustomFavoriteList: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let createdAt: Date
}

struct FavoritedProfile: Identifiable {
    let id: String
    let username: String
    let profilePicURL: String?
    let bio: String
}

// MARK: - Tab type

private enum FavTab: Hashable {
    case posts, gyms, profiles
    case custom(String) // list id

    var label: String {
        switch self {
        case .posts:        return "Posts"
        case .gyms:         return "Gyms"
        case .profiles:     return "People"
        case .custom:       return ""
        }
    }
}

// MARK: - Main view

struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: FavTab = .posts
    @State private var customLists: [CustomFavoriteList] = []

    @State private var savedPosts: [Post] = []
    @State private var savedGyms: [GymDetail] = []
    @State private var followedProfiles: [FavoritedProfile] = []

    @State private var showCreateSheet = false
    @State private var newListName = ""
    @State private var newListEmoji = "⭐"

    private let db = Firestore.firestore()

    private let emojiOptions = ["⭐","🏋️","🥗","💪","📍","🔥","🏆","📌","❤️","✅"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabBar
                        .padding(.top, 6)

                    Divider()
                        .background(Color(white: 0.18))

                    tabContent
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.gymLinkPink)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                createListSheet
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            loadSavedPosts()
            loadSavedGyms()
            loadFollowedProfiles()
            loadCustomLists()
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabPill(tab: .posts,    label: "Posts",    icon: "doc.text.fill")
                tabPill(tab: .gyms,     label: "Gyms",     icon: "mappin.and.ellipse")
                tabPill(tab: .profiles, label: "People", icon: "person.2.fill")

                ForEach(customLists) { list in
                    customTabPill(list: list)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func tabPill(tab: FavTab, label: String, icon: String) -> some View {
        let active = selectedTab == tab
        return Button { selectedTab = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(active ? .white : Color(white: 0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? Color.gymLinkPink : Color(white: 0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func customTabPill(list: CustomFavoriteList) -> some View {
        let active = selectedTab == .custom(list.id)
        return Button { selectedTab = .custom(list.id) } label: {
            HStack(spacing: 5) {
                Text(list.emoji)
                    .font(.system(size: 13))
                Text(list.name)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(active ? .white : Color(white: 0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? Color.gymLinkPink : Color(white: 0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteCustomList(list)
            } label: {
                Label("Delete List", systemImage: "trash")
            }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .posts:
            postsTab
        case .gyms:
            gymsTab
        case .profiles:
            profilesTab
        case .custom(let listId):
            if let list = customLists.first(where: { $0.id == listId }) {
                customListTab(list: list)
            }
        }
    }

    // MARK: - Posts tab

    private var postsTab: some View {
        Group {
            if savedPosts.isEmpty {
                emptyState(icon: "bookmark.slash", message: "No saved posts yet", hint: "Bookmark posts to see them here")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(savedPosts) { post in
                            NavigationLink(destination: PostDetailView(post: post)) {
                                savedPostRow(post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func savedPostRow(_ post: Post) -> some View {
        HStack(spacing: 14) {
            if let urlString = post.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color(white: 0.15)
                    }
                }
                .frame(width: 64, height: 64)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gymLinkPink.opacity(0.14))
                        .frame(width: 64, height: 64)
                    Image(systemName: "photo")
                        .foregroundColor(.gymLinkPink)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(post.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(post.content)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(2)
                if let gym = post.gym, !gym.isEmpty {
                    Label(gym, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.gymLinkPink)
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.3))
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Gyms tab

    private var gymsTab: some View {
        Group {
            if savedGyms.isEmpty {
                emptyState(icon: "mappin.slash", message: "No favorite gyms yet", hint: "Save gyms from the map to see them here")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(savedGyms, id: \.name) { gym in
                            savedGymRow(gym)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func savedGymRow(_ gym: GymDetail) -> some View {
        HStack(spacing: 14) {
            Map(position: .constant(.region(
                MKCoordinateRegion(
                    center: gym.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )))
            .disabled(true)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(gym.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(gym.address)
                    .font(.caption)
                    .foregroundColor(Color(white: 0.45))
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.gymLinkPink)
                .font(.system(size: 16))
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Profiles tab

    private var profilesTab: some View {
        Group {
            if followedProfiles.isEmpty {
                emptyState(icon: "person.slash", message: "Not following anyone yet", hint: "Follow GymLinkers to see them here")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(followedProfiles) { profile in
                            NavigationLink(destination: UserProfileView(userId: profile.id)) {
                                profileRow(profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func profileRow(_ profile: FavoritedProfile) -> some View {
        HStack(spacing: 14) {
            if let urlStr = profile.profilePicURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color(white: 0.2)
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gymLinkPink)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.username)
                    .font(.headline)
                    .foregroundColor(.white)
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.45))
                        .lineLimit(1)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.3))
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Custom list tab

    private func customListTab(list: CustomFavoriteList) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(list.emoji)
                .font(.system(size: 56))
            Text(list.name)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text("Coming soon — pin anything here")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.4))
            Spacer()
        }
    }

    // MARK: - Empty state

    private func emptyState(icon: String, message: String, hint: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundColor(Color(white: 0.25))
            Text(message)
                .font(.headline)
                .foregroundColor(Color(white: 0.4))
            Text(hint)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Create list sheet

    private var createListSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("New List")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 8)

                TextField("List name", text: $newListName)
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .foregroundColor(.white)

                Text("Choose an emoji")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.55))

                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button { newListEmoji = emoji } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(newListEmoji == emoji
                                              ? Color.gymLinkPink.opacity(0.25)
                                              : Color(white: 0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(newListEmoji == emoji ? Color.gymLinkPink : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    saveCustomList()
                    showCreateSheet = false
                } label: {
                    Text("Create List")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(newListName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray
                                    : Color.gymLinkPink)
                        .cornerRadius(14)
                }
                .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Firestore loaders

    private func loadSavedPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("savedPosts")
            .order(by: "timestamp", descending: true)
            .getDocuments { snap, _ in
                let postIds = snap?.documents.map(\.documentID) ?? []
                var result: [Post] = []
                let group = DispatchGroup()

                for postId in postIds {
                    group.enter()
                    db.collection("posts").document(postId).getDocument { doc, _ in
                        defer { group.leave() }
                        guard let data = doc?.data() else { return }
                        result.append(Post(
                            id: postId,
                            title: data["title"] as? String ?? "",
                            dishName: nil,
                            content: data["content"] as? String ?? "",
                            imageURL: data["imageURL"] as? String,
                            author: data["author"] as? String ?? "",
                            authorId: data["authorId"] as? String ?? "",
                            gymName: data["gymName"] as? String,
                            gym: data["gym"] as? String,
                            rating: data["rating"] as? Double,
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                            gymLat: data["gymLat"] as? Double,
                            gymLon: data["gymLon"] as? Double
                        ))
                    }
                }

                group.notify(queue: .main) { savedPosts = result }
            }
    }

    private func loadSavedGyms() {
        SavedManager.shared.fetchSaveds { gyms in
            DispatchQueue.main.async { savedGyms = gyms }
        }
    }

    private func loadFollowedProfiles() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("following")
            .getDocuments { snap, _ in
                let followedIds = snap?.documents.map(\.documentID) ?? []
                var profiles: [FavoritedProfile] = []
                let group = DispatchGroup()

                for userId in followedIds {
                    group.enter()
                    db.collection("users").document(userId).getDocument { doc, _ in
                        defer { group.leave() }
                        guard let data = doc?.data() else { return }
                        profiles.append(FavoritedProfile(
                            id: userId,
                            username: data["username"] as? String ?? "User",
                            profilePicURL: data["profileImageURL"] as? String,
                            bio: data["bio"] as? String ?? ""
                        ))
                    }
                }

                group.notify(queue: .main) { followedProfiles = profiles }
            }
    }

    private func loadCustomLists() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("customLists")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snap, _ in
                customLists = snap?.documents.compactMap { doc -> CustomFavoriteList? in
                    let data = doc.data()
                    guard let name = data["name"] as? String else { return nil }
                    return CustomFavoriteList(
                        id: doc.documentID,
                        name: name,
                        emoji: data["emoji"] as? String ?? "⭐",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
            }
    }

    private func saveCustomList() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        db.collection("users").document(uid).collection("customLists").addDocument(data: [
            "name": trimmed,
            "emoji": newListEmoji,
            "createdAt": Timestamp(date: Date())
        ])

        newListName = ""
        newListEmoji = "⭐"
    }

    private func deleteCustomList(_ list: CustomFavoriteList) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("customLists")
            .document(list.id).delete()

        if selectedTab == .custom(list.id) { selectedTab = .posts }
    }
}
