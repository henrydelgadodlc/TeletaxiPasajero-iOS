import Foundation

// Contratos idénticos a los entity del homeModule/promoModule de Android.

struct StopPayload: Codable {
    let latitud: Double
    let longitud: Double
    let direccion: String
}

// Parada intermedia elegida por el pasajero (StopItem de HomeState.kt)
struct StopItem: Equatable, Identifiable {
    let id = UUID()
    let address: String
    let lat: Double
    let lng: Double
}

struct RequestData: Encodable {
    let id_pasajero: Int
    let latitud_origen: Double
    let longitud_origen: Double
    let latitud_destino: Double
    let longitud_destino: Double
    let direccion_actual: String
    let direccion_destino: String
    let referencia: String
    let precio: Float
    let tipo_pago: String
    var codigo_descuento: String? = nil
    var telefono: String? = nil
    var monto_descuento_codigo: Float? = nil
    var tarifa_pasajero: Float? = nil
    var id_categoria: Int = 1
    var paradas: [StopPayload]? = nil
}

struct RequestResponse: Decodable {
    let code: Int
    let message: String?
    let data: RequestDataResponse?
}

struct RequestDataResponse: Decodable {
    let id_solicitud: Int
    let codigo_aplicado: Bool?
    let monto_descuento_codigo: Float?
    let tarifa_pasajero: Float?

    private enum CodingKeys: String, CodingKey {
        case id_solicitud, codigo_aplicado, monto_descuento_codigo, tarifa_pasajero
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id_solicitud = c.flexInt(.id_solicitud) ?? 0
        codigo_aplicado = try? c.decodeIfPresent(Bool.self, forKey: .codigo_aplicado)
        monto_descuento_codigo = c.flexFloat(.monto_descuento_codigo)
        tarifa_pasajero = c.flexFloat(.tarifa_pasajero)
    }
}

struct EstimateData: Encodable {
    let latitud_origen: String
    let longitud_origen: String
    let latitud_destino: String
    let longitud_destino: String
    let route_distance_meters: String
    let route_duration_seconds: String
    var paradas: [StopPayload]? = nil
}

struct EstimateResponse: Decodable {
    let code: Int
    let message: String?
    let data: EstimateDetail?
}

struct EstimateDetail: Decodable {
    let currency: String?
    let precio_referencial: Double
    let precio_minimo: Double?
    let precio_maximo: Double?
    let distancia_metros: Int?
    let distancia_km: Double?
    let duracion_segundos: Int?
    let duracion_minutos: Int?
}

struct CategoriaItem: Decodable, Identifiable, Equatable {
    let id_categoria: Int
    let nombre: String
    let descripcion: String?
    var grupo: String = "auto"
    var nivel: Int = 1
    var ajuste_tipo: String = "fijo"
    var ajuste_valor: Double = 0.0
    var id: Int { id_categoria }

    private enum CodingKeys: String, CodingKey {
        case id_categoria, nombre, descripcion, grupo, nivel, ajuste_tipo, ajuste_valor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id_categoria = try c.decode(Int.self, forKey: .id_categoria)
        nombre = try c.decode(String.self, forKey: .nombre)
        descripcion = try c.decodeIfPresent(String.self, forKey: .descripcion)
        grupo = try c.decodeIfPresent(String.self, forKey: .grupo) ?? "auto"
        nivel = try c.decodeIfPresent(Int.self, forKey: .nivel) ?? 1
        ajuste_tipo = try c.decodeIfPresent(String.self, forKey: .ajuste_tipo) ?? "fijo"
        ajuste_valor = try c.decodeIfPresent(Double.self, forKey: .ajuste_valor) ?? 0.0
    }
}

struct CategoriasResponse: Decodable {
    let code: Int
    let data: CategoriasData?
    struct CategoriasData: Decodable { let categorias: [CategoriaItem]? }
}

struct MetodoPagoItem: Decodable, Identifiable, Equatable {
    let id_metodo: Int
    let clave: String
    let nombre: String
    let color: String?
    var id: Int { id_metodo }
}

struct MetodosPagoResponse: Decodable {
    let code: Int
    let data: MetodosPagoData?
    struct MetodosPagoData: Decodable { let metodos: [MetodoPagoItem]? }
}

struct IsActiveResponse: Decodable {
    let code: Int
    let message: String?
    let data: IsActiveResult?
    struct IsActiveResult: Decodable {
        let active: Bool?
        let multi_stop: MultiStopConfig?
    }
    struct MultiStopConfig: Decodable {
        let enabled: Bool?
        let max_paradas: Int?
    }
}

struct PromoValidateResponse: Decodable {
    let valid: Bool
    let monto_descuento: Double?
    let tarifa_original: Double?
    let tarifa_final: Double?
    let message: String?
}

struct CancelTemporalResponse: Decodable {
    let code: Int
    let message: String?
}
