import Foundation
import CoreLocation
import SocketIO
import SwiftUI

// Puerto de TravelScreenContainer: polling cada 10s + socket en vivo.
@MainActor
final class TravelViewModel: ObservableObject {

    @Published var info: TravelInfo?
    @Published var originLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var destinyLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var driverLocation = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @Published var driverRotation: Double = 0
    @Published var hasNewMessage = false
    @Published var isFollowingDriver = true
    @Published var esperaSegundos: Int?
    @Published var isLoading = false
    @Published var toastMessage: String?
    @Published var shareMessage: String?
    @Published var finishedData: ValorationData?   // navega a valoración
    @Published var exitToHome = false              // cancelado (mío o del conductor)
    @Published var incomingCall: IncomingCallInfo? // llamada entrante del conductor

    private var callIncomingHandlerId: UUID?
    private var pollTimer: Timer?
    private var receivedSocketUpdate = false
    private var lastTravelStatus: String?
    private var cancelRequestedByMe = false
    private var handledDriverCancel = false
    private var requestId: Int { Session.shared.currentRequest }

    func start() {
        originLocation = CLLocationCoordinate2D(latitude: Session.shared.currentLat, longitude: Session.shared.currentLng)
        destinyLocation = CLLocationCoordinate2D(latitude: Session.shared.destinyLat, longitude: Session.shared.destinyLng)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        Task { await poll() }
        connectSocket()
        registerCallListener()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        let id = requestId
        if id != 0 { ChapaSocket.shared.leavePassengerRoom(id) }
        ChapaSocket.shared.socket?.off("position/\(id)")
        ChapaSocket.shared.socket?.off("chat/\(id)")
        unregisterCallListener()
    }

    // Escucha `call:incoming` mientras se ve el viaje: si el conductor llama al
    // pasajero, se abre la pantalla de llamada entrante (WebRTC, primer plano).
    // App cerrada/segundo plano requiere PushKit+CallKit+cert VoIP (credenciales)
    // → pendiente, fuera de este alcance.
    private func registerCallListener() {
        guard callIncomingHandlerId == nil, let socket = ChapaSocket.shared.socket else { return }
        callIncomingHandlerId = socket.on("call:incoming") { [weak self] data, _ in
            Task { @MainActor in
                guard let self, self.incomingCall == nil,
                      let o = data.first as? [String: Any] else { return }
                self.incomingCall = IncomingCallInfo(
                    callId: o["call_id"] as? String ?? "",
                    fromName: o["from_name"] as? String ?? ""
                )
            }
        }
    }

    private func unregisterCallListener() {
        if let id = callIncomingHandlerId { ChapaSocket.shared.socket?.off(id: id) }
        callIncomingHandlerId = nil
    }

