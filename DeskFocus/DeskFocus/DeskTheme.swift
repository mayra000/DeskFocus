//
//  DeskTheme.swift
//  DeskFocus
//

import SwiftUI

enum DeskTheme {
    /// Legacy blue‑grey background (unused for live desk chrome; previews may reference).
    static let background = Color(red: 26 / 255, green: 43 / 255, blue: 60 / 255)

    /// Full-screen tint behind desk content; standing is navy, sitting stays green.
    static func screenBackground(for posture: Posture) -> Color {
        switch posture {
        case .standing:
            return Color(red: 22 / 255, green: 38 / 255, blue: 60 / 255)
        case .sitting:
            return Color(red: 22 / 255, green: 48 / 255, blue: 40 / 255)
        }
    }

    /// Main timer card on top of the posture tinted screen.
    static func mainCard(for posture: Posture) -> Color {
        switch posture {
        case .standing:
            return Color(red: 38 / 255, green: 58 / 255, blue: 86 / 255)
        case .sitting:
            return Color(red: 40 / 255, green: 64 / 255, blue: 52 / 255)
        }
    }

    /// Lighter band for timer progress split (above the rising edge).
    static func timerSplitBase(for posture: Posture) -> Color {
        switch posture {
        case .standing:
            return Color(red: 34 / 255, green: 54 / 255, blue: 84 / 255)
        case .sitting:
            return Color(red: 42 / 255, green: 78 / 255, blue: 60 / 255)
        }
    }

    /// Deeper shade that rises from the bottom as the session advances / time drains.
    static func timerSplitDeep(for posture: Posture) -> Color {
        switch posture {
        case .standing:
            return Color(red: 14 / 255, green: 24 / 255, blue: 44 / 255)
        case .sitting:
            return Color(red: 12 / 255, green: 32 / 255, blue: 26 / 255)
        }
    }

    static let muted = Color(red: 149 / 255, green: 165 / 255, blue: 166 / 255)
    static let primary = Color.white
    static let pillBackground = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.35)
}
