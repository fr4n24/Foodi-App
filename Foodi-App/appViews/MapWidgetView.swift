import SwiftUI
  import MapKit
  import CoreLocation
                                                                                
  private struct SheetGym: Identifiable {
      let result: GymResult
      let distanceText: String?
      var id: UUID { result.id }
  }
                                                                                
  struct MapWidgetView: View {
      var onSelectGym: ((GymDetail) -> Void)? = nil
                                                                                
      @StateObject private var locationMgr = LocationManager()
      @State private var position = MapCameraPosition.region(
          MKCoordinateRegion(
              center: CLLocationCoordinate2D(latitude: 34.2411, longitude:
  -119.0434),
              span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
          )
      )
      @State private var searchText    = ""
      @State private var results: [GymResult] = []
      @State private var selectedID: UUID?    = nil
      @State private var hasAutoLoaded        = false
      @State private var sheetGym: SheetGym? = nil
                                                                                
      private let gymManager = GymSearchManager()
                                                                                
      var body: some View {
          ZStack(alignment: .top) {
              mapLayer
              overlayControls
          }
          .onAppear {
              // Load immediately from default/current region; location update will re-center
              if !hasAutoLoaded, let region = position.region {
                  loadNearbyGyms(region: region)
              }
          }
          .onChange(of: locationMgr.location) {
              guard let loc = locationMgr.location, !hasAutoLoaded else { return
   }
              hasAutoLoaded = true
              let region = MKCoordinateRegion(
                  center: loc.coordinate,
                  span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta:
  0.04)
              )
              withAnimation { position = .region(region) }
              loadNearbyGyms(region: region)
          }
          .onChange(of: selectedID) {
              guard let id = selectedID,
                    let sel = results.first(where: { $0.id == id }) else {
                  sheetGym = nil
                  return
              }
              sheetGym = SheetGym(result: sel, distanceText: distanceString(for:
   sel))
          }
          .sheet(item: $sheetGym, onDismiss: { selectedID = nil }) { sg in
              GymDetailSheet(
                  item: sg.result.item,
                  distanceText: sg.distanceText,
                  onViewProfile: onSelectGym.map { cb in
                      { mapItem in
                          let detail = GymDetail(
                              name: mapItem.name ?? "Gym",
                              coordinate: mapItem.placemark.coordinate,
                              address: mapItem.placemark.title ?? "",
                              phone: mapItem.phoneNumber,
                              url: mapItem.url,
                              category: mapItem.pointOfInterestCategory
                          )
                          cb(detail)
                      }
                  }
              )
          }
      }
                                                            
      // MARK: - Map

      private var mapLayer: some View {
          Map(position: $position, selection: $selectedID) {
              UserAnnotation()
              ForEach(results) { r in
                  let name: String = r.item.name ?? "Gym"
                  let coord = r.item.placemark.coordinate
                  Marker(name, systemImage: "dumbbell.fill", coordinate: coord)
                      .tint(Color.gymLinkPink)
                      .tag(r.id)
              }
          }
          .mapStyle(.standard(elevation: .realistic))
          .ignoresSafeArea()
          .onMapCameraChange { ctx in position = .region(ctx.region) }
      }
                                                            
      // MARK: - Overlay
                                                            
      private var overlayControls: some View {
          VStack(spacing: 0) {
              searchBar.padding(.top, 10).padding(.horizontal, 14)
              Spacer()
              zoomControls
                  .padding(.bottom, 100)
                  .padding(.trailing, 14)
                  .frame(maxWidth: .infinity, alignment: .trailing)
          }
      }
   
      // MARK: - Search bar
                                                            
      private var searchBar: some View {
          HStack(spacing: 10) {
              Image(systemName: "magnifyingglass")
                  .foregroundColor(.gymLinkPink)
                  .font(.system(size: 14, weight: .semibold))
              TextField("Search gyms...", text: $searchText)
                  .foregroundColor(.white)
                  .autocorrectionDisabled()
                  .autocapitalization(.none)
                  .submitLabel(.search)
                  .onSubmit { performSearch() }
              if !searchText.isEmpty {
                  Button {
                      searchText = ""
                      if let region = position.region { loadNearbyGyms(region:
  region) }
                  } label: {
                      Image(systemName:
  "xmark.circle.fill").foregroundColor(Color(white: 0.4))
                  }
              }
          }
          .padding(.horizontal, 14).padding(.vertical, 10)
          .background(.ultraThinMaterial)
          .cornerRadius(14)
      }
                                                            
      // MARK: - Zoom controls
   
      private var zoomControls: some View {
          VStack(spacing: 8) {
              zoomBtn(icon: "plus",  factor: 0.6)
              zoomBtn(icon: "minus", factor: 1.4)
          }
      }
                                                                                
      private func zoomBtn(icon: String, factor: Double) -> some View {
          Button { zoom(factor: factor) } label: {
              Image(systemName: icon)
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundColor(.white)
                  .frame(width: 38, height: 38)
                  .background(.ultraThinMaterial)
                  .clipShape(Circle())
          }
      }
                                                            
      // MARK: - Helpers

      private func distanceString(for gym: GymResult) -> String? {
          guard let loc = locationMgr.location else { return nil }
          let coord = gym.item.placemark.coordinate
          let itemLoc = CLLocation(latitude: coord.latitude, longitude:
  coord.longitude)
          return String(format: "%.1f km away", itemLoc.distance(from: loc) /
  1000)
      }
                                                                                
      private func loadNearbyGyms(region: MKCoordinateRegion) {
          gymManager.searchGyms(query: nil, region: region) { found in
              DispatchQueue.main.async { results = found }
          }
      }
                                                                                
      private func performSearch() {
          guard let region = position.region else { return }
          gymManager.searchGyms(query: searchText.isEmpty ? nil : searchText,
  region: region) { found in
              DispatchQueue.main.async { results = found }
          }
      }

      private func zoom(factor: Double) {
          guard let r = position.region else { return }
          let span = MKCoordinateSpan(
              latitudeDelta: r.span.latitudeDelta * factor,
              longitudeDelta: r.span.longitudeDelta * factor
          )
          withAnimation(.easeInOut(duration: 0.25)) {
              position = .region(MKCoordinateRegion(center: r.center, span:
  span))
          }
      }
  }
