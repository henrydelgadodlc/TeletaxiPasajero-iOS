import Foundation
import SocketIO

// Puerto de SocketHandler.kt: socket al namespace /location_driver con
// transporte websocket, reconexión y salas de pasajero.
final class ChapaSocket {
    static let shared = ChapaSocket()

    private var manager: SocketManager?
    private(set) var socket: SocketIOClient?

    private init() {}

    func ensureConnected() {
        if manager == nil {
            guard let url = URL(string: "https://api.teletaxi.city") else { return }
            manager = SocketManager(socketURL: url, config: [
                .path("/socket.io"),
                .forceWebsockets(true),
                .reconnects(true),
                .compress
            ])
            socket = manager?.socket(forNamespace: "/location_driver")
        }
        if socket?.status != .connected {
            socket?.connect()
        }
    }

    func joinPassengerRoom(_ requestId: Int) {
        socket?.emit("join_passenger_room", ["request_id": requestId])
    }

    func leavePassengerRoom(_ requestId: Int) {
        socket?.emit("leave_passenger_room", ["request_id": requestId])
    }

    func disconnect() {
        socket?.disconnect()
    }
}
