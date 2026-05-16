//
//  RootContainer.swift
//  GymLink
//

import SwiftUI

enum Route: Hashable { case settings, profile }

struct RootContainer: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var path: [Route] = []

    var body: some View {
        Group {
            if authVM.isCheckingAuth {
                // Holds black screen briefly while Firebase resolves auth state
                Color.black.ignoresSafeArea()
            } else if authVM.isSignedIn {
                NavigationStack(path: $path) {
                    HomeView()
                        .toolbar(.hidden, for: .navigationBar)
                        .safeAreaInset(edge: .top) {
                            GymLinkHeader(
                                bannerColor: .black,
                                titleSize: 22,
                                titleWeight: .bold,
                                onProfile:  { path.append(.profile) },
                                onSettings: { path.append(.settings) }
                            )
                        }
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .settings: SettingsView()
                            case .profile:  ProfileView()
                            }
                        }
                }
            } else {
                LoginView()
            }
        }
    }
}
