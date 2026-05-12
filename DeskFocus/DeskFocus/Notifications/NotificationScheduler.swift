//
//  NotificationScheduler.swift
//  DeskFocus
//

import Foundation
import UserNotifications

/// Schedules ahead-of-time local alerts only — no background timer execution.
@MainActor
final class NotificationScheduler {

    static let shared = NotificationScheduler()

    private enum ID {
        static let countdownCompletion = "deskfocus.countdown.completion"
        static let sittingAlertCap = 8

        static func sittingHour(_ index: Int) -> String {
            "deskfocus.sitting.hour.\(index)"
        }
    }

    private let center = UNUserNotificationCenter.current()

    init() {}

    func requestPermission() async {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in
                continuation.resume()
            }
        }
    }

    /// Schedules eight one-shot alerts on upcoming hour boundaries, each with a rotating stretch hint.
    func scheduleSittingHourAlerts(startedAt: Date, currentHour: Int) {
        cancelSittingAlerts()

        let calendar = Calendar.current
        guard let firstFire = calendar.nextDate(
            after: startedAt,
            matching: DateComponents(minute: 0, second: 0, nanosecond: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) else {
            return
        }

        var cursor = firstFire

        for index in 0 ..< ID.sittingAlertCap {
            let fireHour = calendar.component(.hour, from: cursor)
            let rotationKey = fireHour + currentHour + index
            let content = SittingHourReminder.sittingHourNotificationContent(hour: rotationKey)

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: cursor
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: ID.sittingHour(index),
                content: content,
                trigger: trigger
            )

            center.add(request)

            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: cursor) else {
                break
            }
            cursor = nextHour
        }
    }

    func cancelSittingAlerts() {
        let ids = (0 ..< ID.sittingAlertCap).map(ID.sittingHour)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func scheduleCountdownComplete(at date: Date, posture: Posture) {
        cancelCountdownAlert()

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: ID.countdownCompletion,
            content: countdownCompleteContent(posture: posture),
            trigger: trigger
        )

        center.add(request)
    }

    func cancelCountdownAlert() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.countdownCompletion])
    }

    /// Cancels anything this scheduler owns (pause / teardown).
    func cancelAllDeskAlerts() {
        cancelSittingAlerts()
        cancelCountdownAlert()
    }
}
