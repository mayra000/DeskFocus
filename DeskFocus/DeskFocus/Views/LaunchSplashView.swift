//
//  LaunchSplashView.swift
//  DeskFocus
//

import SwiftUI
import UIKit

/// Same greens as `LaunchScreen.storyboard` (top → bottom linear fade in SwiftUI).
struct LaunchBrandGradient: View {
    static let top = Color(red: 20 / 255, green: 53 / 255, blue: 48 / 255)
    static let bottom = Color(red: 13 / 255, green: 35 / 255, blue: 32 / 255)

    /// `UIKit` fill for `UIWindow` to avoid a black flash before SwiftUI paints.
    static var uiWindowFallback: UIColor {
        UIColor(red: 20 / 255, green: 53 / 255, blue: 48 / 255, alpha: 1)
    }

    var body: some View {
        LinearGradient(
            colors: [Self.top, Self.bottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
