import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ConversationView: View {
    let conversationId: String
    let otherUID: String
    let otherUsername: String
    let otherPicURL: String?

    @State private var messages: [DirectMessage] = []
    @State private var inputText = ""
    @State private var listener: (any ListenerRegistration)?
    @FocusState private var inputFocused: Bool

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Input bar
                inputBar
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(otherUsername)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { UserProfileView(userId: otherUID) } label: {
                    Group {
                        if let urlStr = otherPicURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                placeholder: { Color(white: 0.2) }
                                .frame(width: 30, height: 30).clipShape(Circle())
                        } else {
                            Circle().fill(Color(white: 0.2)).frame(width: 30, height: 30)
                                .overlay(Image(systemName: "person.fill").font(.system(size: 12)).foregroundColor(Color(white: 0.5)))
                        }
                    }
                }
            }
        }
        .onAppear {
            startListening()
            MessagingManager.shared.markAsRead(conversationId: conversationId, uid: myUID)
        }
        .onDisappear { listener?.remove() }
    }

    // MARK: - Message bubble
    private func messageBubble(_ msg: DirectMessage) -> some View {
        let isMe = msg.senderId == myUID
        return HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundColor(isMe ? .white : .white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isMe ? Color.gymLinkPink : Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(shortTime(msg.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.32))
                    .padding(.horizontal, 4)
            }

            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Input bar
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(white: 0.12))
                .cornerRadius(22)
                .foregroundColor(.white)
                .focused($inputFocused)

            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                              ? Color(white: 0.18) : Color.gymLinkPink)
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Color(white: 0.35) : .white)
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(white: 0.07))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !myUID.isEmpty else { return }
        inputText = ""
        MessagingManager.shared.sendMessage(
            conversationId: conversationId,
            senderId: myUID,
            text: text
        ) { error in
            if error != nil {
                DispatchQueue.main.async { self.inputText = text }
            }
        }
    }

    private func startListening() {
        listener = MessagingManager.shared.listenToMessages(conversationId: conversationId) { msgs in
            messages = msgs
        }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = Date().timeIntervalSince(date) < 86400 ? "h:mm a" : "MMM d"
        return f.string(from: date)
    }
}
