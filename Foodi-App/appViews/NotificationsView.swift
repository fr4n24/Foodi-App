import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Model

struct AppNotification: Identifiable {
    let id: String
    let type: String
    let fromUserId: String
    let fromUsername: String
    let postId: String?
    let commentText: String?
    let timestamp: Date
    var read: Bool
}

// MARK: - Filter

enum NotifFilter: String, CaseIterable {
    case all      = "All"
    case likes    = "Likes"
    case comments = "Comments"
    case follows  = "Follows"
}

// MARK: - Section group

private struct NotifGroup: Identifiable {
    let id: String
    let title: String
    let items: [AppNotification]
}

// MARK: - NotificationsView

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var filter: NotifFilter = .all
    @State private var isLoading = false
    @State private var selectedPost: Post? = nil
    @State private var isOpeningPost = false

    private let db = Firestore.firestore()

    // MARK: - Computed

    private var filteredNotifications: [AppNotification] {
        switch filter {
        case .all:      return notifications
        case .likes:    return notifications.filter { $0.type == "like" }
        case .comments: return notifications.filter { $0.type == "comment" }
        case .follows:  return notifications.filter { $0.type == "follow" }
        }
    }

    private var groupedNotifications: [NotifGroup] {
        let cal = Calendar.current
        var today:     [AppNotification] = []
        var yesterday: [AppNotification] = []
        var thisWeek:  [AppNotification] = []
        var older:     [AppNotification] = []
        for n in filteredNotifications {
            if cal.isDateInToday(n.timestamp) {
                today.append(n)
            } else if cal.isDateInYesterday(n.timestamp) {
                yesterday.append(n)
            } else if let d = cal.dateComponents([.day], from: n.timestamp, to: Date()).day, d < 7 {
                thisWeek.append(n)
            } else {
                older.append(n)
            }
        }
        return [
            NotifGroup(id: "today",     title: "Today",     items: today),
            NotifGroup(id: "yesterday", title: "Yesterday", items: yesterday),
            NotifGroup(id: "week",      title: "This Week", items: thisWeek),
            NotifGroup(id: "older",     title: "Earlier",   items: older)
        ].filter { !$0.items.isEmpty }
    }

    private var last7Days: [AppNotification] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return notifications.filter { $0.timestamp >= cutoff }
    }
    private var recentLikes:    Int { last7Days.filter { $0.type == "like" }.count }
    private var recentComments: Int { last7Days.filter { $0.type == "comment" }.count }
    private var recentFollows:  Int { last7Days.filter { $0.type == "follow" }.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                mainContent
                if isOpeningPost {
                    Color.black.opacity(0.45).ignoresSafeArea()
                        .overlay(ProgressView().tint(.gymLinkPink).scaleEffect(1.3))
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarMenu }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $selectedPost) { post in
            NavigationStack { PostDetailView(post: post) }
        }
        .onAppear {
            loadNotifications()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                markAllRead()
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if isLoading && notifications.isEmpty {
            loadingView
        } else if notifications.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                filterPicker
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if recentLikes > 0 || recentComments > 0 || recentFollows > 0 {
                            activitySummaryCard
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                        }
                        if filteredNotifications.isEmpty {
                            noResultsState.padding(.top, 60)
                        } else {
                            ForEach(groupedNotifications) { group in
                                Section {
                                    ForEach(group.items) { notif in
                                        notifRowContainer(notif)
                                    }
                                } header: {
                                    sectionHeader(group.title)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { markAllRead() } label: {
                    Label("Mark All Read", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) { clearAll() } label: {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gymLinkPink)
            }
        }
    }

    // MARK: - Filter picker

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NotifFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { filter = f }
                    } label: {
                        HStack(spacing: 5) {
                            Text(f.rawValue)
                                .font(.system(size: 13, weight: filter == f ? .semibold : .regular))
                                .foregroundColor(filter == f ? .white : Color(white: 0.5))
                            let badge = unreadCount(for: f)
                            if badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(filter == f ? .white : Color(white: 0.9))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(filter == f ? Color.white.opacity(0.28) : Color.gymLinkPink)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(filter == f ? Color.gymLinkPink : Color(white: 0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Activity summary card

    private var activitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gymLinkPink)
                Text("PAST 7 DAYS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.42))
                    .tracking(1)
            }
            HStack(spacing: 0) {
                summaryItem("heart.fill",     "\(recentLikes)",    "Likes",    .gymLinkPink)
                Rectangle().fill(Color(white: 0.18)).frame(width: 1, height: 34)
                summaryItem("bubble.right.fill", "\(recentComments)", "Comments",
                            Color(red: 0.35, green: 0.72, blue: 1.0))
                Rectangle().fill(Color(white: 0.18)).frame(width: 1, height: 34)
                summaryItem("person.badge.plus", "\(recentFollows)", "Followers",
                            Color(red: 0.28, green: 0.85, blue: 0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.08))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.12), lineWidth: 1))
    }

    private func summaryItem(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.38))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(white: 0.35))
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    // MARK: - Notification row

    @ViewBuilder
    private func notifRowContainer(_ notif: AppNotification) -> some View {
        if notif.type == "follow" {
            NavigationLink { UserProfileView(userId: notif.fromUserId) } label: {
                notifRowContent(notif)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteSwipeButton(notif)
            }
        } else {
            Button { handleTap(notif) } label: {
                notifRowContent(notif)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                deleteSwipeButton(notif)
            }
        }
    }

    private func deleteSwipeButton(_ notif: AppNotification) -> some View {
        Button(role: .destructive) { deleteNotification(notif) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func notifRowContent(_ notif: AppNotification) -> some View {
        let cfg = notifConfig(notif.type)
        return HStack(spacing: 14) {
            // Type icon bubble
            ZStack {
                Circle()
                    .fill(cfg.color.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: cfg.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(cfg.color)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                // Bold username + action sentence
                (Text(notif.fromUsername).bold()
                    + Text(" \(actionText(notif))"))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)

                // Comment preview
                if notif.type == "comment",
                   let preview = notif.commentText, !preview.isEmpty {
                    Text("\"\(preview)\"")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.46))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Relative time
                Text(timeString(notif.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.3))
            }

            Spacer(minLength: 0)

            // Unread dot
            if !notif.read {
                Circle()
                    .fill(Color.gymLinkPink)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(notif.read ? Color.clear : Color.gymLinkPink.opacity(0.045))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.1))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Empty / loading states

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.gymLinkPink.opacity(0.1))
                    .frame(width: 96, height: 96)
                Image(systemName: "bell.slash")
                    .font(.system(size: 40))
                    .foregroundColor(Color.gymLinkPink.opacity(0.45))
            }
            Text("No activity yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("When people like, comment on,\nor follow you — it shows up here.")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.35))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 34))
                .foregroundColor(Color(white: 0.18))
            Text("No \(filter.rawValue.lowercased()) yet")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.28))
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.gymLinkPink).scaleEffect(1.3)
            Text("Loading activity...")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.32))
        }
    }

    // MARK: - Helpers

    private func notifConfig(_ type: String) -> (icon: String, color: Color) {
        switch type {
        case "like":    return ("heart.fill",          .gymLinkPink)
        case "comment": return ("bubble.right.fill",   Color(red: 0.35, green: 0.72, blue: 1.0))
        case "follow":  return ("person.badge.plus",   Color(red: 0.28, green: 0.85, blue: 0.45))
        default:        return ("bell.fill",           Color(white: 0.48))
        }
    }

    private func actionText(_ notif: AppNotification) -> String {
        switch notif.type {
        case "like":    return "liked your post"
        case "comment": return "commented on your post"
        case "follow":  return "started following you"
        default:        return "interacted with you"
        }
    }

    private func unreadCount(for f: NotifFilter) -> Int {
        switch f {
        case .all:      return notifications.filter { !$0.read }.count
        case .likes:    return notifications.filter { $0.type == "like"    && !$0.read }.count
        case .comments: return notifications.filter { $0.type == "comment" && !$0.read }.count
        case .follows:  return notifications.filter { $0.type == "follow"  && !$0.read }.count
        }
    }

    private func timeString(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60     { return "just now" }
        if s < 3600   { return "\(s / 60)m ago" }
        if s < 86400  { return "\(s / 3600)h ago" }
        if s < 604800 { return "\(s / 86400)d ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    // MARK: - Actions

    private func handleTap(_ notif: AppNotification) {
        guard let postId = notif.postId, !postId.isEmpty else { return }
        isOpeningPost = true
        db.collection("posts").document(postId).getDocument { snap, _ in
            defer { DispatchQueue.main.async { isOpeningPost = false } }
            guard let snap = snap, let data = snap.data() else { return }
            let post = Post(
                id:               snap.documentID,
                title:            data["title"]           as? String ?? "",
                dishName:         data["dishName"]        as? String,
                content:          data["content"]         as? String ?? "",
                imageURL:         data["imageURL"]        as? String,
                author:           data["author"]          as? String ?? "",
                authorId:         data["authorId"]        as? String ?? "",
                gymName:          data["gymName"]         as? String,
                gym:              data["gym"]             as? String,
                rating:           data["rating"]          as? Double,
                timestamp:        (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                gymLat:           data["gymLat"]          as? Double,
                gymLon:           data["gymLon"]          as? Double,
                mealCalories:     data["mealCalories"]    as? Int,
                mealProtein:      data["mealProtein"]     as? Int,
                mealCarbs:        data["mealCarbs"]       as? Int,
                mealFat:          data["mealFat"]         as? Int,
                exerciseName:     data["exerciseName"]    as? String,
                previousValue:    data["previousValue"]   as? Double,
                newValue:         data["newValue"]        as? Double,
                progressionUnit:  data["progressionUnit"] as? String,
                category:         data["category"]        as? String
            )
            DispatchQueue.main.async { selectedPost = post }
        }
    }

    private func deleteNotification(_ notif: AppNotification) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid)
            .collection("notifications").document(notif.id)
            .delete { _ in }
        notifications.removeAll { $0.id == notif.id }
    }

    private func clearAll() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let batch = db.batch()
        notifications.forEach {
            batch.deleteDocument(
                db.collection("users").document(uid)
                    .collection("notifications").document($0.id)
            )
        }
        batch.commit { _ in }
        notifications = []
    }

    // MARK: - Data

    private func loadNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        db.collection("users").document(uid).collection("notifications")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                isLoading = false
                guard let docs = snapshot?.documents, error == nil else { return }
                notifications = docs.compactMap { doc in
                    let data = doc.data()
                    return AppNotification(
                        id:           doc.documentID,
                        type:         data["type"]         as? String ?? "",
                        fromUserId:   data["fromUserId"]   as? String ?? "",
                        fromUsername: data["fromUsername"] as? String ?? "Someone",
                        postId:       data["postId"]       as? String,
                        commentText:  data["commentText"]  as? String,
                        timestamp:    (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        read:         data["read"]         as? Bool ?? false
                    )
                }
            }
    }

    private func markAllRead() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        notifications = notifications.map { var n = $0; n.read = true; return n }
        db.collection("users").document(uid).collection("notifications")
            .whereField("read", isEqualTo: false)
            .getDocuments { snap, _ in
                snap?.documents.forEach { $0.reference.updateData(["read": true]) }
            }
    }
}
