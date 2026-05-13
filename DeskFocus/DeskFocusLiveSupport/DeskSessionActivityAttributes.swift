//
//  DeskSessionActivityAttributes.swift
//  DeskFocusLiveSupport
//

import ActivityKit
import Foundation

public struct DeskSessionActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var postureRaw: String
        public var displayModeRaw: String
        public var sessionPausedMs: Int
        public var segmentStartedAt: Date?
        public var isRunning: Bool
        public var countdownDurationMs: Int

        public init(
            postureRaw: String,
            displayModeRaw: String,
            sessionPausedMs: Int,
            segmentStartedAt: Date?,
            isRunning: Bool,
            countdownDurationMs: Int
        ) {
            self.postureRaw = postureRaw
            self.displayModeRaw = displayModeRaw
            self.sessionPausedMs = sessionPausedMs
            self.segmentStartedAt = segmentStartedAt
            self.isRunning = isRunning
            self.countdownDurationMs = countdownDurationMs
        }
    }

    public init() {}
}
