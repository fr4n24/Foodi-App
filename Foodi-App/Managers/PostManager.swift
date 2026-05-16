import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Post Model
struct Post: Identifiable, Codable {
    var id: String
    var title: String
    var dishName: String?
    var content: String
    var imageURL: String?
    var author: String
    var authorId: String
    var gymName: String?
    var gym: String?
    var rating: Double?
    var timestamp: Date
    var gymLat: Double?
    var gymLon: Double?
    // Meal macros
    var mealCalories: Int? = nil
    var mealProtein: Int? = nil
    var mealCarbs: Int? = nil
    var mealFat: Int? = nil
    // Workout progression
    var exerciseName: String? = nil
    var previousValue: Double? = nil
    var newValue: Double? = nil
    var progressionUnit: String? = nil
    var category: String?
}

// MARK: - Comment Model
struct Comment: Identifiable {
    let id: String
    let authorId: String
    let authorName: String
    let text: String
    let timestamp: Date
}

// MARK: - PostManager
class PostManager {
    static let shared = PostManager()
    private let db = Firestore.firestore()
    private init() {}
    
    // MARK: - Add Post
    func addPost(
        title: String,
        content: String,
        imageURL: String? = nil,
        gym: String? = nil,
        rating: Double? = nil,
        gymLat: Double? = nil,
        gymLon: Double? = nil,
        category: String? = nil,
        foodType: String? = nil,
        mealCalories: Int? = nil,
        mealProtein: Int? = nil,
        mealCarbs: Int? = nil,
        mealFat: Int? = nil,
        exerciseName: String? = nil,
        previousValue: Double? = nil,
        newValue: Double? = nil,
        progressionUnit: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            return completion(.failure(NSError(
                domain: "", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not logged in."]
            )))
        }

