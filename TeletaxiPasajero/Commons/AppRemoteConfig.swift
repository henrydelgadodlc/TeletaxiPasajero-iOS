import Foundation

// Puerto de AppRemoteConfig: ajustes remotos del panel (configuracion_app).
// Si la petición falla, la app sigue con el último valor cacheado en Session.
enum AppRemoteConfig {

    private static let minInterval: TimeInterval = 5 * 60
    private static var lastFetchAt: Date = .distantPast

    struct ConfigResponse: Decodable {
        let data: [String: AnyDecodable]?
    }

    static func refresh(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastFetchAt) >= minInterval else { return }
        lastFetchAt = now

        Task {
            guard let settings: ConfigResponse = try? await TaxiAPI.shared.get("app/config?plataforma=pasajero"),
                  let data = settings.data else { return }
            if let hide = data["boton_ocultar_teclado"]?.value as? Bool {
                Session.shared.keyboardHideButton = hide
            }
        }
    }
}

// Decodifica valores JSON heterogéneos (bool/num/string) del config remoto.
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { value = b }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let s = try? container.decode(String.self) { value = s }
        else { value = NSNull() }
    }
}
