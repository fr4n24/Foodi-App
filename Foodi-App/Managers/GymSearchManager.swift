//
//  MapWidgetView.swift
//  GymLink
//
//  Created by Hasan on 10/12/25.
//

import Foundation
import MapKit

struct GymResult: Identifiable, Hashable, Equatable {
    let id = UUID()
    let item: MKMapItem
    let distance: Double
    let relevance: Double

    static func == (lhs: GymResult, rhs: GymResult) -> Bool {
        lhs.id == rhs.id
    }
}

class GymSearchManager {
    func searchGyms(
        query: String?,
        region: MKCoordinateRegion,
        completion: @escaping ([GymResult]) -> Void
    ) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query?.isEmpty == false ? query : "gym"
        request.region = region

        MKLocalSearch(request: request).start { response, error in
            guard let response = response, error == nil else {
                completion([])
                return
            }

            let filtered = response.mapItems.filter {
                let name = $0.name?.lowercased() ?? ""
                return name.contains("gym") ||
                       name.contains("fitness") ||
                       name.contains("crossfit") ||
                       name.contains("workout") ||
                       name.contains("sport") ||
                       name.contains("health club") ||
                       name.contains("ymca") ||
                       !name.isEmpty // fallback: include all results from a "gym" query
            }

            let centerLoc = CLLocation(latitude: region.center.latitude,
                                         longitude: region.center.longitude)
              let results = filtered.map { item -> GymResult in
                  let coord = item.placemark.coordinate
                  let itemLoc = CLLocation(latitude: coord.latitude, longitude:
              coord.longitude)
                  let distance = itemLoc.distance(from: centerLoc)
                  let match = item.name?.lowercased()
                      .contains(query?.lowercased() ?? "") ?? false
                  let relevance = match ? 0.9 : 0.6
                  return GymResult(item: item, distance: distance, relevance: relevance)
              }


            completion(results.sorted {
                $0.relevance == $1.relevance
                    ? $0.distance < $1.distance
                    : $0.relevance > $1.relevance
            })
        }
    }
}
