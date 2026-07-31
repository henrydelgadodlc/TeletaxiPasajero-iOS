import Foundation

// Contratos idénticos a temporaltModule/data/entity de Android.

struct Temporal: Decodable, Identifiable, Equatable {
    let id: Int
    let id_conductor: Int
    let id_solicitud: Int
    let conductor: String?
    let foto: String?
    let color: String?
    let marca: String?
    let placa: String?
    let tarifa: Double
    let token: String?
    let unidad: String?
    let valoraciones: String?
    let viajes_realizados: Int
    let latitud: String?
    let longitud: String?

    private enum CodingKeys: String, CodingKey {
        case id, id_conductor, id_solicitud, conductor, foto, color, marca,
             placa, tarifa, token, unidad, valoraciones, viajes_realizados,
             latitud, longitud
    }

    // Decode tolerante: tarifa y valoraciones llegan como string (DECIMAL
    // de MySQL); Gson en Android los coercionaba, Codable no.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        id_conductor = c.flexInt(.id_conductor) ?? 0
        id_solicitud = c.flexInt(.id_solicitud) ?? 0
        conductor = c.flexString(.conductor)
        foto = c.flexString(.foto)
        color = c.flexString(.color)
        marca = c.flexString(.marca)
        placa = c.flexString(.placa)
        tarifa = c.flexDouble(.tarifa) ?? 0
        token = c.flexString(.token)
        unidad = c.flexString(.unidad)
        valoraciones = c.flexString(.valoraciones)
        viajes_realizados = c.flexInt(.viajes_realizados) ?? 0
        latitud = c.flexString(.latitud)
        longitud = c.flexString(.longitud)
    }
}

struct TemporalResponse: Decodable {
    let solicitudes: [Temporal]?
}

struct AceptResponse: Decodable {
    let code: Int
    let message: String?
}

enum TemporalAPI {
    // GET request/temporal/{id}: 500 = sin postulantes (esperado)
    static func offers(requestId: Int) async -> [Temporal] {
        do {
            let r: TemporalResponse = try await TaxiAPI.shared.get("request/temporal/\(requestId)")
            return r.solicitudes ?? []
        } catch {
            return []
        }
    }

    static func accept(idSolicitud: Int, idConductor: Int, precio: Float) async throws -> AceptResponse {
        struct Body: Encodable { let id_solicitud: Int; let id_conductor: Int; let precio: Float }
        return try await TaxiAPI.shared.post("request/confirmartemporal", body: Body(id_solicitud: idSolicitud, id_conductor: idConductor, precio: precio))
    }

    // POST request/dispatch/pulse: cada pulso ejecuta un ciclo de despacho
    struct PulseResponse: Decodable {
        let code: Int
        let dispatch: DispatchInfo?
        struct DispatchInfo: Decodable {
            let current_radius_km: Double?
            let total_notified: Int?
        }
    }

    static func pulse(requestId: Int) async throws -> PulseResponse {
        struct Body: Encodable { let id_solicitud: Int }
        return try await TaxiAPI.shared.post("request/dispatch/pulse", body: Body(id_solicitud: requestId))
    }

    // POST request/resume/passenger — estado real del viaje en el servidor
    struct ResumeResponse: Decodable {
        let code: Int
        let info: ResumeInfo?
        struct ResumeInfo: Decodable {
            let id: Int?
            let estado: String?
        }
    }

    static func resumePassenger() async throws -> ResumeResponse {
        struct Body: Encodable { let id_pasajero: Int }
        return try await TaxiAPI.shared.post("request/resume/passenger", body: Body(id_pasajero: Session.shared.idPassenger))
    }
}
