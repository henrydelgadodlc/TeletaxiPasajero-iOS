import SwiftUI

// Puerto de ForgotPasswordScreen.kt + Container
struct ForgotPasswordView: View {
    let onBack: () -> Void
    let onCodeSent: (String) -> Void

    @State private var email = ""
    @State private var isLoading = false
    @State private var toastMessage: String?

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var p: AuthPalette { AuthPalette(isDark: isDark) }

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

                VStack(spacing: 0) {
                    Text("Recuperar contraseña")
                        .font(ChapaFont.bold(24))
                        .foregroundColor(p.text)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 12)

                    Text("Ingresa tu correo electrónico para recibir un código de verificación.")
                        .font(ChapaFont.medium(14))
                        .foregroundColor(p.muted)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 32)

                    ChapaTextField(value: $email, label: "Correo electrónico", icon: "envelope.fill", keyboard: .emailAddress, palette: p)

                    Spacer().frame(height: 32)

                    Button(action: doSend) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Enviar código")
                                    .font(ChapaFont.bold(16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(ChapaTheme.purplePrimary.opacity(email.isEmpty || isLoading ? 0.5 : 1))
                        .cornerRadius(14)
                    }
                    .disabled(isLoading || email.isEmpty)
                }
                .padding(24)

                Spacer()
            }
        }
        .toast($toastMessage)
        .navigationBarBackButtonHidden(true)
    }

    private func doSend() {
        isLoading = true
        Task {
            do {
                let response = try await AuthService.forgotPassword(correo: email)
                await MainActor.run {
                    isLoading = false
                    if response.code == 200 {
                        toastMessage = "Código enviado correctamente"
                        onCodeSent(email)
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
