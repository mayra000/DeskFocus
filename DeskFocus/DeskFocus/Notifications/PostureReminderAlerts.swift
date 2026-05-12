//
//  PostureReminderAlerts.swift
//  DeskFocus
//

import Foundation
import UserNotifications

func countdownCompleteContent(posture: Posture) -> UNMutableNotificationContent {
    let notification = UNMutableNotificationContent()

    switch posture {
    case .sitting:
        notification.title = "Desk countdown finished"
        notification.body =
            "Nice focused stretch of sitting time—stand, stretch lightly, then reset before the next sprint."
        notification.sound = .default
        return notification
    case .standing:
        notification.title = "Standing countdown finished"
        notification.body =
            "Standing block complete—sit or move as needed, hydrate, then start your next block when ready."
        notification.sound = .default
        return notification
    }
}
