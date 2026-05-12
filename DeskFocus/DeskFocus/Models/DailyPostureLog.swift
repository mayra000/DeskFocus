//
//  DailyPostureLog.swift
//  DeskFocus
//

import Foundation
import SwiftData

@Model
final class DailyPostureLog {
    var dayKey: String
    var date: Date
    var sittingMs: Int
    var standingMs: Int

    init(dayKey: String, date: Date, sittingMs: Int = 0, standingMs: Int = 0) {
        self.dayKey = dayKey
        self.date = date
        self.sittingMs = sittingMs
        self.standingMs = standingMs
    }
}
