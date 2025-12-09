//
//  FavoriteManager.swift
//  Foodi
//
//  Created by Francisco Campa on 12/4/25.
//

import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import MapKit

class FavoriteManager {
    static let shared = FavoriteManager()
    private let db = Firestore.firestore()
    
    private func userFavoritesRef() -> CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("favorites")
    }
    
    // Check if restaurant is favorited
    func isFavorited(_ restaurant: RestaurantDetail, completion: @escaping (Bool) -> Void) {
        guard let ref = userFavoritesRef() else {
            completion(false)
            return
        }
        
        let docId = restaurant.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
        
        ref.document(docId).getDocument { doc, _ in
            completion(doc?.exists ?? false)
        }
    }
    
    
    // Toggle favorite
    func toggleFavorite(_ restaurant: RestaurantDetail, completion: @escaping (Bool) -> Void) {
        guard let ref = userFavoritesRef() else {
            completion(false)
            return
        }
        
        let docId = restaurant.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
        
        let docRef = ref.document(docId)
        
        docRef.getDocument { doc, _ in
            if doc?.exists == true {
                docRef.delete { _ in completion(false) }
            } else {
                docRef.setData([
                    "name": restaurant.name,
                    "lat": restaurant.coordinate.latitude,
                    "lon": restaurant.coordinate.longitude,
                    "address": restaurant.address,
                    "timestamp": FieldValue.serverTimestamp()
                ]) { _ in completion(true) }
            }
        }
    }
    
    func fetchFavorites(completion: @escaping ([RestaurantDetail]) -> Void) {
            guard let ref = userFavoritesRef() else {
                completion([])
                return
            }

            ref.getDocuments { snap, _ in
                let items: [RestaurantDetail] = snap?.documents.compactMap { doc in
                    let data = doc.data()

                    return RestaurantDetail(
                        name: data["name"] as? String ?? "Unknown",
                        coordinate: CLLocationCoordinate2D(
                            latitude: data["lat"] as? Double ?? 0,
                            longitude: data["lon"] as? Double ?? 0
                        ),
                        address: data["address"] as? String ?? ""
                    )
                } ?? []

                completion(items)
            }
        }
    }

