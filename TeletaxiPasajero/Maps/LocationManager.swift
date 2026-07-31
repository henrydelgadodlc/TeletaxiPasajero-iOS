import Foundation
import CoreLocation

// Equivalente de FusedLocationProviderClient + MapUtils.getAddressPosition:
// ubicación actual y geocodificación inversa.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published var location: CLLocationCoordinate2D?
    @Published var authorized: Bool?

    private var oneShotCallbacks: [(CLLocationCoordinate2D?) -> Void] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermissionAndLocation(_ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        oneShotCallbacks.append(completion)
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            manager.requestLocation()
        default:
            authorized = false
            flush(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorized = true
            if !oneShotCallbacks.isEmpty { manager.requestLocation() }
        case .denied, .restricted:
            authorized = false
            flush(nil)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last?.coordinate else { return }
        location = loc
        Session.shared.currentLat = loc.latitude
        Session.shared.currentLng = loc.longitude
        flush(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        flush(nil)
    }

    private func flush(_ loc: CLLocationCoordinate2D?) {
        let callbacks = oneShotCallbacks
        oneShotCallbacks = []
        callbacks.forEach { $0(loc) }
    }

    // Puerto de getAddressPosition: coordenada → dirección legible.
    func address(for coordinate: CLLocationCoordinate2D) async -> String {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(loc).first else {
            return "Ubicación (\(String(format: "%.5f", coordinate.latitude)), \(String(format: "%.5f", coordinate.longitude)))"
        }
        var parts: [String] = []
        if let street = placemark.thoroughfare {
            parts.append(placemark.subThoroughfare.map { "\(street) \($0)" } ?? street)
        } else if let name = placemark.name {
            parts.append(name)
        }
        if let district = placemark.subLocality ?? placemark.locality {
            parts.append(district)
        }
        return parts.isEmpty ? (placemark.name ?? "Ubicación seleccionada") : parts.joined(separator: ", ")
    }
}
