//
//  GymProfileLoaderView.swift
//  GymLink
//
//  Created by Tyler Hedberg on 12/9/25.
//

import SwiftUI
import CoreLocation

struct GymProfileLoaderView: View {
    let gymName: String

    @State private var detail: GymDetail? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let detail = detail {
                GymProfileView(gym: detail)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading \(gymName)...")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Unable to load gym.")
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        loadGym()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(gymName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if detail == nil && !isLoading {
                loadGym()
            }
        }
    }

    private func loadGym() {
        isLoading = true

        PostManager.shared.fetchPosts(forGym: gymName) { posts in
            DispatchQueue.main.async {
                self.isLoading = false

                if let p = posts.first,
                   let lat = p.gymLat,
                   let lon = p.gymLon {

                    self.detail = GymDetail(
                        name: gymName,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        address: "Unknown address"
                    )
                } else {
                    self.detail = GymDetail(
                        name: gymName,
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        address: "Unknown address"
                    )
                }
            }
        }
    }
}
