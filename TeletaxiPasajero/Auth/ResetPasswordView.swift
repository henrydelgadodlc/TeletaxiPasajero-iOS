import SwiftUI

// Puerto de ResetPasswordScreen.kt + Container
struct ResetPasswordView: View {
    let email: String
    let onBack: () -> Void
    let onResetSuccess: () -> Void

    @State private var code = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toastMessage: String?

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var p: AuthPalette { AuthPalette(isDark: isDark) }

    private var formReady: Bool {
        !code.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
    }

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(p.text)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("Nueva contraseña")
                            .font(ChapaFont.bold(24))
                            .foregroundColor(p.text)

                        Spacer().frame(height: 8)

                        Text("Ingresa el código enviado a \(email) y tu nueva contraseña.")
                            .font(ChapaFont.medium(14))
                            .foregroundColor(p.muted)
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 32)

                        ChapaTextField(value: $code, label: "Código de verificación", icon: "number", keyboard: .numberPad, palette: p)
                        Spacer().frame(height: 16)
                        ChapaTextField(value: $password, label: "Nueva contraseña", icon: "lock.fill", isPassword: true, palette: p)
                        Spacer().frame(height: 16)
                        ChapaTextField(value: $confirmPassword, label: "Confirmar contraseña", icon: "lock.fill", isPassword: true, palette: p)

                        Spacer().frame(height: 32)

                        Button(action: doReset) {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Cambiar contraseña")
                                        .font(ChapaFont.bold(16))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(ChapaTheme.purplePrimary.opacity(!formReady || isLoading ? 0.5 : 1))
                            .cornerRadius(14)
                        }
                        .disabled(isLoading || !formReady)
                    }
                    .padding(24)
                }
            }
        }
        .toast($toastMessage)
        .navigationBarBackButtonHidden(true)
    }

    private func doReset() {
        guard password == confirmPassword else {
            toastMessage = "Las contraseñas no coinciden"
            return
        }
        isLoading = true
        Task {
            do {
                let response = try await AuthService.resetPassword(correo: email, codigo: code, clave: password)
                await MainActor.run {
                    isLoading = false
                    if response.code == 200 {
                        toastMessage = "Contraseña actualizada"
                        onResetSuccess()
                    } else {
                        toastMessage = "Error: \(response.message ?? "")"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    toastMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}
