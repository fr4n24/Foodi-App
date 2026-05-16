import SwiftUI
import FirebaseFirestore
import FirebaseAuth

enum FeedFilter: String, CaseIterable {
    case explore   = "Explore"
    case forYou    = "For You"
    case following = "Following"
    case workout   = "Gym"
    case meal      = "Eats"
    case progress  = "Progress"

    var categoryKey: String? {
        switch self {
        case .workout:  return "workout"
        case .meal:     return "meal"
        case .progress: return "progress"
        default:        return nil
        }
    }

    var icon: String {
        switch self {
        case .explore:   return "globe"
        case .forYou:    return "sparkles"
        case .following: return "person.2.fill"
        case .workout:   return "dumbbell.fill"
        case .meal:      return "fork.knife"
        case .progress:  return "chart.line.uptrend.xyaxis"
        }
    }
}

struct FeedContainer: View {
    @State private var posts: [Post] = []
    @State private var usernames: [String: String] = [:]
    @State private var streaks:   [String: Int] = [:]
    @State private var selectedPost: Post? = nil
    @State private var feedFilter: FeedFilter = .explore
    @State private var savedStates:  [String: Bool] = [:]
    @State private var likeCounts:   [String: Int]  = [:]
    @State private var likedStates:  [String: Bool] = [:]

