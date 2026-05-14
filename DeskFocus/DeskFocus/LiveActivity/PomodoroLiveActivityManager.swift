//
//  PomodoroLiveActivityManager.swift
//  DeskFocus
//

import ActivityKit
import DeskFocusLiveSupport
import Foundation

/// Owns the Pomodoro Live Activity; mirrors `DeskSessionLiveActivityManager` lifecycle (scene-active gate).
@MainActor
final class PomodoroLiveActivityManager {

    /// Called immediately before requesting a Pomodoro Live Activity — end desk activities and refresh the desk manager’s references.
    var beforeRequestingPomodoroLiveActivity: (() async -> Void)?

    private var activity: Activity<PomodoroSessionActivityAttributes>?
    private var lastPushedState: PomodoroSessionActivityAttributes.ContentState?
    private var sceneIsActive = false
    private var startTask: Task<Void, Never>?
    /// Superseded starter tasks can overlap `Activity.request`; only the newest nonce wins.
    private var exclusiveStartNonce = 0

    func resetTrackedActivityAfterExternalTermination() {
        activity = nil
        lastPushedState = nil
    }

    func noteSceneBecameActive(syncing store: PomodoroStore) {
        sceneIsActive = true
        scheduleResync(store: store)
    }

    func noteSceneBecameInactive() {
        sceneIsActive = false
        startTask?.cancel()
        startTask = nil
    }

    func pomodoroStoreDidUpdate(_ store: PomodoroStore) {
        scheduleResync(store: store)
    }

    private func scheduleResync(store: PomodoroStore) {
        let state = contentState(from: store)
        let wantActivity = store.pomodoroLiveActivityVisible

        if !wantActivity {
            Task { await endActivityIfNeeded() }
            lastPushedState = nil
            return
        }

        guard state != lastPushedState else { return }

        if activity == nil {
            guard sceneIsActive else { return }
            enqueueStartIfNeeded(store: store, state: state)
        } else {
            Task { await pushUpdate(state: state) }
        }
    }

    private func enqueueStartIfNeeded(store: PomodoroStore, state: PomodoroSessionActivityAttributes.ContentState) {
        exclusiveStartNonce += 1
        let nonce = exclusiveStartNonce
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            await Task.yield()
            guard !Task.isCancelled, self.sceneIsActive else { return }
            guard nonce == self.exclusiveStartNonce else { return }
            let latest = self.contentState(from: store)
            guard store.pomodoroLiveActivityVisible else { return }
            await self.startOrRefresh(with: latest, nonce: nonce)
        }
    }

    private func startOrRefresh(with state: PomodoroSessionActivityAttributes.ContentState, nonce: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let activity {
            await LiveActivityDuplicateTeardown.endPomodoroSessionActivities(except: activity)
            await activity.update(.init(state: state, staleDate: nil))
            lastPushedState = state
            return
        }

        guard nonce == exclusiveStartNonce else { return }

        await beforeRequestingPomodoroLiveActivity?()

        guard nonce == exclusiveStartNonce else { return }

        await LiveActivityDuplicateTeardown.endAllPomodoroSessionActivities()
        self.activity = nil

        guard nonce == exclusiveStartNonce else { return }

        do {
            let newActivity = try Activity.request(
                attributes: PomodoroSessionActivityAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            guard nonce == exclusiveStartNonce else {
                await newActivity.end(nil, dismissalPolicy: .immediate)
                return
            }
            activity = newActivity
            lastPushedState = state
        } catch {
            activity = nil
        }
    }

    private func pushUpdate(state: PomodoroSessionActivityAttributes.ContentState) async {
        guard let activity else { return }
        await LiveActivityDuplicateTeardown.endPomodoroSessionActivities(except: activity)
        await activity.update(.init(state: state, staleDate: nil))
        lastPushedState = state
    }

    private func endActivityIfNeeded() async {
        startTask?.cancel()
        startTask = nil
        await LiveActivityDuplicateTeardown.endAllPomodoroSessionActivities()
        activity = nil
    }

    private func contentState(from store: PomodoroStore) -> PomodoroSessionActivityAttributes.ContentState {
        let now = Date()
        let running = store.running && store.remainingMs > 0
        let span = TimeInterval(store.remainingMs) / 1000
        /// One stable wall-clock interval per push; extension animates locally (avoids re-basing every tick).
        let endAt = running ? now.addingTimeInterval(span) : nil
        let startAt = running ? endAt?.addingTimeInterval(-span) : nil
        return PomodoroSessionActivityAttributes.ContentState(
            phaseRaw: store.phase.rawValue,
            isRunning: store.running,
            remainingMs: store.remainingMs,
            countdownStartAt: startAt,
            countdownEndsAt: endAt
        )
    }
}
