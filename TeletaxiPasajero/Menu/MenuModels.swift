import Foundation

// Contratos de historyModule / placesModule / recommendedModule.

struct HistoryEntity: Decodable, Identifiable {
    let id_solicitud: Int
    let fechayhora: String?
    let precio: Double
    let tipo_pago: String?
    let conductor: String?
    let foto: String?
    let origen: String?
    let destino: String?
    let referencia: String?
    var id: Int { id_solicitud }

    private enum CodingKeys: String, CodingKey {
        case id_solicitud, fechayhora, precio, tipo_pago, conductor, foto, origen, destino, referencia
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id_solicitud = c.flexInt(.id_solicitud) ?? 0
        fechayhora = c.flexString(.fechayhora)
        precio = c.flexDouble(.precio) ?? 0
        tipo_pago = c.flexString(.tipo_pago)
        conductor = c.flexString(.conductor)
        foto = c.flexString(.foto)
        origen = c.flexString(.origen)
        destino = c.flexString(.destino)
        referencia = c.flexString(.referencia)
    }
}

struct FavoritePlace: Decodable, Identifiable {
    let id: String
    let titulo: String
    let direccion: String
    let latitud: String
    let longitud: String

    private enum CodingKeys: String, CodingKey { case id, titulo, direccion, latitud, longitud }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexString(.id) ?? ""
        titulo = c.flexString(.titulo) ?? ""
        direccion = c.flexString(.direccion) ?? ""
        latitud = c.flexString(.latitud) ?? "0"
        longitud = c.flexString(.longitud) ?? "0"
    }
}

struct RecommendedCategory: Decodable, Identifiable {
    let id_categoria: Int
    let nombre: String
    let icono_url: String?
    var id: Int { id_categoria }

    private enum CodingKeys: String, CodingKey { case id_categoria, nombre, icono_url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id_categoria = c.flexInt(.id_categoria) ?? 0
        nombre = c.flexString(.nombre) ?? ""
        icono_url = c.flexString(.icono_url)
    }
}

struct RecommendedPlace: Decodable, Identifiable {
    let id_lugar: Int
    let nombre: String
    let logo_url: String?
    let banner_url: String?
    let direccion: String?
    let lat: Double
    let lng: Double
    let categoria_nombre: String?
    let destacado: Int
    var id: Int { id_lugar }

    private enum CodingKeys: String, CodingKey {
        case id_lugar, nombre, logo_url, banner_url, direccion, lat, lng, categoria_nombre, destacado
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id_lugar = c.flexInt(.id_lugar) ?? 0
        nombre = c.flexString(.nombre) ?? ""
        logo_url = c.flexString(.logo_url)
        banner_url = c.flexString(.banner_url)
        direccion = c.flexString(.direccion)
        lat = c.flexDouble(.lat) ?? 0
        lng = c.flexDouble(.lng) ?? 0
        categoria_nombre = c.flexString(.categoria_nombre)
        destacado = c.flexInt(.destacado) ?? 0
    }
}

enum MenuAPI {
    static func history() async throws -> [HistoryEntity] {
        struct R: Decodable { let code: Int; let historial: [HistoryEntity]? }
        let r: R = try await TaxiAPI.shared.postMultipart("history/default", fields: [
            "id_passenger": "\(Session.shared.idPassenger)"
        ])
        return r.historial ?? []
    }

    static func favoritePlaces() async throws -> [FavoritePlace] {
        struct R: Decodable { let lugares: [FavoritePlace]? }
        let r: R = try await TaxiAPI.shared.postMultipart("passenger/getplaces", fields: [
            "id_pasajero": "\(Session.shared.idPassenger)"
        ])
        return r.lugares ?? []
    }

    struct GenericResponse: Decodable {}

    static func createPlace(titulo: String, direccion: String, lat: Double, lng: Double) async throws {
        let _: GenericResponse = try await TaxiAPI.shared.postMultipart("passenger/places", fields: [
            "id": "\(Session.shared.idPassenger)",
            "titulo": titulo,
            "direccion": direccion,
            "latitud": "\(lat)",
            "longitud": "\(lng)"
        ])
    }

    static func deletePlace(id: String) async throws {
        let _: GenericResponse = try await TaxiAPI.shared.postMultipart("passenger/delete", fields: [
            "id_place": id
        ])
    }

    static func categories() async throws -> [RecommendedCategory] {
        struct R: Decodable { let categorias: [RecommendedCategory]? }
        struct Empty: Encodable {}
        let r: R = try await TaxiAPI.shared.post("passenger/placescategories", body: Empty())
        return r.categorias ?? []
    }

    static func recommendedPlaces(categoryId: Int?) async throws -> [RecommendedPlace] {
        struct R: Decodable { let lugares: [RecommendedPlace]? }
        var fields: [String: String] = [:]
        if let categoryId { fields["id_categoria"] = "\(categoryId)" }
        let r: R = try await TaxiAPI.shared.postMultipart("passenger/placesrecommended", fields: fields)
        return r.lugares ?? []
    }

    static func featuredPlaces() async throws -> [RecommendedPlace] {
        struct R: Decodable { let lugares: [RecommendedPlace]? }
        struct Empty: Encodable {}
        let r: R = try await TaxiAPI.shared.post("passenger/placesrecommendedfeatured", body: Empty())
        return r.lugares ?? []
    }

    // passenger/update | updatefull (con foto base64), igual que UpdateData Android
    static func updateProfile(nombres: String, correo: String, telefono: String, fotoBase64: String?) async throws -> RegisterResponse {
        var fields = [
            "nombres": nombres,
            "correo": correo,
            "telefono": telefono,
            "id_persona": "\(Session.shared.idPerson)",
            "id_cuenta": "\(Session.shared.idAccount)"
        ]
        if let fotoBase64 {
            fields["foto"] = fotoBase64
            return try await TaxiAPI.shared.postMultipart("passenger/updatefull", fields: fields)
        }
        return try await TaxiAPI.shared.postMultipart("passenger/update", fields: fields)
    }
}
