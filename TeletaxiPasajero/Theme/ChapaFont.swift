import SwiftUI
import UIKit

// Mismas fuentes que Android (res/font/poppinsbold.ttf, poppinsmedium.ttf).
enum ChapaFont {
    static func bold(_ size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size)
    }
    static func medium(_ size: CGFloat) -> Font {
        .custom("Poppins-Medium", size: size)
    }
}

// Equivalente del scaleFactor de Android: (screenHeightDp / 800).coerceIn(0.65, 1.0)
var chapaScaleFactor: CGFloat {
    min(max(UIScreen.main.bounds.height / 844.0, 0.65), 1.0)
}
