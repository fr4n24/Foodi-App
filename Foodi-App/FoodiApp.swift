import SwiftUI
import Firebase

@main
struct GymLinkApp: App {
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootContainer()
        }
    }
}
