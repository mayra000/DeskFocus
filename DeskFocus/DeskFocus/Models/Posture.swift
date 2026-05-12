//
//  Posture.swift
//  DeskFocus
//

import Foundation

enum Posture: String, Codable {
    case sitting
    case standing
}

enum SessionDisplayMode: String, Codable {
    case stopwatch
    case countdown
}

enum PomodoroPhase: String, Codable {
    case pomodoro
    case shortBreak
    case longBreak

    var durationMs: Int {
        switch self {
        case .pomodoro: return 25 * 60 * 1000
        case .shortBreak: return 5 * 60 * 1000
        case .longBreak: return 15 * 60 * 1000
        }
    }
}
