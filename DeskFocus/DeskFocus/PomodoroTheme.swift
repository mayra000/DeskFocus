//
//  PomodoroTheme.swift
//  DeskFocus
//

import SwiftUI

enum PomodoroTheme {
    struct PhaseColors {
        let background: Color
        let card: Color
        let headerButtonFill: Color
        let startFill: Color
        let startText: Color
    }

    static func timerSplitColors(for phase: PomodoroPhase) -> (base: Color, deep: Color) {
        switch phase {
        case .pomodoro:
            return (
                base: Color(red: 168 / 255, green: 95 / 255, blue: 90 / 255),
                deep: Color(red: 100 / 255, green: 44 / 255, blue: 40 / 255)
            )
        case .shortBreak:
            return (
                base: Color(red: 78 / 255, green: 118 / 255, blue: 116 / 255),
                deep: Color(red: 38 / 255, green: 74 / 255, blue: 72 / 255)
            )
        case .longBreak:
            return (
                base: Color(red: 94 / 255, green: 138 / 255, blue: 176 / 255),
                deep: Color(red: 42 / 255, green: 78 / 255, blue: 108 / 255)
            )
        }
    }

    /// Muted palettes per phase: warm focus, teal short break, slate long break.
    static func colors(for phase: PomodoroPhase) -> PhaseColors {
        switch phase {
        case .pomodoro:
            return PhaseColors(
                background: Color(red: 142 / 255, green: 72 / 255, blue: 68 / 255),
                card: Color(red: 168 / 255, green: 98 / 255, blue: 92 / 255),
                headerButtonFill: Color(red: 108 / 255, green: 52 / 255, blue: 48 / 255),
                startFill: Color(red: 245 / 255, green: 240 / 255, blue: 236 / 255),
                startText: Color(red: 100 / 255, green: 44 / 255, blue: 40 / 255)
            )
        case .shortBreak:
            return PhaseColors(
                background: Color(red: 58 / 255, green: 98 / 255, blue: 96 / 255),
                card: Color(red: 74 / 255, green: 118 / 255, blue: 114 / 255),
                headerButtonFill: Color(red: 44 / 255, green: 76 / 255, blue: 74 / 255),
                startFill: Color(red: 245 / 255, green: 248 / 255, blue: 246 / 255),
                startText: Color(red: 38 / 255, green: 72 / 255, blue: 69 / 255)
            )
        case .longBreak:
            return PhaseColors(
                background: Color(red: 62 / 255, green: 112 / 255, blue: 148 / 255),
                card: Color(red: 91 / 255, green: 135 / 255, blue: 169 / 255),
                headerButtonFill: Color(red: 46 / 255, green: 82 / 255, blue: 108 / 255),
                startFill: Color(red: 253 / 255, green: 242 / 255, blue: 240 / 255),
                startText: Color(red: 36 / 255, green: 68 / 255, blue: 92 / 255)
            )
        }
    }

    static let primary = Color.white
    /// Soft gray-white for task placeholder — high readability on phase backgrounds.
    static let addTaskPlaceholder = Color.white.opacity(0.88)
    static let muted = Color.white.opacity(0.62)
    static let tabPill = Color.black.opacity(0.22)
    static let dashedStroke = Color.white.opacity(0.55)
}
