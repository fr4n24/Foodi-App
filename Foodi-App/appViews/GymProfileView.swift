import SwiftUI
import MapKit

struct GymProfileView: View {
    let gym: GymDetail

    @State private var posts: [Post] = []
    @State private var averageRating: Double = 0.0
    @State private var showFullMap = false
    @State private var isSaved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mapSection
                    headerSection
                    divider
                    infoSection
                    divider
                    actionsSection
                    divider
                    postsSection
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PostManager.shared.fetchPosts(forGym: gym.name) { fetched in
                posts = fetched
                let rated = fetched.compactMap { $0.rating }.filter { $0 > 0 }
                if !rated.isEmpty {
                    averageRating = rated.reduce(0, +) / Double(rated.count)
                }
            }
            SavedManager.shared.isSavedd(gym) { saved in isSaved = saved }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        ZStack {
            Map { Marker(gym.name, coordinate: gym.coordinate) }
                .frame(height: 200)
                .clipped()
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showFullMap = true }
        }
        .sheet(isPresented: $showFullMap) {
            GymMapSheet(target: gym.coordinate, gymName: gym.name)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(gym.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                if averageRating > 0 {
                    HStack(spacing: 4) {
                        ForEach(1..<6) { star in
                            Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(star <= Int(averageRating.rounded()) ? .gymLinkPink : Color(white: 0.28))
                        }
                        Text(String(format: "%.1f", averageRating))
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.42))
                        Text("· \(posts.count) posts")
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.32))
                    }
                } else {
                    Label("\(posts.count) posts", systemImage: "photo.on.rectangle.angled")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            Spacer()
            Button {
                SavedManager.shared.toggleSaved(gym) { saved in
                    withAnimation(.easeInOut(duration: 0.15)) { isSaved = saved }
                }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(isSaved ? .gymLinkPink : Color(white: 0.45))
                    .frame(width: 42, height: 42)
                    .background(Color(white: 0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Info")
            VStack(spacing: 0) {
                Button { openDirections() } label: {
                    infoRow(icon: "mappin.circle.fill", label: gym.address, color: Color(white: 0.45), chevron: true)
                }
                if let phone = gym.phone, !phone.isEmpty {
                    thinDivider
                    Button { dialPhone(phone) } label: {
                        infoRow(icon: "phone.fill", label: phone, color: .gymLinkPink, chevron: true)
                    }
                }
                if let url = gym.url {
                    thinDivider
                    Button { UIApplication.shared.open(url) } label: {
                        infoRow(icon: "globe", label: url.host ?? url.absoluteString, color: .gymLinkPink, chevron: true)
                    }
                }
            }
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 20)
    }

    private func infoRow(icon: String, label: String, color: Color, chevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(chevron ? color : Color(white: 0.78))
                .lineLimit(2)
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(white: 0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Actions")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    actionChip(icon: "arrow.triangle.turn.up.right.circle.fill", label: "Directions", action: openDirections)
                    if let phone = gym.phone, !phone.isEmpty {
                        actionChip(icon: "phone.fill", label: "Call") { dialPhone(phone) }
                    }
                    if let url = gym.url {
                        actionChip(icon: "safari.fill", label: "Website") { UIApplication.shared.open(url) }
                    }
                    actionChip(icon: "square.and.arrow.up", label: "Share", action: shareGym)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
    }

    private func actionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.gymLinkPink)
                    .frame(width: 50, height: 50)
                    .background(Color.gymLinkPink.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
            }
        }
    }

    // MARK: - Posts

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel(posts.isEmpty ? "Posts" : "Posts  \(posts.count)")
                Spacer()
            }
            .padding(.trailing, 20)

            if posts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 34))
                            .foregroundColor(Color(white: 0.22))
                        Text("No posts at this gym yet")
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.32))
                        Text("Be the first to check in here!")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.25))
                    }
                    Spacer()
                }
                .padding(.vertical, 36)
            } else {
                let cols = [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ]
                LazyVGrid(columns: cols, spacing: 2) {
                    ForEach(posts) { post in
                        NavigationLink { PostDetailView(post: post) } label: {
                            postTile(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 40)
    }

    private func postTile(_ post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Color(white: 0.1) }
                } else {
                    Color(white: 0.1)
                        .overlay(
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(Color.gymLinkPink.opacity(0.3))
                        )
                }
            }
            .frame(height: 110)
            .clipped()

            if let rating = post.rating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text(String(format: "%.1f", rating)).font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Shared UI

    private var divider: some View {
        Color(white: 0.1).frame(height: 1).padding(.horizontal, 16).padding(.bottom, 20)
    }

    private var thinDivider: some View {
        Color(white: 0.12).frame(height: 1).padding(.leading, 52)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(Color(white: 0.38))
            .padding(.horizontal, 20)
    }

    // MARK: - Action helpers

    private func dialPhone(_ phone: String) {
        let cleaned = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(cleaned)") { UIApplication.shared.open(url) }
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: gym.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = gym.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func shareGym() {
        let text = "\(gym.name)\n\(gym.address)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}
