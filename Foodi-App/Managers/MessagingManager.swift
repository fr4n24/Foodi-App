import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Models
struct Conversation: Identifiable {
    let id: String
    let otherUID: String
    let otherUsername: String
    let otherPicURL: String?
    let lastMessage: String
    let lastMessageTimestamp: Date
    let unreadCount: Int
}

struct DirectMessage: Identifiable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
}

// MARK: - Manager
class MessagingManager {
    static let shared = MessagingManager()
    private let db = Firestore.firestore()
    private init() {}

    // Deterministic conversation ID — same pair always gets same doc
    static func conversationId(uid1: String, uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    // MARK: - Get or create conversation
    func getOrCreateConversation(
        myUID: String, myUsername: String, myPic: String?,
        theirUID: String, theirUsername: String, theirPic: String?,
        completion: @escaping (String) -> Void
    ) {
        let convoId = Self.conversationId(uid1: myUID, uid2: theirUID)
        let ref = db.collection("conversations").document(convoId)
        ref.getDocument { snap, _ in
            if snap?.exists == true {
                completion(convoId)
                return
            }
            let data: [String: Any] = [
                "participants":          [myUID, theirUID],
                "lastMessage":           "",
                "lastMessageTimestamp":  Timestamp(date: Date()),
                "lastSenderId":          "",
                "participantUsernames":  [myUID: myUsername, theirUID: theirUsername],
                "participantPics":       [myUID: myPic ?? "", theirUID: theirPic ?? ""],
                "unread":                [myUID: 0, theirUID: 0]
            ]
            ref.setData(data) { _ in completion(convoId) }
        }
    }

    // MARK: - Listen to conversations
    func listenToConversations(uid: String,
                               completion: @escaping ([Conversation]) -> Void) -> ListenerRegistration {
        db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .addSnapshotListener { snap, error in
            if let error { print("Conversations listener error:", error.localizedDescription) }
                let convos: [Conversation] = (snap?.documents.compactMap { doc -> Conversation? in
                    let d = doc.data()
                    let participants = d["participants"] as? [String] ?? []
                    let usernames    = d["participantUsernames"] as? [String: String] ?? [:]
                    let pics         = d["participantPics"] as? [String: String] ?? [:]
                    let unread       = d["unread"] as? [String: Int] ?? [:]
                    let otherUID     = participants.first { $0 != uid } ?? ""
                    return Conversation(
                        id:                    doc.documentID,
                        otherUID:              otherUID,
                        otherUsername:         usernames[otherUID] ?? "Unknown",
                        otherPicURL:           pics[otherUID],
                        lastMessage:           d["lastMessage"] as? String ?? "",
                        lastMessageTimestamp:  (d["lastMessageTimestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        unreadCount:           unread[uid] ?? 0
                    )
                } ?? []).sorted { $0.lastMessageTimestamp > $1.lastMessageTimestamp }
                completion(convos)
            }
    }

    // MARK: - Listen to messages
    func listenToMessages(conversationId: String,
                          completion: @escaping ([DirectMessage]) -> Void) -> ListenerRegistration {
        db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snap, _ in
                let msgs: [DirectMessage] = snap?.documents.compactMap { doc in
                    let d = doc.data()
                    return DirectMessage(
                        id:        doc.documentID,
                        senderId:  d["senderId"] as? String ?? "",
                        text:      d["text"] as? String ?? "",
                        timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
                completion(msgs)
            }
    }

    // MARK: - Send message
    func sendMessage(conversationId: String, senderId: String, text: String,
                     completion: ((Error?) -> Void)? = nil) {
        guard !conversationId.isEmpty, !senderId.isEmpty else {
            completion?(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing IDs"]))
            return
        }
        let convoRef = db.collection("conversations").document(conversationId)
        let msgRef   = convoRef.collection("messages").document()

        msgRef.setData([
            "senderId":  senderId,
            "text":      text,
            "timestamp": Timestamp(date: Date()),
            "read":      false
        ]) { error in
            completion?(error)
            guard error == nil else { return }
            convoRef.getDocument { snap, _ in
                var update: [String: Any] = [
                    "lastMessage":          text,
                    "lastMessageTimestamp": Timestamp(date: Date()),
                    "lastSenderId":         senderId
                ]
                if let data = snap?.data() {
                    let participants = data["participants"] as? [String] ?? []
                    let receiverUID  = participants.first { $0 != senderId } ?? ""
                    if !receiverUID.isEmpty {
                        var unread = data["unread"] as? [String: Int] ?? [:]
                        unread[receiverUID] = (unread[receiverUID] ?? 0) + 1
                        update["unread"] = unread
                    }
                }
                convoRef.setData(update, merge: true)
            }
        }
    }

    // MARK: - Mark as read
    func markAsRead(conversationId: String, uid: String) {
        db.collection("conversations").document(conversationId)
            .updateData(["unread.\(uid)": 0])
    }
}
