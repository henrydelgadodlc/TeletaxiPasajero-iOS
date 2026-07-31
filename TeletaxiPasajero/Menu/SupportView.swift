import SwiftUI

// Puerto de SupportScreen.kt
struct SupportView: View {
    let onBack: () -> Void

    private let email = "teletaxidev@gmail.com"
    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MenuHeader(title: "Soporte", c: c, onBack: onBack)

                ScrollView {
                    VStack(spacing: 0) {
                        Image(systemName: "headset.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(ChapaTheme.purplePrimary)
                            .frame(width: 84, height: 84)
                            .background(ChapaTheme.purplePrimary.opacity(0.12))
                            .clipShape(Circle())
                            .padding(.top, 24)

                        Text("¿Necesitas ayuda?")
                            .font(ChapaFont.bold(22))
                            .foregroundColor(c.textMain)
                            .padding(.top, 16)

                        Text("Estamos para apoyarte. Si tienes dudas, un inconveniente con un viaje o tu cuenta, escríbenos y te responderemos lo antes posible.")
                            .font(ChapaFont.medium(13.5))
                            .foregroundColor(c.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)

                        Text("Nuestro canal")
                            .font(ChapaFont.bold(12))
                            .foregroundColor(c.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 28)
                            .padding(.bottom, 10)

                        Button {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(ChapaTheme.purplePrimary)
                                    .frame(width: 46, height: 46)
                                    .background(ChapaTheme.purplePrimary.opacity(0.1))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Correo electrónico")
                                        .font(ChapaFont.medium(12))
                                        .foregroundColor(c.textMuted)
                                    Text(email)
                                        .font(ChapaFont.bold(14.5))
                                        .foregroundColor(c.textMain)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15))
                                    .foregroundColor(c.textMuted)
                            }
                            .padding(14)
                            .background(c.cardBg)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
                        }

                        Text("Teletaxi — Estamos contigo en cada viaje.")
                            .font(ChapaFont.medium(11))
                            .foregroundColor(c.textMuted.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 28)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
