import SwiftUI
import SocketIO

// Puerto de ChatScreen.kt + Container: chat pasajero↔conductor por socket
// (evento "chat" / "chat/{id}") con historial de history/ChatHistory.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isPassenger: Bool
}

enum ChatAPI {
    struct ChatDetail: Decodable {
        let sender_id: String?
        let sender_type: String?
        let message: String?

        private enum CodingKeys: String, CodingKey { case sender_id, sender_type, message }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sender_id = c.flexString(.sender_id)
            sender_type = c.flexString(.sender_type)
            message = c.flexString(.message)
        }
    }

    static func history(requestId: Int) async throws -> [ChatDetail] {
        struct Body: Encodable { let id_solicitud: String }
        struct R: Decodable { let code: Int; let historial: [ChatDetail]? }
        let r: R = try await TaxiAPI.shared.post("history/ChatHistory", body: Body(id_solicitud: "\(requestId)"))
        return r.historial ?? []
    }
}

struct ChatView: View {
    let requestId: Int
    let driverName: String
    let onBack: () -> Void

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var toastMessage: String?
    @State private var socketHandlerId: UUID?
    @FocusState private var inputFocused: Bool

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(c.textMain)
                            .frame(width: 44, height: 44)
                    }
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(ChapaTheme.purplePrimary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(driverName)
                            .font(ChapaFont.bold(16))
                            .foregroundColor(c.textMain)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle().fill(ChapaTheme.green).frame(width: 7, height: 7)
                            Text("Tu conductor")
                                .font(ChapaFont.medium(11))
                                .foregroundColor(c.textMuted)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(c.cardBg.opacity(0.5))

                // Mensajes
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 8) {
                            if messages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(ChapaTheme.purplePrimary.opacity(0.3))
                                    Text("Escríbele a tu conductor")
                                        .font(ChapaFont.medium(13))
                                        .foregroundColor(c.textMuted)
                                }
                                .padding(.top, 80)
                            }
                            ForEach(messages) { msg in
                                bubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages) { list in
                        if let last = list.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Input
                HStack(spacing: 10) {
                    TextField("", text: $draft, prompt: Text("Escribe un mensaje...").foregroundColor(c.textDim))
                        .font(ChapaFont.medium(14))
                        .foregroundColor(c.textMain)
                        .focused($inputFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 46)
                        .background(c.surfaceDark)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(c.borderPurple, lineWidth: 1))

                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(draft.trimmingCharacters(in: .whitespaces).isEmpty ? ChapaTheme.purplePrimary.opacity(0.4) : ChapaTheme.purplePrimary)
                            .clipShape(Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(c.cardBg)
            }
        }
        .toast($toastMessage)
        .onAppear {
            loadHistory()
            listenSocket()
        }
        .onDisappear {
            // Quitar SOLO el handler del chat (TravelView mantiene el suyo
            // para el badge de mensajes nuevos).
            if let socketHandlerId {
                ChapaSocket.shared.socket?.off(id: socketHandlerId)
            }
        }
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isPassenger { Spacer(minLength: 60) }
            Text(msg.message)
                .font(ChapaFont.medium(14))
                .foregroundColor(msg.isPassenger ? .white : c.textMain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isPassenger ? ChapaTheme.purplePrimary : c.surfaceDark)
                .clipShape(RoundedCorners(
                    radius: 18,
                    corners: msg.isPassenger
                        ? [.topLeft, .topRight, .bottomLeft]
                        : [.topLeft, .topRight, .bottomRight]
                ))
            if !msg.isPassenger { Spacer(minLength: 60) }
        }
    }

    private func loadHistory() {
        Task {
            let history = (try? await ChatAPI.history(requestId: requestId)) ?? []
            messages = history.map { detail in
                let type = (detail.sender_type ?? "").lowercased()
                return ChatMessage(
                    message: detail.message ?? "",
                    isPassenger: type == "passenger" || type == "pasajero"
                )
            }
        }
    }

    private func listenSocket() {
        ChapaSocket.shared.ensureConnected()
        socketHandlerId = ChapaSocket.shared.socket?.on("chat/\(requestId)") { data, _ in
            Task { @MainActor in
                guard let dict = data.first as? [String: Any] else { return }
                let senderType = "\(dict["sender_type"] ?? "")".lowercased()
                if senderType == "driver" || senderType == "conductor" {
                    SoundPlayer.shared.play("notifmessage")
                    messages.append(ChatMessage(
                        message: "\(dict["message"] ?? "")",
                        isPassenger: false
                    ))
                }
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        guard let socket = ChapaSocket.shared.socket, socket.status == .connected else {
            toastMessage = "Sin conexión al chat, reintentando..."
            ChapaSocket.shared.ensureConnected()
            return
        }
        socket.emit("chat", [
            "request_id": "\(requestId)",
            "message": text,
            "sender_id": "\(Session.shared.idPassenger)",
            "sender_type": "passenger"
        ])
        SoundPlayer.shared.play("notifmessage")
        messages.append(ChatMessage(message: text, isPassenger: true))
        draft = ""
    }
}
