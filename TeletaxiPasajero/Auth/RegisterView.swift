import SwiftUI

// Puerto 1:1 de RegisterScreen.kt + RegisterScreenContainer.kt
struct RegisterView: View {
    let onRegisterSuccess: () -> Void
    let onBack: () -> Void

    @State private var isDark = Session.shared.themeMode == 2
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var toastMessage: String?

    private var p: AuthPalette { AuthPalette(isDark: isDark) }
    private var scale: CGFloat { chapaScaleFactor }

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()

            SkylineGraphic(color: ChapaTheme.purplePrimary)
                .opacity(isDark ? 0.15 : 0.08)
                .padding(.top, 110 * scale)
                .frame(maxHeight: .infinity, alignment: .top)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24 * scale)

                    // --- HEADER ---
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18))
                                .foregroundColor(p.text)
                                .frame(width: 44, height: 44)
                                .background(p.panel.opacity(0.5))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                        }
                        Spacer()
                        Image("LogoChapa")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60 * scale, height: 60 * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer().frame(height: 10 * scale)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Crea tu cuenta")
                            .font(ChapaFont.bold(28 * scale))
                            .foregroundColor(p.text)
                        Text("Únete a la mejor experiencia de viaje.")
                            .font(ChapaFont.medium(14 * scale))
                            .foregroundColor(p.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 30 * scale)

                    // --- FORMULARIO ---
                    ChapaTextField(value: $name, label: "Nombre completo", icon: "person.fill", palette: p)
                    Spacer().frame(height: 12 * scale)
                    ChapaTextField(value: $email, label: "Correo electrónico", icon: "envelope.fill", keyboard: .emailAddress, palette: p)
                    Spacer().frame(height: 12 * scale)
                    ChapaTextField(value: $phone, label: "Teléfono / Celular", icon: "phone.fill", keyboard: .phonePad, palette: p)
                    Spacer().frame(height: 12 * scale)
                    ChapaTextField(value: $password, label: "Contraseña", icon: "lock.fill", isPassword: true, palette: p)
                    Spacer().frame(height: 12 * scale)
                    ChapaTextField(value: $confirmPassword, label: "Confirmar contraseña", icon: "lock.fill", isPassword: true, palette: p)

                    Spacer().frame(height: 24 * scale)

                    // --- BOTÓN REGISTRO ---
                    Button(action: doRegister) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Registrarme")
                                    .font(ChapaFont.bold(16 * scale))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54 * scale)
                        .background(ChapaTheme.purplePrimary)
                        .cornerRadius(14)
                    }
                    .disabled(isLoading)

                    if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Las contraseñas no coinciden")
                            .font(ChapaFont.medium(12))
                            .foregroundColor(.red)
                            .padding(.top, 8)
                    }

                    Spacer().frame(height: 24 * scale)

                    Button(action: onBack) {
                        Text("¿Ya tienes cuenta? ")
                            .font(ChapaFont.medium(14 * scale))
                            .foregroundColor(p.text)
                        + Text("Inicia sesión")
                            .font(ChapaFont.bold(14 * scale))
                            .foregroundColor(p.accent)
                    }

                    Spacer().frame(height: 32)

                    // --- SWITCH DE TEMA ---
                    Button {
                        isDark.toggle()
                        Session.shared.themeMode = isDark ? 2 : 1
                    } label: {
                        Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isDark ? .yellow : ChapaTheme.purplePrimary)
                            .frame(width: 44, height: 44)
                            .background(p.panel.opacity(0.5))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 24)
            }

            // --- LOADER OVERLAY ---
            if isLoading {
                (isDark ? Color.black : Color.white).opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(ChapaTheme.purplePrimary)
                    Text("Creando cuenta...")
                        .font(ChapaFont.medium(16))
                        .foregroundColor(p.text)
                }
            }
        }
        .toast($toastMessage)
        .navigationBarBackButtonHidden(true)
    }

    private func doRegister() {
        if name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty {
            toastMessage = "Completa todos los campos"
            return
        }
        if password != confirmPassword {
            toastMessage = "Las contraseñas no coinciden"
            return
        }
        isLoading = true
        Task {
            do {
                let response = try await AuthService.register(nombres: name, correo: email, telefono: phone, clave: password)
                await MainActor.run {
                    isLoading = false
                    if response.code == "200", let user = response.user {
                        toastMessage = "Cuenta creada correctamente"
                        AuthService.persistSession(user: user, isGoogle: false)
                        onRegisterSuccess()
                    } else {
                        toastMessage = "Error al registrarse. Verifica tus datos."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    toastMessage = "Error al registrarse. Verifica tus datos."
                }
            }
        }
    }
}
