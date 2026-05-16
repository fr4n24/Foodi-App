import SwiftUI

struct PostRowView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = post.imageURL, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(white: 0.12)).overlay(ProgressView().tint(.gymLinkPink))
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(16, corners: [.topLeft, .topRight])
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(post.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if let gym = post.gym, !gym.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 10)).foregroundColor(.gymLinkPink)
                            Text(gym).font(.system(size: 12)).foregroundColor(.gymLinkPink).lineLimit(1)
                        }
                    }
                }

                if let rating = post.rating, rating > 0 {
                    HStack(spacing: 3) {
                        ForEach(1..<6) { index in
                            Image(systemName: index <= Int(rating) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(index <= Int(rating) ? .gymLinkPink : Color(white: 0.28))
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.42))
                    }
                }

                Text(post.content)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.62))
                    .lineLimit(3)

                Text("@\(post.author)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.38))
            }
            .padding(14)
        }
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(white: 0.13), lineWidth: 0.5))
    }
}

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerRow(radius: radius, corners: corners))
    }
}

private struct RoundedCornerRow: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
