import SwiftUI
import MapKit
import UIKit

// Mapa del seguimiento: punto de recojo, destino, auto del conductor rotado
// y línea punteada curva hacia el objetivo (igual que TravelScreen Android).
struct TravelMapView: UIViewRepresentable {
    let proxy: MapProxy
    var origin: CLLocationCoordinate2D
    var destiny: CLLocationCoordinate2D
    var driver: CLLocationCoordinate2D
    var driverRotation: Double
    var estado: String?
    var isDark: Bool
    var onUserGesture: () -> Void

    private var isActive: Bool { estado == "aceptado" || estado == "abordo" }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        proxy.mapView = mapView
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didPan(_:)))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)
        context.coordinator.onUserGesture = onUserGesture
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        proxy.mapView = mapView
        context.coordinator.onUserGesture = onUserGesture
        mapView.overrideUserInterfaceStyle = isDark ? .dark : .light

        // Anotaciones
        mapView.removeAnnotations(mapView.annotations)
        if origin.latitude != 0 && estado == "aceptado" {
            mapView.addAnnotation(TravelAnnotation(coordinate: origin, kind: .origin))
        }
        if destiny.latitude != 0 && isActive {
            mapView.addAnnotation(TravelAnnotation(coordinate: destiny, kind: .destiny))
        }
        if driver.latitude != 0 && isActive {
            let a = TravelAnnotation(coordinate: driver, kind: .driver)
            a.rotation = driverRotation
            mapView.addAnnotation(a)
        }

        // Línea punteada conductor → objetivo
        mapView.removeOverlays(mapView.overlays)
        if driver.latitude != 0 && isActive {
            let target = estado == "aceptado" ? origin : destiny
            if target.latitude != 0 {
                let points = GeoUtil.curvePoints(from: driver, to: target)
                mapView.addOverlay(MKPolyline(coordinates: points, count: points.count))
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var onUserGesture: () -> Void = {}

        @objc func didPan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began { onUserGesture() }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0, alpha: 1)
                renderer.lineWidth = 4
                renderer.lineDashPattern = [8, 8]
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let travel = annotation as? TravelAnnotation else { return nil }
            switch travel.kind {
            case .driver:
                let id = "driver-car"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: travel, reuseIdentifier: id)
                view.annotation = travel
                let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
                view.image = UIImage(systemName: "car.top.radiowaves.rear.right.fill", withConfiguration: config)?
                    .withTintColor(UIColor(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0, alpha: 1), renderingMode: .alwaysOriginal)
                    ?? UIImage(systemName: "car.fill", withConfiguration: config)
                view.transform = CGAffineTransform(rotationAngle: travel.rotation * .pi / 180)
                view.layer.zPosition = 10
                return view
            case .origin, .destiny:
                let id = "travel-dot"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: travel, reuseIdentifier: id)
                view.annotation = travel
                view.markerTintColor = travel.kind == .origin
                    ? UIColor(red: 0x58 / 255.0, green: 0x30 / 255.0, blue: 0xC3 / 255.0, alpha: 1)
                    : UIColor(red: 0xE9 / 255.0, green: 0x1E / 255.0, blue: 0x8C / 255.0, alpha: 1)
                view.glyphImage = UIImage(systemName: travel.kind == .origin ? "figure.wave" : "mappin")
                return view
            }
        }
    }
}

final class TravelAnnotation: NSObject, MKAnnotation {
    enum Kind { case origin, destiny, driver }
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
    var rotation: Double = 0

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
    }
}

// Share sheet (Intent.ACTION_SEND de Android)
struct ActivityView: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
