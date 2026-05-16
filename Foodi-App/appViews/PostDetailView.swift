import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

// MARK: - Reaction types (gym-themed)

private struct HypeReaction: Identifiable {
    let id: String
    let emoji: String
    let label: String
}

private let hypeOptions: [HypeReaction] = [
    .init(id: "pump",   emoji: "💪", label: "Pump"),
    .init(id: "fire",   emoji: "🔥", label: "Fire"),
    .init(id: "trophy", emoji: "🏆", label: "PR")
]

// MARK: - PostDetailView

struct PostDetailView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss

    @State private var likeCount  = 0
    @State private var liked      = false
    @State private var isSaved    = false
    @State private var comments: [Comment] = []
    @State private var commentText  = ""
    @State private var isPosting    = false
    @State private var authorUsername = ""
    @State private var authorStreak   = 0
    @State private var reactionCounts: [String: Int] = [:]
    @State private var myReaction: String? = nil
    @State private var showDeleteAlert = false
    @State private var showReportAlert = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroImage
                    mainContent
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                    actionBar
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                    hypeRow
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                    if post.category == "workout",
                       let uid = Auth.auth().currentUser?.uid,
                       uid != post.authorId {
                        trainTogetherCard
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }
                    commentsSection
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            // Fixed top controls (always visible)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                Spacer()
                Menu {
                    if Auth.auth().currentUser?.uid == post.authorId {
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            Label("Delete Post", systemImage: "trash")
                        }
                    } else {
                        Button { showReportAlert = true } label: {
                            Label("Report Post", systemImage: "flag")
                        }
                    }
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) { commentInputBar }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete Post?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                PostManager.shared.deletePost(post) { _ in dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .alert("Report Submitted", isPresented: $showReportAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text("Thank you — our team will review this post.") }
        .onAppear { loadAll() }
    }

    // MARK: - Hero image / category banner

    @ViewBuilder
    private var heroImage: some View {
        if let url = post.imageURL, !url.isEmpty {
            AsyncImage(url: URL(string: url)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(white: 0.1).overlay(ProgressView().tint(.gymLinkPink))
            }
            .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 320)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .center,
                    endPoint: .bottom
                )
            )
        } else {
            ZStack {
                categoryGradient
                VStack(spacing: 10) {
                    Text(categoryEmoji).font(.system(size: 64))
                    Text(categoryLabel.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.52))
                        .tracking(2.5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        }
    }

    // MARK: - Main content block

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category badge + timestamp
            HStack {
                categoryBadge
                Spacer()
                Text(timeAgo(post.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.38))
            }

            // Title
            Text(post.title)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Author
            authorCard

            Rectangle().fill(Color(white: 0.12)).frame(height: 1)

            // Body text
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.system(size: 15))
                    .foregroundColor(Color(white: 0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }

            // PR progression
            if let ex = post.exerciseName, !ex.isEmpty,
               let newVal = post.newValue, let unit = post.progressionUnit {
                prCard(exercise: ex, prev: post.previousValue, new: newVal, unit: unit)
            }

            // Meal macros
            if let cal = post.mealCalories, cal > 0 {
                macroCard(cal: cal, protein: post.mealProtein,
                          carbs: post.mealCarbs, fat: post.mealFat)
            }

            // Star rating
            if let rating = post.rating, rating > 0 {
                ratingRow(rating: rating)
            }

            // Gym card
            if let name = (post.gym ?? post.gymName), !name.isEmpty {
                gymCard(name: name)
            }
        }
    }

    // MARK: - PR card

    private func prCard(exercise: String, prev: Double?, new: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11)).foregroundColor(.gymLinkPink)
                Text("NEW PERSONAL RECORD")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.gymLinkPink)
                    .tracking(0.5)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(exercise)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let p = prev, p > 0 {
                    Text("\(Int(p)) \(unit)")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.38))
                        .strikethrough(color: Color(white: 0.25))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                }
                Text("\(Int(new)) \(unit)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.gymLinkPink)
            }
        }
        .padding(14)
        .background(Color.gymLinkPink.opacity(0.07))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.gymLinkPink.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Macro card

    private func macroCard(cal: Int, protein: Int?, carbs: Int?, fat: Int?) -> some View {
        HStack(spacing: 0) {
            macroItem("Cal", "\(cal)", .gymLinkPink)
            if let p = protein, p > 0 {
                macroItem("Protein", "\(p)g", Color(red: 0.35, green: 0.72, blue: 1.0))
            }
            if let c = carbs, c > 0 {
                macroItem("Carbs", "\(c)g", Color(red: 1.0, green: 0.76, blue: 0.2))
            }
            if let f = fat, f > 0 {
                macroItem("Fat", "\(f)g", Color(red: 1.0, green: 0.46, blue: 0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
        .cornerRadius(14)
    }

    private func macroItem(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rating row

    private func ratingRow(rating: Double) -> some View {
        HStack(spacing: 6) {
            ForEach(1..<6) { star in
                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                    .font(.system(size: 16))
                    .foregroundColor(star <= Int(rating) ? .gymLinkPink : Color(white: 0.2))
            }
            Text(String(format: "%.1f", rating))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.45))
                .padding(.leading, 2)
        }
    }

    // MARK: - Gym card

    private func gymCard(name: String) -> some View {
        NavigationLink {
            GymProfileView(gym: GymDetail(
                name: name,
                coordinate: CLLocationCoordinate2D(
                    latitude: post.gymLat ?? 0,
                    longitude: post.gymLon ?? 0
                )
            ))
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gymLinkPink.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("GYM")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(white: 0.38))
                        .tracking(1.2)
                    Text(name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(Color(white: 0.28))
            }
            .padding(12)
            .background(Color(white: 0.1))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Author card

    private var authorCard: some View {
        NavigationLink { UserProfileView(userId: post.authorId) } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((authorUsername.isEmpty ? post.author : authorUsername)
                            .prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gymLinkPink)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(authorUsername.isEmpty ? post.author : authorUsername)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    if authorStreak >= 2 {
                        HStack(spacing: 3) {
                            Text("🔥").font(.system(size: 10))
                            Text("\(authorStreak) day streak")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.1))
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.25))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action bar (like / comments / save / share)

    private var actionBar: some View {
        VStack(spacing: 12) {
            Rectangle().fill(Color(white: 0.12)).frame(height: 1)
            HStack(spacing: 0) {
                // Like
                Button { toggleLike() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(liked ? .gymLinkPink : Color(white: 0.38))
                            .scaleEffect(liked ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: liked)
                        Text("\(likeCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
                .frame(maxWidth: .infinity)

                // Comments count (no action — input is at bottom)
                VStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 22))
                        .foregroundColor(Color(white: 0.38))
                    Text("\(comments.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity)

                // Save
                Button {
                    PostManager.shared.toggleSaved(postId: post.id) { saved in isSaved = saved }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 22))
                            .foregroundColor(isSaved ? .gymLinkPink : Color(white: 0.38))
                        Text(isSaved ? "Saved" : "Save")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
                .frame(maxWidth: .infinity)

                // Share
                ShareLink(item: shareText) {
                    VStack(spacing: 4) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 22))
                            .foregroundColor(Color(white: 0.38))
                        Text("Share")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.4))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            Rectangle().fill(Color(white: 0.12)).frame(height: 1)
        }
    }

    // MARK: - Hype reactions (💪 🔥 🏆)

    private var hypeRow: some View {
        HStack(spacing: 8) {
            ForEach(hypeOptions) { r in
                Button { toggleReaction(r.id) } label: {
                    HStack(spacing: 5) {
                        Text(r.emoji).font(.system(size: 15))
                        Text(r.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(myReaction == r.id ? .white : Color(white: 0.5))
                        if let count = reactionCounts[r.id], count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(myReaction == r.id ? .white.opacity(0.85) : Color(white: 0.35))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(myReaction == r.id ? Color.gymLinkPink : Color(white: 0.11))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(myReaction == r.id ? Color.clear : Color(white: 0.17), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: myReaction)
            }
            Spacer()
        }
    }

    // MARK: - Train Together (workout posts only, viewing others)

    private var trainTogetherCard: some View {
        NavigationLink { UserProfileView(userId: post.authorId) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.gymLinkPink.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Text("🏋️").font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Train Together")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Message \(authorUsername.isEmpty ? post.author : authorUsername) to plan a session")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.45))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12)).foregroundColor(Color(white: 0.28))
            }
            .padding(14)
            .background(Color(white: 0.09))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gymLinkPink.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comments section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("Comments")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.38))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color(white: 0.14))
                        .clipShape(Capsule())
                }
            }

            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 30))
                        .foregroundColor(Color(white: 0.18))
                    Text("No comments yet")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.28))
                    Text("Be the first to hype this post!")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.2))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(comments) { comment in
                    commentBubble(comment)
                }
            }
        }
    }

    private func commentBubble(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink { UserProfileView(userId: comment.authorId) } label: {
                Circle()
                    .fill(Color(white: 0.14))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text(String(comment.authorName.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(white: 0.52))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(comment.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.68))
                    Text(timeAgo(comment.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.3))
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(12)
            .background(Color(white: 0.1))
            .cornerRadius(14)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Comment input bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(white: 0.12)).frame(height: 0.5)
            HStack(spacing: 10) {
                TextField("Add a comment...", text: $commentText)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.12))
                    .cornerRadius(22)
                    .submitLabel(.send)
                    .onSubmit { postComment() }
                Button(action: postComment) {
                    ZStack {
                        Circle()
                            .fill(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  ? Color(white: 0.12) : Color.gymLinkPink)
                            .frame(width: 40, height: 40)
                        Image(systemName: isPosting ? "ellipsis" : "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundColor(
                                commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color(white: 0.28) : .white
                            )
                    }
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(white: 0.06))
        }
    }

    // MARK: - Category helpers

    private var categoryEmoji: String {
        switch post.category {
        case "workout":  return "💪"
        case "meal":     return "🍽️"
        case "progress": return "📈"
        default:         return "✏️"
        }
    }

    private var categoryLabel: String {
        switch post.category {
        case "workout":  return "Workout"
        case "meal":     return "Meal"
        case "progress": return "Progress"
        default:         return "Post"
        }
    }

    private var categoryGradient: LinearGradient {
        switch post.category {
        case "workout":
            return LinearGradient(
                colors: [Color.gymLinkPink.opacity(0.4), Color.black],
                startPoint: .top, endPoint: .bottom)
        case "meal":
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.38), Color.black],
                startPoint: .top, endPoint: .bottom)
        case "progress":
            return LinearGradient(
                colors: [Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.38), Color.black],
                startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(
                colors: [Color(white: 0.18), Color.black],
                startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private var categoryBadge: some View {
        let config: (icon: String, label: String, color: Color) = {
            switch post.category {
            case "workout":  return ("dumbbell.fill",                 "Workout",  .gymLinkPink)
            case "meal":     return ("fork.knife",                    "Meal",     Color(red: 0.35, green: 0.72, blue: 1.0))
            case "progress": return ("chart.line.uptrend.xyaxis",     "Progress", Color(red: 0.3,  green: 0.85, blue: 0.45))
            default:         return ("pencil",                        "Post",     Color(white: 0.48))
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: config.icon).font(.system(size: 10, weight: .semibold))
            Text(config.label).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(config.color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Utility

    private var shareText: String {
        "Check out this post on GymLink:\n\n\(post.title)\n\(post.content)"
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60    { return "just now" }
        if s < 3600  { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }

    // MARK: - Actions

    private func toggleLike() {
        let was = liked
        liked     = !was
        likeCount = max(0, likeCount + (was ? -1 : 1))
        PostManager.shared.toggleLike(for: post) { _ in }
    }

    private func toggleReaction(_ type: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Firestore.firestore()
            .collection("posts").document(post.id)
            .collection("reactions").document(uid)

        if myReaction == type {
            ref.delete { _ in }
            reactionCounts[type, default: 1] -= 1
            if (reactionCounts[type] ?? 0) <= 0 { reactionCounts.removeValue(forKey: type) }
            myReaction = nil
        } else {
            if let old = myReaction {
                reactionCounts[old, default: 1] -= 1
                if (reactionCounts[old] ?? 0) <= 0 { reactionCounts.removeValue(forKey: old) }
            }
            ref.setData(["type": type, "timestamp": Timestamp(date: Date())]) { _ in }
            reactionCounts[type, default: 0] += 1
            myReaction = type
        }
    }

    private func postComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isPosting = true
        PostManager.shared.addComment(to: post, text: trimmed) { _ in
            DispatchQueue.main.async {
                commentText = ""
                isPosting   = false
                hideKeyboard()
            }
        }
    }

    // MARK: - Data loading

    private func loadAll() {
        let db = Firestore.firestore()

        PostManager.shared.listenForLikes(of: post) { count in likeCount = count }

        if let uid = Auth.auth().currentUser?.uid {
            db.collection("posts").document(post.id)
                .collection("likes").document(uid)
                .addSnapshotListener { snap, _ in liked = snap?.exists ?? false }
        }

        PostManager.shared.isPostSaved(postId: post.id) { saved in isSaved = saved }
        PostManager.shared.listenForComments(of: post) { c in comments = c }

        db.collection("users").document(post.authorId).getDocument { snap, _ in
            guard let d = snap?.data() else { return }
            DispatchQueue.main.async {
                authorUsername = d["username"] as? String ?? post.author
                authorStreak   = d["workoutStreak"] as? Int ?? 0
            }
        }

        if let uid = Auth.auth().currentUser?.uid {
            db.collection("posts").document(post.id)
                .collection("reactions")
                .addSnapshotListener { snap, _ in
                    var counts: [String: Int] = [:]
                    var mine: String? = nil
                    snap?.documents.forEach { doc in
                        let t = doc.data()["type"] as? String ?? ""
                        counts[t, default: 0] += 1
                        if doc.documentID == uid { mine = t }
                    }
                    DispatchQueue.main.async {
                        reactionCounts = counts
                        myReaction     = mine
                    }
                }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
