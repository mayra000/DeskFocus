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

    private var activity: Activity<PomodoroSessionActivityAttributes>?
    private var lastPushedState: PomodoroSessionActivityAttributes.ContentState?
    private var sceneIsActive = false
    private var startTask: Task<Void, Never>?

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
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            await Task.yield()
            guard !Task.isCancelled, self.sceneIsActive else { return }
            let latest = self.contentState(from: store)
            guard store.pomodoroLiveActivityVisible else { return }
            await self.startOrRefresh(with: latest)
        }
    }

    private func startOrRefresh(with state: PomodoroSessionActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let activity {
            await activity.update(.init(state: state, staleDate: nil))
            lastPushedState = state
            return
        }

        do {
            let newActivity = try Activity.request(
                attributes: PomodoroSessionActivityAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            activity = newActivity
            lastPushedState = state
        } catch {
            activity = nil
        }
    }

    private func pushUpdate(state: PomodoroSessionActivityAttributes.ContentState) async {
        guard let activity else { return }
        await activity.update(.init(state: state, staleDate: nil))
        lastPushedState = state
    }

    private func endActivityIfNeeded() async {
        startTask?.cancel()
        startTask = nil
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }

    private func contentState(from store: PomodoroStore) -> PomodoroSessionActivityAttributes.ContentState {
        let now = Date()
        let running = store.running && store.remainingMs > 0
        let startAt = running ? now : nil
        let endAt = running ? now.addingTimeInterval(Double(store.remainingMs) / 1000) : nil
        return PomodoroSessionActivityAttributes.ContentState(
            phaseRaw: store.phase.rawValue,
            isRunning: store.running,
            remainingMs: store.remainingMs,
            countdownStartAt: startAt,
            countdownEndsAt: endAt
        )
    }
}
