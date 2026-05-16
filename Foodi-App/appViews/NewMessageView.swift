import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct NewMessageView: View {
    var onConversationStarted: (String, String, String, String?) -> Void  // (convoId, otherUID, otherUsername, otherPicURL)

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchUser] = []
    @State private var isSearching = false

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gymLinkPink).frame(width: 20)
                        TextField("Search by username...", text: $query)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: query) { search() }
                        if !query.isEmpty {
                            Button { query = ""; results = [] } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(white: 0.38))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.11))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                    if isSearching {
                        ProgressView().tint(.gymLinkPink).padding(.top, 30)
                    } else if results.isEmpty && !query.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "person.slash").font(.system(size: 36))
                                .foregroundColor(Color(white: 0.22)).padding(.top, 40)
                            Text("No users found").font(.subheadline).foregroundColor(Color(white: 0.35))
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(results) { user in
                                    if user.id != myUID {
                                        Button { startConversation(with: user) } label: {
                                            userRow(user)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.gymLinkPink)
                }
            }
        }
    }

    private func userRow(_ user: SearchUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(white: 0.15)).frame(width: 46, height: 46)
                if let urlStr = user.profileImageURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Color(white: 0.15) }
                        .frame(width: 46, height: 46).clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18)).foregroundColor(Color(white: 0.4))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio).font(.caption).foregroundColor(Color(white: 0.42)).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Color(white: 0.25))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(white: 0.07))
    }

    private func search() {
        guard !query.isEmpty else { results = []; return }
        isSearching = true
        Firestore.firestore().collection("users").getDocuments { snap, _ in
            let all: [SearchUser] = snap?.documents.compactMap { doc in
                guard let username = doc.data()["username"] as? String else { return nil }
                return SearchUser(id: doc.documentID, username: username,
                                  profileImageURL: doc.data()["profilePicURL"] as? String,
                                  bio: doc.data()["bio"] as? String)
            } ?? []
            DispatchQueue.main.async {
                results = all.filter { $0.username.localizedCaseInsensitiveContains(query) }
                isSearching = false
            }
        }
    }

    private func startConversation(with user: SearchUser) {
        guard !myUID.isEmpty else { return }
        // Fetch my profile info first
        Firestore.firestore().collection("users").document(myUID).getDocument { snap, _ in
            let myUsername = snap?.data()?["username"] as? String ?? "Me"
            let myPic      = snap?.data()?["profilePicURL"] as? String
            MessagingManager.shared.getOrCreateConversation(
                myUID: myUID, myUsername: myUsername, myPic: myPic,
                theirUID: user.id, theirUsername: user.username,
                theirPic: user.profileImageURL
            ) { convoId in
                DispatchQueue.main.async {
                    onConversationStarted(convoId, user.id, user.username, user.profileImageURL)
                }
            }
        }
    }
}
