import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            ChapaTheme.darkBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("LogoChapa")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(ChapaTheme.borderPurple, lineWidth: 1.5))

                Text("Teletaxi")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ChapaTheme.textMain)

                Text("Tu taxi, al toque")
                    .font(.system(size: 14))
                    .foregroundColor(ChapaTheme.textMuted)

                ProgressView()
                    .tint(ChapaTheme.purpleLight)
                    .padding(.top, 12)
            }
        }
    }
}
