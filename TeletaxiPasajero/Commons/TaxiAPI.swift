import Foundation

// Equivalente de TaxiRetrofit/NetworkModule: cliente único contra la API.
// Los servicios de cada módulo llaman TaxiAPI.shared.post/get con structs
// Codable cuyas claves replican EXACTAMENTE los @SerializedName de Android.

enum APIError: LocalizedError {
    case http(status: Int, message: String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .http(_, let message): return message
        case .invalidURL(let path): return "URL inválida: \(path)"
        }
    }
}

private struct APIMessageBody: Decodable {
    let message: String?
    let error: String?
}

final class TaxiAPI {
    static let shared = TaxiAPI()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    func get<R: Decodable>(_ path: String) async throws -> R {
        try await request(path: path, method: "GET", bodyData: nil)
    }

    func post<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await request(path: path, method: "POST", bodyData: try encoder.encode(body))
    }

    // Equivalente de los @Multipart de RegisterService (solo campos de texto).
    func postMultipart<R: Decodable>(_ path: String, fields: [String: String]) async throws -> R {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (name, value) in fields {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return try await request(
            path: path, method: "POST", bodyData: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    // Equivalente de @FormUrlEncoded (uploadImage a la plataforma).
    func postForm(_ url: String, fields: [String: String]) async throws -> String {
        let body = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
        struct RawString: Decodable {}
        guard let u = URL(string: url) else { throw APIError.invalidURL(url) }
        var request = URLRequest(url: u)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, message: "Error al subir (\(status))")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func request<R: Decodable>(
        path: String, method: String, bodyData: Data?,
        contentType: String = "application/json"
    ) async throws -> R {
        let urlString = path.hasPrefix("http") ? path : Config.baseURL + path
        guard let url = URL(string: urlString) else { throw APIError.invalidURL(path) }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let bodyData {
            request.httpBody = bodyData
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            // Igual que PromoInterceptor en Android: rescatar el message del
            // errorBody en 400/404 para mostrarlo al usuario.
            let parsed = try? decoder.decode(APIMessageBody.self, from: data)
            let message = parsed?.message ?? parsed?.error ?? "Error de conexión (\(status))"
            throw APIError.http(status: status, message: message)
        }

        return try decoder.decode(R.self, from: data)
    }
}
