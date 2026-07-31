import Foundation

// Puerto de RequestService/RequestInterceptor + PromoService.
enum RequestAPI {

    static func createRequest(_ data: RequestData) async throws -> RequestResponse {
        try await TaxiAPI.shared.post("request", body: data)
    }

    static func estimate(_ data: EstimateData) async throws -> EstimateResponse {
        try await TaxiAPI.shared.post("request/estimate", body: data)
    }

    static func categorias() async throws -> [CategoriaItem] {
        let r: CategoriasResponse = try await TaxiAPI.shared.get("request/categorias")
        return r.data?.categorias ?? []
    }

    static func metodosPago() async throws -> [MetodoPagoItem] {
        let r: MetodosPagoResponse = try await TaxiAPI.shared.get("request/metodospago")
        return r.data?.metodos ?? []
    }

    static func isActive(latitude: Double, longitude: Double) async throws -> IsActiveResponse {
        struct Body: Encodable { let latitude: Double; let longitude: Double }
        return try await TaxiAPI.shared.post("request/isactive", body: Body(latitude: latitude, longitude: longitude))
    }

    static func validatePromo(codigo: String, telefono: String, tarifa: Double) async throws -> PromoValidateResponse {
        struct Body: Encodable { let codigo: String; let telefono: String; let tarifa: Double }
        return try await TaxiAPI.shared.post("promo/validate", body: Body(codigo: codigo, telefono: telefono, tarifa: tarifa))
    }

    static func cancelRequest(idSolicitud: Int, motivo: String? = nil) async throws -> CancelTemporalResponse {
        struct Body: Encodable { let id_solicitud: Int; let motivo: String? }
        return try await TaxiAPI.shared.post("request/delete", body: Body(id_solicitud: idSolicitud, motivo: motivo))
    }
}
