import Foundation

// Contratos idénticos a los entity de Android (SigninModule/SignupModule/passwordModule).

struct AuthData: Encodable {
    let correo: String
    let clave: String
}

struct AuthUser: Decodable {
    let correo: String?
    let estado: String?
    let id_cuenta: Int?
    let id_pasajero: Int?
    let id: Int?
    let id_persona: Int?
    let nombres: String?
    let telefono: String?
    let foto: String?
}

struct AuthResponse: Decodable {
    let code: String
    let token: String?
    let user: AuthUser?
}

struct RegisterResponse: Decodable {
    let code: String
    let foto: String?
    let user: AuthUser?
}

struct ForgotPasswordResponse: Decodable {
    let code: Int
    let message: String?
}

struct ResetPasswordResponse: Decodable {
    let code: Int
    let message: String?
}

struct TokenData: Encodable {
    let id_rol: Int
    let token: String
    let tipo_rol: String
}
