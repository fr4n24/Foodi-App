//
//  UserProgressView.swift
//  GymLink
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage

// MARK: - Models

enum ProgressEntryType: String, Codable {
    case physique = "physique"
    case workout  = "workout"
}

struct ProgressEntry: Identifiable {
    let id: String
    let type: ProgressEntryType
    let timestamp: Date
    let imageURL: String?
    let caption: String?
    let exercise: String?
    let previousValue: Double?
    let newValue: Double?
    let unit: String?

    var delta: Double? {
        guard let n = newValue, let p = previousValue else { return nil }
        return n - p
    }

    var formattedDelta: String? {
        guard let d = delta else { return nil }
        let sign = d >= 0 ? "+" : ""
        let val  = d.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(d))" : String(format: "%.1f", d)
        return "\(sign)\(val) \(unit ?? "")"
    }
}

// MARK: - Progress section (embedded in profile views)

struct ProgressSectionView: View {
    let uid: String
    let isOwner: Bool

    @State private var entries: [ProgressEntry] = []
    @State private var isLoading  = false
    @State private var showAddSheet = false

    // Add sheet state
    @State private var addMode    : ProgressEntryType = .workout
    @State private var addExercise = ""
    @State private var addPrev     = ""
    @State private var addNew      = ""
    @State private var addUnit     = "lbs"
    @State private var addCaption  = ""
    @State private var addImageItem: PhotosPickerItem? = nil
    @State private var addImageData: Data? = nil
    @State private var isSaving    = false

    private let db    = Firestore.firestore()
    private let units = ["lbs", "kg", "reps", "km", "min", "sec"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gymLinkPink)
                    Text("Progress")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                if isOwner {
                    Button { showAddSheet = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.gymLinkPink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gymLinkPink.opacity(0.14))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 20)

