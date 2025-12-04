//
//  RestaurantProfileView.swift
//  Foodi
//
//  Created by Francisco Campa on 11/23/25.
//


import SwiftUI
import MapKit

struct RestaurantProfileView: View {
    let restaurant: RestaurantDetail
    
    @State private var posts: [Post] = []
    @State private var averageRating: Double = 0.0
    @State private var hours: [String] = []
    @State private var showFullMap = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: - TAP TO OPEN MAP
                ZStack {
                    Map {
                        Marker(restaurant.name, coordinate: restaurant.coordinate)
                    }
                    .frame(height: 220)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Rectangle()
                        .foregroundColor(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { showFullMap = true }
                }
                .sheet(isPresented: $showFullMap) {
                    RestaurantMapSheet(
                        target: restaurant.coordinate,
                        restaurantName: restaurant.name
                    )
                }
                
                
                // MARK: - NAME + AVG RATING
                VStack(spacing: 6) {
                    Text(restaurant.name)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    Text("\(String(format: "%.1f", averageRating)) / 5")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                
                // MARK: - INFORMATION SECTION
                VStack(alignment: .leading, spacing: 8) {
                    Text("Information")
                        .font(.headline)
                    
                    Button {
                        openInAppleMaps(detail: restaurant)
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(restaurant.address)
                                .underline()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    
                    if let phone = restaurant.phone {
                        Text("📞 Phone: \(phone)")
                    }
                    
                    if let website = restaurant.url {
                        Link("🌐 Website", destination: website)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                
                // MARK: - HOURS (optional)
                if !hours.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hours")
                            .font(.headline)
                        
                        ForEach(hours, id: \.self) {
                            Text($0).font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                
                // MARK: - POSTS SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("Posts")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)
                    
                    if posts.isEmpty {
                        Text("No posts yet for this restaurant.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    } else {
                        ForEach(posts) { post in
                            NavigationLink {
                                PostDetailView(post: post)
                            } label: {
                                PostRowView(post: post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onAppear {
            PostManager.shared.fetchPosts(forRestaurant: restaurant.name) { fetched in
                posts = fetched
                
                if !fetched.isEmpty {
                    averageRating = fetched
                        .compactMap { $0.rating }
                        .reduce(0, +) / Double(fetched.count)
                }
            }
        }
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // HELPER FOR THE MAP
    func openInAppleMaps(detail: RestaurantDetail) {
        let location = CLLocation(latitude: detail.coordinate.latitude,
                                  longitude: detail.coordinate.longitude)
        
        let item = MKMapItem(location: location, address: nil)
        item.name = detail.name
        
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
