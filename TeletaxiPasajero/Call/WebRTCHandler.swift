import Foundation
import WebRTC
import AVFoundation

/// Negociación WebRTC de la llamada de voz 1:1 pasajero↔conductor. Puerto de
/// `callModule/WebRtcClient.kt`, con el **mismo contrato de señales** que el
/// servidor y el conductor Android esperan:
///   - offer/answer:  { type, sdp }
///   - candidate:     { sdpMid, sdpMLineIndex, candidate }
///
/// En el pasajero el camino principal es `startCall()` (crear la oferta), porque
/// es quien INICIA la llamada al conductor. `handleRemoteSignal("offer")` queda
/// para el caso de llamada entrante (el conductor abre el canal).
final class WebRTCHandler {

    /// Devuelve al ViewModel cada señal local para que la emita por el socket.
    var onSignal: ((_ type: String, _ signal: [String: Any]) -> Void)?
    /// Se dispara cuando la conexión ICE llega a `connected` (llamada establecida).
    var onConnected: (() -> Void)?

    private let factory: RTCPeerConnectionFactory
    private var pc: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var routeObserver: NSObjectProtocol?

    // Los candidatos ICE remotos no pueden añadirse antes de fijar la descripción
    // remota; se guardan y se vuelcan cuando ya está (igual que `pendingRemoteIce`
    // en Android).
    private var remoteDescSet = false
    private var pendingRemoteIce: [RTCIceCandidate] = []

    // Estado de audio (lo fija el ViewModel desde los interruptores de la pantalla).
    var isMuted = false
    var isOutputMuted = false