    // --- SOCKET (position/{id}, chat/{id}) ---
    private func connectSocket() {
        let id = requestId
        guard id != 0 else { return }
        ChapaSocket.shared.ensureConnected()
        guard let socket = ChapaSocket.shared.socket else { return }

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                guard self != nil else { return }
                ChapaSocket.shared.joinPassengerRoom(id)
            }
        }
        if socket.status == .connected {
            ChapaSocket.shared.joinPassengerRoom(id)
        }

        socket.on("position/\(id)") { [weak self] data, _ in
            Task { @MainActor in
                guard let self else { return }
                var dict: [String: Any]? = data.first as? [String: Any]
                if dict == nil, let s = data.first as? String,
                   let parsed = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any] {
                    dict = parsed
                }
                guard let dict,
                      let lat = Double("\(dict["lat"] ?? "")"),
                      let lng = Double("\(dict["lng"] ?? "")") else { return }
                let newLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                self.receivedSocketUpdate = true
                let prev = self.driverLocation
                if prev.latitude != 0 && (prev.latitude != lat || prev.longitude != lng) {
                    self.driverRotation = GeoUtil.heading(from: prev, to: newLocation)
                }
                self.driverLocation = newLocation
            }
        }

        socket.on("chat/\(id)") { [weak self] data, _ in
            Task { @MainActor in
                guard let self, let dict = data.first as? [String: Any] else { return }
                if "\(dict["sender_type"] ?? "")" == "driver" {
                    self.hasNewMessage = true
                    SoundPlayer.shared.play("notifmessage")
                }
            }
        }
    }

    // --- POLLING request/info ---
    private func poll() async {
        guard requestId != 0 else { return }
        guard let response = try? await TravelAPI.info(requestId: requestId),
              let info = response.info else { return }

        // Conductor canceló el servicio
        if info.estado == "cancelado" {
            if !cancelRequestedByMe && !handledDriverCancel {
                handledDriverCancel = true
                toastMessage = "El conductor canceló el servicio."
                Session.shared.clearTripStates()
                stop()
                exitToHome = true
            }
            return
        }

        if lastTravelStatus == "aceptado" && info.estado == "abordo" {
            SoundPlayer.shared.play("inicioviaje")
        }
        lastTravelStatus = info.estado

        self.info = info
        if let lat = Double(info.lat ?? ""), let lng = Double(info.lng ?? ""), lat != 0 {
            originLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        if let lat = Double(info.lat_destiny ?? ""), let lng = Double(info.lng_destiny ?? ""), lat != 0 {
            destinyLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        esperaSegundos = info.estado == "aceptado" ? info.espera_segundos : nil

        if !receivedSocketUpdate,
           let lat = Double(info.lat_driver ?? ""), let lng = Double(info.lng_driver ?? ""), lat != 0 {
            driverLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        if info.estado == "finalizado" {
            SoundPlayer.shared.play("finviaje")
            goToValoration(info)
        }
    }

    private func goToValoration(_ info: TravelInfo) {
        stop()
        finishedData = ValorationData(
            conductor: info.conductor ?? "Conductor",
            foto: info.foto,
            precio: "\(info.tarifa_pasajero ?? info.precio ?? 0)",
            origen: info.direccion ?? "—",
            destino: info.destino ?? "—",
            tipoPago: info.tipo_pago ?? "Efectivo",
            marca: info.marca ?? "—",
            placa: info.placa ?? "—",
            color: info.color ?? "—",
            descuento: "\(info.monto_descuento_codigo ?? 0)"
        )
    }

    // --- FINALIZAR (regla ≤250 m del destino) ---
    func finishTravel() {
        let destino = destinyLocation
        let posActual = driverLocation.latitude != 0 ? driverLocation
            : CLLocationCoordinate2D(latitude: Session.shared.currentLat, longitude: Session.shared.currentLng)
        let distancia: Double? = (destino.latitude != 0 && posActual.latitude != 0)
            ? GeoUtil.distanceMeters(posActual, destino) : nil
        let conductorFinalizo = info?.estado == "finalizado"

        if !conductorFinalizo, let distancia, distancia > 250 {
            let texto = distancia < 1000 ? "\(Int(distancia)) m" : String(format: "%.1f km", distancia / 1000)
            toastMessage = "Debes estar a menos de 250 metros del punto de destino para finalizar el viaje (estás a \(texto))"
        } else if let info {
            SoundPlayer.shared.play("finviaje")
            goToValoration(info)
        }
    }

    // --- CANCELAR (reglas de finalizado y ≤100 m) ---
    func cancelWithReason(_ motivo: String) {
        if info?.estado == "finalizado" {
            toastMessage = "El conductor ya finalizó el viaje, ya no se puede cancelar."
            Task { await poll() }
            return
        }
        let destino = destinyLocation
        let posVehiculo = driverLocation.latitude != 0 ? driverLocation
            : CLLocationCoordinate2D(latitude: Session.shared.currentLat, longitude: Session.shared.currentLng)
        if info?.estado == "abordo", destino.latitude != 0, posVehiculo.latitude != 0,
           GeoUtil.distanceMeters(posVehiculo, destino) <= 100 {
            toastMessage = "Estás a menos de 100 metros del destino, ya no se puede cancelar. Usa \"Finalizar viaje\"."
            return
        }
        cancelRequestedByMe = true
        Task {
            let response = try? await RequestAPI.cancelRequest(idSolicitud: requestId, motivo: motivo)
            if response?.message?.lowercased().contains("finalizado") == true {
                toastMessage = "El conductor ya finalizó el viaje, ya no se puede cancelar."
                cancelRequestedByMe = false
                await poll()
            } else {
                toastMessage = response?.message
                Session.shared.clearTripStates()
                stop()
                exitToHome = true
            }
        }
    }

    // --- COMPARTIR VIAJE ---
    func shareTravel() {
        guard let info else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            guard let token = try? await TravelAPI.trackingToken(requestId: requestId), !token.isEmpty else { return }
            shareMessage = """
            *¡Sigue mi viaje en Taxi!*
            \(Config.trackingViewURL)\(token)
            🚗 *Vehículo:* \(info.marca ?? "—") - \(info.color ?? "—")
            🆔 *Placa:* \(info.placa ?? "—")
            👤 *Conductor:* \(info.conductor ?? "—")
            """
        }
    }
}
