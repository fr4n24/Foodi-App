//
//  SavedManager.swift
//  GymLink
//
//  Created by Francisco Campa on 12/4/25.
//

import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import MapKit

class SavedManager {
    static let shared = SavedManager()
    private let db = Firestore.firestore()
    
    private func userSavedsRef() -> CollectionReference? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid).collection("favorites")
    }
    
    // Check if gym is favorited
    func isSavedd(_ gym: GymDetail, completion: @escaping (Bool) -> Void) {
        guard let ref = userSavedsRef() else {
            completion(false)
            return
        }
        
        let docId = gym.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
        
        ref.document(docId).getDocument { doc, _ in
            completion(doc?.exists ?? false)
        }
    }
    
    
    // Toggle favorite
    func toggleSaved(_ gym: GymDetail, completion: @escaping (Bool) -> Void) {
        guard let ref = userSavedsRef() else {
            completion(false)
            return
        }
        
        let docId = gym.name
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
                    "name": gym.name,
                    "lat": gym.coordinate.latitude,
                    "lon": gym.coordinate.longitude,
                    "address": gym.address,
                    "timestamp": FieldValue.serverTimestamp()
                ]) { _ in completion(true) }
            }
        }
    }
    
    func fetchSaveds(completion: @escaping ([GymDetail]) -> Void) {
            guard let ref = userSavedsRef() else {
                completion([])
                return
            }

            ref.getDocuments { snap, _ in
                let items: [GymDetail] = snap?.documents.compactMap { doc in
                    let data = doc.data()

                    return GymDetail(
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

