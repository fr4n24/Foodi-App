import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

struct HomeView: View {
    // Navigation / sheets
    @State private var selectedWidget: WidgetType? = nil
    @State private var showPostTypePicker = false
    @State private var showPostSheet      = false
    @State private var pendingCategory: PostCategory = .workout
    @State private var showUserSearch     = false
    @State private var showPeople         = false
    @State private var showTrackMeals     = false
    @State private var showMessages       = false
    @State private var unreadCount: Int   = 0
    @State private var unreadMessages: Int = 0

    // Dashboard data loaded from Firestore
    @State private var username: String      = ""
    @State private var workoutStreak: Int    = 0
    @State private var score: Int            = 0
    @State private var postsCount: Int       = 0
    @State private var activeWeekdays: Set<Int> = [] // 0 = Mon … 6 = Sun

    private let previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.2411, longitude: -119.0434),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // MARK: - Computed helpers

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:       return "Night grind"
        }
    }

    private var greetingEmoji: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "☀️"
        case 12..<17: return "💪"
        case 17..<21: return "🌆"
        default:       return "🌙"
        }
    }

    private var streakLine: String {
        switch workoutStreak {
        case 0:        return "Start your streak today."
        case 1:        return "Day one energy. Let's go!"
        case 2..<7:    return "Keep the streak alive — \(workoutStreak) days in!"
        default:       return "You're on fire! \(workoutStreak) days strong. 🔥"
        }
    }

    private var todayWeekdayIndex: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        return wd == 1 ? 6 : wd - 2 // 0 = Mon, 6 = Sun
    }

    private static let quotes: [(text: String, author: String)] = [
        ("The only bad workout is the one that didn't happen.", ""),
        ("Your body can stand almost anything. It's your mind you have to convince.", ""),
        ("Push yourself, because no one else is going to do it for you.", ""),
        ("All progress takes place outside the comfort zone.", "Michael John Bobak"),
        ("Don't wish for it. Work for it.", ""),
        ("The pain you feel today will be the strength you feel tomorrow.", ""),
        ("Train insane or remain the same.", ""),
        ("Strive for progress, not perfection.", ""),
        ("You don't have to be great to start, but you have to start to be great.", "Zig Ziglar"),
        ("Champions aren't made in gyms. Champions are made from something deep inside.", "Muhammad Ali"),
        ("The last three or four reps is what makes the muscle grow.", "Arnold Schwarzenegger"),
        ("Your health is an investment, not an expense.", ""),
    ]

    private var todayQuote: (text: String, author: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.quotes[(day - 1) % Self.quotes.count]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    greetingHero
                    statsStrip
                    WorkoutCheckInBanner()
                    quickActionsGrid
                    weeklyTracker
                    gymsCard
                    motivationalQuoteCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .safeAreaInset(edge: .bottom) { dock }
        .fullScreenCover(item: $selectedWidget) { widget in
            WidgetDetailView(type: widget, selectedWidget: $selectedWidget)
        }
        .sheet(isPresented: $showPostTypePicker) {
            PostTypePickerSheet { category in
                pendingCategory = category
                showPostSheet = true
            }
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPostSheet) { PostView(category: pendingCategory) }
        .sheet(isPresented: $showUserSearch) { NavigationStack { UserSearchView() } }
        .sheet(isPresented: $showPeople) { PeopleView() }
        .sheet(isPresented: $showTrackMeals) { TrackMealsView() }
        .sheet(isPresented: $showMessages) { MessagesListView() }
        .onAppear {
            listenForUnreadNotifications()
            listenForUnreadMessages()
            loadDashboard()
        }
    }

    // MARK: - Greeting hero

    private var greetingHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [Color.gymLinkPink.opacity(0.55), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            // Background glow
            Circle()
                .fill(Color.gymLinkPink.opacity(0.13))
                .frame(width: 180, height: 180)
                .blur(radius: 45)
                .offset(x: 160, y: -30)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(greetingEmoji).font(.system(size: 18))
                        Text(greeting)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                    Text(username.isEmpty ? "Athlete" : username)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text(streakLine)
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)

                Spacer()

                VStack(spacing: 2) {
                    Text(workoutStreak > 0 ? "🔥" : "💤")
                        .font(.system(size: 48))
                    if workoutStreak > 0 {
                        Text("\(workoutStreak)d")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.gymLinkPink)
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 18)
            }
        }
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 10) {
            statPill(
                icon: "flame.fill",
                value: "\(workoutStreak)",
                label: "Day Streak",
                color: workoutStreak > 0 ? Color(red: 1, green: 0.45, blue: 0.1) : Color(white: 0.28)
            )
            statPill(
                icon: "trophy.fill",
                value: score > 999 ? "\(score / 1000)k" : "\(score)",
                label: "GymLink Pts",
                color: Color(red: 1.0, green: 0.78, blue: 0.1)
            )
            statPill(
                icon: "doc.text.fill",
                value: "\(postsCount)",
                label: "Posts",
                color: Color(red: 0.35, green: 0.72, blue: 1.0)
            )
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(white: 0.38))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.09))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 0.11), lineWidth: 0.5))
    }

    // MARK: - Quick actions 2x2 grid

    private var quickActionsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionCard(
                    icon: "text.bubble.fill", title: "Feed",
                    subtitle: "What's happening",
                    topColor: Color.gymLinkPink, bottomColor: Color(red: 0.7, green: 0.08, blue: 0.32)
                ) { selectedWidget = .feed }

                actionCard(
                    icon: "person.2.fill", title: "People",
                    subtitle: "Friends & community",
                    topColor: Color(red: 0.25, green: 0.52, blue: 1.0),
                    bottomColor: Color(red: 0.1, green: 0.28, blue: 0.72)
                ) { showPeople = true }
            }
            HStack(spacing: 10) {
                actionCard(
                    icon: "fork.knife", title: "Track Meals",
                    subtitle: "Log your nutrition",
                    topColor: Color(red: 0.18, green: 0.78, blue: 0.48),
                    bottomColor: Color(red: 0.1, green: 0.5, blue: 0.3)
                ) { showTrackMeals = true }

                actionCard(
                    icon: "trophy.fill", title: "Leaderboard",
                    subtitle: "See top athletes",
                    topColor: Color(red: 1.0, green: 0.62, blue: 0.1),
                    bottomColor: Color(red: 0.8, green: 0.4, blue: 0.0)
                ) { selectedWidget = .leaderboard }
            }
        }
    }

    private func actionCard(
        icon: String, title: String, subtitle: String,
        topColor: Color, bottomColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [topColor.opacity(0.22), bottomColor.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 116)

                // Watermark icon
                Image(systemName: icon)
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundColor(topColor.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 8).padding(.top, 6)

                // Glow blob
                Circle()
                    .fill(topColor.opacity(0.25))
                    .frame(width: 70, height: 70)
                    .blur(radius: 22)
                    .offset(x: -8, y: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(topColor)
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.48))
                }
                .padding(14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(topColor.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weekly habit tracker

    private var weeklyTracker: some View {
        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
        let activeDays = activeWeekdays.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                        .tracking(1.5)
                    Text("Your activity log")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.28))
                }
                Spacer()
                Text("\(activeDays) / 7 days")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(activeDays >= 5 ? .gymLinkPink : Color(white: 0.32))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(activeDays >= 5 ? Color.gymLinkPink.opacity(0.12) : Color(white: 0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: 0) {
                ForEach(0..<7) { idx in
                    let isActive = activeWeekdays.contains(idx)
                    let isToday  = todayWeekdayIndex == idx
                    VStack(spacing: 6) {
                        Text(dayLabels[idx])
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isActive ? .gymLinkPink : Color(white: 0.28))
                        ZStack {
                            Circle()
                                .fill(isActive ? Color.gymLinkPink : Color(white: 0.1))
                                .frame(width: 32, height: 32)
                            if isToday && !isActive {
                                Circle()
                                    .stroke(Color.gymLinkPink.opacity(0.55), lineWidth: 1.5)
                                    .frame(width: 32, height: 32)
                            }
                            if isActive {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                            } else if isToday {
                                Circle()
                                    .fill(Color.gymLinkPink.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.07))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(white: 0.1), lineWidth: 0.5))
    }

    // MARK: - Gyms map card

    private var gymsCard: some View {
        Button { selectedWidget = .map } label: {
            ZStack(alignment: .bottomLeading) {
                Map(position: .constant(.region(previewRegion)))
                    .disabled(true)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.78)],
                    startPoint: .center, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gymLinkPink.opacity(0.25))
                            .frame(width: 46, height: 46)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gymLinkPink)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find Gyms Near Me")
                            .font(.headline).foregroundColor(.white)
                        Text("Explore gyms in your area")
                            .font(.subheadline).foregroundColor(Color(white: 0.72))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(white: 0.5))
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Motivational quote card

    private var motivationalQuoteCard: some View {
        let q = todayQuote
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gymLinkPink.opacity(0.18), lineWidth: 0.5)
                )

            // Decorative oversized quote mark
            Text("\"")
                .font(.system(size: 140, weight: .black))
                .foregroundColor(Color.gymLinkPink.opacity(0.055))
                .offset(x: 8, y: -28)
                .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                    Text("TODAY'S FUEL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.4))
                        .tracking(1.5)
                }

                Text("\"\(q.text)\"")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)

                if !q.author.isEmpty {
                    Text("— \(q.author)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.38))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Bottom dock

    private var dock: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gymLinkPink.opacity(0.3))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                DockButton(icon: "message.fill", label: "Messages", badge: unreadMessages) {
                    showMessages = true
                }
                DockButton(icon: "bell.fill", label: "Activity", badge: unreadCount) {
                    selectedWidget = .notifications
                }

                // Center raised post button
                Button { showPostTypePicker = true } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.gymLinkPink)
                                .frame(width: 56, height: 56)
                                .shadow(color: .gymLinkPink.opacity(0.5), radius: 10, x: 0, y: 3)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                        Text("Post")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gymLinkPink)
                    }
                }
                .frame(maxWidth: .infinity)
                .offset(y: -18)

                DockButton(icon: "bookmark.fill", label: "Saved") { selectedWidget = .saved }
                DockButton(icon: "magnifyingglass", label: "Search") { showUserSearch = true }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(Color(white: 0.06))
        }
    }

    // MARK: - Firestore

    private func loadDashboard() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        db.collection("users").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            DispatchQueue.main.async {
                self.username      = data["username"] as? String ?? ""
                self.workoutStreak = data["workoutStreak"] as? Int ?? 0
                self.score         = data["score"] as? Int ?? 0
                let metrics        = data["metrics"] as? [String: Any] ?? [:]
                self.postsCount    = metrics["postsCount"] as? Int ?? 0
            }
        }

        let cal = Calendar.current
        guard let weekStart = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) else { return }

        db.collection("posts")
            .whereField("authorId", isEqualTo: uid)
            .whereField("timestamp", isGreaterThan: Timestamp(date: weekStart))
            .getDocuments { snap, _ in
                var active: Set<Int> = []
                snap?.documents.forEach { doc in
                    if let ts = doc.data()["timestamp"] as? Timestamp {
                        let wd  = cal.component(.weekday, from: ts.dateValue())
                        let idx = wd == 1 ? 6 : wd - 2
                        active.insert(idx)
                    }
                }
                DispatchQueue.main.async { self.activeWeekdays = active }
            }
    }

    private func listenForUnreadNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users").document(uid).collection("notifications")
            .whereField("read", isEqualTo: false)
            .addSnapshotListener { snap, _ in
                unreadCount = snap?.documents.count ?? 0
            }
    }

    private func listenForUnreadMessages() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("conversations")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { snap, _ in
                let total = snap?.documents.reduce(0) { sum, doc in
                    let unread = doc.data()["unread"] as? [String: Int] ?? [:]
                    return sum + (unread[uid] ?? 0)
                } ?? 0
                unreadMessages = total
            }
    }
}

// MARK: - Post type picker sheet

struct PostTypePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (PostCategory) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("What are you sharing?")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .padding(.top, 8)

                ForEach(PostCategory.allCases, id: \.self) { cat in
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSelect(cat) }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(Color.gymLinkPink.opacity(0.18))
                                    .frame(width: 50, height: 50)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.gymLinkPink)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.navigationTitle)
                                    .font(.headline).foregroundColor(.white)
                                Text(cat.subtitle)
                                    .font(.subheadline).foregroundColor(Color(white: 0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(white: 0.3))
                        }
                        .padding(14)
                        .background(Color(white: 0.1))
                        .cornerRadius(18)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Dock button

private struct DockButton: View {
    let icon: String
    let label: String
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(badge > 0 ? .gymLinkPink : Color(white: 0.4))
                        .frame(width: 32, height: 32)
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.gymLinkPink)
                            .clipShape(Capsule())
                            .offset(x: 12, y: -6)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(badge > 0 ? .gymLinkPink : Color(white: 0.4))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
