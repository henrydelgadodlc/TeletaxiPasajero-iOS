import SwiftUI

// Equivalente de los Toast de Android: aviso flotante que se autodescarta.
struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        ZStack {
            content
            if let message {
                VStack {
                    Spacer()
                    Text(message)
                        .font(ChapaFont.medium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(24)
                        .padding(.bottom, 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { self.message = nil }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
