import SwiftUI
import MapKit

// Acceso imperativo al MKMapView (centro actual, animaciones de cámara),
// equivalente al cameraPositionState de maps-compose.
final class MapProxy {
    weak var mapView: MKMapView?

    var centerCoordinate: CLLocationCoordinate2D? { mapView?.centerCoordinate }

    func animate(to coordinate: CLLocationCoordinate2D, meters: CLLocationDistance = 800) {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters)
        mapView?.setRegion(region, animated: true)
    }

    func fit(points: [CLLocationCoordinate2D]) {
        guard let mapView, !points.isEmpty else { return }
        var rect = MKMapRect.null
        for p in points {
            let mp = MKMapPoint(p)
            rect = rect.union(MKMapRect(x: mp.x, y: mp.y, width: 0, height: 0))
        }
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 60, bottom: 80, right: 60), animated: true)
    }
}

// Mapa del Home: pin verde (origen), pin rojo (destino) y polilínea morada,
// igual que la app Android (con tiles de Apple en lugar de Google).
struct HomeMapView: UIViewRepresentable {
    let proxy: MapProxy
    var origin: CLLocationCoordinate2D?
    var destination: CLLocationCoordinate2D?
    var routePoints: [CLLocationCoordinate2D]
    var routeLegs: [[CLLocationCoordinate2D]] = []
    var stops: [StopItem] = []
    var isDark: Bool

    // Colores de tramos multiruta (mismos que Android)
    static let legColors: [UIColor] = [
        UIColor(red: 0x7C/255.0, green: 0x3A/255.0, blue: 0xED/255.0, alpha: 1),
        UIColor(red: 0x03/255.0, green: 0xA9/255.0, blue: 0xF4/255.0, alpha: 1),
        UIColor(red: 0xFF/255.0, green: 0x98/255.0, blue: 0x00/255.0, alpha: 1),
        UIColor(red: 0xE5/255.0, green: 0x39/255.0, blue: 0x35/255.0, alpha: 1)
    ]
    static let stopColors: [UIColor] = [.systemPurple, .systemTeal, .systemOrange]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.pointOfInterestFilter = .includingAll
        proxy.mapView = mapView
        // Centro inicial: Lima (mismo default que Android)
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -12.046374, longitude: -77.042793),
                latitudinalMeters: 2000, longitudinalMeters: 2000
            ),
            animated: false
        )
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        proxy.mapView = mapView
        mapView.overrideUserInterfaceStyle = isDark ? .dark : .light

        // Sincronizar marcadores
        let existing = mapView.annotations.compactMap { $0 as? ChapaAnnotation }
        let desired = buildAnnotations()
        if !annotationsEqual(existing, desired) {
            mapView.removeAnnotations(existing)
            mapView.addAnnotations(desired)
        }

        // Sincronizar polilíneas (un tramo por color si hay paradas)
        let hadTotal = mapView.overlays.compactMap { ($0 as? MKPolyline)?.pointCount }.reduce(0, +)
        if hadTotal != routePoints.count || mapView.overlays.count != max(routeLegs.count, routePoints.count > 1 ? 1 : 0) {
            mapView.removeOverlays(mapView.overlays)
            if routeLegs.count > 1 {
                for (i, leg) in routeLegs.enumerated() where leg.count > 1 {
                    let line = ColoredPolyline(coordinates: leg, count: leg.count)
                    line.color = Self.legColors[i % Self.legColors.count]
                    mapView.addOverlay(line)
                }
            } else if routePoints.count > 1 {
                mapView.addOverlay(MKPolyline(coordinates: routePoints, count: routePoints.count))
            }
        }
    }

    private func buildAnnotations() -> [ChapaAnnotation] {
        var list: [ChapaAnnotation] = []
        if let origin {
            list.append(ChapaAnnotation(coordinate: origin, title: "Recojo aquí", kind: .origin))
        }
        for (i, stop) in stops.enumerated() {
            list.append(ChapaAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng),
                title: "Parada \(i + 1)",
                kind: .stop(index: i)
            ))
        }
        if let destination {
            list.append(ChapaAnnotation(coordinate: destination, title: "Destino", kind: .destination))
        }
        return list
    }

    private func annotationsEqual(_ a: [ChapaAnnotation], _ b: [ChapaAnnotation]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a.sorted { $0.kind.order < $1.kind.order }, b.sorted { $0.kind.order < $1.kind.order }) {
            if x.kind != y.kind { return false }
            if abs(x.coordinate.latitude - y.coordinate.latitude) > 0.000001 { return false }
            if abs(x.coordinate.longitude - y.coordinate.longitude) > 0.000001 { return false }
        }
        return true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = (polyline as? ColoredPolyline)?.color
                    ?? UIColor(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0, alpha: 1)
                renderer.lineWidth = 5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let chapa = annotation as? ChapaAnnotation else { return nil }
            let id = "chapa-pin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: chapa, reuseIdentifier: id)
            view.annotation = chapa
            switch chapa.kind {
            case .origin:
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "figure.wave")
                view.glyphText = nil
            case .destination:
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.fill")
                view.glyphText = nil
            case .stop(let index):
                view.markerTintColor = HomeMapView.stopColors[index % HomeMapView.stopColors.count]
                view.glyphImage = nil
                view.glyphText = "\(index + 1)"
            }
            return view
        }
    }
}

// Polilínea con color propio (tramos multiruta)
final class ColoredPolyline: MKPolyline {
    var color: UIColor = UIColor(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0, alpha: 1)
}

final class ChapaAnnotation: NSObject, MKAnnotation {
    enum Kind: Equatable {
        case origin, destination
        case stop(index: Int)

        var order: Int {
            switch self {
            case .origin: return 0
            case .stop(let i): return 1 + i
            case .destination: return 100
            }
        }
    }

    let coordinate: CLLocationCoordinate2D
    let title: String?
    let kind: Kind

    init(coordinate: CLLocationCoordinate2D, title: String, kind: Kind) {
        self.coordinate = coordinate
        self.title = title
        self.kind = kind
    }
}
