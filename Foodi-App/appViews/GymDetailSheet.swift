import SwiftUI
import MapKit
import Contacts
import FirebaseFirestore

// MARK: - Model

private struct GymPost: Identifiable {
    let id: String
    let imageURL: String?
    let caption: String
    let username: String
    let likeCount: Int
}

// MARK: - Sheet

struct GymDetailSheet: View {
    let item: MKMapItem
    let distanceText: String?
    var onViewProfile: ((MKMapItem) -> Void)?

    @State private var posts: [GymPost] = []
    @State private var loadingPosts = true
    @Environment(\.dismiss) private var dismiss

    private var gymName: String { item.name ?? "Gym" }
    private var address: String {
        if let postal = item.placemark.postalAddress {
            return CNPostalAddressFormatter()
                .string(from: postal)
                .replacingOccurrences(of: "\n", with: ", ")
        }
        return item.placemark.title ?? "Unknown address"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(white: 0.18))
                            .clipShape(Circle())
                    }
                }
                if onViewProfile != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                            onViewProfile?(item)
                        } label: {
                            Text("Full Profile")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gymLinkPink)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.black)
        .onAppear { fetchPosts() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(gymName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                if let dist = distanceText {
                    Label(dist, systemImage: "location.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gymLinkPink)
                }
                if let cat = item.pointOfInterestCategory?.rawValue
                    .replacingOccurrences(of: "MKPOICategory", with: "") {
                    Text(cat)
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.4))
                }
            }
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gymLinkPink.opacity(0.14))
                    .frame(width: 58, height: 58)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.gymLinkPink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 20)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Info")
            VStack(spacing: 0) {
                infoRow(icon: "mappin.circle.fill", label: address, color: Color(white: 0.45))
                if let phone = item.phoneNumber, !phone.isEmpty {
                    thinDivider
                    Button { dialPhone(phone) } label: {
                        infoRow(icon: "phone.fill", label: phone, color: .gymLinkPink, chevron: true)
                    }
                }
                if let url = item.url {
                    thinDivider
                    Button { UIApplication.shared.open(url) } label: {
                        infoRow(icon: "globe", label: url.host ?? url.absoluteString,
                                color: .gymLinkPink, chevron: true)
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
                    actionChip(icon: "arrow.triangle.turn.up.right.circle.fill",
                               label: "Directions", action: openDirections)
                    if let phone = item.phoneNumber, !phone.isEmpty {
                        actionChip(icon: "phone.fill", label: "Call") { dialPhone(phone) }
                    }
                    if let url = item.url {
                        actionChip(icon: "safari.fill", label: "Website") {
                            UIApplication.shared.open(url)
                        }
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

            if loadingPosts {
                HStack {
                    Spacer()
                    ProgressView().tint(.gymLinkPink)
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if posts.isEmpty {
                emptyPosts
            } else {
                postsGrid
            }
        }
        .padding(.bottom, 40)
    }

    private var emptyPosts: some View {
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
    }

    private var postsGrid: some View {
        let cols = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]
        return LazyVGrid(columns: cols, spacing: 2) {
            ForEach(posts) { post in
                postTile(post)
            }
        }
        .padding(.horizontal, 16)
    }

    private func postTile(_ post: GymPost) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(white: 0.1)
                    }
                } else {
                    Color(white: 0.1)
                }
            }
            .frame(height: 110)
            .clipped()

            if post.likeCount > 0 {
                Label("\(post.likeCount)", systemImage: "heart.fill")
                    .font(.system(size: 10, weight: .semibold))
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

    // MARK: - Actions impl

    private func dialPhone(_ phone: String) {
        let cleaned = phone.filter { $0.isNumber || $0 == "+" }
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: item.placemark.coordinate)
        let dest = MKMapItem(placemark: placemark)
        dest.name = gymName
        dest.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func shareGym() {
        let text = "\(gymName)\n\(address)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    // MARK: - Firebase

    private func fetchPosts() {
        Firestore.firestore()
            .collection("posts")
            .whereField("gymName", isEqualTo: gymName)
            .order(by: "timestamp", descending: true)
            .limit(to: 9)
            .getDocuments { snap, _ in
                let fetched: [GymPost] = snap?.documents.compactMap { doc in
                    let d = doc.data()
                    return GymPost(
                        id: doc.documentID,
                        imageURL: d["imageURL"] as? String,
                        caption: d["caption"] as? String ?? "",
                        username: d["username"] as? String ?? "",
                        likeCount: d["likeCount"] as? Int ?? 0
                    )
                } ?? []
                DispatchQueue.main.async {
                    posts = fetched
                    loadingPosts = false
                }
            }
    }
}
