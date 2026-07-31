import SwiftUI

// Paleta de TemporalScreen.kt (getTemporalColors)
struct TemporalColors {
    let isDark: Bool
    var bg: Color { isDark ? ChapaTheme.darkBg : ChapaTheme.surfaceLight }
    var panel: Color { isDark ? ChapaTheme.cardBg : .white }
    var surface: Color { isDark ? ChapaTheme.mapBlock : Color(hex: 0xF3F4FB) }
    var border: Color { Color(hex: 0x4AA13D, alpha: isDark ? 0.157 : 0.082) }
    var purple: Color { ChapaTheme.purplePrimary }
    var purpleLight: Color { isDark ? ChapaTheme.purpleLight : Color(hex: 0x6D28D9) }
    var textMain: Color { isDark ? ChapaTheme.textMain : Color(hex: 0x111827) }
    var textMuted: Color { isDark ? ChapaTheme.textMuted : Color(hex: 0x6B7280) }
    var greenOnline: Color { isDark ? ChapaTheme.green : Color(hex: 0x16A34A) }
}

// Puerto 1:1 de TemporalScreen.kt
struct TemporalView: View {
    let onCancelled: () -> Void
    let onAccepted: () -> Void

    @StateObject private var vm = TemporalViewModel()
    @State private var showCancelDialog = false

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: TemporalColors { TemporalColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.bg.ignoresSafeArea()

            if vm.offers.isEmpty {
                searchingView
            } else {
                offersView
            }

            if let offer = vm.selectedOffer {
                tripSummaryModal(offer)
            }

            if vm.showTimeout {
                timeoutModal
            }

            if showCancelDialog {
                CancelReasonDialog(
                    isDark: isDark,
                    motivos: MOTIVOS_CANCELACION_ESPERA,
                    onConfirm: { motivo in
                        showCancelDialog = false
                        vm.cancel(motivo: motivo)
                    },
                    onDismiss: { showCancelDialog = false }
                )
            }
        }
        .toast($vm.toastMessage)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: vm.accepted) { if $0 { onAccepted() } }
        .onChange(of: vm.cancelled) { if $0 { onCancelled() } }
    }

    // --- HEADER (ScreenHeader) ---
    private var header: some View {
        HStack {
            Button { showCancelDialog = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15))
                    .foregroundColor(c.textMain)
                    .frame(width: 36, height: 36)
                    .background(c.textMain.opacity(0.07))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(c.textMain.opacity(0.1), lineWidth: 1))
            }
            Spacer()
            Text("Teletaxi")
                .font(ChapaFont.bold(18))
                .foregroundColor(c.purpleLight)
            Spacer()
            Spacer().frame(width: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // --- BUSCANDO (SearchingView) ---
    private var searchingView: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 2) {
                Text("Buscando conductor")
                    .font(ChapaFont.bold(24))
                    .foregroundColor(c.textMain)
                Text("¡Conductores encontrados!")
                    .font(ChapaFont.medium(14))
                    .foregroundColor(c.purpleLight)
            }
            .padding(.vertical, 8)

            VStack(spacing: 3) {
                Text(vm.timeLeft)
                    .font(ChapaFont.bold(34))
                    .foregroundColor(c.purpleLight)
                Text("Tiempo estimado")
                    .font(ChapaFont.medium(11))
                    .foregroundColor(c.textMuted)
            }
            .padding(.vertical, 12)

            ZStack(alignment: .bottom) {
                SkylineGraphic(color: c.purple)
                    .opacity(isDark ? 0.18 : 0.08)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                VStack(spacing: 0) {
                    RadarAnimation(colors: c)
                        .frame(maxHeight: .infinity)
                    statsPanel
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // Panel de stats (BottomPanel)
    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                statCard(icon: "car.fill", label: "Conductores cerca", value: "\(vm.notifiedCount)")
                statCard(icon: "map.fill", label: "Alcance", value: "\(Int(vm.radiusKm)) km")
            }
            Text(vm.notifiedCount > 0 ? "Hay conductores cerca de tu ubicación." : "Ampliando radio de búsqueda para encontrarte un taxi.")
                .font(ChapaFont.medium(12))
                .foregroundColor(c.textMuted)

            Button { showCancelDialog = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark").font(.system(size: 15))
                    Text("Cancelar solicitud").font(ChapaFont.bold(15))
                }
                .foregroundColor(c.purpleLight)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(c.purple.opacity(0.08))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(c.purple, lineWidth: 1.5))
            }
        }
        .padding(18)
        .background(c.panel)
        .clipShape(RoundedCorners(radius: 28, corners: [.topLeft, .topRight]))
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(c.purpleLight)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(ChapaFont.medium(10)).foregroundColor(c.textMuted)
                Text(value).font(ChapaFont.bold(20)).foregroundColor(c.textMain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(c.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.border, lineWidth: 1))
    }

    // --- OFERTAS (OffersReceivedView) ---
    private var offersView: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ofertas Recibidas")
                            .font(ChapaFont.bold(24))
                            .foregroundColor(c.textMain)
                        Text("Selecciona la mejor propuesta")
                            .font(ChapaFont.medium(14))
                            .foregroundColor(c.textMuted)
                            .padding(.bottom, 20)

                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(c.textMain)
                                Text(vm.timeLeft)
                                    .font(ChapaFont.bold(32))
                                    .foregroundColor(c.purpleLight)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(c.textMain.opacity(0.03))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(c.textMain.opacity(0.08), lineWidth: 1))
                            Spacer()
                            Image(systemName: "car.side.fill")
                                .font(.system(size: 44))
                                .foregroundColor(c.textMain.opacity(isDark ? 0.4 : 0.15))
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 100)
                        .background(c.panel)
                        .cornerRadius(24)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.border, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)

                    ForEach(vm.offers) { offer in
                        offerCard(offer)
                            .padding(.horizontal, 20)
                    }

                    securityBanner
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }

            Button { showCancelDialog = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle").font(.system(size: 18))
                    Text("Cancelar solicitud").font(ChapaFont.bold(15))
                }
                .foregroundColor(c.purpleLight)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.purple.opacity(0.3), lineWidth: 1))
            }
            .padding(20)
        }
    }

    // Tarjeta de oferta (OfferItem)
    private func offerCard(_ offer: Temporal) -> some View {
        let promoDiscount = Double(Session.shared.promoDiscount)
        return Button { vm.selectedOffer = offer } label: {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        driverPhoto(offer.foto, size: 52)
                            .overlay(Circle().stroke(c.purple, lineWidth: 1.5))
                        Circle()
                            .fill(c.greenOnline)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(c.surface, lineWidth: 1.5))
                    }
                    Text("2 min aprox.")
                        .font(ChapaFont.bold(10))
                        .foregroundColor(c.purpleLight)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(offer.conductor ?? "Conductor")
                        .font(ChapaFont.bold(15))
                        .foregroundColor(c.textMain)
                        .lineLimit(1)
                    Text("\(offer.marca ?? "—") · \(offer.color ?? "—")")
                        .font(ChapaFont.medium(12))
                        .foregroundColor(c.textMuted)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let u = offer.unidad, !u.isEmpty {
                            Text("Unidad \(u)")
                                .font(ChapaFont.bold(11))
                                .foregroundColor(c.purpleLight)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(c.purple.opacity(0.15))
                                .cornerRadius(10)
                        }
                        Text(offer.placa ?? "—")
                            .font(ChapaFont.bold(11))
                            .foregroundColor(c.purpleLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(c.purple.opacity(0.15))
                            .cornerRadius(10)
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: 0xFFC107))
                            Text("\(offer.valoraciones ?? "—") · \(offer.viajes_realizados) viajes")
                                .font(ChapaFont.bold(11))
                                .foregroundColor(c.textMain)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    if promoDiscount > 0 {
                        Text("S/ \(String(format: "%.2f", offer.tarifa))")
                            .font(ChapaFont.medium(11))
                            .foregroundColor(c.textMuted)
                            .strikethrough()
                        Text("S/ \(String(format: "%.2f", max(offer.tarifa - promoDiscount, 0)))")
                            .font(ChapaFont.bold(19))
                            .foregroundColor(c.purpleLight)
                    } else {
                        Text("S/ \(HomeViewModel.formatPrice(offer.tarifa))")
                            .font(ChapaFont.bold(19))
                            .foregroundColor(c.purpleLight)
                    }
                    Text(promoDiscount > 0 ? "Con código promo" : "Tarifa estimada")
                        .font(ChapaFont.medium(9))
                        .foregroundColor(c.textMuted)

                    Text("Aceptar")
                        .font(ChapaFont.bold(13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(c.purple)
                        .cornerRadius(12)
                        .padding(.top, 6)
                }
            }
            .padding(12)
            .background(c.surface)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.border, lineWidth: 1.5))
        }
    }

    private func driverPhoto(_ url: String?, size: CGFloat) -> some View {
        Group {
            if let url, !url.isEmpty, let u = URL(string: url) {
                AsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(c.textMuted)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(c.textMuted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var securityBanner: some View {
        HStack(spacing: 16) {
            Image(systemName: "shield.fill")
                .font(.system(size: 18))
                .foregroundColor(c.purpleLight)
                .frame(width: 40, height: 40)
                .background(c.purple.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(c.purple.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text("Tu seguridad es nuestra prioridad")
                    .font(ChapaFont.bold(13))
                    .foregroundColor(c.textMain)
                Text("Todos los conductores pasan por un proceso de verificación.")
                    .font(ChapaFont.medium(11))
                    .foregroundColor(c.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c.panel.opacity(0.5))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(c.textMain.opacity(0.05), lineWidth: 1))
    }

    // --- MODAL RESUMEN (TripSummaryModal) ---
    private func tripSummaryModal(_ offer: Temporal) -> some View {
        let promoDiscount = Double(Session.shared.promoDiscount)
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { vm.selectedOffer = nil }

            VStack(spacing: 0) {
                Text("Resumen del viaje")
                    .font(ChapaFont.bold(19))
                    .foregroundColor(c.textMain)

                driverPhoto(offer.foto, size: 72)
                    .overlay(Circle().stroke(c.purpleLight, lineWidth: 2))
                    .padding(.top, 16)

                Text(offer.conductor ?? "Conductor")
                    .font(ChapaFont.bold(17))
                    .foregroundColor(c.textMain)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    summaryRow(icon: "car.fill", label: "Vehículo", value: "\(offer.marca ?? "—") (\(offer.color ?? "—"))")
                    if let u = offer.unidad, !u.isEmpty {
                        summaryRow(icon: "number.circle", label: "N° Unidad", value: u)
                    }
                    summaryRow(icon: "number", label: "Placa", value: offer.placa ?? "—")
                    if promoDiscount > 0 {
                        summaryRow(
                            icon: "banknote",
                            label: "Tarifa con código promocional",
                            value: "S/ \(String(format: "%.2f", max(offer.tarifa - promoDiscount, 0)))",
                            highlighted: true,
                            strikeValue: "S/ \(String(format: "%.2f", offer.tarifa))"
                        )
                    } else {
                        summaryRow(icon: "banknote", label: "Tarifa", value: "S/ \(HomeViewModel.formatPrice(offer.tarifa))", highlighted: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(c.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.border, lineWidth: 1))
                .padding(.top, 16)

                HStack(spacing: 10) {
                    Button { vm.selectedOffer = nil } label: {
                        Text("Cancelar")
                            .font(ChapaFont.medium(14))
                            .foregroundColor(c.textMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(c.textMuted.opacity(0.3), lineWidth: 1))
                    }
                    Button { vm.confirmOffer(offer) } label: {
                        Text("Confirmar")
                            .font(ChapaFont.bold(14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(c.purple)
                            .cornerRadius(14)
                    }
                }
                .padding(.top, 24)
            }
            .padding(20)
            .background(c.panel)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    private func summaryRow(icon: String, label: String, value: String, highlighted: Bool = false, strikeValue: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(highlighted ? c.purpleLight : c.textMuted)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(ChapaFont.medium(11)).foregroundColor(c.textMuted)
                HStack(spacing: 6) {
                    if let strikeValue {
                        Text(strikeValue)
                            .font(ChapaFont.medium(12))
                            .foregroundColor(c.textMuted)
                            .strikethrough()
                    }
                    Text(value)
                        .font(highlighted ? ChapaFont.bold(17) : ChapaFont.medium(14))
                        .foregroundColor(highlighted ? c.purpleLight : c.textMain)
                }
            }
        }
    }

    // --- MODAL TIMEOUT (TimeoutModal) ---
    private var timeoutModal: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28))
                    .foregroundColor(c.purpleLight)
                    .frame(width: 64, height: 64)
                    .background(c.purple.opacity(0.1))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(c.purple.opacity(0.2), lineWidth: 1))

                Text("¡Woow por ahora!")
                    .font(ChapaFont.bold(19))
                    .foregroundColor(c.textMain)
                    .padding(.top, 16)

                Text("Todos nuestros conductores están en carrera en este momento.\n\nVolvamos a intentar en unos minutos.")
                    .font(ChapaFont.medium(13))
                    .foregroundColor(c.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Button {
                    vm.showTimeout = false
                    vm.cancel(motivo: "Tiempo de espera agotado sin conductores")
                } label: {
                    Text("Entendido")
                        .font(ChapaFont.bold(15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(c.purple)
                        .cornerRadius(14)
                }
                .padding(.top, 24)
            }
            .padding(20)
            .background(c.panel)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.border, lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }
}

// Radar animado (RadarAnimation): arco giratorio + autos orbitando
struct RadarAnimation: View {
    let colors: TemporalColors
    @State private var rotation = 0.0
    @State private var pulse = false

    private let carAngles: [Double] = [30, 95, 155, 230, 300]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radarSize = size * 0.7
            let innerSize = radarSize * 0.9
            let orbitRadius = innerSize / 2
            let centerSize = radarSize * 0.35
            let carSize = radarSize * 0.15

            ZStack {
                Circle()
                    .fill(colors.purple.opacity(0.08))
                    .frame(width: radarSize * 1.15, height: radarSize * 1.15)

                Circle()
                    .stroke(colors.purple.opacity(0.18), lineWidth: 2)
                    .frame(width: innerSize, height: innerSize)

                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, colors.purpleLight, Color(hex: 0xC084FC)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: innerSize, height: innerSize)
                    .rotationEffect(.degrees(rotation))

                ForEach(Array(carAngles.enumerated()), id: \.offset) { _, angle in
                    let rad = (angle - 90) * .pi / 180
                    Image(systemName: "car.fill")
                        .font(.system(size: carSize * 0.5))
                        .foregroundColor(colors.purpleLight)
                        .frame(width: carSize, height: carSize)
                        .background(colors.isDark ? ChapaTheme.mapStreet : .white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(colors.border, lineWidth: 1))
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .offset(x: cos(rad) * orbitRadius, y: sin(rad) * orbitRadius)
                }

                ZStack {
                    Circle()
                        .fill(colors.isDark ? ChapaTheme.mapStreet : .white)
                        .frame(width: centerSize, height: centerSize)
                        .overlay(Circle().stroke(colors.border, lineWidth: 1.5))
                    Circle()
                        .fill(RadialGradient(colors: [colors.purpleLight, colors.purple], center: .center, startRadius: 0, endRadius: centerSize * 0.4))
                        .frame(width: centerSize * 0.8, height: centerSize * 0.8)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: centerSize * 0.3))
                        .foregroundColor(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
