//
//  TrackMealsView.swift
//  GymLink
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Models

struct MealEntry: Identifiable {
    let id: String
    let name: String
    let type: String
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
    let timestamp: Date
}

struct DailyGoals {
    var calories: Int = 2000
    var protein: Int  = 150
    var carbs: Int    = 200
    var fat: Int      = 65
    var water: Int    = 8
}

// MARK: - ViewModel

final class MacroTrackerViewModel: ObservableObject {
    @Published var meals: [MealEntry] = []
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var goals = DailyGoals()
    @Published var waterGlasses: Int = 0

    private let db = Firestore.firestore()
    private var mealListener: ListenerRegistration?
    private var waterListener: ListenerRegistration?

    var totalCalories: Int { meals.compactMap(\.calories).reduce(0, +) }
    var totalProtein:  Int { meals.compactMap(\.protein).reduce(0, +) }
    var totalCarbs:    Int { meals.compactMap(\.carbs).reduce(0, +) }
    var totalFat:      Int { meals.compactMap(\.fat).reduce(0, +) }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        loadMeals()
        loadWater()
    }

    func loadMeals() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        mealListener?.remove()
        let start = selectedDate
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        mealListener = db.collection("users").document(uid).collection("meals")
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("timestamp", isLessThan: Timestamp(date: end))
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snap, _ in
                self?.meals = snap?.documents.compactMap { doc -> MealEntry? in
                    let d = doc.data()
                    guard let name = d["name"] as? String, !name.isEmpty else { return nil }
                    return MealEntry(
                        id: doc.documentID,
                        name: name,
                        type: d["type"] as? String ?? "Snack",
                        calories: d["calories"] as? Int,
                        protein:  d["protein"]  as? Int,
                        carbs:    d["carbs"]    as? Int,
                        fat:      d["fat"]      as? Int,
                        timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                } ?? []
            }
    }

    func loadGoals() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let d = snap?.data() else { return }
            DispatchQueue.main.async {
                self?.goals = DailyGoals(
                    calories: d["goalCalories"] as? Int ?? 2000,
                    protein:  d["goalProtein"]  as? Int ?? 150,
                    carbs:    d["goalCarbs"]    as? Int ?? 200,
                    fat:      d["goalFat"]      as? Int ?? 65,
                    water:    d["goalWater"]    as? Int ?? 8
                )
            }
        }
    }

    func saveGoals(_ g: DailyGoals) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).setData([
            "goalCalories": g.calories,
            "goalProtein":  g.protein,
            "goalCarbs":    g.carbs,
            "goalFat":      g.fat,
            "goalWater":    g.water
        ], merge: true)
        goals = g
    }

    func loadWater() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        waterListener?.remove()
        waterListener = db.collection("users").document(uid).collection("water")
            .document(dateKey(selectedDate))
            .addSnapshotListener { [weak self] snap, _ in
                self?.waterGlasses = snap?.data()?["glasses"] as? Int ?? 0
            }
    }

    func adjustWater(by delta: Int) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let new = max(0, waterGlasses + delta)
        db.collection("users").document(uid).collection("water")
            .document(dateKey(selectedDate))
            .setData(["glasses": new])
        waterGlasses = new
    }

    func saveMeal(name: String, type: String,
                  calories: String, protein: String, carbs: String, fat: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let isToday = Calendar.current.isDateInToday(selectedDate)
        var data: [String: Any] = [
            "name":      trimmed,
            "type":      type,
            "timestamp": Timestamp(date: isToday ? Date() : selectedDate)
        ]
        if let c  = Int(calories), c  > 0 { data["calories"] = c  }
        if let p  = Int(protein),  p  > 0 { data["protein"]  = p  }
        if let cb = Int(carbs),    cb > 0 { data["carbs"]    = cb }
        if let f  = Int(fat),      f  > 0 { data["fat"]      = f  }

        db.collection("users").document(uid).collection("meals").addDocument(data: data)
    }

    func deleteMeal(_ meal: MealEntry) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("meals").document(meal.id).delete()
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
}

// MARK: - Main view

