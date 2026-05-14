//
//  TimerVerticalFillBackground.swift
//  DeskFocus
//

import SwiftUI

/// Full-area background with a sharper horizontal split: lighter region on top,
/// darker fill rising from the bottom as `fraction` approaches 1.
struct TimerVerticalFillBackground: View {
    var fraction: CGFloat
    var baseColor: Color
    var deepColor: Color

    var body: some View {
        GeometryReader { geo in
            let h = max(
                0,
                min(geo.size.height * CGFloat(min(max(fraction, 0), 1)), geo.size.height)
            )

            ZStack(alignment: .bottom) {
                baseColor

                Rectangle()
                    .fill(deepColor)
                    .frame(height: h)
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.42), value: fraction)
        }
        .allowsHitTesting(false)
    }
}
