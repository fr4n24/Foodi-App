import SwiftUI
import FirebaseAuth
import FirebaseFirestore

private struct NewConvoTarget {
    let convoId: String
    let otherUID: String
    let otherUsername: String
    let otherPicURL: String?
}

struct MessagesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var conversations: [Conversation] = []
    @State private var showNewMessage = false
    @State private var listener: (any ListenerRegistration)?
    @State private var pendingConvo: NewConvoTarget? = nil
    @State private var navigateToNew = false

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if conversations.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(Color(white: 0.22))
                        Text("No messages yet")
                            .font(.headline).foregroundColor(Color(white: 0.35))
                        Text("Start a conversation by tapping the compose button")
                            .font(.subheadline).foregroundColor(Color(white: 0.28))
                            .multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(conversations) { convo in
                                NavigationLink {
                                    ConversationView(
                                        conversationId:   convo.id,
                                        otherUID:         convo.otherUID,
                                        otherUsername:    convo.otherUsername,
                                        otherPicURL:      convo.otherPicURL
                                    )
                                } label: {
                                    convoRow(convo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.gymLinkPink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewMessage = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.gymLinkPink)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToNew) {
                if let c = pendingConvo {
                    ConversationView(
                        conversationId: c.convoId,
                        otherUID:       c.otherUID,
                        otherUsername:  c.otherUsername,
                        otherPicURL:    c.otherPicURL
                    )
                }
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView { convoId, otherUID, otherUsername, picURL in
                    pendingConvo = NewConvoTarget(
                        convoId: convoId,
                        otherUID: otherUID,
                        otherUsername: otherUsername,
                        otherPicURL: picURL
                    )
                    showNewMessage = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        navigateToNew = true
                    }
                }
            }
            .onAppear { startListening() }
            .onDisappear { listener?.remove() }
        }
    }

    private func convoRow(_ convo: Conversation) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle().fill(Color(white: 0.15)).frame(width: 52, height: 52)
                if let urlStr = convo.otherPicURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Color(white: 0.15) }
                        .frame(width: 52, height: 52).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20)).foregroundColor(Color(white: 0.4))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(convo.otherUsername)
                    .font(.system(size: 15, weight: convo.unreadCount > 0 ? .bold : .semibold))
                    .foregroundColor(.white)
                Text(convo.lastMessage.isEmpty ? "Say hello 👋" : convo.lastMessage)
                    .font(.system(size: 13))
                    .foregroundColor(convo.unreadCount > 0 ? Color(white: 0.75) : Color(white: 0.42))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(relativeTime(convo.lastMessageTimestamp))
                    .font(.system(size: 11)).foregroundColor(Color(white: 0.35))
                if convo.unreadCount > 0 {
                    Text("\(min(convo.unreadCount, 99))")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gymLinkPink).clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(white: 0.07))
    }

    private func startListening() {
        guard !myUID.isEmpty else { return }
        listener = MessagingManager.shared.listenToConversations(uid: myUID) { convos in
            conversations = convos
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60       { return "now" }
        if diff < 3600     { return "\(Int(diff/60))m" }
        if diff < 86400    { return "\(Int(diff/3600))h" }
        if diff < 604800   { return "\(Int(diff/86400))d" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
}
