import SwiftUI

// Paleta portada de ChapaPasajero Android (res/values/colors.xml "Redesign v2"
// + colores inline más usados en las pantallas Compose). Mantener hex idénticos.
enum ChapaTheme {

    // Fondo y superficies (modo oscuro, diseño principal de la app)
    static let darkBg = Color(hex: 0x090914)        // dark_bg
    static let cardBg = Color(hex: 0x111126)        // card_bg
    static let surfaceDark = Color(hex: 0x1A1A35)   // surface_dark
    static let surfaceDeep = Color(hex: 0x1A1A2E)
    static let mapBlock = Color(hex: 0x13132A)      // map_block
    static let mapStreet = Color(hex: 0x1A1A38)     // map_street

    // Marca
    static let purplePrimary = Color(hex: 0x4AA13D) // purple_primary
    static let purpleLight = Color(hex: 0x6DBF5F)   // purple_light
    static let purpleDeep = Color(hex: 0x3E8E32)    // primary (legado)
    static let borderPurple = Color(hex: 0x2E4A2C)  // border_purple

    // Texto sobre fondo oscuro
    static let textMain = Color(hex: 0xF0F0FF)      // text_main
    static let textMuted = Color(hex: 0x8080A8)     // text_muted
    static let textDim = Color(hex: 0x3D3D60)       // text_dim

    // Superficies claras (tarjetas blancas del flujo de viaje)
    static let backgroundLight = Color(hex: 0xF0F2F5)
    static let surfaceLight = Color(hex: 0xF8F9FF)
    static let slate = Color(hex: 0x64748B)         // texto secundario en claro
    static let borderLight = Color(hex: 0xE2E8F0)
    static let ink = Color(hex: 0x0F172A)           // texto principal en claro

    // Estados
    static let red = Color(hex: 0xEF4444)
    static let redAlt = Color(hex: 0xE53935)
    static let green = Color(hex: 0x22C55E)
    static let greenAlt = Color(hex: 0x4CAF50)

    // Métodos de pago
    static let yape = Color(hex: 0x871495)
    static let plin = Color(hex: 0x0281F1)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
