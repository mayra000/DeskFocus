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
        /// Whole seconds of stopwatch elapsed or countdown **remaining**; bumps ~1 Hz while running and forces distinct `ContentState` hashes for ActivityKit.
        public var tickingWholeSeconds: Int
        /// Bumps whenever the desk timer **starts / pauses** so ActivityKit reliably ships a distinct payload (lock-screen
        /// control chrome can otherwise stay on the previous SF Symbol briefly).
        public var interactionEpoch: UInt32
        /// Preformatted for Dynamic Island **compact** trailing (`Text` only — avoids broken `TimelineView` in Live Activities).
        public var islandCompactTime: String
        /// Preformatted for Dynamic Island expanded region / full clock style.
        public var islandExpandedTime: String

        public init(
            postureRaw: String,
            displayModeRaw: String,
            sessionPausedMs: Int,
            segmentStartedAt: Date?,
            isRunning: Bool,
            countdownDurationMs: Int,
            tickingWholeSeconds: Int,
            interactionEpoch: UInt32 = 0,
            islandCompactTime: String,
            islandExpandedTime: String
        ) {
            self.postureRaw = postureRaw
            self.displayModeRaw = displayModeRaw
            self.sessionPausedMs = sessionPausedMs
            self.segmentStartedAt = segmentStartedAt
            self.isRunning = isRunning
            self.countdownDurationMs = countdownDurationMs
            self.tickingWholeSeconds = tickingWholeSeconds
            self.interactionEpoch = interactionEpoch
            self.islandCompactTime = islandCompactTime
            self.islandExpandedTime = islandExpandedTime
        }

        enum CodingKeys: String, CodingKey {
            case postureRaw
            case displayModeRaw
            case sessionPausedMs
            case segmentStartedAt
            case isRunning
            case countdownDurationMs
            case tickingWholeSeconds
            case interactionEpoch
            case islandCompactTime
            case islandExpandedTime
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            postureRaw = try c.decode(String.self, forKey: .postureRaw)
            displayModeRaw = try c.decode(String.self, forKey: .displayModeRaw)
            sessionPausedMs = try c.decode(Int.self, forKey: .sessionPausedMs)
            segmentStartedAt = try c.decodeIfPresent(Date.self, forKey: .segmentStartedAt)
            isRunning = try c.decode(Bool.self, forKey: .isRunning)
            countdownDurationMs = try c.decode(Int.self, forKey: .countdownDurationMs)
            tickingWholeSeconds = try c.decodeIfPresent(Int.self, forKey: .tickingWholeSeconds) ?? 0
            interactionEpoch = try c.decodeIfPresent(UInt32.self, forKey: .interactionEpoch) ?? 0
            islandCompactTime = try c.decodeIfPresent(String.self, forKey: .islandCompactTime) ?? ""
            islandExpandedTime = try c.decodeIfPresent(String.self, forKey: .islandExpandedTime) ?? ""
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(postureRaw, forKey: .postureRaw)
            try c.encode(displayModeRaw, forKey: .displayModeRaw)
            try c.encode(sessionPausedMs, forKey: .sessionPausedMs)
            try c.encodeIfPresent(segmentStartedAt, forKey: .segmentStartedAt)
            try c.encode(isRunning, forKey: .isRunning)
            try c.encode(countdownDurationMs, forKey: .countdownDurationMs)
            try c.encode(tickingWholeSeconds, forKey: .tickingWholeSeconds)
            try c.encode(interactionEpoch, forKey: .interactionEpoch)
            try c.encode(islandCompactTime, forKey: .islandCompactTime)
            try c.encode(islandExpandedTime, forKey: .islandExpandedTime)
        }
    }

    public init() {}
}
