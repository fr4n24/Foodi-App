//
//  MapDetailPage.swift
//  GymLink
//
//  Created by Francisco Campa on 12/4/25.
//

import SwiftUI
import MapKit

struct MapDetailScreen: View {
    @State private var selectedGym: GymDetail? = nil
    @State private var showGymProfile = false
    
    var body: some View {
        MapWidgetView { detail in
            selectedGym = detail
            showGymProfile = true
        }
        .ignoresSafeArea()
        .padding(.top, 40)
        .sheet(isPresented: $showGymProfile) {
            if let detail = selectedGym {
                GymProfileView(gym: detail)
            }
        }
    }
}
