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
        static let streakMorning = "deskfocus.streak.morning"
        static let streakEvening = "deskfocus.streak.evening"
        static let streakMorningHour = 8
        static let streakEveningHour = 18
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

    // MARK: - Workday streak retention (standing goal)

    func cancelStreakReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.streakMorning, ID.streakEvening])
    }

    /// Schedules up to two one-shot reminders (morning / evening) when today’s standing is below goal on a workday.
    func rescheduleStreakReminders(now: Date, standingGoalMs: Int, todayStandingMs: Int) {
        cancelStreakReminders()

        guard standingGoalMs > 0, todayStandingMs < standingGoalMs, isWorkday(now) else {
            return
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)

        func scheduleIfFuture(hour: Int, identifier: String, content: UNMutableNotificationContent) {
            guard let fire = calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: dayStart
            ),
                fire > now
            else {
                return
            }
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fire
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }

        scheduleIfFuture(hour: ID.streakMorningHour, identifier: ID.streakMorning, content: Self.streakMorningContent())
        scheduleIfFuture(hour: ID.streakEveningHour, identifier: ID.streakEvening, content: Self.streakEveningContent())
    }

    private static func streakMorningContent() -> UNMutableNotificationContent {
        let notification = UNMutableNotificationContent()
        notification.title = "Keep your streak going"
        notification.body =
            "You haven’t hit today’s standing goal yet. Start a short standing block on the desk timer."
        notification.sound = .default
        return notification
    }

    private static func streakEveningContent() -> UNMutableNotificationContent {
        let notification = UNMutableNotificationContent()
        notification.title = "Still time for your streak"
        notification.body =
            "Log standing time before the day ends to meet your goal and protect your workday streak."
        notification.sound = .default
        return notification
    }
}
