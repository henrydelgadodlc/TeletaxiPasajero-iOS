import SwiftUI
import UIKit

// Puerto de LoginTextField (LoginScreen.kt): campo redondeado con ícono,
// borde de 1px y toggle de visibilidad para contraseñas.
struct ChapaTextField: View {
    @Binding var value: String
    let label: String
    let icon: String
    var isPassword: Bool = false
    var keyboard: UIKeyboardType = .default
    let palette: AuthPalette

    @State private var passwordVisible = false
    private var scale: CGFloat { chapaScaleFactor }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20 * scale))
                .foregroundColor(palette.accent)

            Group {
                if isPassword && !passwordVisible {
                    SecureField("", text: $value, prompt: prompt)
                } else {
                    TextField("", text: $value, prompt: prompt)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                }
            }
            .font(ChapaFont.medium(14 * scale))
            .foregroundColor(palette.text)

            if isPassword {
                Button {
                    passwordVisible.toggle()
                } label: {
                    Image(systemName: passwordVisible ? "eye" : "eye.slash")
                        .font(.system(size: 18 * scale))
                        .foregroundColor(palette.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56 * scale)
        .background(palette.panel)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.border, lineWidth: 1))
    }

    private var prompt: Text {
        Text(label).font(ChapaFont.medium(14 * scale)).foregroundColor(palette.muted)
    }
}
