import Foundation

// Puerto de AuthInteractor/RegisterInteractor/PasswordInteractor.
// Endpoints y payloads idénticos a Android.
enum AuthService {

    static func login(correo: String, clave: String) async throws -> AuthResponse {
        try await TaxiAPI.shared.post("passenger/authcredentials", body: AuthData(correo: correo, clave: clave))
    }

    // passenger/register es multipart en Android (RegisterService).
    static func register(nombres: String, correo: String, telefono: String, clave: String) async throws -> RegisterResponse {
        try await TaxiAPI.shared.postMultipart("passenger/register", fields: [
            "nombres": nombres,
            "correo": correo,
            "telefono": telefono,
            "clave": clave
        ])
    }

    static func forgotPassword(correo: String) async throws -> ForgotPasswordResponse {
        struct Body: Encodable { let correo: String }
        return try await TaxiAPI.shared.post("passenger/password/forgot", body: Body(correo: correo))
    }

    static func resetPassword(correo: String, codigo: String, clave: String) async throws -> ResetPasswordResponse {
        struct Body: Encodable { let correo: String; let codigo: String; let clave: String }
        return try await TaxiAPI.shared.post("passenger/password/reset", body: Body(correo: correo, codigo: codigo, clave: clave))
    }

    // Igual que handleSuccess de LoginScreenContainer/RegisterScreenContainer:
    // persiste la sesión completa. (El registro del token FCM llega en Fase 6.)
    static func persistSession(user: AuthUser, isGoogle: Bool = false) {
        let s = Session.shared
        s.isLogin = true
        s.isGoogleLogin = isGoogle
        s.idAccount = user.id_cuenta ?? 0
        s.idPassenger = user.id_pasajero ?? user.id ?? 0
        s.idPerson = user.id_persona ?? 0
        if let n = user.nombres { s.nameUser = n }
        if let c = user.correo { s.emailUser = c }
        if let t = user.telefono { s.phoneUser = t }
        if let f = user.foto { s.savePhoto = f }
    }
}
