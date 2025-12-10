import SwiftUI

struct LeaderboardView: View {
    @StateObject private var vm = LeaderboardViewModel()
    @State private var selectedFilter: LeaderboardFilter = .users   // users / restaurants / food types

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                VStack(spacing: 12) {
                    filterPicker
                    Divider()
                    contentList
                }
                .background(Color(.systemBackground))
            }
        }
        .onAppear { vm.fetchOnce() }
    }

    // MARK: - Header
    private var header: some View {
        ZStack {
            Color.foodiBlue
                .ignoresSafeArea(edges: .top)

            HStack {
                Text("Leaderboard")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(height: 110)
    }

    // MARK: - Filter Picker
    private var filterPicker: some View {
        Picker("Leaderboard Filter", selection: $selectedFilter) {
            ForEach(LeaderboardFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Content List
    private var contentList: some View {
        List {
            switch selectedFilter {
            case .users:
                ForEach(vm.users.indices, id: \.self) { i in
                    let u = vm.users[i]

                    NavigationLink {
                        UserProfileView(userId: u.id)
                    } label: {
                        leaderboardRow(
                            rank: i + 1,
                            title: u.username,
                            valueText: "\(u.score) pts"
                        )
                    }
                }

            case .restaurants:
                ForEach(vm.restaurantRanks.indices, id: \.self) { i in
                    let r = vm.restaurantRanks[i]

                    NavigationLink {
                        RestaurantProfileLoaderView(restaurantName: r.name)
                    } label: {
                        leaderboardRow(
                            rank: i + 1,
                            title: r.name,
                            valueText: "\(r.count) posts"
                        )
                    }
                }

            case .foodTypes:
                ForEach(vm.foodTypeRanks.indices, id: \.self) { i in
                    let f = vm.foodTypeRanks[i]
                    leaderboardRow(
                        rank: i + 1,
                        title: f.name,
                        valueText: "\(f.count) posts"
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Row builder
    private func leaderboardRow(rank: Int, title: String, valueText: String) -> some View {
        HStack {
            Text("#\(rank)")
                .font(.headline)
                .frame(width: 32, alignment: .trailing)

            Text(title)
                .bold()

            Spacer()

            Text(valueText)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

