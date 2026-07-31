import SwiftUI

// Puerto 1:1 de LoginScreen.kt + LoginScreenContainer.kt
struct LoginView: View {
    let onLoginSuccess: () -> Void
    let onNavigateToRegister: () -> Void
    let onNavigateToForgotPassword: () -> Void

    @State private var isDark = Session.shared.themeMode == 2
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
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
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Bienvenido a")
                                .font(ChapaFont.bold(28 * scale))
                                .foregroundColor(p.text)
                            Text("Teletaxi")
                                .font(ChapaFont.bold(28 * scale))
                                .foregroundColor(p.accent)
                        }
                        Spacer()
                        Image(isDark ? "LogoChapa" : "LogoChapaLight")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80 * scale, height: 80 * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    Spacer().frame(height: 10 * scale)

                    Text("Viaja seguro, rápido y cómodo.")
                        .font(ChapaFont.medium(14 * scale))
                        .foregroundColor(p.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 160 * scale)

                    // --- FORMULARIO ---
                    ChapaTextField(value: $email, label: "Correo electrónico", icon: "envelope.fill", keyboard: .emailAddress, palette: p)
                    Spacer().frame(height: 12 * scale)
                    ChapaTextField(value: $password, label: "Contraseña", icon: "lock.fill", isPassword: true, palette: p)
                    Spacer().frame(height: 10 * scale)

                    HStack {
                        Button {
                            rememberMe.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20 * scale))
                                    .foregroundColor(rememberMe ? ChapaTheme.purplePrimary : p.border)
                                Text("Recordarme")
                                    .font(ChapaFont.medium(12 * scale))
                                    .foregroundColor(p.muted)
                            }
                        }
                        Spacer()
                        Button(action: onNavigateToForgotPassword) {
                            Text("¿Olvidaste tu contraseña?")
                                .font(ChapaFont.medium(12 * scale))
                                .foregroundColor(p.accent)
                        }
                    }

                    Spacer().frame(height: 24 * scale)

                    // --- BOTÓN LOGIN ---
                    Button(action: doLogin) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Iniciar sesión")
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

                    Spacer().frame(height: 16 * scale)

                    HStack {
                        Rectangle().fill(p.border).frame(height: 1)
                        Text("o")
                            .font(.system(size: 12 * scale))
                            .foregroundColor(p.text)
                            .padding(.horizontal, 12)
                        Rectangle().fill(p.border).frame(height: 1)
                    }

                    Spacer().frame(height: 16 * scale)

                    // --- GOOGLE BUTTON (se habilita en Fase 6) ---
                    Button {
                        toastMessage = "Google llegará pronto a iOS"
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 18 * scale))
                                .foregroundColor(p.text)
                            Text("Continuar con Google")
                                .font(ChapaFont.medium(14 * scale))
                                .foregroundColor(p.text)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50 * scale)
                        .background(p.panel)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                    }

                    Spacer().frame(height: 12 * scale)

                    Button(action: onNavigateToRegister) {
                        Text("¿No tienes cuenta? ")
                            .font(ChapaFont.medium(14 * scale))
                            .foregroundColor(p.text)
                        + Text("Regístrate")
                            .font(ChapaFont.bold(14 * scale))
                            .foregroundColor(p.accent)
                    }

                    Spacer().frame(height: 40 * scale)

                    // --- FOOTER ---
                    VStack(spacing: 2) {
                        Text("Al continuar, aceptas nuestros")
                            .font(ChapaFont.medium(10 * scale))
                            .foregroundColor(p.muted)
                        HStack(spacing: 0) {
                            Text("Términos").font(ChapaFont.bold(10 * scale)).foregroundColor(p.accent)
                            Text(" y ").font(.system(size: 10 * scale)).foregroundColor(p.muted)
                            Text("Privacidad").font(ChapaFont.bold(10 * scale)).foregroundColor(p.accent)
                        }
                    }

                    Spacer().frame(height: 16)

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
                    Text("Iniciando sesión...")
                        .font(ChapaFont.medium(16))
                        .foregroundColor(p.text)
                }
            }
        }
        .toast($toastMessage)
    }

    private func doLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            toastMessage = "Completa todos los campos"
            return
        }
        isLoading = true
        Task {
            do {
                let response = try await AuthService.login(correo: email, clave: password)
                await MainActor.run {
                    isLoading = false
                    if response.code == "200", let user = response.user {
                        AuthService.persistSession(user: user, isGoogle: false)
                        onLoginSuccess()
                    } else {
                        toastMessage = "Credenciales incorrectas"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    toastMessage = "Credenciales incorrectas"
                }
            }
        }
    }
}
