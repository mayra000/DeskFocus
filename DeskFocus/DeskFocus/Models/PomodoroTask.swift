//
//  PomodoroTask.swift
//  DeskFocus
//

import Foundation
import SwiftData

@Model
final class PomodoroTask {
    private static let maxTitleLength = 200

    var id: String
    var title: String
    var done: Bool
    var order: Int

    init(title: String, order: Int, done: Bool = false, id: String? = nil) {
        self.id = id ?? UUID().uuidString
        self.title = String(title.prefix(Self.maxTitleLength))
        self.done = done
        self.order = order
    }
}
