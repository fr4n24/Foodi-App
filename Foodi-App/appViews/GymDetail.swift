import MapKit
import Contacts

struct GymDetail {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
    let phone: String?
    let url: URL?
    let category: MKPointOfInterestCategory?

    init(item: MKMapItem) {
        self.name = item.name ?? "Unknown"
        self.coordinate = item.location.coordinate

        // MARK: - SAFEST & CLEANEST ADDRESS EXTRACTION
        if let postal = item.placemark.postalAddress {
            // Format properly using Contacts framework
            let formatter = CNPostalAddressFormatter()
            let formatted = formatter.string(from: postal)
                .replacingOccurrences(of: "\n", with: ", ")

            self.address = formatted
        }
        else if let title = item.placemark.title {
            self.address = title
        }
        else {
            self.address = "Unknown address"
        }

        self.phone = item.phoneNumber
        self.url = item.url
        self.category = item.pointOfInterestCategory
    }

    init(
        name: String,
        coordinate: CLLocationCoordinate2D,
        address: String = "Unknown address",
        phone: String? = nil,
        url: URL? = nil,
        category: MKPointOfInterestCategory? = nil
    ) {
        self.name = name
        self.coordinate = coordinate
        self.address = address
        self.phone = phone
        self.url = url
        self.category = category
    }
}
