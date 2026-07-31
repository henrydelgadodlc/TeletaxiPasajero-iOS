import SwiftUI

// Paleta dinámica claro/oscuro de las pantallas de auth (mismos hex que
// LoginScreen.kt/RegisterScreen.kt de Android).
struct AuthPalette {
    let isDark: Bool

    var bg: Color { isDark ? ChapaTheme.darkBg : ChapaTheme.surfaceLight }          // 090914 / F8F9FF
    var panel: Color { isDark ? ChapaTheme.cardBg : .white }                        // 111126 / FFFFFF
    var text: Color { isDark ? ChapaTheme.textMain : ChapaTheme.ink }               // F0F0FF / 0F172A
    var muted: Color { isDark ? ChapaTheme.textMuted : ChapaTheme.slate }           // 8080A8 / 64748B
    var border: Color { isDark ? Color(hex: 0x4AA13D, alpha: 0.157) : ChapaTheme.borderLight } // 287C3AED / E2E8F0
    var accent: Color { isDark ? ChapaTheme.purpleLight : ChapaTheme.purplePrimary } // 9B5CF6 / 7C3AED
}
