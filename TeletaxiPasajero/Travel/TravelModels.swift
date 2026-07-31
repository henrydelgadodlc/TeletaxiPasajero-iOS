import Foundation
import CoreLocation

// Contratos de travelModule/valorationModule (request/info, passengerstate, opinion).

struct TravelInfo: Decodable {
    let color: String?
    let conductor: String?
    let destino: String?
    let direccion: String?
    let estado: String?
    let foto: String?
    let id: Int?
    let lat: String?
    let lat_destiny: String?
    let lat_driver: String?
    let lng: String?
    let lng_destiny: String?
    let lng_driver: String?
    let marca: String?
    let placa: String?
    let precio: Float?
    let referencia: String?
    let telefono: String?
    let tipo_pago: String?
    let monto_descuento_codigo: Float?
    let tarifa_pasajero: Float?
    let codigo_verificacion: String?
    let espera_segundos: Int?
    let total_paradas: Int?
    let paradas: [TripStop]?

    private enum CodingKeys: String, CodingKey {
        case color, conductor, destino, direccion, estado, foto, id,
             lat, lat_destiny, lat_driver, lng, lng_destiny, lng_driver,
             marca, placa, precio, referencia, telefono, tipo_pago,
             monto_descuento_codigo, tarifa_pasajero, codigo_verificacion,
             espera_segundos, total_paradas, paradas
    }

    // Decode tolerante: precio/tarifa vienen como string (DECIMAL de MySQL)
    // y lat/lng pueden llegar como número o string según la columna.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        color = c.flexString(.color)
        conductor = c.flexString(.conductor)
        destino = c.flexString(.destino)
        direccion = c.flexString(.direccion)
        estado = c.flexString(.estado)
        foto = c.flexString(.foto)
        id = c.flexInt(.id)
        lat = c.flexString(.lat)
        lat_destiny = c.flexString(.lat_destiny)
        lat_driver = c.flexString(.lat_driver)
        lng = c.flexString(.lng)
        lng_destiny = c.flexString(.lng_destiny)
        lng_driver = c.flexString(.lng_driver)
        marca = c.flexString(.marca)
        placa = c.flexString(.placa)
        precio = c.flexFloat(.precio)
        referencia = c.flexString(.referencia)
        telefono = c.flexString(.telefono)
        tipo_pago = c.flexString(.tipo_pago)
        monto_descuento_codigo = c.flexFloat(.monto_descuento_codigo)
        tarifa_pasajero = c.flexFloat(.tarifa_pasajero)
        codigo_verificacion = c.flexString(.codigo_verificacion)
        espera_segundos = c.flexInt(.espera_segundos)
        total_paradas = c.flexInt(.total_paradas)
        paradas = try? c.decodeIfPresent([TripStop].self, forKey: .paradas)
    }
}

struct TripStop: Decodable {
    let orden: Int
    let latitud: String?
    let longitud: String?
    let direccion: String?
    let estado: String?

    private enum CodingKeys: String, CodingKey {
        case orden, latitud, longitud, direccion, estado
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        orden = c.flexInt(.orden) ?? 0
        latitud = c.flexString(.latitud)
        longitud = c.flexString(.longitud)
        direccion = c.flexString(.direccion)
        estado = c.flexString(.estado)
    }
}

struct TravelResponse: Decodable {
    let code: Int
    let info: TravelInfo?
    let message: String?
}

// Datos que viajan a la pantalla de valoración (ruta Valoration de Android)
struct ValorationData: Identifiable, Equatable {
    let id = UUID()
    let conductor: String
    let foto: String?
    let precio: String
    let origen: String
    let destino: String
    let tipoPago: String
    let marca: String
    let placa: String
    let color: String
    let descuento: String
}

enum TravelAPI {
    static func info(requestId: Int) async throws -> TravelResponse {
        struct Body: Encodable { let id_solicitud: String }
        return try await TaxiAPI.shared.post("request/info", body: Body(id_solicitud: "\(requestId)"))
    }

    static func finishTravel() async throws -> AceptResponse {
        struct Body: Encodable {
            let id_solicitud: Int
            let estado_viaje: String
            let id_pasajero: Int
            let estado_pasajero: String
        }
        return try await TaxiAPI.shared.post("request/passengerstate", body: Body(
            id_solicitud: Session.shared.currentRequest,
            estado_viaje: "finalizado",
            id_pasajero: Session.shared.idPassenger,
            estado_pasajero: "activo"
        ))
    }

    static func opinion(valoracion: Float, comentario: String) async throws -> AceptResponse {
        struct Body: Encodable {
            let id_solicitud: Int
            let id_pasajero: Int
            let valoracion: Float
            let comentario: String
        }
        return try await TaxiAPI.shared.post("request/opinion", body: Body(
            id_solicitud: Session.shared.currentRequest,
            id_pasajero: Session.shared.idPassenger,
            valoracion: valoracion,
            comentario: comentario
        ))
    }

    // Token de tracking para compartir el viaje (TRACKING_TOKEN_URL)
    static func trackingToken(requestId: Int) async throws -> String? {
        struct TokenResponse: Decodable { let token: String? }
        let r: TokenResponse = try await TaxiAPI.shared.get("\(Config.trackingTokenURL)\(requestId)")
        return r.token
    }
}

// Utilidades geográficas (SphericalUtil de Android)
enum GeoUtil {
    static func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    static func heading(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return atan2(y, x) * 180 / .pi
    }

    static func offset(from origin: CLLocationCoordinate2D, distanceMeters: Double, headingDegrees: Double) -> CLLocationCoordinate2D {
        let radius = 6_371_009.0
        let d = distanceMeters / radius
        let h = headingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lng1 = origin.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(h))
        let lng2 = lng1 + atan2(sin(h) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lng2 * 180 / .pi)
    }

    // Puerto de calculateCurvePoints: curva bezier entre conductor y objetivo
    static func curvePoints(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let distance = distanceMeters(start, end)
        let h = heading(from: start, to: end)
        let mid = offset(from: start, distanceMeters: distance / 2, headingDegrees: h + 20)
        var points: [CLLocationCoordinate2D] = []
        let steps = 50
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * mid.latitude + t * t * end.latitude
            let lng = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * mid.longitude + t * t * end.longitude
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        return points
    }
}
