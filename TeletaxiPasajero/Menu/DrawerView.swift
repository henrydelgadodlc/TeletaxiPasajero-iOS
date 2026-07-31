import SwiftUI

// Destinos del menú lateral (onNavigate de MainDrawerContent)
enum DrawerDestination: Identifiable {
    case places, recommended, history, support, editProfile
    var id: Int {
        switch self {
        case .places: return 1
        case .recommended: return 2
        case .history: return 3
        case .support: return 4
        case .editProfile: return 5
        }
    }
}

// Puerto de MainDrawerContent.kt: header de perfil, tips, ítems de menú,
// switch de modo oscuro, banners destacados y footer de versión.
struct DrawerView: View {
    let isDarkMode: Bool
    let onNavigate: (DrawerDestination) -> Void
    let onShare: () -> Void
    let onLogout: () -> Void
    let onThemeToggle: (Bool) -> Void
    let onClose: () -> Void

    @State private var featured: [RecommendedPlace] = []
    @State private var tipIndex = 0

    private let tips = [
        "Revisa tus pertenencias antes de bajar del taxi.",
        "Nuestros conductores pasan por un estricto proceso.",
        "Comparte tu viaje para mayor seguridad de tus contactos.",
        "Soporte 24/7 disponible para ayudarte siempre.",
        "Tu calificación nos ayuda a mejorar el servicio."
    ]

    private var bg: Color { isDarkMode ? ChapaTheme.darkBg : ChapaTheme.surfaceLight }
    private var surface: Color { isDarkMode ? ChapaTheme.cardBg : .white }
    private var textMain: Color { isDarkMode ? ChapaTheme.textMain : ChapaTheme.surfaceDeep }
    private var textMuted: Color { isDarkMode ? ChapaTheme.textMuted : ChapaTheme.slate }
    private var border: Color { isDarkMode ? Color(hex: 0x4AA13D, alpha: 0.28) : ChapaTheme.borderLight }
    private var textDim: Color { isDarkMode ? ChapaTheme.textDim : Color(hex: 0x94A3B8) }

    var body: some View {
        GeometryReader { geo in
            let menuWidth = geo.size.width - 28

            HStack(spacing: 0) {
                // Panel del menú
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            drawerHeader
                            tipsCard
                                .padding(.horizontal, 16)
                                .padding(.top, 10)

                            VStack(spacing: 0) {
                                menuItem(icon: "star.fill", title: "Lugares Favoritos") { onNavigate(.places) }
                                menuItem(icon: "flag.fill", title: "Recomendados") { onNavigate(.recommended) }
                                menuItem(icon: "clock.arrow.circlepath", title: "Historial de Viajes") { onNavigate(.history) }
                                menuItem(icon: "square.and.arrow.up", title: "Compartir App") { onShare() }
                                menuItem(icon: "envelope.fill", title: "Soporte") { onNavigate(.support) }
                                themeSwitch
                                menuItem(icon: "rectangle.portrait.and.arrow.right", title: "Cerrar Sesión", destructive: true) { onLogout() }
                            }
                            .padding(.top, 8)
                        }
                    }
                    drawerFooter
                }
                .frame(width: menuWidth)
                .background(bg)
                .clipShape(RoundedCorners(radius: 24, corners: [.topRight, .bottomRight]))

                // Pestaña lateral para cerrar
                VStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 80)
                            .background((isDarkMode ? ChapaTheme.purpleLight : ChapaTheme.purplePrimary).opacity(0.9))
                            .clipShape(RoundedCorners(radius: 16, corners: [.topRight, .bottomRight]))
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            Task { featured = (try? await MenuAPI.featuredPlaces()) ?? [] }
        }
        .onReceive(Timer.publish(every: 6, on: .main, in: .common).autoconnect()) { _ in
            tipIndex = (tipIndex + 1) % tips.count
        }
    }

    private var drawerHeader: some View {
        Button { onNavigate(.editProfile) } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    let foto = Session.shared.savePhoto
                    let url = foto.hasPrefix("http") ? foto : Config.imageURL + foto
                    Group {
                        if !foto.isEmpty, let u = URL(string: url) {
                            AsyncImage(url: u) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill").resizable().foregroundColor(textMuted)
                            }
                        } else {
                            Image(systemName: "person.circle.fill").resizable().foregroundColor(textMuted)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ChapaTheme.purplePrimary, lineWidth: 1.5))

                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(ChapaTheme.purplePrimary)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(Session.shared.nameUser.isEmpty ? "Usuario" : Session.shared.nameUser)
                        .font(ChapaFont.bold(17))
                        .foregroundColor(textMain)
                        .lineLimit(1)
                    Text(Session.shared.phoneUser.isEmpty ? "Sin número" : Session.shared.phoneUser)
                        .font(ChapaFont.medium(12))
                        .foregroundColor(textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(textMuted)
            }
            .padding(10)
            .background(surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var tipsCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "info")
                .font(.system(size: 12))
                .foregroundColor(ChapaTheme.purpleLight)
                .frame(width: 28, height: 28)
                .background(ChapaTheme.purplePrimary.opacity(0.15))
                .clipShape(Circle())
            Text(tips[tipIndex])
                .font(ChapaFont.medium(10.5))
                .foregroundColor(textMain)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
        .animation(.easeInOut, value: tipIndex)
    }

    private func menuItem(icon: String, title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(destructive ? .red : ChapaTheme.purpleLight)
                    .frame(width: 36, height: 36)
                    .background((destructive ? Color.red : ChapaTheme.purplePrimary).opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke((destructive ? Color.red : ChapaTheme.purplePrimary).opacity(0.2), lineWidth: 1))
                Text(title)
                    .font(ChapaFont.medium(15))
                    .foregroundColor(destructive ? .red.opacity(0.9) : textMain)
                Spacer()
                if !destructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(textDim)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private var themeSwitch: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.fill")
                .font(.system(size: 15))
                .foregroundColor(ChapaTheme.purpleLight)
                .frame(width: 36, height: 36)
                .background(ChapaTheme.purplePrimary.opacity(0.1))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
            Text("Modo Oscuro")
                .font(ChapaFont.medium(15))
                .foregroundColor(textMain)
            Spacer()
            Toggle("", isOn: Binding(get: { isDarkMode }, set: { onThemeToggle($0) }))
                .labelsHidden()
                .tint(ChapaTheme.purplePrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }

    private var drawerFooter: some View {
        VStack(spacing: 10) {
            if let banner = featured.first {
                Button { onNavigate(.recommended) } label: {
                    AsyncImage(url: URL(string: (banner.banner_url?.isEmpty == false ? banner.banner_url : banner.logo_url) ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        surface
                    }
                    .frame(height: 105)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ChapaTheme.purpleLight)
                VStack(alignment: .leading, spacing: 0) {
                    Text("HDev © \(Calendar.current.component(.year, from: Date()))")
                        .font(ChapaFont.medium(9))
                        .foregroundColor(textMuted)
                    Text("Versión 1.0.0 (iOS)")
                        .font(ChapaFont.medium(8))
                        .foregroundColor(textDim)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(surface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        }
        .padding(12)
    }
}
