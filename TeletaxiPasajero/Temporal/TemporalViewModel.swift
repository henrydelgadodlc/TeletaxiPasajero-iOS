import Foundation
import SwiftUI

// Puerto de TemporalScreenContainer: polling de ofertas cada 5s, pulse de
// despacho cada 5s, timer de 3 minutos y aceptar/cancelar.
@MainActor
final class TemporalViewModel: ObservableObject {

    @Published var timeLeft = "03:00"
    @Published var notifiedCount = 0
    @Published var radiusKm = 0.0
    @Published var offers: [Temporal] = []
    @Published var showTimeout = false
    @Published var selectedOffer: Temporal?
    @Published var toastMessage: String?
    @Published var accepted = false     // dispara navegación a Travel
    @Published var cancelled = false    // dispara volver al Home

    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var lastOfferCount = 0
    private let maxTimeMillis: Int64 = 180_000

    func start() {
        let requestId = Session.shared.currentRequest
        guard requestId != 0 else { return }

        // Polling de ofertas + pulse (Handler.postDelayed de Android)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        Task { await tickAsync() }

        // Timer de 3 minutos desde requestStartTime
        var startTime = Session.shared.requestStartTime
        if startTime == 0 {
            startTime = Int64(Date().timeIntervalSince1970 * 1000)
            Session.shared.requestStartTime = startTime
        }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let elapsed = Int64(Date().timeIntervalSince1970 * 1000) - Session.shared.requestStartTime
                let remaining = self.maxTimeMillis - elapsed
                if remaining <= 0 {
                    self.timeLeft = "00:00"
                    if !self.showTimeout && self.offers.isEmpty { self.showTimeout = true }
                    self.countdownTimer?.invalidate()
                } else {
                    let m = remaining / 60000
                    let s = (remaining % 60000) / 1000
                    self.timeLeft = String(format: "%02d:%02d", m, s)
                }
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        countdownTimer?.invalidate()
        pollTimer = nil
        countdownTimer = nil
    }

    private func tick() {
        Task { await tickAsync() }
    }

    private func tickAsync() async {
        let requestId = Session.shared.currentRequest
        guard requestId != 0 else { return }

        let list = await TemporalAPI.offers(requestId: requestId)
        if list.count > lastOfferCount {
            SoundPlayer.shared.play("propuesta")
        }
        lastOfferCount = list.count
        offers = list

        if let pulse = try? await TemporalAPI.pulse(requestId: requestId),
           pulse.code == 200, let d = pulse.dispatch {
            radiusKm = d.current_radius_km ?? radiusKm
            notifiedCount = d.total_notified ?? notifiedCount
        }
    }

    func confirmOffer(_ offer: Temporal) {
        selectedOffer = nil
        Task {
            do {
                let r = try await TemporalAPI.accept(
                    idSolicitud: offer.id_solicitud,
                    idConductor: offer.id_conductor,
                    precio: Float(offer.tarifa)
                )
                if r.code == 200 {
                    SoundPlayer.shared.play("encamino")
                    Session.shared.requestStartTime = 0
                    Session.shared.stateTemporal = false
                    Session.shared.stateTravel = true
                    stop()
                    accepted = true
                } else {
                    toastMessage = "El conductor ya no está disponible"
                }
            } catch {
                toastMessage = "El conductor ya no está disponible"
            }
        }
    }

    func cancel(motivo: String) {
        let requestId = Session.shared.currentRequest
        Task {
            let message = (try? await RequestAPI.cancelRequest(idSolicitud: requestId, motivo: motivo))?.message
            toastMessage = message
            Session.shared.clearTripStates()
            stop()
            cancelled = true
        }
    }
}
