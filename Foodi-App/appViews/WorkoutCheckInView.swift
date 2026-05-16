import SwiftUI
import Combine
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Check-in banner shown on HomeView

struct WorkoutCheckInBanner: View {
    @StateObject private var vm = CheckInViewModel()
    @State private var showCheckIn = false

    var body: some View {
        Group {
            if vm.shouldShowBanner {
                banner
                    .sheet(isPresented: $showCheckIn) {
                        WorkoutCheckInSheet(vm: vm)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.shouldShowBanner)
        .onAppear { vm.evaluate() }
    }

    private var banner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 46, height: 46)
                Text("💪")
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Time to train!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("Have you worked out yet today?")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.55))
            }
            Spacer()
            Button {
                withAnimation { vm.shouldShowBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(white: 0.4))
                    .padding(6)
                    .background(Color(white: 0.15))
                    .clipShape(Circle())
            }
            Button {
                showCheckIn = true
            } label: {
                Text("Log it")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.gymLinkPink)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.09))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gymLinkPink.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Quick check-in sheet

struct WorkoutCheckInSheet: View {
    @ObservedObject var vm: CheckInViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var caption    = ""
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var isPosting  = false
    @State private var didPost    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if didPost {
                    successView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerRow
                            photoSection
                            captionSection
                            postButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        vm.dismissForToday()
                        dismiss()
                    }
                    .foregroundColor(Color(white: 0.45))
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gymLinkPink.opacity(0.18))
                    .frame(width: 58, height: 58)
                Text("💪")
                    .font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Workout Check-In")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text("Share your session with the community")
                    .font(.subheadline).foregroundColor(Color(white: 0.48))
            }
            Spacer()
        }
    }

    // MARK: - Photo section

    private var photoSection: some View {
        Group {
            if let img = image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(18)
                    Button {
                        image = nil
                        pickerItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(10)
                }
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.gymLinkPink)
                        Text("Add a workout photo")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.gymLinkPink)
                        Text("Optional")
                            .font(.caption).foregroundColor(Color(white: 0.38))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color(white: 0.09))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.gymLinkPink.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    )
                }
                .onChange(of: pickerItem) {
                    Task {
                        if let item = pickerItem,
                           let data = try? await item.loadTransferable(type: Data.self) {
                            image = UIImage(data: data)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Caption

    private var captionSection: some View {
        TextField("How was the session? (optional)", text: $caption, axis: .vertical)
            .lineLimit(4, reservesSpace: true)
            .foregroundColor(.white)
            .padding(14)
            .background(Color(white: 0.11))
            .cornerRadius(14)
    }

    // MARK: - Post button

    private var postButton: some View {
        Button(action: post) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gymLinkPink)
                    .frame(height: 54)
                    .shadow(color: Color.gymLinkPink.opacity(0.4), radius: 12, y: 4)
                if isPosting {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Log Workout")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .disabled(isPosting)
    }

    // MARK: - Success screen

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🔥").font(.system(size: 72))
            Text("Workout logged!")
                .font(.system(size: 28, weight: .black)).foregroundColor(.white)
            Text("Keep the streak alive 💪")
                .font(.subheadline).foregroundColor(Color(white: 0.5))
            Button {
                vm.dismissForToday()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.gymLinkPink)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 10)
            Spacer()
        }
    }

    // MARK: - Post logic

    private func post() {
        isPosting = true
        if let img = image, let data = img.jpegData(compressionQuality: 0.8) {
            let ref = Storage.storage().reference().child("postImages/\(UUID().uuidString).jpg")
            let meta = StorageMetadata(); meta.contentType = "image/jpeg"
            let task = ref.putData(data, metadata: meta)
            task.observe(.success) { _ in
                ref.downloadURL { url, _ in
                    savePost(imageURL: url?.absoluteString)
                }
            }
            task.observe(.failure) { _ in
                DispatchQueue.main.async { isPosting = false }
            }
        } else {
            savePost(imageURL: nil)
        }
    }

    private func savePost(imageURL: String?) {
        PostManager.shared.addPost(
            title: "Workout Check-In ✅",
            content: caption.isEmpty ? "Showed up and put in the work! 💪" : caption,
            imageURL: imageURL,
            category: "workout"
        ) { result in
            DispatchQueue.main.async {
                isPosting = false
                if case .success = result {
                    withAnimation { didPost = true }
                }
            }
        }
    }
}

// MARK: - ViewModel

final class CheckInViewModel: ObservableObject {
    @Published var shouldShowBanner = false

    private let db = Firestore.firestore()
    private let dismissedKey = "gymlink_checkin_dismissed_date"

    func evaluate() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Don't show if already dismissed today
        if let dismissed = UserDefaults.standard.object(forKey: dismissedKey) as? Date {
            if Calendar.current.isDateInToday(dismissed) { return }
        }

        // Check if user already posted a workout today
        let startOfDay = Calendar.current.startOfDay(for: Date())
        db.collection("posts")
            .whereField("authorId", isEqualTo: uid)
            .whereField("category", isEqualTo: "workout")
            .whereField("timestamp", isGreaterThan: Timestamp(date: startOfDay))
            .getDocuments { [weak self] snap, _ in
                guard let self = self else { return }
                let alreadyPosted = (snap?.documents.count ?? 0) > 0
                if alreadyPosted { return }

                // Check user's workout times
                self.db.collection("users").document(uid).getDocument { snap, _ in
                    guard let data = snap?.data() else { return }
                    let times = data["workoutTimes"] as? [String] ?? []
                    let show = times.isEmpty ? self.isInDefaultWorkoutWindow() : self.isInWorkoutWindow(times)
                    DispatchQueue.main.async {
                        withAnimation { self.shouldShowBanner = show }
                    }
                }
            }
    }

    func dismissForToday() {
        UserDefaults.standard.set(Date(), forKey: dismissedKey)
        withAnimation { shouldShowBanner = false }
    }

    // Default window: show banner 8 AM – 9 PM if no times set
    private func isInDefaultWorkoutWindow() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 8 && h < 21
    }

    // Match any user-set workout time window
    private func isInWorkoutWindow(_ times: [String]) -> Bool {
        let now = Calendar.current.component(.hour, from: Date())
        for t in times {
            if let window = parseTimeWindow(t), now >= window.start && now < window.end {
                return true
            }
            // Also show 1h before their window ends as a reminder
            if let window = parseTimeWindow(t), now >= (window.start - 1) && now < window.end {
                return true
            }
        }
        return false
    }

    private func parseTimeWindow(_ slot: String) -> (start: Int, end: Int)? {
        switch slot {
        case "Early Morning (5–7 AM)":  return (5,  7)
        case "Morning (7–9 AM)":        return (7,  9)
        case "Late Morning (9–11 AM)":  return (9,  11)
        case "Noon (11 AM–1 PM)":       return (11, 13)
        case "Afternoon (1–4 PM)":      return (13, 16)
        case "Late Afternoon (4–6 PM)": return (16, 18)
        case "Evening (6–8 PM)":        return (18, 20)
        case "Night (8–10 PM)":         return (20, 22)
        default: return nil
        }
    }
}
