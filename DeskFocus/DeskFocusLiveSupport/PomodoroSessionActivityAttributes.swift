//
//  PomodoroSessionActivityAttributes.swift
//  DeskFocusLiveSupport
//

import ActivityKit
import Foundation

public struct PomodoroSessionActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var phaseRaw: String
        public var isRunning: Bool
        public var remainingMs: Int
        /// Wall-clock span for `Text(timerInterval:countsDown:)` while running; ignored when paused.
        public var countdownStartAt: Date?
        public var countdownEndsAt: Date?

        public init(
            phaseRaw: String,
            isRunning: Bool,
            remainingMs: Int,
            countdownStartAt: Date?,
            countdownEndsAt: Date?
        ) {
            self.phaseRaw = phaseRaw
            self.isRunning = isRunning
            self.remainingMs = remainingMs
            self.countdownStartAt = countdownStartAt
            self.countdownEndsAt = countdownEndsAt
        }
    }

    public init() {}
}
