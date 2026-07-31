import Foundation
import CoreLocation

// Puerto de RouteInterceptor: rutas por carretera vía OpenRouteService,
// misma key y endpoint que Android (v2/directions/driving-car).
enum RouteService {

    private static let orsKey = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijk2ODE0ZTA4NDkwYzRlYTg5N2M5MTRmZjEwMDAwY2Q5IiwiaCI6Im11cm11cjY0In0="

    struct RouteResponse: Decodable {
        let features: [Feature]
        struct Feature: Decodable {
            let geometry: Geometry?
            let properties: Properties?
        }
        struct Geometry: Decodable { let coordinates: [[Double]] }
        struct Properties: Decodable { let summary: Summary? }
        struct Summary: Decodable { let distance: Double; let duration: Double }
    }

    struct RouteResult {
        let points: [CLLocationCoordinate2D]
        // Multiruta: mismos puntos separados por tramo (origen→P1, P1→P2, ...)
        // para pintar cada tramo de un color distinto, igual que Android
        let legs: [[CLLocationCoordinate2D]]
        let distanceMeters: Double
        let durationSeconds: Double
    }

    // points en formato "lng,lat" (igual que Android); tramos consecutivos.
    static func route(points: [String]) async throws -> RouteResult {
        guard points.count >= 2 else { throw APIError.invalidURL("ruta sin puntos") }
        var allPoints: [CLLocationCoordinate2D] = []
        var legs: [[CLLocationCoordinate2D]] = []
        var distance = 0.0
        var duration = 0.0
        for i in 0..<(points.count - 1) {
            let url = "https://api.openrouteservice.org/v2/directions/driving-car?api_key=\(orsKey)&start=\(points[i])&end=\(points[i + 1])"
            let leg: RouteResponse = try await TaxiAPI.shared.get(url)
            guard let feature = leg.features.first else { continue }
            let coords = (feature.geometry?.coordinates ?? []).map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            }
            if !coords.isEmpty { legs.append(coords) }
            allPoints.append(contentsOf: coords)
            distance += feature.properties?.summary?.distance ?? 0
            duration += feature.properties?.summary?.duration ?? 0
        }
        return RouteResult(points: allPoints, legs: legs, distanceMeters: distance, durationSeconds: duration)
    }
}
