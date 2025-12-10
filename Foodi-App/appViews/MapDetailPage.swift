//
//  MapDetailPage.swift
//  Foodi
//
//  Created by Francisco Campa on 12/4/25.
//

import SwiftUI
import MapKit

struct MapDetailScreen: View {
    @State private var selectedRestaurant: RestaurantDetail? = nil
    @State private var showRestaurantProfile = false
    
    var body: some View {
        MapWidgetView { detail in
            selectedRestaurant = detail
            showRestaurantProfile = true
        }
        .ignoresSafeArea()
        .padding(.top, 40)
        .sheet(isPresented: $showRestaurantProfile) {
            if let detail = selectedRestaurant {
                RestaurantProfileView(restaurant: detail)
            }
        }
    }
}
