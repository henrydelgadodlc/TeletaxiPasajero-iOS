import Foundation
import Combine

/// Datos de una llamada entrante detectada por socket (`call:incoming`), para
/// presentar la pantalla de llamada en modo entrante.
struct IncomingCallInfo: Identifiable {
    let id = UUID()
    let callId: String
    let fromName: String
}

/// Orquesta una llamada de voz 1:1 (señalización + WebRTC + estado de UI).
/// Puerto de la lógica de `callModule/CallActivity.kt`, adaptado a MVVM.
///
/// El pasajero es normalmente el que LLAMA (`.outgoing`): invita → espera
/// `onAccepted` → crea la oferta → recibe la respuesta → conecta. El modo
/// `.incoming` queda para cuando el conductor abre el canal (llamada entrante
/// por socket en primer plano).
final class CallViewModel: ObservableObject, CallSignaling.Listener {

    enum Mode { case outgoing, incoming }
    enum UIState: Equatable { case outgoing, incoming, connecting, inCall, ended }

    @Published var state: UIState
    @Published var muted = false
    @Published var speaker = false
    @Published var statusText: String
    @Published var elapsed = 0            // segundos desde que se estableció la llamada

    let peerName: String
    private let requestId: Int
    private let isCaller: Bool
    private let callId: String
    private let myRole = "passenger"
    private let myName: String

    private let signaling: CallSignaling
    private let webrtc = WebRTCHandler()
    private var timer: Timer?
    private var closed = false

    /// Se invoca cuando la llamada termina para que la vista se cierre.
    var onClosed: (() -> Void)?

    init(requestId: Int, peerName: String, mode: Mode, callId: String? = nil) {
        self.requestId = requestId
        self.peerName = peerName
        self.isCaller = (mode == .outgoing)
        self.callId = callId ?? "\(requestId)-\(UUID().uuidString)"
        self.myName = Session.shared.nameUser.isEmpty ? "Pasajero" : Session.shared.nameUser
        self.signaling = CallSignaling(requestId: requestId)
        self.state = (mode == .outgoing) ? .outgoing : .incoming
        self.statusText = (mode == .outgoing) ? "Llamando…" : "Llamada entrante"
    }

    // MARK: - Ciclo de vida

    func start() {
        guard requestId > 0 else { endCall(notifyPeer: false); return }
        WebRTCHandler.pedirPermisoMicrofono()

        webrtc.onSignal = { [weak self] type, signal in
            guard let self else { return }
            switch type {
            case "offer":     self.signaling.sendOffer(signal["sdp"] as? String ?? "")
            case "answer":    self.signaling.sendAnswer(signal["sdp"] as? String ?? "")
            case "candidate": self.signaling.sendIce(
                                sdpMid: signal["sdpMid"] as? String,
                                sdpMLineIndex: signal["sdpMLineIndex"] as? Int ?? 0,
                                candidate: signal["candidate"] as? String ?? "")
            default: break
            }
        }
        webrtc.onConnected = { [weak self] in self?.markConnected() }

        signaling.connect(listener: self)

        if isCaller {
            signaling.invite(fromRole: myRole, fromName: myName, callId: callId)
        }
    }

    /// Contesta una llamada entrante (modo `.incoming`).
    func acceptIncoming() {
        ui { self.state = .connecting; self.statusText = "Conectando…" }
        signaling.joinRoom()
        signaling.accept(callId: callId)
    }

    func hangup() { endCall(notifyPeer: true) }

    private func markConnected() {
        ui {
            guard self.state != .inCall else { return }
            self.state = .inCall
            self.statusText = "En llamada"
            self.startTimer()
        }
    }

    private func endCall(notifyPeer: Bool) {
        if closed { return }
        closed = true
        if notifyPeer { signaling.hangup(callId: callId) }
        stopTimer()
        webrtc.stopCall()
        signaling.disconnect()
        ui { self.state = .ended; self.onClosed?() }
    }

    // MARK: - Controles

    func toggleMute() { muted.toggle(); webrtc.setMuted(muted) }
    func toggleSpeaker() { speaker.toggle(); webrtc.setSpeaker(speaker) }

    // MARK: - CallSignaling.Listener

    func onIncoming(callId: String, fromRole: String, fromName: String) {}   // no aplica una vez abierta

    func onAccepted() {
        ui { self.state = .connecting; self.statusText = "Conectando…" }
        webrtc.startCall()   // crea la oferta → onSignal("offer")
    }

    func onRejected() { endCall(notifyPeer: false) }

    func onRemoteOffer(sdp: String) {
        webrtc.handleRemoteSignal(type: "offer", signal: ["sdp": sdp])
    }

    func onRemoteAnswer(sdp: String) {
        webrtc.handleRemoteSignal(type: "answer", signal: ["sdp": sdp])
    }

    func onRemoteIce(sdpMid: String?, sdpMLineIndex: Int, candidate: String) {
        webrtc.handleRemoteSignal(type: "candidate", signal: [
            "sdpMid": sdpMid as Any, "sdpMLineIndex": sdpMLineIndex, "candidate": candidate
        ])
    }

    func onHangup() { endCall(notifyPeer: false) }

    func onUnreachable() {
        ui { self.statusText = "No disponible" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.endCall(notifyPeer: false)
        }
    }

    // MARK: - Helpers

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    var elapsedText: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    /// Ejecuta en el hilo principal (los callbacks del socket pueden llegar fuera de él).
    private func ui(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}
