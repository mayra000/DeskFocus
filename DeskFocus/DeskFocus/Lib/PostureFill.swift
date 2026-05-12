//
//  PostureFill.swift
//  DeskFocus
//

import Foundation

private let postureFillWindowMs = 60 * 60 * 1000

/// Fill over a rolling 60-minute window (`0 ... 1`).
func postureFillRatio(elapsedMs: Int) -> Double {
    let e = max(0, elapsedMs)
    guard postureFillWindowMs > 0 else { return 0 }
    return min(1.0, Double(e) / Double(postureFillWindowMs))
}

/// Progress of a countdown or segment (`0 ... 1`) from elapsed amount vs total duration.
func countdownFillRatio(elapsed: Int, total: Int) -> Double {
    guard total > 0 else { return 0 }
    let e = max(0, elapsed)
    let ratio = Double(e) / Double(total)
    return min(1.0, max(0.0, ratio))
}