            if isLoading {
                ProgressView().tint(.gymLinkPink).frame(maxWidth: .infinity).padding(.top, 8)
            } else if entries.isEmpty {
                Text("No progress tracked yet\(isOwner ? " — tap Add to start" : "")")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(entries) { entry in
                            progressCard(entry)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear { loadEntries() }
        .sheet(isPresented: $showAddSheet) {
            addSheet
                .presentationDetents([.fraction(0.75)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func progressCard(_ entry: ProgressEntry) -> some View {
        if entry.type == .physique {
            physiqueCard(entry)
        } else {
            workoutCard(entry)
        }
    }

    private func workoutCard(_ entry: ProgressEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gymLinkPink)
                Text("Workout")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gymLinkPink)
            }

            if let exercise = entry.exercise {
                Text(exercise)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            if let prev = entry.previousValue, let newVal = entry.newValue {
                HStack(spacing: 4) {
                    Text(fmtVal(prev))
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.5))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.35))
                    Text(fmtVal(newVal))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text(entry.unit ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.38))
                }
            }

            if let delta = entry.formattedDelta {
                let isPositive = (entry.delta ?? 0) >= 0
                Text(delta)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(isPositive
                        ? Color(red: 0.2, green: 0.85, blue: 0.4)
                        : .gymLinkPink)
            }

            Spacer()

            Text(shortDate(entry.timestamp))
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.3))
        }
        .padding(14)
        .frame(width: 158, height: 155)
        .background(Color(white: 0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gymLinkPink.opacity(0.18), lineWidth: 1)
        )
    }

    private func physiqueCard(_ entry: ProgressEntry) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let urlStr = entry.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color(white: 0.12)
                    }
                } else {
                    Color(white: 0.12)
                        .overlay(
                            Image(systemName: "figure.stand")
                                .font(.system(size: 30))
                                .foregroundColor(Color(white: 0.25))
                        )
                }
            }
            .frame(width: 158, height: 195)
            .clipped()
            .cornerRadius(16)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .center, endPoint: .bottom
            )
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.7))
                    Text("Physique")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.7))
                }
                if let caption = entry.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Text(shortDate(entry.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.55))
            }
            .padding(10)
        }
        .frame(width: 158, height: 195)
    }

    // MARK: - Add sheet

    private var addSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Add Progress")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .padding(.top, 8)

                // Mode toggle
                HStack(spacing: 0) {
                    ForEach([ProgressEntryType.workout, .physique], id: \.self) { mode in
                        Button { addMode = mode } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .workout ? "dumbbell.fill" : "figure.stand")
                                    .font(.system(size: 13))
                                Text(mode == .workout ? "Workout" : "Physique")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(addMode == mode ? .white : Color(white: 0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(addMode == mode ? Color.gymLinkPink : Color.clear)
                            .cornerRadius(10)
                            .padding(3)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: addMode)
                    }
                }
                .background(Color(white: 0.12))
                .cornerRadius(13)

                if addMode == .workout {
                    workoutAddFields
                } else {
                    physiqueAddFields
                }

                Button { saveEntry() } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canSave ? Color.gymLinkPink : Color(white: 0.2))
                            .frame(height: 52)
                            .shadow(color: canSave ? Color.gymLinkPink.opacity(0.4) : .clear, radius: 8, y: 3)
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Progress")
                                .font(.headline).foregroundColor(canSave ? .white : Color(white: 0.38))
                        }
                    }
                }
                .disabled(!canSave || isSaving)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private var workoutAddFields: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.gymLinkPink)
                    .frame(width: 20)
                TextField("Exercise (e.g. Bench Press)", text: $addExercise)
                    .foregroundColor(.white)
            }
            .padding(14)
            .background(Color(white: 0.12))
            .cornerRadius(12)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Previous")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                    TextField("185", text: $addPrev)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(white: 0.12))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                }
                Image(systemName: "arrow.right")
                    .foregroundColor(Color(white: 0.35))
                    .padding(.top, 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text("New PR")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                    TextField("195", text: $addNew)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(white: 0.12))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .semibold))
                }
            }

            HStack {
                Text("Unit").foregroundColor(Color(white: 0.55))
                Spacer()
                Picker("Unit", selection: $addUnit) {
                    ForEach(units, id: \.self) { Text($0) }
                }
                .tint(.gymLinkPink)
            }
            .padding(12)
            .background(Color(white: 0.12))
            .cornerRadius(12)

            // Live delta preview
            if let p = Double(addPrev), let n = Double(addNew) {
                let d = n - p
                let sign = d >= 0 ? "+" : ""
                let fmt = d.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(d))" : String(format: "%.1f", d)
                HStack(spacing: 6) {
                    Image(systemName: d >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(d >= 0 ? Color(red: 0.2, green: 0.85, blue: 0.4) : .gymLinkPink)
                    Text("\(sign)\(fmt) \(addUnit)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(d >= 0 ? Color(red: 0.2, green: 0.85, blue: 0.4) : .gymLinkPink)
                    Text("change")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.38))
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color(white: 0.1))
                .cornerRadius(10)
            }
        }
    }

    private var physiqueAddFields: some View {
        VStack(spacing: 10) {
            if let data = addImageData, let img = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 160)
                        .clipped().cornerRadius(14)
                    Button {
                        addImageData = nil
                        addImageItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(8)
                }
            } else {
                PhotosPicker(selection: $addImageItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.gymLinkPink)
                        Text("Add a progress photo")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundColor(.gymLinkPink)
                        Text("Before / after, physique check-in, etc.")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.35))
                    }
                    .frame(maxWidth: .infinity).frame(height: 130)
                    .background(Color(white: 0.1))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gymLinkPink.opacity(0.35),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                }
                .onChange(of: addImageItem) {
                    Task {
                        if let item = addImageItem,
                           let data = try? await item.loadTransferable(type: Data.self) {
                            addImageData = data
                        }
                    }
                }
            }

            TextField("Caption (optional)", text: $addCaption)
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(12)
                .foregroundColor(.white)
        }
    }

    private var canSave: Bool {
        if addMode == .workout {
            return !addExercise.trimmingCharacters(in: .whitespaces).isEmpty
                && Double(addNew) != nil
        } else {
            return addImageData != nil
                || !addCaption.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Firestore

    private func loadEntries() {
        isLoading = true
        db.collection("users").document(uid).collection("progress")
            .order(by: "timestamp", descending: true)
            .getDocuments { snap, _ in
                DispatchQueue.main.async {
                    entries = snap?.documents.compactMap { doc -> ProgressEntry? in
                        let d = doc.data()
                        guard let typeStr = d["type"] as? String,
                              let type = ProgressEntryType(rawValue: typeStr) else { return nil }
                        return ProgressEntry(
                            id:            doc.documentID,
                            type:          type,
                            timestamp:     (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                            imageURL:      d["imageURL"]      as? String,
                            caption:       d["caption"]       as? String,
                            exercise:      d["exercise"]      as? String,
                            previousValue: d["previousValue"] as? Double,
                            newValue:      d["newValue"]      as? Double,
                            unit:          d["unit"]          as? String
                        )
                    } ?? []
                    isLoading = false
                }
            }
    }

    private func saveEntry() {
        guard !isSaving else { return }
        isSaving = true

        if addMode == .workout {
            var data: [String: Any] = [
                "type":      ProgressEntryType.workout.rawValue,
                "timestamp": Timestamp(date: Date()),
                "exercise":  addExercise.trimmingCharacters(in: .whitespaces),
                "unit":      addUnit
            ]
            if let p = Double(addPrev) { data["previousValue"] = p }
            if let n = Double(addNew)  { data["newValue"]      = n }

            db.collection("users").document(uid).collection("progress")
                .addDocument(data: data) { _ in
                    DispatchQueue.main.async {
                        isSaving = false
                        showAddSheet = false
                        resetForm()
                        loadEntries()
                    }
                }
        } else {
            if let imageData = addImageData,
               let compressed = UIImage(data: imageData)?.jpegData(compressionQuality: 0.8) {
                let ref = Storage.storage().reference()
                    .child("progressPhotos/\(uid)/\(UUID().uuidString).jpg")
                ref.putData(compressed) { _, err in
                    guard err == nil else {
                        DispatchQueue.main.async { isSaving = false }
                        return
                    }
                    ref.downloadURL { url, _ in
                        let data: [String: Any] = [
                            "type":      ProgressEntryType.physique.rawValue,
                            "timestamp": Timestamp(date: Date()),
                            "imageURL":  url?.absoluteString ?? "",
                            "caption":   self.addCaption.trimmingCharacters(in: .whitespaces)
                        ]
                        self.persist(data: data)
                    }
                }
            } else {
                let data: [String: Any] = [
                    "type":      ProgressEntryType.physique.rawValue,
                    "timestamp": Timestamp(date: Date()),
                    "caption":   addCaption.trimmingCharacters(in: .whitespaces)
                ]
                persist(data: data)
            }
        }
    }

    private func persist(data: [String: Any]) {
        db.collection("users").document(uid).collection("progress")
            .addDocument(data: data) { _ in
                DispatchQueue.main.async {
                    isSaving = false
                    showAddSheet = false
                    resetForm()
                    loadEntries()
                }
            }
    }

    private func resetForm() {
        addExercise = ""; addPrev = ""; addNew = ""; addUnit = "lbs"
        addCaption  = ""; addImageData = nil; addImageItem = nil
        addMode     = .workout
    }

    // MARK: - Helpers

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func fmtVal(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}