struct TrackMealsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MacroTrackerViewModel()

    @State private var showAddSheet = false
    @State private var showGoals    = false

    @State private var newName     = ""
    @State private var newType     = "Breakfast"
    @State private var newCalories = ""
    @State private var newProtein  = ""
    @State private var newCarbs    = ""
    @State private var newFat      = ""

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack", "Pre-workout", "Post-workout"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    dateStrip
                    ScrollView {
                        VStack(spacing: 12) {
                            macroCard
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            waterCard
                                .padding(.horizontal, 16)
                            if vm.meals.isEmpty {
                                emptyState
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(vm.meals) { meal in
                                        mealRow(meal)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    vm.deleteMeal(meal)
                                                } label: {
                                                    Label("Delete Meal", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 110)
                    }
                }

                Button { showAddSheet = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gymLinkPink)
                            .frame(width: 58, height: 58)
                            .shadow(color: .gymLinkPink.opacity(0.4), radius: 10, x: 0, y: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 36)
            }
            .navigationTitle("Track Macros")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGoals = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.gymLinkPink)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addMealSheet
                    .presentationDetents([.fraction(0.78)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showGoals) {
                GoalsSheet(goals: vm.goals) { vm.saveGoals($0) }
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            vm.loadGoals()
            vm.loadMeals()
            vm.loadWater()
        }
    }

    // MARK: - Date strip

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(last30Days(), id: \.self) { date in
                        DateChip(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: vm.selectedDate)
                        )
                        .id(date)
                        .onTapGesture { vm.selectDate(date) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(Calendar.current.startOfDay(for: Date()), anchor: .trailing)
                }
            }
        }
    }

    private func last30Days() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (-29...0).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    // MARK: - Macro summary card

    private var macroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel(vm.selectedDate))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.4))
                        .textCase(.uppercase)
                    Text(vm.totalCalories > 0 ? "\(vm.totalCalories)" : "—")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.gymLinkPink)
                    Text("/ \(vm.goals.calories) kcal")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.35))
                }
                Spacer()
                CalorieRing(current: vm.totalCalories, goal: vm.goals.calories)
            }

            Rectangle()
                .fill(Color(white: 0.14))
                .frame(height: 1)

            HStack(spacing: 0) {
                MacroProgressBar(
                    label: "Protein",
                    value: vm.totalProtein,
                    goal: vm.goals.protein,
                    color: Color(red: 0.35, green: 0.72, blue: 1.0)
                )
                Rectangle().fill(Color(white: 0.14)).frame(width: 1, height: 48)
                MacroProgressBar(
                    label: "Carbs",
                    value: vm.totalCarbs,
                    goal: vm.goals.carbs,
                    color: Color(red: 1.0, green: 0.76, blue: 0.2)
                )
                Rectangle().fill(Color(white: 0.14)).frame(width: 1, height: 48)
                MacroProgressBar(
                    label: "Fat",
                    value: vm.totalFat,
                    goal: vm.goals.fat,
                    color: Color(red: 1.0, green: 0.46, blue: 0.3)
                )
            }
        }
        .padding(18)
        .background(Color(white: 0.09))
        .cornerRadius(20)
    }

    // MARK: - Water card

    private var waterCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.2, green: 0.55, blue: 1.0).opacity(0.18))
                    .frame(width: 46, height: 46)
                Image(systemName: "drop.fill")
                    .foregroundColor(Color(red: 0.35, green: 0.72, blue: 1.0))
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.headline).foregroundColor(.white)
                Text("\(vm.waterGlasses) / \(vm.goals.water) glasses")
                    .font(.caption).foregroundColor(Color(white: 0.4))
            }
            Spacer()
            HStack(spacing: 14) {
                Button { vm.adjustWater(by: -1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(white: 0.22))
                }
                Text("\(vm.waterGlasses)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 22)
                Button { vm.adjustWater(by: 1) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.35, green: 0.72, blue: 1.0))
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "fork.knife")
                .font(.system(size: 50))
                .foregroundColor(Color(white: 0.22))
            Text("No meals logged")
                .font(.headline).foregroundColor(Color(white: 0.38))
            Text("Tap + to add your first meal")
                .font(.subheadline).foregroundColor(Color(white: 0.28))
        }
    }

    // MARK: - Meal row

    private func mealRow(_ meal: MealEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gymLinkPink.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: icon(for: meal.type))
                    .foregroundColor(.gymLinkPink)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.headline).foregroundColor(.white)
                HStack(spacing: 6) {
                    Text(meal.type)
                        .font(.caption).foregroundColor(Color(white: 0.4))
                    if let p = meal.protein {
                        macroTag("P \(p)g", color: Color(red: 0.35, green: 0.72, blue: 1.0))
                    }
                    if let c = meal.carbs {
                        macroTag("C \(c)g", color: Color(red: 1.0, green: 0.76, blue: 0.2))
                    }
                    if let f = meal.fat {
                        macroTag("F \(f)g", color: Color(red: 1.0, green: 0.46, blue: 0.3))
                    }
                }
            }
            Spacer()
            if let cal = meal.calories {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(cal)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gymLinkPink)
                    Text("kcal")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.35))
                }
            }
        }
        .padding(14)
        .background(Color(white: 0.09))
        .cornerRadius(16)
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14))
            .cornerRadius(6)
    }

    // MARK: - Add meal sheet

    private var addMealSheet: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Log a Meal")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .padding(.top, 8)

                TextField("Meal name", text: $newName)
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .foregroundColor(.white)

                HStack {
                    Text("Type").foregroundColor(Color(white: 0.55))
                    Spacer()
                    Picker("Type", selection: $newType) {
                        ForEach(mealTypes, id: \.self) { Text($0) }
                    }
                    .tint(.gymLinkPink)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)

                TextField("Calories", text: $newCalories)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .foregroundColor(.white)

                HStack(spacing: 10) {
                    macroInputField(
                        label: "Protein",
                        text: $newProtein,
                        color: Color(red: 0.35, green: 0.72, blue: 1.0)
                    )
                    macroInputField(
                        label: "Carbs",
                        text: $newCarbs,
                        color: Color(red: 1.0, green: 0.76, blue: 0.2)
                    )
                    macroInputField(
                        label: "Fat",
                        text: $newFat,
                        color: Color(red: 1.0, green: 0.46, blue: 0.3)
                    )
                }

                Button {
                    vm.saveMeal(
                        name: newName, type: newType,
                        calories: newCalories, protein: newProtein,
                        carbs: newCarbs, fat: newFat
                    )
                    resetForm()
                    showAddSheet = false
                } label: {
                    Text("Log Meal")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(
                            newName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray : Color.gymLinkPink
                        )
                        .cornerRadius(14)
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func macroInputField(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            TextField("0g", text: text)
                .keyboardType(.numberPad)
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func resetForm() {
        newName = ""; newType = "Breakfast"
        newCalories = ""; newProtein = ""; newCarbs = ""; newFat = ""
    }

    // MARK: - Helpers

    private func dateLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date)     { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func icon(for type: String) -> String {
        switch type {
        case "Breakfast":    return "sun.rise.fill"
        case "Lunch":        return "sun.max.fill"
        case "Dinner":       return "moon.fill"
        case "Pre-workout":  return "bolt.fill"
        case "Post-workout": return "arrow.counterclockwise"
        default:             return "fork.knife"
        }
    }
}

// MARK: - Date chip

private struct DateChip: View {
    let date: Date
    let isSelected: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayLetter)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(white: 0.38))
            Text(dayNumber)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(isSelected ? .white : Color(white: 0.58))
        }
        .frame(width: 40, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(isSelected ? Color.gymLinkPink : Color(white: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    isToday && !isSelected ? Color.gymLinkPink.opacity(0.55) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    private var dayLetter: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(1))
    }
    private var dayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Calorie ring

private struct CalorieRing: View {
    let current: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gymLinkPink.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.gymLinkPink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            Image(systemName: "flame.fill")
                .font(.system(size: 22))
                .foregroundColor(.gymLinkPink)
        }
        .frame(width: 68, height: 68)
    }
}