    private var trendingGym: String? {
        let cutoff = Date().addingTimeInterval(-86400)
        var counts: [String: Int] = [:]
        for p in posts where p.timestamp > cutoff {
            if let g = p.gym, !g.isEmpty { counts[g, default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    feedTypePicker
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if let gym = trendingGym {
                                NavigationLink { GymProfileLoaderView(gymName: gym) } label: {
                                    trendingBanner(gymName: gym)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                            ForEach(posts) { post in
                                postCard(post)
                                    .onTapGesture { selectedPost = post }
                                    .contextMenu {
                                        if Auth.auth().currentUser?.uid == post.authorId {
                                            Button(role: .destructive) {
                                                PostManager.shared.deletePost(post) { _ in loadPosts() }
                                            } label: {
                                                Label("Delete Post", systemImage: "trash")
                                            }
                                        } else {
                                            Button { } label: {
                                                Label("Report Post", systemImage: "flag")
                                            }
                                        }
                                        ShareLink(item: "\(post.title)\n\n\(post.content)\n\n— via GymLink") {
                                            Label("Share Post", systemImage: "square.and.arrow.up")
                                        }
                                        Button {
                                            PostManager.shared.toggleSaved(postId: post.id) { saved in
                                                savedStates[post.id] = saved
                                            }
                                        } label: {
                                            Label(
                                                (savedStates[post.id] ?? false) ? "Remove Bookmark" : "Save Post",
                                                systemImage: (savedStates[post.id] ?? false) ? "bookmark.slash" : "bookmark"
                                            )
                                        }
                                    }
                                    .onAppear {
                                        PostManager.shared.isPostSaved(postId: post.id) { saved in
                                            savedStates[post.id] = saved
                                        }
                                        loadLikeData(for: post)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 30)
                    }
                    .refreshable { loadPosts() }
                }
            }
            .navigationTitle("GymLink Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image("GymLinkLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .onAppear {
                if Auth.auth().currentUser?.uid != nil {
                    loadPosts()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { loadPosts() }
                }
            }
            .fullScreenCover(item: $selectedPost) { post in
                NavigationStack { PostDetailView(post: post) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Feed filter picker

    private var feedTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { feedFilter = filter }
                        loadPosts()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: feedFilter == filter ? .semibold : .regular))
                        }
                        .foregroundColor(feedFilter == filter ? .white : Color(white: 0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(feedFilter == filter ? Color.gymLinkPink : Color(white: 0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: feedFilter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Trending banner

    private func trendingBanner(gymName: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .foregroundColor(.gymLinkPink)
                    .font(.system(size: 17, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Trending Today")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymLinkPink)
                    .tracking(0.5)
                Text(gymName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer()
            Text("🔥")
                .font(.system(size: 20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.09))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gymLinkPink.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Post card

    @ViewBuilder
    private func postCard(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Hero image
            if let imageURL = post.imageURL, !imageURL.isEmpty {
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(white: 0.12))
                            .overlay(ProgressView().tint(.gymLinkPink))
                    }
                    .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 210)
                    .clipped()
                    .cornerRadius(16, corners: [.topLeft, .topRight])

                    if let exercise = post.exerciseName, !exercise.isEmpty {
                        prBadge
                            .padding(10)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                // Category + gym row
                HStack(spacing: 8) {
                    categoryBadge(for: post.category)
                    Spacer()
                    if let gym = post.gym, !gym.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                                .foregroundColor(.gymLinkPink)
                            Text(gym)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gymLinkPink)
                                .lineLimit(1)
                        }
                    }
                }

                // PR badge (no image case)
                if let exercise = post.exerciseName, !exercise.isEmpty,
                   (post.imageURL ?? "").isEmpty {
                    prBadge
                }

                // Title
                Text(post.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Content
                Text(post.content)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.62))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // PR progression detail
                if let exercise = post.exerciseName, !exercise.isEmpty,
                   let newVal = post.newValue, let unit = post.progressionUnit {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gymLinkPink)
                        if let prev = post.previousValue, prev > 0 {
                            Text("\(exercise): \(Int(prev)) → \(Int(newVal)) \(unit)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gymLinkPink)
                        } else {
                            Text("\(exercise): \(Int(newVal)) \(unit)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gymLinkPink)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gymLinkPink.opacity(0.1))
                    .cornerRadius(8)
                }

                // Meal macro chips
                if let cal = post.mealCalories, cal > 0 {
                    HStack(spacing: 8) {
                        macroChip("\(cal) kcal", color: .gymLinkPink)
                        if let p = post.mealProtein, p > 0 {
                            macroChip("\(p)g P", color: Color(red: 0.35, green: 0.72, blue: 1.0))
                        }
                        if let c = post.mealCarbs, c > 0 {
                            macroChip("\(c)g C", color: Color(red: 1.0, green: 0.76, blue: 0.2))
                        }
                        if let f = post.mealFat, f > 0 {
                            macroChip("\(f)g F", color: Color(red: 1.0, green: 0.46, blue: 0.3))
                        }
                    }
                }

                // Star rating
                if let rating = post.rating, rating > 0 {
                    HStack(spacing: 3) {
                        ForEach(1..<6) { star in
                            Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(star <= Int(rating) ? .gymLinkPink : Color(white: 0.28))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.42))
                    }
                }

                // Footer: author info + action buttons
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(usernames[post.authorId] ?? post.author)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.42))
                        if let s = streaks[post.authorId], s >= 2 {
                            HStack(spacing: 3) {
                                Text("🔥").font(.system(size: 10))
                                Text("\(s)d streak")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.1))
                            }
                        }
                    }
                    Spacer()
                    // Like
                    Button { toggleLike(post) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: likedStates[post.id] == true ? "heart.fill" : "heart")
                                .font(.system(size: 15))
                                .foregroundColor(likedStates[post.id] == true ? .gymLinkPink : Color(white: 0.35))
                            if let c = likeCounts[post.id], c > 0 {
                                Text("\(c)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(white: 0.35))
                            }
                        }
                    }
                    .padding(.trailing, 16)
                    // Comment
                    Button { selectedPost = post } label: {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.35))
                    }
                    .padding(.trailing, 16)
                    // Share
                    ShareLink(item: "\(post.title)\n\n\(post.content)\n\n— via GymLink") {
                        Image(systemName: "paperplane")
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.35))
                    }
                    .padding(.trailing, 16)
                    // Bookmark
                    Button {
                        PostManager.shared.toggleSaved(postId: post.id) { saved in
                            savedStates[post.id] = saved
                        }
                    } label: {
                        Image(systemName: (savedStates[post.id] ?? false) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15))
                            .foregroundColor((savedStates[post.id] ?? false) ? .gymLinkPink : Color(white: 0.35))
                    }
                }
            }
            .padding(14)
        }
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .clipped()
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.13), lineWidth: 0.5))
    }

    // MARK: - Sub-views

    private var prBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").font(.system(size: 10))
            Text("NEW PR").font(.system(size: 11, weight: .black))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gymLinkPink)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func categoryBadge(for category: String?) -> some View {
        let config: (icon: String, label: String, color: Color) = {
            switch category {
            case "workout":  return ("dumbbell.fill", "Workout", .gymLinkPink)
            case "meal":     return ("fork.knife", "Meal", Color(red: 0.35, green: 0.72, blue: 1.0))
            case "progress": return ("chart.line.uptrend.xyaxis", "Progress", Color(red: 0.3, green: 0.85, blue: 0.45))
            default:         return ("pencil", "Post", Color(white: 0.48))
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: config.icon).font(.system(size: 9, weight: .semibold))
            Text(config.label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(config.color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func macroChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Like helpers

    private func toggleLike(_ post: Post) {
        guard Auth.auth().currentUser != nil else { return }
        let was = likedStates[post.id] ?? false
        likedStates[post.id] = !was
        likeCounts[post.id]  = max(0, (likeCounts[post.id] ?? 0) + (was ? -1 : 1))
        PostManager.shared.toggleLike(for: post) { _ in }
    }

    private func loadLikeData(for post: Post) {
        guard likeCounts[post.id] == nil else { return }
        let db = Firestore.firestore()
        db.collection("posts").document(post.id).collection("likes")
            .getDocuments { snap, _ in
                DispatchQueue.main.async { self.likeCounts[post.id] = snap?.documents.count ?? 0 }
            }
        if let uid = Auth.auth().currentUser?.uid {
            db.collection("posts").document(post.id)
                .collection("likes").document(uid)
                .getDocument { snap, _ in
                    DispatchQueue.main.async { self.likedStates[post.id] = snap?.exists ?? false }
                }
        }
    }

    // MARK: - Helpers

    private func fetchUsernames(for posts: [Post]) {
        let userIds = Set(posts.map { $0.authorId }).filter { !$0.isEmpty }
        for uid in userIds where usernames[uid] == nil {
            Firestore.firestore().collection("users").document(uid).getDocument { snapshot, _ in
                guard let data = snapshot?.data() else { return }
                if let username = data["username"] as? String {
                    usernames[uid] = username
                }
                if let s = data["workoutStreak"] as? Int, s > 0 {
                    streaks[uid] = s
                }
            }
        }
    }

    private func loadPosts() {
        switch feedFilter {
        case .explore:
            PostManager.shared.fetchPosts { fetched in
                DispatchQueue.main.async { posts = fetched; fetchUsernames(for: fetched) }
            }
        case .following:
            guard let uid = Auth.auth().currentUser?.uid else { return }
            PostManager.shared.fetchFollowingPosts(for: uid) { fetched in
                DispatchQueue.main.async { posts = fetched; fetchUsernames(for: fetched) }
            }
        case .forYou:
            guard let uid = Auth.auth().currentUser?.uid else { return }
            PostManager.shared.fetchForYouPosts(for: uid) { fetched in
                DispatchQueue.main.async { posts = fetched; fetchUsernames(for: fetched) }
            }
        case .workout, .meal, .progress:
            let cat = feedFilter.categoryKey!
            PostManager.shared.fetchPosts { fetched in
                let filtered = fetched.filter { $0.category == cat }
                DispatchQueue.main.async { posts = filtered; fetchUsernames(for: filtered) }
            }
        }
    }
}

// MARK: - Corner radius helper

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
