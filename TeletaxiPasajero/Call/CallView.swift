import SwiftUI

/// Pantalla de llamada de voz 1:1. Puerto de `callModule/CallScreen.kt`.
struct CallView: View {
    @StateObject var vm: CallViewModel
    let onClose: () -> Void

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [c.darkBg, c.surfaceDark],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Avatar
                ZStack {
                    Circle()
                        .fill(c.purplePrimary.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: "person.fill")
                        .font(.system(size: 64))
                        .foregroundColor(c.purplePrimary)
                }
                .overlay(Circle().stroke(c.purplePrimary.opacity(0.35), lineWidth: 2))

                Spacer().frame(height: 28)

                Text(vm.peerName)
                    .font(ChapaFont.bold(24))
                    .foregroundColor(c.textMain)

                Spacer().frame(height: 8)

                Text(vm.state == .inCall ? vm.elapsedText : vm.statusText)
                    .font(ChapaFont.medium(16))
                    .foregroundColor(c.textMuted)

                Spacer()

                controls
                    .padding(.bottom, 56)
            }
        }
        .onAppear { vm.start() }
        .onChange(of: vm.state) { st in
            if st == .ended { onClose() }
        }
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private var controls: some View {
        switch vm.state {
        case .incoming:
            HStack(spacing: 64) {
                roundButton(icon: "phone.down.fill", bg: .red) { vm.hangup() }
                roundButton(icon: "phone.fill", bg: Color(hex: 0x2E7D32)) { vm.acceptIncoming() }
            }
        case .inCall:
            VStack(spacing: 28) {
                HStack(spacing: 48) {
                    toggleButton(icon: vm.muted ? "mic.slash.fill" : "mic.fill", on: vm.muted, label: "Silenciar") {
                        vm.toggleMute()
                    }
                    toggleButton(icon: vm.speaker ? "speaker.wave.3.fill" : "speaker.fill", on: vm.speaker, label: "Altavoz") {
                        vm.toggleSpeaker()
                    }
                }
                roundButton(icon: "phone.down.fill", bg: .red) { vm.hangup() }
            }
        default:   // outgoing / connecting
            roundButton(icon: "phone.down.fill", bg: .red) { vm.hangup() }
        }
    }

    private func roundButton(icon: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(bg)
                .clipShape(Circle())
        }
    }

    private func toggleButton(icon: String, on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(on ? c.darkBg : c.textMain)
                    .frame(width: 64, height: 64)
                    .background(on ? c.purplePrimary : c.cardBg)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(c.borderPurple, lineWidth: 1))
                Text(label)
                    .font(ChapaFont.medium(12))
                    .foregroundColor(c.textMuted)
            }
        }
    }
}
