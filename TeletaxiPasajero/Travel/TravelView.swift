import SwiftUI
import CoreLocation

// Puerto 1:1 de TravelScreen.kt: seguimiento del viaje activo.
struct TravelView: View {
    let onExitToHome: () -> Void
    let onFinished: (ValorationData) -> Void

    @StateObject private var vm = TravelViewModel()
    @State private var mapProxy = MapProxy()
    @State private var showFinishDialog = false
    @State private var showCancelDialog = false
    @State private var showChat = false
    @State private var showCall = false

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }
    private var isActive: Bool { vm.info?.estado == "aceptado" || vm.info?.estado == "abordo" }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer().frame(width: 40)
                    Spacer()
                    Text("Seguimiento de viaje")
                        .font(ChapaFont.bold(18))
                        .foregroundColor(c.textMain)
                    Spacer()
                    Button { vm.shareTravel() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17))
                            .foregroundColor(c.purplePrimary)
                            .frame(width: 40, height: 40)
                            .background(c.cardBg)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Mapa
                ZStack {
                    TravelMapView(
                        proxy: mapProxy,
                        origin: vm.originLocation,
                        destiny: vm.destinyLocation,
                        driver: vm.driverLocation,
                        driverRotation: vm.driverRotation,
                        estado: vm.info?.estado,
                        isDark: isDark,
                        onUserGesture: { vm.isFollowingDriver = false }
                    )
                    .clipShape(RoundedCorners(radius: 24, corners: [.topLeft, .topRight]))

                    if isActive {
                        VStack(spacing: 12) {
                            travelMapButton(icon: "phone.fill") { startVoiceCall() }
                            ZStack(alignment: .topTrailing) {
                                travelMapButton(icon: "message.fill") {
                                    vm.hasNewMessage = false
                                    showChat = true
                                }
                                if vm.hasNewMessage {
                                    Circle().fill(.red)
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().stroke(c.cardBg, lineWidth: 1.5))
                                }
                            }
                            travelMapButton(icon: "location.fill", active: vm.isFollowingDriver) {
                                vm.isFollowingDriver = true
                                followCamera()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 16)
                        .padding(.bottom, 48)
                    }
                }
                .frame(maxHeight: .infinity)

                bottomPanel
                    .offset(y: -24)
                    .padding(.bottom, -24)
            }

            if showCancelDialog {
                let esperandoAbordar = vm.info?.estado == "aceptado" && vm.esperaSegundos != nil
                CancelReasonDialog(
                    isDark: isDark,
                    motivos: esperandoAbordar ? MOTIVOS_CANCELACION_LLEGADA : MOTIVOS_CANCELACION_VIAJE,
                    onConfirm: { motivo in
                        showCancelDialog = false
                        vm.cancelWithReason(motivo)
                    },
                    onDismiss: { showCancelDialog = false }
                )
            }

            if vm.isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().scaleEffect(1.3).tint(c.purplePrimary)
            }
        }
        .toast($vm.toastMessage)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: vm.driverLocation.latitude) { _ in
            if vm.isFollowingDriver { followCamera() }
        }
        .onChange(of: vm.exitToHome) { if $0 { onExitToHome() } }
        .onChange(of: vm.finishedData) { data in
            if let data { onFinished(data) }
        }
        .sheet(item: Binding(
            get: { vm.shareMessage.map { ShareText(text: $0) } },
            set: { vm.shareMessage = $0?.text }
        )) { share in
            ActivityView(text: share.text)
        }
        .background(
            EmptyView().fullScreenCover(isPresented: $showChat) {
                ChatView(
                    requestId: Session.shared.currentRequest,
                    driverName: vm.info?.conductor ?? "Conductor",
                    onBack: { showChat = false }
                )
            }
        )
        .background(
            EmptyView().fullScreenCover(isPresented: $showCall) {
                CallView(
                    vm: CallViewModel(
                        requestId: Session.shared.currentRequest,
                        peerName: vm.info?.conductor ?? "Conductor",
                        mode: .outgoing
                    ),
                    onClose: { showCall = false }
                )
            }
        )
        .background(
            EmptyView().fullScreenCover(item: $vm.incomingCall) { info in
                CallView(
                    vm: CallViewModel(
                        requestId: Session.shared.currentRequest,
                        peerName: info.fromName.isEmpty ? (vm.info?.conductor ?? "Conductor") : info.fromName,
                        mode: .incoming,
                        callId: info.callId
                    ),
                    onClose: { vm.incomingCall = nil }
                )
            }
        )
        .alert("Finalizar viaje", isPresented: $showFinishDialog) {
            Button("Sí, finalizar") { vm.finishTravel() }
            Button("No, continuar", role: .cancel) {}
        } message: {
            Text("¿Has llegado a tu destino?")
        }
    }

    private func followCamera() {
        guard vm.driverLocation.latitude != 0 else { return }
        let target = vm.info?.estado == "aceptado" ? vm.originLocation : vm.destinyLocation
        if target.latitude != 0 {
            mapProxy.fit(points: [vm.driverLocation, target])
        } else {
            mapProxy.animate(to: vm.driverLocation)
        }
    }

    // Llamada de voz in-app (WebRTC) hacia el conductor. Si no hay una solicitud
    // activa válida, cae al marcador telefónico nativo como respaldo.
    private func startVoiceCall() {
        if Session.shared.currentRequest > 0 {
            showCall = true
        } else {
            callDriver()
        }
    }

    private func callDriver() {
        let phone = vm.info?.telefono ?? ""
        guard !phone.isEmpty, let url = URL(string: "tel://\(phone)") else {
            vm.toastMessage = "Teléfono del conductor no disponible"
            return
        }
        UIApplication.shared.open(url)
    }

    private func travelMapButton(icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(active ? c.purplePrimary : c.purpleLight)
                .frame(width: 44, height: 44)
                .background(c.cardBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))
        }
    }

    // --- PANEL INFERIOR (TravelBottomPanel) ---
    private var bottomPanel: some View {
        VStack(spacing: 10) {
            // Estado + precio + código de seguridad
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 8) {
                    Text(vm.info?.estado == "aceptado" ? "En camino" : (vm.info?.estado == "abordo" ? "En ruta" : "..."))
                        .font(ChapaFont.bold(10))
                        .foregroundColor(c.purplePrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(c.purplePrimary.opacity(0.1))
                        .cornerRadius(6)

                    let montoPromo = vm.info?.monto_descuento_codigo ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if montoPromo > 0 {
                                Text("S/ \(String(format: "%.2f", vm.info?.precio ?? 0))")
                                    .font(ChapaFont.medium(11))
                                    .foregroundColor(c.textMuted)
                                    .strikethrough()
                            }
                            Text("S/ \(String(format: "%.2f", vm.info?.tarifa_pasajero ?? vm.info?.precio ?? 0))")
                                .font(ChapaFont.bold(16))
                                .foregroundColor(c.purplePrimary)
                        }
                        if montoPromo > 0 {
                            Text("PROMO −S/ \(String(format: "%.2f", montoPromo))")
                                .font(ChapaFont.bold(9))
                                .foregroundColor(c.purplePrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(c.purplePrimary.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                }
                Spacer()

                let codigo = (vm.info?.codigo_verificacion ?? "").trimmingCharacters(in: .whitespaces)
                if vm.info?.estado == "aceptado" && !codigo.isEmpty && codigo != "0000" {
                    HStack(spacing: 6) {
                        Image(systemName: "number")
                            .font(.system(size: 13))
                            .foregroundColor(c.purplePrimary)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Código de seguridad")
                                .font(ChapaFont.medium(9))
                                .foregroundColor(c.textMuted)
                            Text(codigo)
                                .font(ChapaFont.bold(16))
                                .foregroundColor(c.purplePrimary)
                                .kerning(3)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(c.textMuted)
                        Text(vm.info?.estado == "aceptado" ? "Llega pronto" : "En viaje")
                            .font(ChapaFont.medium(10))
                            .foregroundColor(c.textMuted)
                    }
                }
            }

            // Conductor + vehículo
            HStack(spacing: 10) {
                driverPhoto(vm.info?.foto, size: 40)
                    .overlay(Circle().stroke(c.purplePrimary, lineWidth: 1))
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.info?.conductor ?? "Cargando...")
                        .font(ChapaFont.bold(14))
                        .foregroundColor(c.textMain)
                        .lineLimit(1)
                    Text("\(vm.info?.marca ?? "—") • \(vm.info?.color ?? "—")")
                        .font(ChapaFont.medium(11))
                        .foregroundColor(c.textMuted)
                    if let u = vm.info?.unidad, !u.isEmpty {
                        Text("Unidad \(u)")
                            .font(ChapaFont.bold(11))
                            .foregroundColor(ChapaTheme.purplePrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(vm.info?.placa ?? "—")
                    .font(ChapaFont.bold(12))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: 0xFFD700))
                    .cornerRadius(4)
            }
            .padding(10)
            .background(c.surfaceDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple.opacity(0.3), lineWidth: 1))

            // Direcciones (multiruta: timeline de paradas, la última es el destino)
            VStack(alignment: .leading, spacing: 4) {
                locationRow(icon: "smallcircle.filled.circle", color: ChapaTheme.purpleDeep, text: vm.info?.direccion ?? "Origen")
                let paradas = vm.info?.paradas ?? []
                if paradas.isEmpty {
                    locationRow(icon: "mappin.circle.fill", color: Color(hex: 0xE91E8C), text: vm.info?.destino ?? "Destino")
                } else {
                    let actualOrden = paradas.first { $0.estado != "completada" }?.orden
                    ForEach(Array(paradas.enumerated()), id: \.offset) { _, stop in
                        let esFinal = stop.orden == paradas.last?.orden
                        let completada = stop.estado == "completada"
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: esFinal ? "mappin.circle.fill" : "smallcircle.filled.circle")
                                .font(.system(size: 13))
                                .foregroundColor(
                                    completada ? ChapaTheme.greenAlt
                                    : (stop.orden == actualOrden ? Color(hex: 0xE91E8C) : c.textMuted)
                                )
                            Text((esFinal ? "Destino: " : "Parada \(stop.orden): ") + (stop.direccion ?? ""))
                                .font(stop.orden == actualOrden ? ChapaFont.bold(12) : ChapaFont.medium(12))
                                .foregroundColor(completada ? c.textMuted : c.textMain)
                                .strikethrough(completada)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if completada {
                                Text("✓").font(ChapaFont.bold(12)).foregroundColor(ChapaTheme.greenAlt)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                let referencia = (vm.info?.referencia ?? "").trimmingCharacters(in: .whitespaces)
                if !referencia.isEmpty {
                    locationRow(icon: "info.circle", color: c.textMuted, text: referencia, muted: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(c.surfaceDark)
            .cornerRadius(12)

            // Conductor llegó: cuenta regresiva de 4 min para abordar
            if vm.info?.estado == "aceptado", let espera = vm.esperaSegundos {
                PassengerWaitingCard(esperaSegundos: espera, c: c)
            }

            // Botones
            HStack(spacing: 10) {
                if vm.info?.estado == "aceptado" {
                    Button { showCancelDialog = true } label: {
                        Text("Cancelar viaje")
                            .font(ChapaFont.bold(14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(ChapaTheme.red)
                            .cornerRadius(12)
                    }
                } else {
                    Button { showFinishDialog = true } label: {
                        Text("Finalizar viaje")
                            .font(ChapaFont.bold(14))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(c.purplePrimary)
                            .cornerRadius(12)
                    }
                }
                Button { showCancelDialog = true } label: {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 17))
                        .foregroundColor(ChapaTheme.red)
                        .frame(width: 44, height: 44)
                        .background(ChapaTheme.red.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChapaTheme.red.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(12)
        .background(c.cardBg)
        .clipShape(RoundedCorners(radius: 24, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.3), radius: 10, y: -2)
    }

    private func locationRow(icon: String, color: Color, text: String, muted: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(text)
                .font(ChapaFont.medium(muted ? 11 : 12))
                .foregroundColor(muted ? c.textMuted : c.textMain)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }

    private func driverPhoto(_ foto: String?, size: CGFloat) -> some View {
        let urlString: String? = {
            guard let foto, !foto.isEmpty else { return nil }
            return foto.hasPrefix("http") ? foto : Config.imageURL + foto
        }()
        return Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill").resizable().foregroundColor(c.textMuted)
                }
            } else {
                Image(systemName: "person.circle.fill").resizable().foregroundColor(c.textMuted)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct ShareText: Identifiable {
    let id = UUID()
    let text: String
}

// Tarjeta de espera para abordar (PassengerWaitingCard): 4 min de margen
private let passengerWaitTotalSeconds = 4 * 60

struct PassengerWaitingCard: View {
    let esperaSegundos: Int
    let c: HomeColors

    @State private var elapsed = 0

    private var remaining: Int { max(passengerWaitTotalSeconds - elapsed, 0) }
    private var expired: Bool { remaining <= 0 }
    private let alertColor = ChapaTheme.red

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundColor(expired ? alertColor : c.purplePrimary)
            VStack(alignment: .leading, spacing: 1) {
                Text(expired ? "Tiempo de espera agotado" : "¡Tu conductor llegó!")
                    .font(ChapaFont.bold(13))
                    .foregroundColor(expired ? alertColor : c.textMain)
                Text(expired
                    ? "El conductor puede cancelar el servicio. Aborda o comunícate con él."
                    : "Acércate al punto de recojo antes de que termine el tiempo.")
                    .font(ChapaFont.medium(10.5))
                    .foregroundColor(c.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(ChapaFont.bold(22))
                .foregroundColor(expired ? alertColor : c.purplePrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background((expired ? alertColor : c.purplePrimary).opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke((expired ? alertColor : c.purplePrimary).opacity(expired ? 0.5 : 0.35), lineWidth: 1))
        .onAppear { elapsed = esperaSegundos }
        .onChange(of: esperaSegundos) { elapsed = $0 }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            elapsed += 1
        }
    }
}