// MARK: - Macro progress bar

private struct MacroProgressBar: View {
    let label: String
    let value: Int
    let goal: Int
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)g")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.2))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 5)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 5)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(white: 0.38))
            Text("/ \(goal)g")
                .font(.system(size: 9))
                .foregroundColor(Color(white: 0.28))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Goals sheet

struct GoalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calories: String
    @State private var protein:  String
    @State private var carbs:    String
    @State private var fat:      String
    @State private var water:    String
    let onSave: (DailyGoals) -> Void

    init(goals: DailyGoals, onSave: @escaping (DailyGoals) -> Void) {
        self.onSave = onSave
        _calories = State(initialValue: "\(goals.calories)")
        _protein  = State(initialValue: "\(goals.protein)")
        _carbs    = State(initialValue: "\(goals.carbs)")
        _fat      = State(initialValue: "\(goals.fat)")
        _water    = State(initialValue: "\(goals.water)")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Goals")
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .padding(.top, 8)

                goalRow(label: "Calories", unit: "kcal",    text: $calories, color: .gymLinkPink)
                goalRow(label: "Protein",  unit: "g",       text: $protein,  color: Color(red: 0.35, green: 0.72, blue: 1.0))
                goalRow(label: "Carbs",    unit: "g",       text: $carbs,    color: Color(red: 1.0, green: 0.76, blue: 0.2))
                goalRow(label: "Fat",      unit: "g",       text: $fat,      color: Color(red: 1.0, green: 0.46, blue: 0.3))
                goalRow(label: "Water",    unit: "glasses", text: $water,    color: Color(red: 0.35, green: 0.72, blue: 1.0))

                Button {
                    onSave(DailyGoals(
                        calories: Int(calories) ?? 2000,
                        protein:  Int(protein)  ?? 150,
                        carbs:    Int(carbs)    ?? 200,
                        fat:      Int(fat)      ?? 65,
                        water:    Int(water)    ?? 8
                    ))
                    dismiss()
                } label: {
                    Text("Save Goals")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.gymLinkPink).cornerRadius(14)
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func goalRow(label: String, unit: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(color)
                .font(.headline)
                .frame(width: 64)
            Text(unit)
                .font(.caption).foregroundColor(Color(white: 0.38))
                .frame(width: 50, alignment: .leading)
        }
        .padding(14)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}
