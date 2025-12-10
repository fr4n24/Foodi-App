//
//  RestaurantProfileLoaderView.swift
//  Foodi
//
//  Created by Tyler Hedberg on 12/9/25.
//

import SwiftUI
import CoreLocation

struct RestaurantProfileLoaderView: View {
    let restaurantName: String

    @State private var detail: RestaurantDetail? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let detail = detail {
                RestaurantProfileView(restaurant: detail)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading \(restaurantName)...")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Text("Unable to load restaurant.")
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        loadRestaurant()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(restaurantName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if detail == nil && !isLoading {
                loadRestaurant()
            }
        }
    }

    private func loadRestaurant() {
        isLoading = true

        PostManager.shared.fetchPosts(forRestaurant: restaurantName) { posts in
            DispatchQueue.main.async {
                self.isLoading = false

                if let p = posts.first,
                   let lat = p.restaurantLat,
                   let lon = p.restaurantLon {

                    self.detail = RestaurantDetail(
                        name: restaurantName,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        address: "Unknown address"
                    )
                } else {
                    self.detail = RestaurantDetail(
                        name: restaurantName,
                        coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        address: "Unknown address"
                    )
                }
            }
        }
    }
}
