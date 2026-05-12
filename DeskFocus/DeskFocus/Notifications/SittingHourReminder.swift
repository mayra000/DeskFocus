//
//  SittingHourReminder.swift
//  DeskFocus
//

import Foundation
import UserNotifications

/// Sitting-hour stretch cues (mirrors the web app’s ergonomics carousel).
enum SittingHourReminder {

    nonisolated static let stretchHints: [String] = [
        "Look at something 20+ feet away for 20 seconds—give your eyes a break.",
        "Roll your shoulders: up, back, and down in slow circles ×5.",
        "Interlace fingers, palms up—reach toward the ceiling and breathe in deeply.",
        "Chin retractions: gently tuck your chin, hold two seconds—repeat 10×.",
        "Stand briefly and hinge at hips with soft knees—let arms hang loose for 30 seconds.",
        "Open your chest: elbows wide, thumbs back, pinch shoulder blades lightly together.",
        "Wrist rotations: loosen hands for 30 seconds clockwise, then counter‑clockwise.",
        "Breathing reset: inhale four counts, exhale six—repeat six slow rounds.",
        "Lower trap wake‑up: small “W” elbows; squeeze blades without shrugging shoulders.",
        "Neck side bend: tilt ear toward shoulder alternate sides—stay smooth, avoid pain.",
        "Seated pelvic tilt three times forward and back—wake up hips and lumbar spine.",
        "Stand and march in place quietly for one minute—get blood moving.",
        "Open / close palms wide with straight elbows—stretch forearms ×10 reps.",
        "Wall angel: elbows and wrists on wall; slide arms up/down without ribs flaring.",
        "Ankle alphabet: trace big letters gently with toes on each foot—swap sides.",
        "Micro‑squat ×5 with chair support behind you—light load, tall spine.",
        "Face release: softly massage cheeks and temples with palms for thirty seconds.",
        "Reset posture cue: ribs stacked over hips, ribs soft—not flared.",
    ]

    /// Rotating cues keyed off a nominal hour bucket (typically `calendarHour + step`).
    static func sittingHourNotificationContent(hour: Int) -> UNMutableNotificationContent {
        guard !stretchHints.isEmpty else {
            let fallback = UNMutableNotificationContent()
            fallback.title = "Stretch break"
            fallback.body = "Take a posture break—you’ve been sitting a while."
            return fallback
        }

        let modulo = stretchHints.count
        let rotated = ((hour % modulo) + modulo) % modulo
        let body = stretchHints[rotated]

        let notification = UNMutableNotificationContent()
        notification.title = "Move for a minute"
        notification.body = body
        notification.sound = .default
        return notification
    }
}
