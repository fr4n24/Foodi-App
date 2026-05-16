import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = LeaderboardViewModel()
    @State private var category: LeaderboardCategory = .overall
    @State private var period: TimePeriod = .allTime

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                categoryTabs
                if category != .gyms && category != .streak { timePicker }
                content
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { vm.fetch(period: period, category: category) }
        .onChange(of: category) { vm.fetch(period: period, category: category) }
        .onChange(of: period)   { vm.fetch(period: period, category: category) }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.gymLinkPink)
            Text("Leaderboard")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(.white)
            Spacer()
            if vm.isLoading {
                ProgressView().tint(.gymLinkPink).scaleEffect(0.8)
            }
            Image("GymLinkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Category tabs
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LeaderboardCategory.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { category = cat }
                    } label: {
                        Text(cat.rawValue)
                            .font(.system(size: 14, weight: category == cat ? .semibold : .regular))
                            .foregroundColor(category == cat ? .white : Color(white: 0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(category == cat ? Color.gymLinkPink : Color(white: 0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Time period picker
    private var timePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimePeriod.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { period = p }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 12, weight: period == p ? .semibold : .regular))
                        .foregroundColor(period == p ? .white : Color(white: 0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(period == p ? Color.gymLinkPink : Color.clear)
                        .cornerRadius(10)
                        .padding(3)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.1))
        .cornerRadius(13)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                switch category {
                case .gyms:
                    gymsList
                case .gains:
                    gainsList
                case .weight:
                    weightList
                case .streak:
                    streakList
                default:
                    usersList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Users list
    @ViewBuilder
    private var usersList: some View {
        if vm.users.isEmpty && !vm.isLoading {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundColor(Color(white: 0.25))
                Text("No activity yet for this period")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            // Top 3 podium
            if vm.users.count >= 3 {
                podiumView
                    .padding(.bottom, 6)
            }

            // Rest of the list
            let startIndex = min(3, vm.users.count)
            ForEach(Array(vm.users.enumerated()).dropFirst(startIndex), id: \.element.id) { (i, user) in
                NavigationLink { UserProfileView(userId: user.id) } label: {
                    rankRow(rank: i + 1, user: user)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Podium (top 3)
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 2nd place
            if vm.users.count > 1 {
                podiumCard(rank: 2, user: vm.users[1], height: 100)
            }
            // 1st place — tallest
            if vm.users.count > 0 {
                podiumCard(rank: 1, user: vm.users[0], height: 130)
            }
            // 3rd place
            if vm.users.count > 2 {
                podiumCard(rank: 3, user: vm.users[2], height: 80)
            }
        }
        .padding(.top, 10)
    }

    private func podiumCard(rank: Int, user: LeaderboardUser, height: CGFloat) -> some View {
        let medals: [Int: (String, Color)] = [
            1: ("🥇", Color(red: 1, green: 0.84, blue: 0)),
            2: ("🥈", Color(white: 0.75)),
            3: ("🥉", Color(red: 0.8, green: 0.5, blue: 0.2))
        ]
        let (medal, color) = medals[rank] ?? ("", .white)

        return NavigationLink { UserProfileView(userId: user.id) } label: {
            VStack(spacing: 6) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: rank == 1 ? 68 : 54, height: rank == 1 ? 68 : 54)
                        .overlay(Circle().stroke(color, lineWidth: rank == 1 ? 2.5 : 1.5))

                    if let urlStr = user.profilePicURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill").foregroundColor(Color(white: 0.4))
                        }
                        .frame(width: rank == 1 ? 64 : 50, height: rank == 1 ? 64 : 50)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: rank == 1 ? 26 : 20))
                            .foregroundColor(Color(white: 0.4))
                    }

                    // Medal overlay
                    Text(medal)
                        .font(.system(size: 18))
                        .offset(x: rank == 1 ? 22 : 18, y: rank == 1 ? -22 : -18)
                }

                Text(user.username)
                    .font(.system(size: rank == 1 ? 13 : 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(valueText(score: user.score))
                    .font(.system(size: 11))
                    .foregroundColor(.gymLinkPink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .frame(height: height + 90)
            .background(Color(white: 0.09))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(rank == 1 ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rank row (4th+)
    private func rankRow(rank: Int, user: LeaderboardUser) -> some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .frame(width: 32, alignment: .trailing)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 42, height: 42)
                if let urlStr = user.profilePicURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "person.fill").foregroundColor(Color(white: 0.4)) }
                        .frame(width: 42, height: 42).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.4))
                }
            }

            Text(user.username)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Text(valueText(score: user.score))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.gymLinkPink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.09))
        .cornerRadius(14)
    }

    // MARK: - Gyms list
    @ViewBuilder
    private var gymsList: some View {
        if vm.gymRanks.isEmpty {
            Text("No gym data yet")
                .font(.subheadline).foregroundColor(Color(white: 0.35))
                .frame(maxWidth: .infinity).padding(.top, 60)
        } else {
            ForEach(Array(vm.gymRanks.enumerated()), id: \.element.id) { i, gym in
                NavigationLink { GymProfileLoaderView(gymName: gym.name) } label: {
                    HStack(spacing: 14) {
                        Text("#\(i + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.38))
                            .frame(width: 32, alignment: .trailing)

                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gymLinkPink.opacity(0.15))
                                .frame(width: 42, height: 42)
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.gymLinkPink)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(gym.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text("\(gym.count) posts")
                                .font(.caption)
                                .foregroundColor(Color(white: 0.45))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(white: 0.25))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.09))
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Gains list
    @ViewBuilder
    private var gainsList: some View {
        if vm.users.isEmpty && !vm.isLoading {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundColor(Color(white: 0.25))
                Text("No progressions logged yet")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.35))
                Text("Post a workout with a PR to appear here")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.28))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            ForEach(Array(vm.users.enumerated()), id: \.element.id) { i, user in
                NavigationLink { UserProfileView(userId: user.id) } label: {
                    gainsRow(rank: i + 1, user: user)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func gainsRow(rank: Int, user: LeaderboardUser) -> some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .frame(width: 32, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 42, height: 42)
                if let urlStr = user.profilePicURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "person.fill").foregroundColor(Color(white: 0.4)) }
                        .frame(width: 42, height: 42).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.4))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if let detail = user.gainDetail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(user.score)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.45))
                Text("best gain")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.09))
        .cornerRadius(14)
    }

    // MARK: - Weight list (heaviest lifts)
    @ViewBuilder
    private var weightList: some View {
        if vm.users.isEmpty && !vm.isLoading {
            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(white: 0.25))
                Text("No weight data yet")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.35))
                Text("Log a workout with lbs/kg to appear here")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.28))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            if vm.users.count >= 3 { podiumView.padding(.bottom, 6) }
            let startIndex = min(3, vm.users.count)
            ForEach(Array(vm.users.enumerated()).dropFirst(startIndex), id: \.element.id) { (i, user) in
                NavigationLink { UserProfileView(userId: user.id) } label: {
                    weightRow(rank: i + 1, user: user)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func weightRow(rank: Int, user: LeaderboardUser) -> some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .frame(width: 32, alignment: .trailing)

            ZStack {
                Circle().fill(Color(white: 0.15)).frame(width: 42, height: 42)
                if let urlStr = user.profilePicURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "person.fill").foregroundColor(Color(white: 0.4)) }
                        .frame(width: 42, height: 42).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill").font(.system(size: 16)).foregroundColor(Color(white: 0.4))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user.username)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                if let detail = user.gainDetail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.gymLinkPink.opacity(0.12)).frame(height: 32)
                Text("\(user.score) kg")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.gymLinkPink)
                    .padding(.horizontal, 10)
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.09))
        .cornerRadius(14)
    }

    // MARK: - Streak list
    @ViewBuilder
    private var streakList: some View {
        if vm.users.isEmpty && !vm.isLoading {
            VStack(spacing: 12) {
                Text("🔥").font(.system(size: 48))
                Text("No active streaks yet")
                    .font(.subheadline).foregroundColor(Color(white: 0.35))
                Text("Post workouts on consecutive days to build a streak")
                    .font(.caption).foregroundColor(Color(white: 0.28))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.top, 60)
        } else {
            if vm.users.count >= 3 { podiumView.padding(.bottom, 6) }
            let startIndex = min(3, vm.users.count)
            ForEach(Array(vm.users.enumerated()).dropFirst(startIndex), id: \.element.id) { (i, user) in
                NavigationLink { UserProfileView(userId: user.id) } label: {
                    streakRow(rank: i + 1, user: user)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func streakRow(rank: Int, user: LeaderboardUser) -> some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
                .frame(width: 32, alignment: .trailing)

            ZStack {
                Circle().fill(Color(white: 0.15)).frame(width: 42, height: 42)
                if let urlStr = user.profilePicURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Image(systemName: "person.fill").foregroundColor(Color(white: 0.4)) }
                        .frame(width: 42, height: 42).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill").font(.system(size: 16)).foregroundColor(Color(white: 0.4))
                }
            }

            Text(user.username)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 4) {
                Text("🔥").font(.system(size: 16))
                Text("\(user.score)d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.1))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.09))
        .cornerRadius(14)
    }

    // MARK: - Helpers
    private func valueText(score: Int) -> String {
        switch category {
        case .overall:  return "\(score) pts"
        case .weight:   return "\(score) kg"
        case .streak:   return "🔥 \(score)d"
        case .gains:    return "+\(score)"
        default:        return "\(score) posts"
        }
    }
}
