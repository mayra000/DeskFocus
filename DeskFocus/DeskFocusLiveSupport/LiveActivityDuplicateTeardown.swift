//
//  LiveActivityDuplicateTeardown.swift
//  DeskFocusLiveSupport
//

import ActivityKit
import Foundation

/// Ensures the lock screen never stacks multiple DeskFocus Live Activities of the same kind (lost references, aborted starts, races).
public enum LiveActivityDuplicateTeardown {

    public static func endAllDeskSessionActivities() async {
        let activities = Activity<DeskSessionActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    public static func endAllPomodoroSessionActivities() async {
        let activities = Activity<PomodoroSessionActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    public static func endDeskSessionActivities(except keeper: Activity<DeskSessionActivityAttributes>) async {
        for candidate in Activity<DeskSessionActivityAttributes>.activities where candidate.id != keeper.id {
            await candidate.end(nil, dismissalPolicy: .immediate)
        }
    }

    public static func endPomodoroSessionActivities(except keeper: Activity<PomodoroSessionActivityAttributes>)
        async
    {
        for candidate in Activity<PomodoroSessionActivityAttributes>.activities where candidate.id != keeper.id {
            await candidate.end(nil, dismissalPolicy: .immediate)
        }
    }
}
