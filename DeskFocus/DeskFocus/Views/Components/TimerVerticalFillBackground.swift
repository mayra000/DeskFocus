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
            let safeFrac = CGFloat(min(max(fraction, 0), 1))
            let h = min(geo.size.height * safeFrac, geo.size.height)

            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(baseColor)
                    .frame(width: geo.size.width, height: geo.size.height)

                Rectangle()
                    .fill(deepColor)
                    .frame(width: geo.size.width, height: h)
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.42), value: fraction)
        }
        .allowsHitTesting(false)
    }
}
