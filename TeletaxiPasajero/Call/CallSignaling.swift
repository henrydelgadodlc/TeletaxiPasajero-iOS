import Foundation
import SocketIO

/// Señalización WebRTC sobre el socket del pasajero (namespace /location_driver).
/// Puerto 1:1 de `callModule/CallSignaling.kt`: emite/escucha los eventos `call:*`
/// que expone el servidor, con las MISMAS claves de payload.
final class CallSignaling {

    protocol Listener: AnyObject {
        func onIncoming(callId: String, fromRole: String, fromName: String)
        func onAccepted()
        func onRejected()
        func onRemoteOffer(sdp: String)
        func onRemoteAnswer(sdp: String)
        func onRemoteIce(sdpMid: String?, sdpMLineIndex: Int, candidate: String)
        func onHangup()
        func onUnreachable()
    }

    private let requestId: Int
    private weak var listener: Listener?
    private var handlerIds: [UUID] = []
    private var socket: SocketIOClient? { ChapaSocket.shared.socket }

    init(requestId: Int) {
        self.requestId = requestId
    }

    // MARK: - Ciclo de vida

    func connect(listener: Listener) {
        self.listener = listener
        ChapaSocket.shared.ensureConnected()
        guard let socket else { return }

        // Se guardan los UUID de cada handler para poder quitar SOLO los propios en
        // `disconnect()` (con `off(id:)`), sin tumbar otros listeners de `call:*`.
        handlerIds.append(socket.on("call:incoming") { [weak self] data, _ in
            guard let o = data.first as? [String: Any] else { return }
            self?.listener?.onIncoming(
                callId: o["call_id"] as? String ?? "",
                fromRole: o["from_role"] as? String ?? "",
                fromName: o["from_name"] as? String ?? ""
            )
        })
        handlerIds.append(socket.on("call:accepted") { [weak self] _, _ in self?.listener?.onAccepted() })
        handlerIds.append(socket.on("call:rejected") { [weak self] _, _ in self?.listener?.onRejected() })
        handlerIds.append(socket.on("call:offer") { [weak self] data, _ in
            guard let o = data.first as? [String: Any], let sdp = o["sdp"] as? String else { return }
            self?.listener?.onRemoteOffer(sdp: sdp)
        })
        handlerIds.append(socket.on("call:answer") { [weak self] data, _ in
            guard let o = data.first as? [String: Any], let sdp = o["sdp"] as? String else { return }
            self?.listener?.onRemoteAnswer(sdp: sdp)
        })
        handlerIds.append(socket.on("call:ice") { [weak self] data, _ in
            guard let o = data.first as? [String: Any] else { return }
            let cand = (o["candidate"] as? [String: Any]) ?? o
            self?.listener?.onRemoteIce(
                sdpMid: cand["sdpMid"] as? String,
                sdpMLineIndex: cand["sdpMLineIndex"] as? Int ?? 0,
                candidate: cand["candidate"] as? String ?? ""
            )
        })
        handlerIds.append(socket.on("call:hangup") { [weak self] _, _ in self?.listener?.onHangup() })
        handlerIds.append(socket.on("call:unreachable") { [weak self] _, _ in self?.listener?.onUnreachable() })

        joinRoom()
    }

    func disconnect() {
        if let socket { handlerIds.forEach { socket.off(id: $0) } }
        handlerIds.removeAll()
        listener = nil
    }

    // MARK: - Emisión

    private func base() -> [String: Any] { ["request_id": requestId] }

    func joinRoom() { emit("call:join", base()) }

    func invite(fromRole: String, fromName: String, callId: String) {
        var p = base(); p["from_role"] = fromRole; p["from_name"] = fromName; p["call_id"] = callId
        emit("call:invite", p)
    }

    func accept(callId: String) { var p = base(); p["call_id"] = callId; emit("call:accept", p) }
    func reject(callId: String) { var p = base(); p["call_id"] = callId; emit("call:reject", p) }
    func hangup(callId: String) { var p = base(); p["call_id"] = callId; emit("call:hangup", p) }

    func sendOffer(_ sdp: String) { var p = base(); p["sdp"] = sdp; emit("call:offer", p) }
    func sendAnswer(_ sdp: String) { var p = base(); p["sdp"] = sdp; emit("call:answer", p) }
    func sendIce(sdpMid: String?, sdpMLineIndex: Int, candidate: String) {
        var p = base()
        p["candidate"] = ["sdpMid": sdpMid as Any, "sdpMLineIndex": sdpMLineIndex, "candidate": candidate]
        emit("call:ice", p)
    }

    private func emit(_ event: String, _ data: [String: Any]) {
        guard let socket, socket.status == .connected else { return }
        socket.emit(event, data)
    }
}