    init() {
        RTCInitializeSSL()

        // Que la sesión propia de WebRTC use el AURICULAR (llamada 1:1 pegada a la
        // oreja), a diferencia del radio que fuerza altavoz de manos libres.
        let cfg = RTCAudioSessionConfiguration.webRTC()
        cfg.category = AVAudioSession.Category.playAndRecord.rawValue
        cfg.categoryOptions = [.allowBluetooth]
        cfg.mode = AVAudioSession.Mode.voiceChat.rawValue
        RTCAudioSessionConfiguration.setWebRTC(cfg)

        let encoder = RTCDefaultVideoEncoderFactory()
        let decoder = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoder, decoderFactory: decoder)
    }

    deinit {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }

    /// Pide el permiso de micrófono si aún no se ha resuelto. Se llama al abrir la
    /// pantalla de llamada, con tiempo antes de que se cree el track de audio.
    static func pedirPermisoMicrofono() {
        let sesion = AVAudioSession.sharedInstance()
        guard sesion.recordPermission == .undetermined else { return }
        sesion.requestRecordPermission { _ in }
    }

    // MARK: - Sesión de audio

    private func configurarAudio() {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[WebRTC] No se pudo configurar la sesión de audio: \(error)")
        }
        session.unlockForConfiguration()
    }

    // MARK: - PeerConnection

    private func createPeerConnection() {
        configurarAudio()

        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc = factory.peerConnection(with: config, constraints: constraints, delegate: PCDelegate(handler: self))

        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: [:], optionalConstraints: nil)
        let source = factory.audioSource(with: audioConstraints)
        let track = factory.audioTrack(with: source, trackId: "ARDAMSa0")
        track.isEnabled = !isMuted
        localAudioTrack = track
        pc?.add(track, streamIds: ["ARDAMS"])
    }

    // MARK: - Iniciar (el pasajero llama al conductor)

    func startCall() {
        if pc == nil { createPeerConnection() }
        guard let pc else { return }
        let cons = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        pc.offer(for: cons) { [weak self] offer, err in
            guard let self, let offer, err == nil else { return }
            pc.setLocalDescription(offer) { _ in }
            self.onSignal?("offer", ["type": "offer", "sdp": offer.sdp])
        }
    }

    // MARK: - Señales entrantes

    func handleRemoteSignal(type: String, signal: [String: Any]) {
        if pc == nil { createPeerConnection() }
        guard let pc else { return }

        switch type {
        case "offer":
            guard let sdp = signal["sdp"] as? String else { return }
            let remote = RTCSessionDescription(type: .offer, sdp: sdp)
            pc.setRemoteDescription(remote) { [weak self] err in
                if let err { print("[WebRTC] setRemote(offer) falló: \(err)"); return }
                self?.flushRemoteIce()
                let cons = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
                pc.answer(for: cons) { [weak self] answer, err in
                    guard let self, let answer, err == nil else { return }
                    pc.setLocalDescription(answer) { _ in }
                    self.onSignal?("answer", ["type": "answer", "sdp": answer.sdp])
                }
            }

        case "answer":
            guard let sdp = signal["sdp"] as? String else { return }
            pc.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { [weak self] err in
                if let err { print("[WebRTC] setRemote(answer) falló: \(err)"); return }
                self?.flushRemoteIce()
            }

        case "candidate":
            guard let cand = signal["candidate"] as? String else { return }
            let mid = signal["sdpMid"] as? String
            let mline = (signal["sdpMLineIndex"] as? Int).map(Int32.init) ?? 0
            let ice = RTCIceCandidate(sdp: cand, sdpMLineIndex: mline, sdpMid: mid)
            if remoteDescSet {
                pc.add(ice) { _ in }
            } else {
                pendingRemoteIce.append(ice)
            }

        default:
            break
        }
    }

    private func flushRemoteIce() {
        remoteDescSet = true
        pendingRemoteIce.forEach { c in pc?.add(c) { _ in } }
        pendingRemoteIce.removeAll()
    }

    func stopCall() {
        pc?.close()
        pc = nil
        localAudioTrack = nil
        remoteAudioTrack = nil
        remoteDescSet = false
        pendingRemoteIce.removeAll()
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        try? session.setActive(false)
        session.unlockForConfiguration()
    }

    // MARK: - Controles

    func setMuted(_ muted: Bool) {
        isMuted = muted
        localAudioTrack?.isEnabled = !muted
    }

    func setOutputMuted(_ muted: Bool) {
        isOutputMuted = muted
        remoteAudioTrack?.isEnabled = !muted
    }

    /// Alterna entre altavoz (manos libres) y auricular.
    func setSpeaker(_ on: Bool) {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        try? session.overrideOutputAudioPort(on ? .speaker : .none)
        session.unlockForConfiguration()
    }

    fileprivate func onRemoteTrack(_ track: RTCAudioTrack) {
        remoteAudioTrack = track
        track.isEnabled = !isOutputMuted
    }

    fileprivate func emitLocalCandidate(_ c: RTCIceCandidate) {
        onSignal?("candidate", [
            "sdpMid": c.sdpMid as Any,
            "sdpMLineIndex": Int(c.sdpMLineIndex),
            "candidate": c.sdp
        ])
    }

    fileprivate func iceStateChanged(_ state: RTCIceConnectionState) {
        if state == .connected || state == .completed {
            DispatchQueue.main.async { [weak self] in self?.onConnected?() }
        }
    }
}

/// Delegado de la PeerConnection. Separado para no exponer los métodos del
/// protocolo en la API pública del handler.
private final class PCDelegate: NSObject, RTCPeerConnectionDelegate {
    weak var handler: WebRTCHandler?
    init(handler: WebRTCHandler) { self.handler = handler }

    func peerConnection(_ pc: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        handler?.emitLocalCandidate(candidate)
    }

    func peerConnection(_ pc: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        if let track = rtpReceiver.track as? RTCAudioTrack {
            handler?.onRemoteTrack(track)
        }
    }

    // Requeridos por el protocolo; sin uso.
    func peerConnection(_ pc: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ pc: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ pc: RTCPeerConnection) {}
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        handler?.iceStateChanged(newState)
    }
    func peerConnection(_ pc: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ pc: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ pc: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
