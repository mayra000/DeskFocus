//
//  DeskSessionLiveActivityManager.swift
//  DeskFocus
//

import ActivityKit
import DeskFocusLiveSupport
import Foundation

/// Owns the desk timer Live Activity: `Activity.request` runs only asynchronously after the scene is active.
@MainActor
final class DeskSessionLiveActivityManager {

    private var activity: Activity<DeskSessionActivityAttributes>?
    private var lastPushedState: DeskSessionActivityAttributes.ContentState?
    private var sceneIsActive = false
    private var startTask: Task<Void, Never>?

    func noteSceneBecameActive(syncing store: DeskSessionStore) {
        sceneIsActive = true
        scheduleResync(store: store)
    }

    func noteSceneBecameInactive() {
        sceneIsActive = false
        startTask?.cancel()
        startTask = nil
    }

    func deskSessionStoreDidPersist(_ store: DeskSessionStore) {
        scheduleResync(store: store)
    }

    private func scheduleResync(store: DeskSessionStore) {
        let state = contentState(from: store)
        let wantActivity = shouldKeepLiveActivityVisible(for: store)

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

    /// Kept across pause until the user clears the session or countdown completes (`DeskSessionStore.deskLiveActivityVisible`).
    private func shouldKeepLiveActivityVisible(for store: DeskSessionStore) -> Bool {
        store.deskLiveActivityVisible
    }

    private func enqueueStartIfNeeded(store: DeskSessionStore, state: DeskSessionActivityAttributes.ContentState) {
        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }
            await Task.yield()
            await Task.yield()
            guard !Task.isCancelled, self.sceneIsActive else { return }
            let latest = self.contentState(from: store)
            guard self.shouldKeepLiveActivityVisible(for: store) else { return }
            await self.startOrRefresh(with: latest)
        }
    }

    private func startOrRefresh(with state: DeskSessionActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let activity {
            await activity.update(.init(state: state, staleDate: nil))
            lastPushedState = state
            return
        }

        do {
            let newActivity = try Activity.request(
                attributes: DeskSessionActivityAttributes(),
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            activity = newActivity
            lastPushedState = state
        } catch {
            activity = nil
        }
    }

    private func pushUpdate(state: DeskSessionActivityAttributes.ContentState) async {
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

    private func contentState(from store: DeskSessionStore) -> DeskSessionActivityAttributes.ContentState {
        DeskSessionActivityAttributes.ContentState(
            postureRaw: store.posture.rawValue,
            displayModeRaw: store.sessionDisplayMode.rawValue,
            sessionPausedMs: store.sessionPausedMs,
            segmentStartedAt: store.runStartedAt,
            isRunning: store.running,
            countdownDurationMs: store.countdownDurationMs
        )
    }
}
