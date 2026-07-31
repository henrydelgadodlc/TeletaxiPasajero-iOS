import SwiftUI

// Puerto 1:1 de ValorationScreen.kt + Container: resumen del viaje y calificación.
struct ValorationView: View {
    let data: ValorationData
    let onFinished: () -> Void

    @State private var rating = 5
    @State private var comment = ""
    @State private var isSending = false
    @State private var toastMessage: String?

    private var isDark: Bool { Session.shared.themeMode == 2 }

    private var bg: Color { isDark ? ChapaTheme.darkBg : Color(hex: 0xF8F9FE) }
    private var panel: Color { isDark ? ChapaTheme.cardBg : .white }
    private var surface: Color { isDark ? ChapaTheme.mapBlock : Color(hex: 0xF3F4F6) }
    private var border: Color { isDark ? Color(hex: 0x4AA13D, alpha: 0.157) : Color(hex: 0xE5E7EB) }
    private var textMain: Color { isDark ? ChapaTheme.textMain : Color(hex: 0x111827) }
    private var textMuted: Color { isDark ? ChapaTheme.textMuted : Color(hex: 0x6B7280) }

    private let quickComments = [
        "Buen servicio 👍", "Auto limpio ✨", "Llegó rápido ⏰",
        "Conductor amable 😊", "Manejo seguro 🚗", "Excelente ruta 📍"
    ]

    private var fareFormatted: String {
        Float(data.precio).map { String(format: "S/ %.2f", $0) } ?? "S/ \(data.precio)"
    }
    private var discountFormatted: String? {
        guard let monto = Float(data.descuento), monto > 0 else { return nil }
        return String(format: "−S/ %.2f", monto)
    }
    private var dateTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_PE")
        f.dateFormat = "d MMM. yyyy, hh:mm a"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header con degradado (modo oscuro) o blanco
                        VStack(spacing: 12) {
                            ZStack(alignment: .bottomTrailing) {
                                driverPhoto
                                    .overlay(Circle().stroke(ChapaTheme.purpleLight, lineWidth: 2))
                                Circle().fill(ChapaTheme.green)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(bg, lineWidth: 2))
                                    .offset(x: -4, y: -4)
                            }
                            VStack(spacing: 2) {
                                Text("¡Viaje con \(data.conductor)!")
                                    .font(ChapaFont.bold(20))
                                    .foregroundColor(isDark ? .white : textMain)
                                Text("Resumen del servicio")
                                    .font(ChapaFont.medium(14))
                                    .foregroundColor((isDark ? Color.white : textMain).opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(
                            Group {
                                if isDark {
                                    LinearGradient(colors: [ChapaTheme.purplePrimary.opacity(0.8), bg], startPoint: .top, endPoint: .bottom)
                                } else {
                                    Color.white
                                }
                            }
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            // Tarjeta de detalles
                            VStack(spacing: 8) {
                                detailRow("Total pagado", fareFormatted, isFare: true)
                                if let discountFormatted {
                                    divider
                                    detailRow("Descuento por código", discountFormatted)
                                }
                                divider
                                detailRow("Vehículo", "\(data.marca) (\(data.color))")
                                divider
                                detailRow("Placa", data.placa)
                                divider
                                detailRow("Método de pago", data.tipoPago.capitalized)
                                divider
                                detailRow("Fecha y hora", dateTime)
                                divider
                                detailRow("Origen", data.origen, multiline: true)
                                divider
                                detailRow("Destino", data.destino, multiline: true)
                            }
                            .padding(16)
                            .background(panel)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(border, lineWidth: 1))

                            Text("¿Cómo fue tu experiencia?")
                                .font(ChapaFont.bold(18))
                                .foregroundColor(textMain)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 28)

                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { i in
                                    Button { rating = i } label: {
                                        Image(systemName: i <= rating ? "star.fill" : "star")
                                            .font(.system(size: 38))
                                            .foregroundColor(i <= rating ? Color(hex: 0xFFC107) : textMuted)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)

                            TextField("", text: $comment, prompt: Text("Cuéntanos más sobre el servicio (opcional)").font(.system(size: 13)).foregroundColor(textMuted), axis: .vertical)
                                .font(ChapaFont.medium(14))
                                .foregroundColor(textMain)
                                .lineLimit(3, reservesSpace: true)
                                .padding(12)
                                .background(surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1))
                                .padding(.top, 16)

                            Text("Sugerencias rápidas")
                                .font(ChapaFont.medium(12))
                                .foregroundColor(textMuted)
                                .padding(.top, 12)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(quickComments, id: \.self) { quick in
                                        Button {
                                            if comment.isEmpty { comment = quick }
                                            else if !comment.contains(quick) { comment = "\(comment), \(quick)" }
                                        } label: {
                                            Text(quick)
                                                .font(ChapaFont.medium(12))
                                                .foregroundColor(ChapaTheme.purpleLight)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(ChapaTheme.purplePrimary.opacity(0.1))
                                                .cornerRadius(12)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChapaTheme.purplePrimary.opacity(0.2), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 30)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Button(action: finish) {
                    Group {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Listo").font(ChapaFont.bold(16)).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ChapaTheme.purplePrimary)
                    .cornerRadius(16)
                }
                .disabled(isSending)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .toast($toastMessage)
        .interactiveDismissDisabled(true)
    }

    private var divider: some View {
        Rectangle().fill(textMuted.opacity(0.1)).frame(height: 1).padding(.vertical, 4)
    }

    private func detailRow(_ label: String, _ value: String, isFare: Bool = false, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center) {
            Text(label)
                .font(ChapaFont.medium(13))
                .foregroundColor(textMuted)
            Spacer()
            Text(value)
                .font(isFare ? ChapaFont.bold(18) : ChapaFont.medium(13))
                .foregroundColor(isFare ? ChapaTheme.purpleLight : textMain)
                .multilineTextAlignment(.trailing)
                .lineLimit(multiline ? 3 : 1)
        }
    }

    private var driverPhoto: some View {
        let urlString: String? = {
            guard let foto = data.foto, !foto.isEmpty else { return nil }
            return foto.hasPrefix("http") ? foto : Config.imageURL + foto
        }()
        return Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill").resizable().foregroundColor(textMuted)
                }
            } else {
                Image(systemName: "person.circle.fill").resizable().foregroundColor(textMuted)
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(Circle())
    }

    // Igual que el Container Android: passengerstate → opinion → clearTripStates
    private func finish() {
        isSending = true
        Task {
            let finishCode = (try? await TravelAPI.finishTravel())?.code ?? 400
            if finishCode == 200 || finishCode == 400 {
                _ = try? await TravelAPI.opinion(valoracion: Float(rating), comentario: comment)
                toastMessage = "Gracias por tu opinión"
                Session.shared.clearTripStates()
                try? await Task.sleep(nanoseconds: 600_000_000)
                onFinished()
            } else {
                isSending = false
                toastMessage = "Error al finalizar viaje"
            }
        }
    }
}
