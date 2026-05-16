import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SocialUser: Identifiable {
    let id: String
    let username: String
    let fullName: String
    let profilePicURL: String?
    var isFollowing: Bool
}

struct PeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SocialTab = .friends
    @State private var friends:     [SocialUser] = []
    @State private var recommended: [SocialUser] = []
    @State private var followers:   [SocialUser] = []
    @State private var blocked:     [SocialUser] = []
    @State private var isLoading = false

    private let db = Firestore.firestore()
    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }

    enum SocialTab: String, CaseIterable {
        case friends     = "Friends"
        case recommended = "For You"
        case followers   = "Followers"
        case blocked     = "Blocked"

        var icon: String {
            switch self {
            case .friends:     return "person.2.fill"
            case .recommended: return "sparkles"
            case .followers:   return "person.badge.plus"
            case .blocked:     return "nosign"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    tabBar
                    Divider().background(Color(white: 0.12))
                    tabContent
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundColor(.gymLinkPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        // caller can open UserSearchView
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gymLinkPink)
                    }
                }
            }
            .onAppear { loadAll() }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SocialTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selectedTab = tab }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? .white : Color(white: 0.42))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.gymLinkPink : Color(white: 0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color(white: 0.05))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(.gymLinkPink)
            Spacer()
        } else {
            switch selectedTab {
            case .friends:
                userList(friends, emptyIcon: "person.2", emptyText: "No mutual follows yet.\nFollow people and get them to follow back.")
            case .recommended:
                userList(recommended, emptyIcon: "sparkles", emptyText: "No recommendations yet.\nFollow more people to get suggestions.")
            case .followers:
                userList(followers, emptyIcon: "person.badge.plus", emptyText: "No followers yet.")
            case .blocked:
                blockedList
            }
        }
    }

    // MARK: - User list

    private func userList(_ users: [SocialUser], emptyIcon: String, emptyText: String) -> some View {
        Group {
            if users.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 44)).foregroundColor(Color(white: 0.2))
                    Text(emptyText)
                        .font(.subheadline).foregroundColor(Color(white: 0.35))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(users) { user in
                            NavigationLink { UserProfileView(userId: user.id) } label: {
                                userRow(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private func userRow(_ user: SocialUser) -> some View {
        HStack(spacing: 14) {
            avatar(url: user.profilePicURL, size: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username.isEmpty ? "unknown" : user.username)")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                if !user.fullName.isEmpty {
                    Text(user.fullName)
                        .font(.system(size: 13)).foregroundColor(Color(white: 0.42))
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { toggleFollow(userId: user.id) } label: {
                    Text(user.isFollowing ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(user.isFollowing ? Color(white: 0.45) : .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(user.isFollowing ? Color(white: 0.14) : Color.gymLinkPink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { blockUser(user) } label: {
                    Image(systemName: "nosign")
                        .font(.system(size: 13)).foregroundColor(Color(white: 0.35))
                        .frame(width: 30, height: 30)
                        .background(Color(white: 0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(white: 0.07))
    }

    // MARK: - Blocked list

    private var blockedList: some View {
        Group {
            if blocked.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 44)).foregroundColor(Color(white: 0.2))
                    Text("No blocked users")
                        .font(.subheadline).foregroundColor(Color(white: 0.35))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(blocked) { user in
                            HStack(spacing: 14) {
                                avatar(url: nil, size: 50)
                                Text("@\(user.username)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(white: 0.55))
                                Spacer()
                                Button { unblockUser(user) } label: {
                                    Text("Unblock")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.gymLinkPink)
                                        .padding(.horizontal, 14).padding(.vertical, 6)
                                        .background(Color.gymLinkPink.opacity(0.1))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.gymLinkPink.opacity(0.35), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Color(white: 0.07))
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Reusable avatar

    private func avatar(url: String?, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.15)).frame(width: size, height: size)
                .overlay(Circle().stroke(Color.gymLinkPink.opacity(0.25), lineWidth: 1))
            if let urlStr = url, !urlStr.isEmpty, let u = URL(string: urlStr) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() }
                    placeholder: { Color(white: 0.15) }
                    .frame(width: size, height: size).clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4)).foregroundColor(Color(white: 0.38))
            }
        }
    }

    // MARK: - Data loading

    private func loadAll() {
        guard !myUID.isEmpty else { return }
        isLoading = true

        let group = DispatchGroup()
        var followingIDs: Set<String> = []
        var followerIDs:  [String]    = []

        group.enter()
        db.collection("users").document(myUID).collection("following")
            .getDocuments { snap, _ in
                followingIDs = Set(snap?.documents.map { $0.documentID } ?? [])
                group.leave()
            }

        group.enter()
        db.collection("users").document(myUID).collection("followers")
            .getDocuments { snap, _ in
                followerIDs = snap?.documents.map { $0.documentID } ?? []
                group.leave()
            }

        group.notify(queue: .main) {
            let friendIDs = Array(followingIDs.intersection(Set(followerIDs)))
            let innerGroup = DispatchGroup()

            innerGroup.enter()
            self.fetchUsers(ids: friendIDs, followingSet: followingIDs) {
                self.friends = $0
                innerGroup.leave()
            }

            innerGroup.enter()
            self.fetchUsers(ids: followerIDs, followingSet: followingIDs) {
                self.followers = $0
                innerGroup.leave()
            }

            innerGroup.enter()
            self.loadRecommended(followingIDs: followingIDs) {
                self.recommended = $0
                innerGroup.leave()
            }

            innerGroup.notify(queue: .main) {
                self.isLoading = false
            }
        }

        db.collection("users").document(myUID).collection("blocked")
            .getDocuments { snap, _ in
                let ids = snap?.documents.map { $0.documentID } ?? []
                self.fetchUsers(ids: ids, followingSet: []) { users in
                    DispatchQueue.main.async { self.blocked = users }
                }
            }
    }

    private func loadRecommended(followingIDs: Set<String>, completion: @escaping ([SocialUser]) -> Void) {
        guard !followingIDs.isEmpty else { completion([]); return }
        let sample = Array(followingIDs.prefix(8))
        let group = DispatchGroup()
        var candidates: Set<String> = []

        for uid in sample {
            group.enter()
            db.collection("users").document(uid).collection("following")
                .limit(to: 20)
                .getDocuments { snap, _ in
                    (snap?.documents.map { $0.documentID } ?? []).forEach { candidates.insert($0) }
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            let newOnes = Array(candidates.subtracting(followingIDs).subtracting([self.myUID])).prefix(20)
            self.fetchUsers(ids: Array(newOnes), followingSet: followingIDs, completion: completion)
        }
    }

    private func fetchUsers(ids: [String], followingSet: Set<String>, completion: @escaping ([SocialUser]) -> Void) {
        guard !ids.isEmpty else { completion([]); return }
        let chunks = stride(from: 0, to: ids.count, by: 30).map { Array(ids[$0..<min($0 + 30, ids.count)]) }
        let group = DispatchGroup()
        var results: [SocialUser] = []

        for chunk in chunks {
            group.enter()
            db.collection("users").whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snap, _ in
                    let users: [SocialUser] = snap?.documents.compactMap { doc in
                        let d = doc.data()
                        return SocialUser(
                            id:            doc.documentID,
                            username:      d["username"]      as? String ?? "",
                            fullName:      d["fullName"]      as? String ?? "",
                            profilePicURL: d["profilePicURL"] as? String,
                            isFollowing:   followingSet.contains(doc.documentID)
                        )
                    } ?? []
                    results.append(contentsOf: users)
                    group.leave()
                }
        }

        group.notify(queue: .main) { completion(results) }
    }

    // MARK: - Actions

    private func toggleFollow(userId: String) {
        let wasFollowing = friends.first(where: { $0.id == userId })?.isFollowing
            ?? recommended.first(where: { $0.id == userId })?.isFollowing
            ?? followers.first(where: { $0.id == userId })?.isFollowing
            ?? false

        let followerRef = db.collection("users").document(userId).collection("followers").document(myUID)
        let followingRef = db.collection("users").document(myUID).collection("following").document(userId)

        if wasFollowing { followerRef.delete(); followingRef.delete() }
        else            { followerRef.setData([:]); followingRef.setData([:]) }

        flip(userId: userId, in: &friends)
        flip(userId: userId, in: &recommended)
        flip(userId: userId, in: &followers)
    }

    private func flip(userId: String, in list: inout [SocialUser]) {
        if let idx = list.firstIndex(where: { $0.id == userId }) {
            list[idx].isFollowing.toggle()
        }
    }

    private func blockUser(_ user: SocialUser) {
        let uid = user.id
        db.collection("users").document(uid).collection("followers").document(myUID).delete()
        db.collection("users").document(myUID).collection("following").document(uid).delete()
        db.collection("users").document(uid).collection("following").document(myUID).delete()
        db.collection("users").document(myUID).collection("followers").document(uid).delete()
        db.collection("users").document(myUID).collection("blocked").document(uid)
            .setData(["username": user.username, "timestamp": Timestamp(date: Date())])

        friends.removeAll     { $0.id == uid }
        recommended.removeAll { $0.id == uid }
        followers.removeAll   { $0.id == uid }
        let blockedEntry = SocialUser(id: uid, username: user.username, fullName: "", profilePicURL: nil, isFollowing: false)
        blocked.insert(blockedEntry, at: 0)
    }

    private func unblockUser(_ user: SocialUser) {
        db.collection("users").document(myUID).collection("blocked").document(user.id).delete()
        blocked.removeAll { $0.id == user.id }
    }
}