        let userRef = db.collection("users").document(user.uid)
        userRef.getDocument { snapshot, _ in
            var displayName = "Unknown User"
            if let data = snapshot?.data(),
               let username = data["username"] as? String {
                displayName = username
            }

            var postData: [String: Any] = [
                "title":     title,
                "content":   content,
                "imageURL":  imageURL ?? "",
                "author":    displayName,
                "authorId":  user.uid,
                "gym":       gym ?? "",
                "rating":    rating ?? 0.0,
                "gymLat":    gymLat ?? NSNull(),
                "gymLon":    gymLon ?? NSNull(),
                "category":  category ?? "workout",
                "foodType":  foodType ?? "",
                "timestamp": Timestamp(date: Date())
            ]
            if let v = mealCalories   { postData["mealCalories"]   = v }
            if let v = mealProtein    { postData["mealProtein"]    = v }
            if let v = mealCarbs      { postData["mealCarbs"]      = v }
            if let v = mealFat        { postData["mealFat"]        = v }
            if let v = exerciseName   { postData["exerciseName"]   = v }
            if let v = previousValue  { postData["previousValue"]  = v }
            if let v = newValue       { postData["newValue"]       = v }
            if let v = progressionUnit { postData["progressionUnit"] = v }

            self.db.collection("posts").addDocument(data: postData) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                ScoreService.shared.bumpOnPostCreated(actorUid: user.uid)
                if category == "workout" {
                    self.updateWorkoutStreak(for: user.uid)
                }
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Fetch Posts
    func fetchPosts(completion: @escaping ([Post]) -> Void) {
        db.collection("posts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching posts: \(error?.localizedDescription ?? "Unknown")")
                    completion([])
                    return
                }
                
                let posts = documents.compactMap { doc -> Post? in
                    let data = doc.data()
                    return Post(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        dishName: data["dishName"] as? String ?? "",
                        content: data["content"] as? String ?? "",
                        imageURL: data["imageURL"] as? String,
                        author: data["author"] as? String ?? "",
                        authorId: data["authorId"] as? String ?? "",
                        gymName: data["gymName"] as? String ?? "",
                        gym: data["gym"] as? String ?? "",
                        rating: data["rating"] as? Double ?? 0.0,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        gymLat: data["gymLat"] as? Double,
                        gymLon: data["gymLon"] as? Double,
                        mealCalories: data["mealCalories"] as? Int,
                        mealProtein: data["mealProtein"] as? Int,
                        mealCarbs: data["mealCarbs"] as? Int,
                        mealFat: data["mealFat"] as? Int,
                        exerciseName: data["exerciseName"] as? String,
                        previousValue: data["previousValue"] as? Double,
                        newValue: data["newValue"] as? Double,
                        progressionUnit: data["progressionUnit"] as? String,
                        category: data["category"] as? String
                    )
                }

                completion(posts)
            }
    }
    
    // MARK: - Fetch posts from followed users
    func fetchFollowingPosts(for uid: String, completion: @escaping ([Post]) -> Void) {
        let followingRef = db.collection("users").document(uid).collection("following")
        
        followingRef.getDocuments { snap, _ in
            let followedIds = snap?.documents.map { $0.documentID } ?? []
            print("DEBUG FOLLOWING IDS →", followedIds)
            
            guard !followedIds.isEmpty else {
                completion([])
                return
            }
            
            self.db.collection("posts")
                .whereField("authorId", in: followedIds)
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { postSnap, _ in
                    let posts = postSnap?.documents.compactMap { doc -> Post? in
                        let data = doc.data()
                        return Post(
                            id: doc.documentID,
                            title: data["title"] as? String ?? "",
                            dishName: data["dishName"] as? String ?? "",
                            content: data["content"] as? String ?? "",
                            imageURL: data["imageURL"] as? String,
                            author: data["author"] as? String ?? "",
                            authorId: data["authorId"] as? String ?? "",
                            gymName: data["gym"] as? String,
                            gym: data["gym"] as? String,
                            rating: data["rating"] as? Double ?? 0.0,
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                            gymLat: data["gymLat"] as? Double,
                            gymLon: data["gymLon"] as? Double,
                            mealCalories: data["mealCalories"] as? Int,
                            mealProtein: data["mealProtein"] as? Int,
                            mealCarbs: data["mealCarbs"] as? Int,
                            mealFat: data["mealFat"] as? Int,
                            exerciseName: data["exerciseName"] as? String,
                            previousValue: data["previousValue"] as? Double,
                            newValue: data["newValue"] as? Double,
                            progressionUnit: data["progressionUnit"] as? String,
                            category: data["category"] as? String
                        )
                    } ?? []

                    completion(posts)
                }
        }
    }

    // MARK: - For You Feed (simple version)
    func fetchForYouPosts(for uid: String, completion: @escaping ([Post]) -> Void) {
        
        // Get user's recent likes to determine interest
        let likedRef = self.db.collection("posts").whereField("likes", arrayContains: uid)
        
        likedRef.getDocuments { likedSnap, _ in
            var interestedGyms: [String] = []
            
            // Collect gym preferences
            likedSnap?.documents.forEach { doc in
                if let rest = doc.data()["gym"] as? String, !rest.isEmpty {
                    interestedGyms.append(rest)
                }
            }
            
            let query = self.db.collection("posts")
            
            query.getDocuments { snap, _ in
                let allPosts = snap?.documents.compactMap { doc -> Post? in
                    let data = doc.data()
                    return Post(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        dishName: data["dishName"] as? String ?? "",
                        content: data["content"] as? String ?? "",
                        imageURL: data["imageURL"] as? String,
                        author: data["author"] as? String ?? "",
                        authorId: data["authorId"] as? String ?? "",
                        gymName: data["gym"] as? String,
                        gym: data["gym"] as? String,
                        rating: data["rating"] as? Double ?? 0.0,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        gymLat: data["gymLat"] as? Double,
                        gymLon: data["gymLon"] as? Double,
                        mealCalories: data["mealCalories"] as? Int,
                        mealProtein: data["mealProtein"] as? Int,
                        mealCarbs: data["mealCarbs"] as? Int,
                        mealFat: data["mealFat"] as? Int,
                        exerciseName: data["exerciseName"] as? String,
                        previousValue: data["previousValue"] as? Double,
                        newValue: data["newValue"] as? Double,
                        progressionUnit: data["progressionUnit"] as? String,
                        category: data["category"] as? String
                    )
                } ?? []
                
                // Rank posts by preference match
                let sorted = allPosts.sorted { a, b in
                    let matchA = interestedGyms.contains(a.gym ?? "")
                    let matchB = interestedGyms.contains(b.gym ?? "")
                    return (matchA ? 1 : 0) > (matchB ? 1 : 0)
                }
                
                completion(sorted)
            }
        }
    }
    
    
    
    
    // MARK: - Delete Post
    func deletePost(_ post: Post, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            return completion(.failure(NSError(domain: "", code: 401,
                                               userInfo: [NSLocalizedDescriptionKey: "Not logged in."])))
        }
        
        // Convert current user email to username
        let currentUsername = user.email?.split(separator: "@").first.map(String.init) ?? ""
        
        let postAuthorUsername = post.author
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        let currentName = currentUsername
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        let ownsByUID = !post.authorId.isEmpty && post.authorId == user.uid
        let ownsByUsername = postAuthorUsername == currentName
        
        // Allow either UID match or username match
        guard ownsByUID || ownsByUsername else {
            return completion(.failure(NSError(domain: "", code: 403,
                                               userInfo: [NSLocalizedDescriptionKey: "You do not own this post."])))
        }
        
        // Delete image in Storage if exists
        if let imageURL = post.imageURL, !imageURL.isEmpty {
            let storageRef = Storage.storage().reference(forURL: imageURL)
            storageRef.delete { error in
                if let error = error {
                    print("⚠️ image delete warning:", error.localizedDescription)
                }
            }
        }
        
        // Delete Firestore document
        db.collection("posts").document(post.id).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Likes
    func toggleLike(for post: Post, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            return completion(NSError(domain: "", code: 401,
                                      userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
        }
        
        let likeRef = db.collection("posts").document(post.id).collection("likes").document(uid)
        
        likeRef.getDocument { snapshot, _ in
            if snapshot?.exists == true {
                // Unlike
                likeRef.delete { err in
                    if err == nil {
                        //  -1 on unlike
                        ScoreService.shared.bumpOnLikeDelta(actorUid: uid, delta: -1)
                    }
                    completion(err)
                }
            } else {
                // Like
                likeRef.setData(["timestamp": Timestamp(date: Date())]) { err in
                    if err == nil {
                        //  +1 on like
                        ScoreService.shared.bumpOnLikeDelta(actorUid: uid, delta: +1)
                        // === Notifications: Like ===
                        if post.authorId != uid {
                            let notifRef = self.db.collection("users")
                                .document(post.authorId)
                                .collection("notifications")

                            self.db.collection("users").document(uid).getDocument { snap, _ in
                                let fromUsername = (snap?.data()?["username"] as? String) ?? "Someone"

                                let notifData: [String: Any] = [
                                    "type": "like",
                                    "fromUserId": uid,
                                    "fromUsername": fromUsername,
                                    "postId": post.id,
                                    "timestamp": Timestamp(date: Date()),
                                    "read": false
                                ]

                                notifRef.addDocument(data: notifData)
                            }
                        }
                    }
                    completion(err)
                }
            }
        }
    }
    
    
    func listenForLikes(of post: Post, completion: @escaping (Int) -> Void) {
        db.collection("posts").document(post.id).collection("likes")
            .addSnapshotListener { snap, _ in
                completion(snap?.documents.count ?? 0)
            }
    }
    
    // MARK: - Comments
    func addComment(to post: Post, text: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            return completion(NSError(domain: "", code: 401,
                                      userInfo: [NSLocalizedDescriptionKey: "Not logged in"]))
        }
        
        let comment: [String: Any] = [
            "authorId": user.uid,
            "authorName": user.email?.split(separator: "@").first.map(String.init) ?? "Unknown",
            "text": text,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("posts").document(post.id).collection("comments")
            .addDocument(data: comment) { err in
                if err == nil {
                    // +3 on comment
                    ScoreService.shared.bumpOnCommentAdded(actorUid: user.uid)
                    // === Notifications: Comment ===
                    if post.authorId != user.uid {
                        let notifRef = self.db.collection("users")
                            .document(post.authorId)
                            .collection("notifications")

                        self.db.collection("users").document(user.uid).getDocument { snap, _ in
                            let fromUsername = (snap?.data()?["username"] as? String) ?? "Someone"

                            let notifData: [String: Any] = [
                                "type": "comment",
                                "fromUserId": user.uid,
                                "fromUsername": fromUsername,
                                "postId": post.id,
                                "commentText": text,
                                "timestamp": Timestamp(date: Date()),
                                "read": false
                            ]

                            notifRef.addDocument(data: notifData)
                        }
                    }
                }
                completion(err)
            }
    }
    
    
    func listenForComments(of post: Post, completion: @escaping ([Comment]) -> Void) {
        db.collection("posts").document(post.id).collection("comments")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snap, _ in
                let comments = snap?.documents.compactMap { doc -> Comment? in
                    let data = doc.data()
                    return Comment(
                        id: doc.documentID,
                        authorId: data["authorId"] as? String ?? "",
                        authorName: data["authorName"] as? String ?? "Unknown",
                        text: data["text"] as? String ?? "",
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
                completion(comments)
            }
    }
    
    func fetchPosts(forGym name: String, completion: @escaping ([Post]) -> Void) {
        db.collection("posts")
            .whereField("gym", isEqualTo: name)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Gym fetch error:", error.localizedDescription)
                    completion([])
                    return
                }
                
                let posts = snapshot?.documents.compactMap { doc -> Post? in
                    let data = doc.data()
                    return Post(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        dishName: data["dishName"] as? String ?? "",
                        content: data["content"] as? String ?? "",
                        imageURL: data["imageURL"] as? String,
                        author: data["author"] as? String ?? "",
                        authorId: data["authorId"] as? String ?? "",
                        gymName: data["gym"] as? String,
                        gym: data["gym"] as? String,
                        rating: data["rating"] as? Double ?? 0.0,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        gymLat: data["gymLat"] as? Double,
                        gymLon: data["gymLon"] as? Double,
                        mealCalories: data["mealCalories"] as? Int,
                        mealProtein: data["mealProtein"] as? Int,
                        mealCarbs: data["mealCarbs"] as? Int,
                        mealFat: data["mealFat"] as? Int,
                        exerciseName: data["exerciseName"] as? String,
                        previousValue: data["previousValue"] as? Double,
                        newValue: data["newValue"] as? Double,
                        progressionUnit: data["progressionUnit"] as? String,
                        category: data["category"] as? String
                    )
                } ?? []

                completion(posts)
            }
    }

    // MARK: - Workout Streak
    func updateWorkoutStreak(for uid: String) {
        let ref = db.collection("users").document(uid)
        ref.getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            let lastDate = (data["lastWorkoutDate"] as? Timestamp)?.dateValue()
            let current  = data["workoutStreak"] as? Int ?? 0
            let today    = Calendar.current.startOfDay(for: Date())
            let newStreak: Int
            if let last = lastDate {
                let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: today).day ?? 0
                newStreak = diff == 0 ? current : (diff == 1 ? current + 1 : 1)
            } else {
                newStreak = 1
            }
            ref.updateData(["workoutStreak": newStreak, "lastWorkoutDate": Timestamp(date: Date())])
        }
    }

    // MARK: - Saved Posts (Bookmark System)

    /// Check if a post is saved by the current user
    func isPostSaved(postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let ref = db.collection("users")
            .document(uid)
            .collection("savedPosts")
            .document(postId)

        ref.getDocument { snap, _ in
            completion(snap?.exists == true)
        }
    }

    /// Toggle saved/unsaved state
    func toggleSaved(postId: String, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        let ref = db.collection("users")
            .document(uid)
            .collection("savedPosts")
            .document(postId)

        ref.getDocument { snap, _ in
            if snap?.exists == true {
                // Unsave
                ref.delete { _ in
                    completion(false)
                }
            } else {
                // Save
                ref.setData([
                    "timestamp": Timestamp(date: Date())
                ]) { _ in
                    completion(true)
                }
            }
        }
    }
}
