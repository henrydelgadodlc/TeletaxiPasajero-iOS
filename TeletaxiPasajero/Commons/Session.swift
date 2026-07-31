import Foundation
import Security

// Puerto de SharedPreferenceApp (context_app_taxi): mismas claves lógicas.
// Todo va a UserDefaults salvo TOKEN, que se guarda en Keychain.
final class Session {
    static let shared = Session()
    private let storage = UserDefaults.standard
    private init() {}

    // MARK: - Login
    var isLogin: Bool {
        get { storage.bool(forKey: "LOGIN") }
        set { storage.set(newValue, forKey: "LOGIN") }
    }

    var isGoogleLogin: Bool {
        get { storage.bool(forKey: "IS_GOOGLE_LOGIN") }
        set { storage.set(newValue, forKey: "IS_GOOGLE_LOGIN") }
    }

    func logout() {
        // Igual que Android: limpia todo, conserva la preferencia de tema.
        let theme = themeMode
        if let domain = Bundle.main.bundleIdentifier {
            storage.removePersistentDomain(forName: domain)
        }
        themeMode = theme
        Keychain.delete("TOKEN")
    }

    // MARK: - Identidad
    var idPassenger: Int {
        get { storage.integer(forKey: "ID_PASSENGER") }
        set { storage.set(newValue, forKey: "ID_PASSENGER") }
    }
    var idAccount: Int {
        get { storage.integer(forKey: "ID_ACCOUNT") }
        set { storage.set(newValue, forKey: "ID_ACCOUNT") }
    }
    var idPerson: Int {
        get { storage.integer(forKey: "ID_PERSON") }
        set { storage.set(newValue, forKey: "ID_PERSON") }
    }

    // MARK: - Datos del usuario
    var nameUser: String {
        get { storage.string(forKey: "NAME_USER") ?? "" }
        set { storage.set(newValue, forKey: "NAME_USER") }
    }
    var phoneUser: String {
        get { storage.string(forKey: "PHONE_USER") ?? "" }
        set { storage.set(newValue, forKey: "PHONE_USER") }
    }
    var emailUser: String {
        get { storage.string(forKey: "EMAIL_USER") ?? "" }
        set { storage.set(newValue, forKey: "EMAIL_USER") }
    }
    var savePhoto: String {
        get { storage.string(forKey: "SAVE_PHOTO") ?? "" }
        set { storage.set(newValue, forKey: "SAVE_PHOTO") }
    }

    var tokenUser: String {
        get { Keychain.get("TOKEN") ?? "" }
        set { Keychain.set(newValue, forKey: "TOKEN") }
    }

    // MARK: - Viaje actual
    var currentRequest: Int {
        get { storage.integer(forKey: "CURRENT_REQUEST") }
        set { storage.set(newValue, forKey: "CURRENT_REQUEST") }
    }
    var hasActiveRequest: Bool { currentRequest != 0 }

    var stateTemporal: Bool {
        get { storage.bool(forKey: "STATE_REQUEST") }
        set { storage.set(newValue, forKey: "STATE_REQUEST") }
    }
    var stateTravel: Bool {
        get { storage.bool(forKey: "STATE_TRAVEL") }
        set { storage.set(newValue, forKey: "STATE_TRAVEL") }
    }
    var requestStartTime: Int64 {
        get { Int64(storage.double(forKey: "REQUEST_START_TIME")) }
        set { storage.set(Double(newValue), forKey: "REQUEST_START_TIME") }
    }
    var promoDiscount: Float {
        get { storage.float(forKey: "PROMO_DISCOUNT") }
        set { storage.set(newValue, forKey: "PROMO_DISCOUNT") }
    }

    func clearTripStates() {
        stateTemporal = false
        stateTravel = false
        currentRequest = 0
        requestStartTime = 0
        promoDiscount = 0
    }

    // MARK: - Ubicaciones
    var currentLat: Double {
        get { storage.double(forKey: "CURRENT_LAT") }
        set { storage.set(newValue, forKey: "CURRENT_LAT") }
    }
    var currentLng: Double {
        get { storage.double(forKey: "CURRENT_LNG") }
        set { storage.set(newValue, forKey: "CURRENT_LNG") }
    }
    var destinyLat: Double {
        get { storage.double(forKey: "DESNITY_LAT") }
        set { storage.set(newValue, forKey: "DESNITY_LAT") }
    }
    var destinyLng: Double {
        get { storage.double(forKey: "DESNITY_LNG") }
        set { storage.set(newValue, forKey: "DESNITY_LNG") }
    }

    // MARK: - Tema (1 = claro por defecto, 2 = oscuro; igual que Android)
    var themeMode: Int {
        get {
            let mode = storage.integer(forKey: "DARK_MODE")
            return mode == 0 ? 1 : mode
        }
        set { storage.set(newValue, forKey: "DARK_MODE") }
    }

    // MARK: - Ajustes remotos cacheados
    var keyboardHideButton: Bool {
        get { storage.bool(forKey: "KEYBOARD_HIDE_BUTTON") }
        set { storage.set(newValue, forKey: "KEYBOARD_HIDE_BUTTON") }
    }
}

// Helper mínimo de Keychain para el token de usuario.
enum Keychain {
    static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
