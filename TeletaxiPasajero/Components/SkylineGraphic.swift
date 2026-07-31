import SwiftUI

// Puerto de SkylineGraphic (LoginScreen.kt): silueta de ciudad en Canvas.
struct SkylineGraphic: View {
    let color: Color
    var scale: CGFloat = chapaScaleFactor

    private let heights: [CGFloat] = [40, 60, 50, 80, 110, 45, 75, 130, 55, 85, 70, 60, 150, 65, 80, 50, 120, 60, 70, 45, 80, 55, 90, 40, 65]

    var body: some View {
        Canvas { context, size in
            let rectWidth = size.width / 25
            for (i, h) in heights.enumerated() {
                let height = h * scale
                let rect = CGRect(
                    x: CGFloat(i) * rectWidth,
                    y: size.height - height,
                    width: rectWidth,
                    height: height
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(height: 220 * scale)
    }
}
