import SwiftUI

@main
struct ChapaPasajeroApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Rutas de auth (espejo de Screen en AppNavigation.kt; las rutas de viaje
// llegan en fases 3-4).
enum AuthRoute: Hashable {
    case register
    case forgotPassword
    case resetPassword(email: String)
}

// Equivalente de SplashActivity + ruta "splash" de AppNavigation:
// decide Login u Home según la sesión. (La reanudación de viaje activo
// contra el servidor se agrega en Fase 4.)
struct RootView: View {
    @State private var showSplash = true
    @State private var isLogin = Session.shared.isLogin
    @State private var authPath = NavigationPath()

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
            } else if isLogin {
                homeFlow
            } else {
                authFlow
            }
        }
        .onAppear {
            AppRemoteConfig.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }

    private var homeFlow: some View {
        HomeView(onLogout: {
            Session.shared.logout()
            authPath = NavigationPath()
            isLogin = false
        })
    }

    private var authFlow: some View {
        NavigationStack(path: $authPath) {
            LoginView(
                onLoginSuccess: { isLogin = true },
                onNavigateToRegister: { authPath.append(AuthRoute.register) },
                onNavigateToForgotPassword: { authPath.append(AuthRoute.forgotPassword) }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .register:
                    RegisterView(
                        onRegisterSuccess: { isLogin = true },
                        onBack: { authPath.removeLast() }
                    )
                case .forgotPassword:
                    ForgotPasswordView(
                        onBack: { authPath.removeLast() },
                        onCodeSent: { email in
                            authPath.append(AuthRoute.resetPassword(email: email))
                        }
                    )
                case .resetPassword(let email):
                    ResetPasswordView(
                        email: email,
                        onBack: { authPath.removeLast() },
                        onResetSuccess: { authPath = NavigationPath() }
                    )
                }
            }
        }
    }
}
